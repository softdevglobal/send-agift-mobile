/// Likes and comments on a reel, as the public API shapes them.
///
/// The API never exposes who is behind a like or comment. No customer ids,
/// no guest tokens. Only a type and a display name.
library;

/// Someone who liked a reel.
class ReelLiker {
  const ReelLiker({required this.type, required this.displayName});

  /// `customer` or `guest`.
  final String type;
  final String displayName;

  factory ReelLiker.fromJson(Map<String, dynamic> json) {
    return ReelLiker(
      type: json['type'] as String? ?? 'guest',
      displayName: (json['display_name'] as String?)?.trim() ?? '',
    );
  }

  static List<ReelLiker> listFromJson(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(ReelLiker.fromJson)
        .toList(growable: false);
  }
}

/// One visible comment.
class ReelComment {
  const ReelComment({
    required this.id,
    required this.reelId,
    required this.body,
    required this.isAnonymous,
    required this.authorType,
    required this.authorName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String reelId;
  final String body;
  final bool isAnonymous;

  /// `customer` (their own name) or `anonymous` (a chosen nickname).
  final String authorType;
  final String authorName;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCustomer => authorType == 'customer';

  /// The API bumps `updated_at` on an edit; a second of slack covers the
  /// insert itself.
  bool get isEdited => updatedAt.difference(createdAt).inSeconds >= 1;

  factory ReelComment.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    final created = _date(json['created_at']);
    return ReelComment(
      id: json['id'] as String? ?? '',
      reelId: json['reel_id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      authorType: author?['type'] as String? ?? 'anonymous',
      authorName: (author?['display_name'] as String?)?.trim().isNotEmpty == true
          ? (author!['display_name'] as String).trim()
          : 'Anonymous',
      createdAt: created,
      updatedAt: json['updated_at'] == null ? created : _date(json['updated_at']),
    );
  }

  static List<ReelComment> listFromJson(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(ReelComment.fromJson)
        .toList(growable: false);
  }

  static DateTime _date(dynamic value) =>
      (value is String ? DateTime.tryParse(value) : null) ?? DateTime.now();
}

/// A page of comments, newest first.
class ReelCommentPage {
  const ReelCommentPage({required this.items, this.nextCursor});

  final List<ReelComment> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}

/// `GET /reels/{id}/likes`. [likedByRequester] is only true when the request
/// carried the signed-in customer's token.
class ReelLikes {
  const ReelLikes({
    required this.likeCount,
    required this.likedByRequester,
    required this.recentLikers,
  });

  final int likeCount;
  final bool likedByRequester;
  final List<ReelLiker> recentLikers;

  factory ReelLikes.fromJson(Map<String, dynamic> json) {
    return ReelLikes(
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      likedByRequester: json['liked_by_requester'] as bool? ?? false,
      recentLikers: ReelLiker.listFromJson(json['recent_likers']),
    );
  }
}

/// What like and unlike return.
class ReelLikeResult {
  const ReelLikeResult({required this.liked, required this.likeCount});

  final bool liked;
  final int likeCount;

  factory ReelLikeResult.fromJson(Map<String, dynamic> json) {
    return ReelLikeResult(
      liked: json['liked'] as bool? ?? false,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
    );
  }
}
