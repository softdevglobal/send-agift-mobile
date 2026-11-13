/// A seller storefront, as returned by `GET /shops`.
class Shop {
  const Shop({
    required this.id,
    required this.sellerId,
    required this.name,
    this.description,
    this.location,
    this.imageUrl,
    this.sellerImageUrl,
    this.verified = false,
    this.categories = const [],
  });

  final String id;
  final String sellerId;
  final String name;
  final String? description;
  final String? location;
  final String? imageUrl;

  /// The seller's own profile photo, on a product's inline shop.
  final String? sellerImageUrl;

  /// An admin has checked the business behind the shop.
  final bool verified;

  /// What the shop sells, as the seller listed it.
  final List<String> categories;

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'] as String? ?? '',
      sellerId: json['seller_id'] as String? ?? '',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Shop',
      description: json['description'] as String?,
      location: json['customer_visible_location'] as String?,
      imageUrl: json['image_url'] as String?,
      sellerImageUrl: _text(json['seller_image_url']),
      verified: json['seller_verification_status'] == 'verified',
      categories: [
        for (final c in (json['categories'] as List? ?? const []))
          if (c.toString().trim().isNotEmpty) c.toString().trim(),
      ],
    );
  }

  static String? _text(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }
}
