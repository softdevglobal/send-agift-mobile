import '../../products/domain/gift.dart';

/// One shop that can reach the searched address in time, with the gifts it
/// can send there. Priced from the shop's own delivery zones.
class ShopAvailability {
  const ShopAvailability({
    required this.shopId,
    required this.shopName,
    required this.priceAmount,
    required this.currency,
    required this.isFree,
    required this.estimatedDays,
    required this.gifts,
    this.distanceKm,
    this.estimatedDeliveryDate,
  });

  final String shopId;
  final String shopName;
  final double? distanceKm;

  /// Delivery for this shop, in minor units of [currency].
  final int priceAmount;
  final String currency;
  final bool isFree;
  final int estimatedDays;
  final DateTime? estimatedDeliveryDate;
  final List<Gift> gifts;

  factory ShopAvailability.fromJson(Map<String, dynamic> json) {
    final shopName = json['shop_name'] as String? ?? '';
    final raw = json['products'];
    return ShopAvailability(
      shopId: json['shop_id'] as String? ?? '',
      shopName: shopName,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      priceAmount: (json['price_amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      isFree: json['is_free'] as bool? ?? false,
      estimatedDays: (json['estimated_days'] as num?)?.toInt() ?? 0,
      estimatedDeliveryDate: DateTime.tryParse(
        json['estimated_delivery_date'] as String? ?? '',
      ),
      gifts: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map((gift) => Gift.fromJson(gift).withShopName(shopName))
                .toList(growable: false)
          : const [],
    );
  }
}

/// Which gifts can be delivered to a map point by a day.
class GiftAvailability {
  const GiftAvailability({required this.shops});

  final List<ShopAvailability> shops;

  List<Gift> get gifts => [for (final shop in shops) ...shop.gifts];

  factory GiftAvailability.fromJson(Map<String, dynamic> json) {
    final raw = json['shops'];
    return GiftAvailability(
      shops: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(ShopAvailability.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}
