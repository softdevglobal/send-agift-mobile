import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/reel.dart';

/// One page of the public reel feed.
class ReelPage {
  const ReelPage({required this.reels, this.nextCursor});

  final List<Reel> reels;

  /// Cursor for the page after this one; null on the last page.
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  static const empty = ReelPage(reels: []);
}

/// Reads `GET /reels`. The public, unauthenticated reel feed.
///
/// Only published, public reels from active shops come back, so the feed is
/// safe to show a guest. Paging is by keyset cursor, which means a reel posted
/// while someone is scrolling never shifts the page under them.
class ReelsRepository {
  ReelsRepository(this._client);

  final ApiClient _client;

  static const int _pageSize = 12;

  /// Fetches a page of the feed.
  ///
  /// [scope] mirrors the API: `all` (default), `product` for reels tagged to a
  /// product, `shop` for a shop's own promos.
  Future<ReelPage> loadFeed({String? cursor, String scope = 'all'}) async {
    final response = await _client.dio.get<dynamic>(
      '/reels',
      queryParameters: {
        'limit': _pageSize,
        'scope': scope,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) return ReelPage.empty;

    final items = (data['items'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(Reel.fromJson)
            // A reel whose media is all private has nothing to show; dropping
            // it here keeps blank pages out of the feed.
            .where((reel) => reel.hasVideo || reel.imageUrl != null)
            .toList(growable: false) ??
        const <Reel>[];

    return ReelPage(
      reels: items,
      nextCursor: data['next_cursor'] as String?,
    );
  }

  /// Counts a view.
  ///
  /// `GET /reels/{id}` increments `view_count` server-side and returns the
  /// already-incremented reel, so the number the feed shows is the one the
  /// database now holds rather than a guess.
  Future<Reel?> registerView(String reelId) async {
    try {
      final response = await _client.dio.get<dynamic>('/reels/$reelId');
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return Reel.fromJson(data);
    } on DioException {
      // A missed view is not worth interrupting playback for.
      return null;
    }
  }
}
