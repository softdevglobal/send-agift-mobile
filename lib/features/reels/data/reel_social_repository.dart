import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/reel_social.dart';

/// Likes and comments on reels.
///
/// Reads are public. Writes ride on the signed-in customer's bearer token,
/// which [ApiClient] attaches on its own. The API also takes an
/// `X-Guest-Token`, but the app only lets signed-in customers like and
/// comment.
class ReelSocialRepository {
  ReelSocialRepository(this._client);

  final ApiClient _client;

  static const int commentPageSize = 20;

  /// Like count, the newest likers, and whether this customer liked it. The
  /// feed itself never says the last part, so this fills in the heart.
  Future<ReelLikes> getLikes(String reelId) => _guard(() async {
        final response = await _client.dio.get<dynamic>('/reels/$reelId/likes');
        return ReelLikes.fromJson(_map(response.data));
      });

  /// Idempotent: liking twice leaves one like.
  Future<ReelLikeResult> like(String reelId) => _guard(() async {
        final response =
            await _client.dio.post<dynamic>('/reels/$reelId/likes');
        return ReelLikeResult.fromJson(_map(response.data));
      });

  /// Fails with 404 when this customer has no like on the reel.
  Future<ReelLikeResult> unlike(String reelId) => _guard(() async {
        final response =
            await _client.dio.delete<dynamic>('/reels/$reelId/likes');
        return ReelLikeResult.fromJson(_map(response.data));
      });

  Future<ReelCommentPage> listComments(String reelId, {String? cursor}) =>
      _guard(() async {
        final response = await _client.dio.get<dynamic>(
          '/reels/$reelId/comments',
          queryParameters: {
            'limit': commentPageSize,
            if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
          },
        );
        final data = _map(response.data);
        return ReelCommentPage(
          items: ReelComment.listFromJson(data['items']),
          nextCursor: data['next_cursor'] as String?,
        );
      });

  /// Posts as the customer. Or, with [anonymous], under [nickname] (the API
  /// falls back to "Anonymous" when it is blank).
  Future<ReelComment> createComment(
    String reelId, {
    required String body,
    bool anonymous = false,
    String? nickname,
  }) =>
      _guard(() async {
        final trimmedNickname = nickname?.trim() ?? '';
        final response = await _client.dio.post<dynamic>(
          '/reels/$reelId/comments',
          data: {
            'body': body,
            'is_anonymous': anonymous,
            if (anonymous && trimmedNickname.isNotEmpty)
              'display_name': trimmedNickname,
          },
        );
        return ReelComment.fromJson(_map(response.data));
      });

  /// Author only; anyone else gets a 404.
  Future<ReelComment> updateComment(
    String reelId,
    String commentId,
    String body,
  ) =>
      _guard(() async {
        final response = await _client.dio.put<dynamic>(
          '/reels/$reelId/comments/$commentId',
          data: {'body': body},
        );
        return ReelComment.fromJson(_map(response.data));
      });

  /// Author only. A soft delete. The comment drops out of every list.
  Future<void> deleteComment(String reelId, String commentId) =>
      _guard(() async {
        await _client.dio.delete<dynamic>('/reels/$reelId/comments/$commentId');
      });

  // ─── Comments this customer posted from this device ──────────────────────
  //
  // The API checks authorship on edit and delete but never says who wrote a
  // comment, so the app remembers its own to know where to offer those
  // controls. Keyed by customer so a shared phone does not hand one person's
  // controls to the next.

  static const _ownPrefix = 'reel_comments_mine_v1_';
  static const _maxTracked = 500;

  Future<Set<String>> ownCommentIds(String? customerId) async {
    if (customerId == null) return const {};
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('$_ownPrefix$customerId') ?? const []).toSet();
  }

  Future<void> rememberOwnComment(String? customerId, String commentId) async {
    if (customerId == null) return;
    final ids = {...await ownCommentIds(customerId), commentId}.toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      '$_ownPrefix$customerId',
      ids.length > _maxTracked ? ids.sublist(ids.length - _maxTracked) : ids,
    );
  }

  Future<void> forgetOwnComment(String? customerId, String commentId) async {
    if (customerId == null) return;
    final ids = {...await ownCommentIds(customerId)};
    if (!ids.remove(commentId)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_ownPrefix$customerId', ids.toList());
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  static Map<String, dynamic> _map(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    throw const AppException('Unexpected response from the server.');
  }
}
