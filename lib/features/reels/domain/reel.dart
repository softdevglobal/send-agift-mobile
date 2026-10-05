import '../../../core/utils/money.dart';
import 'reel_social.dart';

/// One reel from `GET /reels`. A seller's short video (or photo post),
/// optionally tagged to a product.
///
/// A reel with a [product] is the whole point of the feed: it is a gift you
/// can watch and then send. A reel without one is a shop's own promo, which
/// still plays but has nothing to buy.
class Reel {
  const Reel({
    required this.id,
    required this.shopName,
    this.shopId,
    this.shopImageUrl,
    this.caption,
    this.hashtags = const [],
    this.videoUrl,
    this.imageUrl,
    this.photoUrls = const [],
    this.product,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
    this.recentLikers = const [],
    this.comments = const [],
  });

  final String id;
  final String shopName;
  final String? shopId;
  final String? shopImageUrl;
  final String? caption;
  final List<String> hashtags;

  /// First playable video on the reel, if it has one.
  final String? videoUrl;

  /// The still shown while a video loads. And the first frame of a photo
  /// post. Falls back through thumbnail → first image → the product's photo.
  final String? imageUrl;

  /// Every image on the reel, in the order the seller arranged them. A photo
  /// post can carry up to ten, which the feed shows as a carousel.
  final List<String> photoUrls;

  /// The tagged product. Null for a shop's own promo reel.
  final ReelProduct? product;

  final int viewCount;
  final int likeCount;
  final int commentCount;

  /// Whether the signed-in customer liked it. The public feed never fills
  /// this in, so it stays false until `GET /reels/{id}/likes` says otherwise.
  final bool likedByMe;

  /// Newest likers, names only.
  final List<ReelLiker> recentLikers;

  /// Visible comments the feed carried, newest first.
  final List<ReelComment> comments;

  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;

  /// True when this is a photo post with more than one frame to swipe through.
  bool get isCarousel => !hasVideo && photoUrls.length > 1;

  Reel copyWith({
    int? viewCount,
    int? likeCount,
    int? commentCount,
    bool? likedByMe,
    List<ReelLiker>? recentLikers,
    List<ReelComment>? comments,
  }) {
    return Reel(
      id: id,
      shopName: shopName,
      shopId: shopId,
      shopImageUrl: shopImageUrl,
      caption: caption,
      hashtags: hashtags,
      videoUrl: videoUrl,
      imageUrl: imageUrl,
      photoUrls: photoUrls,
      product: product,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedByMe: likedByMe ?? this.likedByMe,
      recentLikers: recentLikers ?? this.recentLikers,
      comments: comments ?? this.comments,
    );
  }

  /// The same reel with a fresh view count, after the API has counted a view.
  Reel withViewCount(int count) => copyWith(viewCount: count);

  /// True when there is something to send. Drives the gift CTA.
  bool get isShoppable => product != null;

  /// Hashtags as one displayable line, each back in `#tag` form (the API
  /// stores them stripped and lowercased).
  String get hashtagLine =>
      hashtags.isEmpty ? '' : hashtags.map((tag) => '#$tag').join(' ');

  /// "Liked by Aisha and 12 others". Only the newest likers have names;
  /// everyone past them is folded into the count.
  String? get likersLine {
    final names = recentLikers
        .map((liker) => liker.displayName)
        .where((name) => name.isNotEmpty)
        .toList();
    if (likeCount <= 0 || names.isEmpty) return null;
    final others = likeCount - 1;
    if (others <= 0) return 'Liked by ${names.first}';
    return 'Liked by ${names.first} and ${compactCount(others)} '
        '${others == 1 ? 'other' : 'others'}';
  }

  factory Reel.fromJson(Map<String, dynamic> json) {
    // `position` is the seller's ordering of a carousel. The API already
    // sorts by it; sorting again costs nothing and keeps the order right if a
    // response ever arrives out of order.
    final media = (json['media'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        <Map<String, dynamic>>[];
    media.sort((a, b) {
      final left = (a['position'] as num?)?.toInt() ?? 0;
      final right = (b['position'] as num?)?.toInt() ?? 0;
      return left.compareTo(right);
    });

    final photos = _urlsOfType(media, 'image');

    final shop = json['shop'] as Map<String, dynamic>?;
    final product = json['product'] as Map<String, dynamic>?;

    return Reel(
      id: json['id'] as String? ?? '',
      shopId: shop?['id'] as String?,
      shopName: (shop?['name'] as String?)?.trim().isNotEmpty == true
          ? shop!['name'] as String
          : 'Send A Gift',
      shopImageUrl: _url(shop?['image_url']),
      caption: (json['caption'] as String?)?.trim(),
      hashtags: (json['hashtags'] as List?)
              ?.map((tag) => tag.toString())
              .where((tag) => tag.isNotEmpty)
              .toList(growable: false) ??
          const [],
      videoUrl: _firstUrlOfType(media, 'video'),
      imageUrl: _mediaUrl(json['thumbnail'] as Map<String, dynamic>?) ??
          (photos.isNotEmpty ? photos.first : null) ??
          _url(product?['image_url']),
      photoUrls: photos,
      product: product == null ? null : ReelProduct.fromJson(product),
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] as bool? ?? false,
      recentLikers: ReelLiker.listFromJson(json['recent_likers']),
      comments: ReelComment.listFromJson(json['comments']),
    );
  }

  /// Media is playable only through `cdn_url`, which the API fills in just for
  /// objects under `public/`. A private object has no URL the app can open, so
  /// it is treated as absent rather than surfaced as a broken player.
  static String? _mediaUrl(Map<String, dynamic>? item) =>
      item == null ? null : _url(item['cdn_url']);

  static String? _firstUrlOfType(
    List<Map<String, dynamic>> media,
    String assetType,
  ) {
    final urls = _urlsOfType(media, assetType);
    return urls.isEmpty ? null : urls.first;
  }

  static List<String> _urlsOfType(
    List<Map<String, dynamic>> media,
    String assetType,
  ) {
    final urls = <String>[];
    for (final item in media) {
      if (item['asset_type'] != assetType) continue;
      final url = _mediaUrl(item);
      if (url != null) urls.add(url);
    }
    return List.unmodifiable(urls);
  }

  static String? _url(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// 1200 → "1.2K". Reel overlays have room for a glance, not a full number.
String compactCount(int count) {
  if (count < 1000) return '$count';
  if (count < 1000000) {
    final thousands = count / 1000;
    return '${thousands.toStringAsFixed(thousands < 10 ? 1 : 0)}K';
  }
  final millions = count / 1000000;
  return '${millions.toStringAsFixed(millions < 10 ? 1 : 0)}M';
}

/// The product tagged on a reel. Enough to show a price and open the gift.
class ReelProduct {
  const ReelProduct({
    required this.id,
    required this.name,
    required this.priceAmount,
    required this.currency,
    this.imageUrl,
  });

  final String id;
  final String name;
  final int priceAmount;
  final String currency;
  final String? imageUrl;

  String get priceLabel => Money.format(priceAmount, currency);

  factory ReelProduct.fromJson(Map<String, dynamic> json) {
    return ReelProduct(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Gift',
      priceAmount: (json['price_amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      imageUrl: Reel._url(json['image_url']),
    );
  }
}
