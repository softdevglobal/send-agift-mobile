import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/data/auth_controller.dart';
import '../../data/reels_providers.dart';
import '../../domain/reel.dart';
import '../widgets/reel_card.dart';

/// Reels: sellers' clips as a full-screen vertical feed. Swipe up for the next
/// one, tap to hold the current one, and any reel with a product tagged offers
/// to send it as a gift.
class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  final PageController _pageController = PageController();
  int _index = 0;

  /// Reels already counted this session. `GET /reels/{id}` increments the
  /// count server-side, so a reel scrolled past twice must not count twice.
  final Set<String> _counted = <String>{};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// The API counts a view when the reel is fetched by id, so that call is
  /// made when a reel actually reaches the screen. Not when the page of
  /// results was loaded.
  void _countView(List<Reel> reels, int index) {
    if (index < 0 || index >= reels.length) return;
    final reel = reels[index];
    _syncLikes(reel.id);
    if (!_counted.add(reel.id)) return;
    ref.read(reelFeedProvider.notifier).registerView(reel.id);
  }

  /// The feed never says whether this customer liked a reel, so each one is
  /// asked about as it reaches the screen. A guest has nothing to ask.
  void _syncLikes(String reelId) {
    if (!ref.read(authProvider).isSignedIn) return;
    ref.read(reelFeedProvider.notifier).syncLikes(reelId);
  }

  void _onPageChanged(int index, List<Reel> reels) {
    setState(() => _index = index);
    _countView(reels, index);

    final loadedCount = reels.length;
    // Fetch the next page before the viewer reaches the end, so the feed
    // never stalls mid-swipe.
    if (index >= loadedCount - 3) {
      ref.read(reelFeedProvider.notifier).loadMore();
    }
  }

  void _advance(int reelCount) {
    // The last reel loops back to the top rather than dead-ending the feed.
    final next = _index + 1 >= reelCount ? 0 : _index + 1;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(reelFeedProvider);

    // Hearts belong to an account: drop them when it changes, and ask again
    // for the reel on screen once someone is signed in.
    ref.listen<bool>(authProvider.select((auth) => auth.isSignedIn),
        (_, signedIn) {
      final controller = ref.read(reelFeedProvider.notifier);
      controller.resetLikes();
      if (!signedIn) return;
      final reels = ref.read(reelFeedProvider).valueOrNull?.reels;
      if (reels != null && _index < reels.length) {
        controller.syncLikes(reels[_index].id);
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: feed.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (_, _) => _ReelsMessage(
          icon: Icons.wifi_off_rounded,
          title: 'Reels are offline',
          description:
              'We could not reach the marketplace just now. Pull up again in '
              'a moment.',
          action: OutlinedButton(
            onPressed: () => ref.read(reelFeedProvider.notifier).refresh(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
            ),
            child: const Text('Try again'),
          ),
        ),
        data: (state) {
          final reels = state.reels;
          if (reels.isEmpty) {
            return _ReelsMessage(
              icon: Icons.play_circle_outline_rounded,
              title: 'No reels yet',
              description:
                  'Sellers have not posted anything to watch yet. Browse the '
                  'shelves in the meantime.',
              action: ElevatedButton(
                onPressed: () => context.go(AppRoutes.explore),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
                child: const Text('Browse gifts'),
              ),
            );
          }

          // The first reel is on screen the moment the feed arrives, so it is
          // counted here rather than waiting for a page change.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _countView(reels, _index);
          });

          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: reels.length,
                onPageChanged: (index) => _onPageChanged(index, reels),
                itemBuilder: (context, index) => ReelCard(
                  reel: reels[index],
                  isActive: index == _index,
                  onCompleted: () => _advance(reels.length),
                ),
              ),
              const _ReelsHeader(),
            ],
          );
        },
      ),
    );
  }
}

/// Screen title, sitting over the clip rather than in an app bar so the feed
/// keeps the full height.
class _ReelsHeader extends StatelessWidget {
  const _ReelsHeader();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 24,
      left: 20,
      child: Text('Reels', style: AppTypography.display(24, color: Colors.white)),
    );
  }
}

/// Empty and error states share the dark ground, so the feed never flashes a
/// white page between states.
class _ReelsMessage extends StatelessWidget {
  const _ReelsMessage({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // EmptyState reads its colours from the theme; on black it needs the
      // light-on-dark pairing.
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: Colors.white70,
              displayColor: Colors.white,
            ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      child: EmptyState(
        icon: icon,
        title: title,
        description: description,
        action: action,
      ),
    );
  }
}
