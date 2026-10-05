import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/providers.dart';
import '../domain/reel.dart';
import 'reel_social_repository.dart';
import 'reels_repository.dart';

final reelsRepositoryProvider = Provider<ReelsRepository>((ref) {
  return ReelsRepository(ref.watch(apiClientProvider));
});

final reelSocialRepositoryProvider = Provider<ReelSocialRepository>((ref) {
  return ReelSocialRepository(ref.watch(apiClientProvider));
});

/// The reel feed as the screen sees it: the reels loaded so far, plus whether
/// there is another page behind them.
class ReelFeedState {
  const ReelFeedState({
    this.reels = const [],
    this.cursor,
    this.loadingMore = false,
  });

  final List<Reel> reels;
  final String? cursor;
  final bool loadingMore;

  bool get hasMore => cursor != null && cursor!.isNotEmpty;

  ReelFeedState copyWith({
    List<Reel>? reels,
    String? cursor,
    bool? loadingMore,
  }) {
    return ReelFeedState(
      reels: reels ?? this.reels,
      cursor: cursor,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

/// Loads the first page of the feed, then appends the next one as the viewer
/// nears the end. The feed should never dead-end while the API still has
/// reels to give.
class ReelFeedController extends StateNotifier<AsyncValue<ReelFeedState>> {
  ReelFeedController(this._repository, this._social)
      : super(const AsyncValue.loading()) {
    refresh();
  }

  final ReelsRepository _repository;

  /// Read lazily: nothing here touches likes until someone acts on a reel,
  /// and a feed that is only being watched should not need it.
  final ReelSocialRepository Function() _social;

  /// Reels whose liked state has been asked for under the current session.
  final Set<String> _likesSynced = <String>{};

  /// A second tap on the heart while the first is in flight would race it.
  final Set<String> _likesPending = <String>{};

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    _likesSynced.clear();
    try {
      final page = await _repository.loadFeed();
      state = AsyncValue.data(
        ReelFeedState(reels: page.reels, cursor: page.nextCursor),
      );
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  /// Re-reads the current view, like and comment counts without counting a
  /// view.
  ///
  /// The feed lives for as long as the app does, so counts otherwise freeze
  /// at whatever they were when the tab was first opened. And drift away
  /// from what another client (or the website) shows. Listing reels does not
  /// increment anything, so this is safe to call whenever the tab is opened.
  Future<void> refreshViewCounts() async {
    final current = state.valueOrNull;
    if (current == null || current.reels.isEmpty) return;

    try {
      final page = await _repository.loadFeed();
      final fresh = {for (final reel in page.reels) reel.id: reel};

      final latest = state.valueOrNull;
      if (latest == null) return;

      state = AsyncValue.data(
        latest.copyWith(
          reels: [
            for (final reel in latest.reels)
              if (fresh[reel.id] case final update?)
                // The feed never knows who is asking, so the viewer's own
                // liked state is kept rather than reset to false.
                reel.copyWith(
                  viewCount: update.viewCount,
                  likeCount: update.likeCount,
                  commentCount: update.commentCount,
                  recentLikers: update.recentLikers,
                  comments: update.comments,
                )
              else
                reel,
          ],
          cursor: latest.cursor,
        ),
      );
    } catch (_) {
      // Stale counts are better than an error over something this small.
    }
  }

  /// Records that this reel was watched, and folds the count the API returns
  /// back into the feed so the rail shows the real number.
  Future<void> registerView(String reelId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = await _repository.registerView(reelId);
    if (updated == null) return;

    patchReel(reelId, (reel) => reel.withViewCount(updated.viewCount));
  }

  Reel? reelById(String reelId) {
    for (final reel in state.valueOrNull?.reels ?? const <Reel>[]) {
      if (reel.id == reelId) return reel;
    }
    return null;
  }

  /// Swaps one reel for an updated copy. A like, a new comment. Without
  /// reloading the page it sits on.
  void patchReel(String reelId, Reel Function(Reel reel) update) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        reels: [
          for (final reel in current.reels)
            reel.id == reelId ? update(reel) : reel,
        ],
        cursor: current.cursor,
      ),
    );
  }

  /// Fills in the heart for a reel now on screen. Only call it for a signed-in
  /// customer. For anyone else the answer is always "not liked".
  Future<void> syncLikes(String reelId) async {
    if (!_likesSynced.add(reelId)) return;
    try {
      final likes = await _social().getLikes(reelId);
      patchReel(
        reelId,
        (reel) => reel.copyWith(
          likedByMe: likes.likedByRequester,
          likeCount: likes.likeCount,
          recentLikers: likes.recentLikers,
        ),
      );
    } catch (_) {
      // Ask again the next time it comes into view.
      _likesSynced.remove(reelId);
    }
  }

  /// Forgets every heart. On sign-out they belong to nobody, and on sign-in
  /// they have to be asked for again under the new account.
  void resetLikes() {
    _likesSynced.clear();
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        reels: [
          for (final reel in current.reels)
            reel.likedByMe ? reel.copyWith(likedByMe: false) : reel,
        ],
        cursor: current.cursor,
      ),
    );
  }

  /// Likes or unlikes for the signed-in customer. The heart answers at once;
  /// the API then settles the count. Throws when the change did not stick, so
  /// the caller can say why.
  Future<void> toggleLike(String reelId) async {
    final reel = reelById(reelId);
    if (reel == null || !_likesPending.add(reelId)) return;

    final like = !reel.likedByMe;
    patchReel(
      reelId,
      (current) => current.copyWith(
        likedByMe: like,
        likeCount: math.max(0, current.likeCount + (like ? 1 : -1)),
      ),
    );

    try {
      final social = _social();
      final result =
          like ? await social.like(reelId) : await social.unlike(reelId);
      patchReel(
        reelId,
        (current) => current.copyWith(
          likedByMe: result.liked,
          likeCount: result.likeCount,
        ),
      );
    } on AppException catch (error) {
      if (!like && error.statusCode == 404) {
        // Already unliked elsewhere. An empty heart is right.
        patchReel(reelId, (current) => current.copyWith(likedByMe: false));
      } else {
        patchReel(
          reelId,
          (current) => current.copyWith(
            likedByMe: reel.likedByMe,
            likeCount: reel.likeCount,
          ),
        );
        rethrow;
      }
    } finally {
      _likesPending.remove(reelId);
    }

    // "Liked by …" names come from the server, so re-read them after a change.
    _likesSynced.remove(reelId);
    await syncLikes(reelId);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncValue.data(current.copyWith(
      cursor: current.cursor,
      loadingMore: true,
    ));

    try {
      final page = await _repository.loadFeed(cursor: current.cursor);
      final latest = state.valueOrNull ?? current;
      state = AsyncValue.data(
        ReelFeedState(
          // Built on the latest reels, not the snapshot from before the
          // request, so a like or comment made meanwhile is not lost.
          reels: [...latest.reels, ...page.reels],
          cursor: page.nextCursor,
        ),
      );
    } catch (_) {
      // Keep what is already on screen; the next scroll can try again.
      final latest = state.valueOrNull ?? current;
      state = AsyncValue.data(latest.copyWith(
        cursor: latest.cursor,
        loadingMore: false,
      ));
    }
  }
}

final reelFeedProvider =
    StateNotifierProvider<ReelFeedController, AsyncValue<ReelFeedState>>((ref) {
  return ReelFeedController(
    ref.watch(reelsRepositoryProvider),
    () => ref.read(reelSocialRepositoryProvider),
  );
});
