import '../../../core/utils/money.dart';
import 'gift_category.dart';
import 'shop.dart';

/// A published product presented as a giftable item.
///
/// Prices come from the API in minor units alongside a currency code, matching
/// the backend's `Product` model; [priceLabel] is the only display path.
class Gift {
  const Gift({
    required this.id,
    required this.name,
    required this.priceAmount,
    required this.currency,
    required this.image,
    this.description = '',
    this.categoryId = '',
    this.shopId,
    this.shopName,
    this.shopImageUrl,
    this.sellerId,
    this.compareAtAmount,
    this.rating = 0,
    this.reviewCount = 0,
    this.prepMinutes = 0,
    this.occasionTags = const [],
    this.rewardPoints = 0,
    this.media = const [],
  });

  final String id;
  final String name;
  final int priceAmount;
  final String currency;
  final String image;
  final String description;
  final String categoryId;
  final String? shopId;
  final String? shopName;
  final String? shopImageUrl;
  final String? sellerId;
  final int? compareAtAmount;
  final double rating;
  final int reviewCount;
  final int prepMinutes;
  final List<String> occasionTags;

  /// Points earned per unit once the order is delivered. The API sends 0 when
  /// the seller cannot currently pay the reward, so any value here is real.
  final int rewardPoints;

  /// Every photo and video the seller added, photos first starting with the
  /// cover, then videos. Empty for a gift with only [image].
  final List<GiftMedia> media;

  /// What the gift page shows: [media], or just [image] when there is none.
  List<GiftMedia> get gallery =>
      media.isNotEmpty ? media : [GiftMedia(url: image, isVideo: false)];

  /// The same gift labelled with its shop, for results that carry the shop
  /// name beside the product rather than inside it.
  Gift withShopName(String name) => Gift(
    id: id,
    name: this.name,
    priceAmount: priceAmount,
    currency: currency,
    image: image,
    description: description,
    categoryId: categoryId,
    shopId: shopId,
    shopName: name.trim().isEmpty ? shopName : name,
    shopImageUrl: shopImageUrl,
    sellerId: sellerId,
    compareAtAmount: compareAtAmount,
    rating: rating,
    reviewCount: reviewCount,
    prepMinutes: prepMinutes,
    occasionTags: occasionTags,
    rewardPoints: rewardPoints,
    media: media,
  );

  String get priceLabel => Money.format(priceAmount, currency);

  String? get compareAtLabel =>
      compareAtAmount == null ? null : Money.format(compareAtAmount!, currency);

  String get categoryLabel => GiftCategory.nameFor(categoryId);

  /// True when the gift is filed under [category]. A seller can pick several
  /// categories, so any of its tags counts, not only the first.
  bool inCategory(String category) {
    final wanted = category.trim().toLowerCase();
    return categoryId == wanted ||
        occasionTags.any((tag) => tag.trim().toLowerCase() == wanted);
  }

  /// Percentage saved against the compare-at price, or null when not on sale.
  int? get discountPercent {
    final compareAt = compareAtAmount;
    if (compareAt == null || compareAt <= priceAmount) return null;
    return (((compareAt - priceAmount) / compareAt) * 100).round();
  }

  static const String placeholderImage =
      'https://images.unsplash.com/photo-1513885535751-8b9238bd345a?auto=format&fit=crop&w=900&q=80';

  factory Gift.fromJson(Map<String, dynamic> json, {Shop? shop}) {
    final tags = (json['occasion_tags'] as List?)
            ?.map((tag) => tag.toString())
            .toList() ??
        const <String>[];

    final media = GiftMedia.listFromJson(json['media']);
    final imageUrl = (json['image_url'] as String?)?.trim() ?? '';
    // The cover: the product image, else the first photo the seller added.
    final firstPhoto = media.where((item) => !item.isVideo).firstOrNull?.url;
    final cover = imageUrl.isNotEmpty ? imageUrl : firstPhoto;

    return Gift(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Gift',
      priceAmount: (json['price_amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      image: cover ?? placeholderImage,
      media: GiftMedia.ordered(media, cover: cover),
      description: (json['description'] as String?)?.trim() ?? '',
      // The API carries occasions as free-form tags; the first one that maps to
      // a known category drives the category chip and filters.
      categoryId: _categoryFromTags(tags),
      shopId: json['shop_id'] as String?,
      shopName: shop?.name,
      shopImageUrl: shop?.imageUrl,
      sellerId: shop?.sellerId,
      prepMinutes: (json['prep_minutes'] as num?)?.toInt() ?? 0,
      occasionTags: tags,
      rewardPoints: (json['reward_points'] as num?)?.toInt() ?? 0,
    );
  }

  static String _categoryFromTags(List<String> tags) {
    for (final tag in tags) {
      final normalized = tag.trim().toLowerCase();
      final match = GiftCategory.all
          .where((category) => category.id == normalized)
          .toList();
      if (match.isNotEmpty) return match.first.id;
    }
    return tags.isNotEmpty ? tags.first.trim().toLowerCase() : '';
  }

  /// True when the gift matches a free-text query across its searchable fields.
  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return [name, description, shopName ?? '', categoryId, ...occasionTags]
        .join(' ')
        .toLowerCase()
        .contains(normalized);
  }
}

/// One photo or video on a gift.
class GiftMedia {
  const GiftMedia({required this.url, required this.isVideo, this.position = 0});

  final String url;
  final bool isVideo;
  final int position;

  /// Reads the API's `media` list; entries with no address are skipped.
  static List<GiftMedia> listFromJson(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw.whereType<Map<String, dynamic>>())
        if ((item['cdn_url'] as String?)?.trim().isNotEmpty ?? false)
          GiftMedia(
            url: (item['cdn_url'] as String).trim(),
            isVideo:
                item['asset_type'] == 'video' ||
                ((item['mime_type'] as String?) ?? '').startsWith('video/'),
            position: (item['position'] as num?)?.toInt() ?? 0,
          ),
    ];
  }

  /// Photos first, starting with [cover], then videos, each in the seller's
  /// order, so the gift page opens on the cover photo.
  static List<GiftMedia> ordered(List<GiftMedia> media, {String? cover}) {
    int rank(GiftMedia item) => item.isVideo
        ? 2
        : item.url == cover
        ? 0
        : 1;
    return [...media]..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.position.compareTo(b.position);
    });
  }
}
