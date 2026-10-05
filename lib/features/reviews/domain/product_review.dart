// Verified-purchase product reviews.
//
// A review always belongs to a delivered order line. The API refuses to
// create one any other way, and UNIQUE(order_item_id) stops the same purchase
// being reviewed twice. That is why writing one is addressed by order item
// rather than by product.

/// One photo or video attached to a review.
class ReviewMedia {
  const ReviewMedia({
    required this.mediaAssetId,
    required this.position,
    required this.assetType,
    required this.objectPath,
    required this.mimeType,
    this.cdnUrl,
  });

  final String mediaAssetId;
  final int position;

  /// `image` or `video`.
  final String assetType;
  final String objectPath;
  final String mimeType;
  final String? cdnUrl;

  bool get isVideo => assetType == 'video' || mimeType.startsWith('video/');

  factory ReviewMedia.fromJson(Map<String, dynamic> json) {
    return ReviewMedia(
      mediaAssetId: json['media_asset_id'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      assetType: json['asset_type'] as String? ?? 'image',
      objectPath: json['object_path'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? '',
      cdnUrl: json['cdn_url'] as String?,
    );
  }
}

/// How a review's author is shown. Already "Anonymous" when they asked for it.
class ReviewAuthor {
  const ReviewAuthor({this.displayName, this.imageUrl});

  final String? displayName;
  final String? imageUrl;

  factory ReviewAuthor.fromJson(Map<String, dynamic> json) {
    return ReviewAuthor(
      displayName: json['display_name'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

class ProductReview {
  const ProductReview({
    required this.id,
    required this.productId,
    required this.orderItemId,
    required this.rating,
    required this.productQualityRating,
    required this.shippingRating,
    required this.sellerServiceRating,
    required this.isAnonymous,
    required this.helpfulCount,
    required this.createdAt,
    this.title,
    this.body,
    this.sellerReply,
    this.sellerRepliedAt,
    this.media = const [],
    this.author,
    this.votedHelpful,
  });

  final String id;
  final String productId;
  final String orderItemId;
  final int rating;
  final int productQualityRating;
  final int shippingRating;
  final int sellerServiceRating;
  final String? title;
  final String? body;
  final bool isAnonymous;
  final String? sellerReply;
  final DateTime? sellerRepliedAt;
  final int helpfulCount;
  final DateTime createdAt;
  final List<ReviewMedia> media;
  final ReviewAuthor? author;

  /// Only set when the caller is a signed-in customer who voted on this review.
  final bool? votedHelpful;

  bool get hasVoted => votedHelpful == true;

  String get authorName {
    if (isAnonymous) return 'Anonymous';
    final name = author?.displayName?.trim();
    return (name == null || name.isEmpty) ? 'Customer' : name;
  }

  /// A local copy with the vote applied, so a tap can update the row before
  /// the server answers.
  ProductReview withVote({required bool voted, required int helpfulCount}) {
    return ProductReview(
      id: id,
      productId: productId,
      orderItemId: orderItemId,
      rating: rating,
      productQualityRating: productQualityRating,
      shippingRating: shippingRating,
      sellerServiceRating: sellerServiceRating,
      title: title,
      body: body,
      isAnonymous: isAnonymous,
      sellerReply: sellerReply,
      sellerRepliedAt: sellerRepliedAt,
      helpfulCount: helpfulCount,
      createdAt: createdAt,
      media: media,
      author: author,
      votedHelpful: voted ? true : null,
    );
  }

  factory ProductReview.fromJson(Map<String, dynamic> json) {
    final rawMedia = json['media'];
    final rawCustomer = json['customer'];
    return ProductReview(
      id: json['id'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      orderItemId: json['order_item_id'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      productQualityRating:
          (json['product_quality_rating'] as num?)?.toInt() ?? 0,
      shippingRating: (json['shipping_rating'] as num?)?.toInt() ?? 0,
      sellerServiceRating: (json['seller_service_rating'] as num?)?.toInt() ?? 0,
      title: json['title'] as String?,
      body: json['body'] as String?,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      sellerReply: json['seller_reply'] as String?,
      sellerRepliedAt: DateTime.tryParse(
        json['seller_replied_at'] as String? ?? '',
      ),
      helpfulCount: (json['helpful_count'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      media: rawMedia is List
          ? rawMedia
                .whereType<Map<String, dynamic>>()
                .map(ReviewMedia.fromJson)
                .toList(growable: false)
          : const [],
      author: rawCustomer is Map<String, dynamic>
          ? ReviewAuthor.fromJson(rawCustomer)
          : null,
      votedHelpful: json['voted_helpful'] as bool?,
    );
  }
}

/// A page of reviews. [nextCursor] is null on the last page.
class ReviewPage {
  const ReviewPage({required this.items, this.nextCursor});

  final List<ProductReview> items;
  final String? nextCursor;

  factory ReviewPage.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    return ReviewPage(
      items: items is List
          ? items
                .whereType<Map<String, dynamic>>()
                .map(ProductReview.fromJson)
                .toList(growable: false)
          : const [],
      nextCursor: json['next_cursor'] as String?,
    );
  }
}

/// The aggregate shown above a product's reviews.
class ReviewSummary {
  const ReviewSummary({
    required this.reviewCount,
    required this.avgRating,
    required this.avgQuality,
    required this.avgShipping,
    required this.avgService,
    required this.breakdown,
  });

  final int reviewCount;
  final double avgRating;
  final double avgQuality;
  final double avgShipping;
  final double avgService;

  /// Stars (1–5) → how many reviews gave that score.
  final Map<int, int> breakdown;

  static const empty = ReviewSummary(
    reviewCount: 0,
    avgRating: 0,
    avgQuality: 0,
    avgShipping: 0,
    avgService: 0,
    breakdown: {},
  );

  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['rating_breakdown'];
    final breakdown = <int, int>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        final stars = int.tryParse('$key');
        final count = (value as num?)?.toInt();
        if (stars != null && count != null) breakdown[stars] = count;
      });
    }
    return ReviewSummary(
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
      avgQuality:
          (json['avg_product_quality_rating'] as num?)?.toDouble() ?? 0,
      avgShipping: (json['avg_shipping_rating'] as num?)?.toDouble() ?? 0,
      avgService:
          (json['avg_seller_service_rating'] as num?)?.toDouble() ?? 0,
      breakdown: breakdown,
    );
  }
}

/// A file already uploaded to storage, ready to attach to a review.
class ReviewMediaUpload {
  const ReviewMediaUpload({
    required this.objectPath,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String objectPath;
  final String mimeType;
  final int sizeBytes;

  bool get isVideo => mimeType.startsWith('video/');

  Map<String, dynamic> toJson() => {
    'object_path': objectPath,
    'mime_type': mimeType,
    'size_bytes': sizeBytes,
  };
}

/// The body for creating or editing a review.
class ReviewDraft {
  const ReviewDraft({
    required this.rating,
    required this.qualityRating,
    required this.shippingRating,
    required this.serviceRating,
    required this.isAnonymous,
    this.title,
    this.body,
    this.media = const [],
  });

  final int rating;
  final int qualityRating;
  final int shippingRating;
  final int serviceRating;
  final String? title;
  final String? body;
  final bool isAnonymous;
  final List<ReviewMediaUpload> media;

  Map<String, dynamic> toJson() => {
    'rating': rating,
    // The API wants 1–5 on every dimension, so an untouched sub-score goes up
    // as the overall rather than as an invalid 0.
    'product_quality_rating': qualityRating == 0 ? rating : qualityRating,
    'shipping_rating': shippingRating == 0 ? rating : shippingRating,
    'seller_service_rating': serviceRating == 0 ? rating : serviceRating,
    'title': title,
    'body': body,
    'is_anonymous': isAnonymous,
    'media': media.map((item) => item.toJson()).toList(growable: false),
  };
}
