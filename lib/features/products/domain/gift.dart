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
  );

  String get priceLabel => Money.format(priceAmount, currency);

  String? get compareAtLabel =>
      compareAtAmount == null ? null : Money.format(compareAtAmount!, currency);

  String get categoryLabel => GiftCategory.nameFor(categoryId);

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

    return Gift(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Gift',
      priceAmount: (json['price_amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      image: (json['image_url'] as String?)?.trim().isNotEmpty == true
          ? json['image_url'] as String
          : placeholderImage,
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
