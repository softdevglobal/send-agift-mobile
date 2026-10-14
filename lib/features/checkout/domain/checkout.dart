// Checkout models: who a gift goes to, and what delivery will cost.

/// A saved delivery address: a recipient's, or the customer's own (the API
/// returns the same shape for both).
class RecipientAddress {
  const RecipientAddress({
    required this.id,
    required this.countryId,
    required this.line1,
    required this.city,
    this.line2,
    this.region,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.label,
    this.addressType = 'shipping',
    this.isDefault = false,
  });

  /// What the customer calls it, e.g. "Home" or "Office".
  final String? label;
  final String addressType;
  final bool isDefault;

  /// The label, else the address type, for a heading.
  String get title {
    final named = label?.trim() ?? '';
    if (named.isNotEmpty) return named;
    final type = addressType.trim();
    if (type.isEmpty) return 'Address';
    return type[0].toUpperCase() + type.substring(1);
  }

  final String id;
  final String countryId;
  final String line1;
  final String city;
  final String? line2;
  final String? region;
  final String? postalCode;

  /// The map point shop delivery zones are measured to. An address saved
  /// without one cannot be priced, so the order cannot be placed to it.
  final double? latitude;
  final double? longitude;

  bool get hasPoint => latitude != null && longitude != null;

  /// One line, the way a label would read it.
  String get formatted => [
    line1,
    line2,
    city,
    region,
    postalCode,
  ].where((part) => part != null && part.trim().isNotEmpty).join(', ');

  factory RecipientAddress.fromJson(Map<String, dynamic> json) {
    return RecipientAddress(
      id: json['id'] as String? ?? '',
      countryId: json['country_id'] as String? ?? '',
      line1: json['line1'] as String? ?? '',
      city: json['city'] as String? ?? '',
      line2: json['line2'] as String?,
      region: json['region'] as String?,
      postalCode: json['postal_code'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      label: json['label'] as String?,
      addressType: json['address_type'] as String? ?? 'shipping',
      isDefault: json['is_default'] as bool? ?? false,
    );
  }
}

/// Someone the customer sends gifts to. [addresses] is only filled in by the
/// single-recipient endpoint; the list endpoint returns names alone.
class Recipient {
  const Recipient({
    required this.id,
    required this.name,
    this.relationship,
    this.email,
    this.phone,
    this.defaultAddressId,
    this.imageUrl,
    this.preferences = const {},
    this.addresses = const [],
  });

  /// Kept only so an update sends them back unchanged: the API replaces
  /// every field on update.
  final String? imageUrl;
  final Map<String, dynamic> preferences;

  final String id;
  final String name;
  final String? relationship;

  /// Gift points reach the recipient's account by this address.
  final String? email;
  final String? phone;
  final String? defaultAddressId;
  final List<RecipientAddress> addresses;

  String get label => relationship == null || relationship!.trim().isEmpty
      ? name
      : '$name · $relationship';

  /// Where this recipient would actually be shipped to: their default, or
  /// their only one.
  RecipientAddress? get deliveryAddress {
    for (final address in addresses) {
      if (address.id == defaultAddressId) return address;
    }
    return addresses.isEmpty ? null : addresses.first;
  }

  factory Recipient.fromJson(Map<String, dynamic> json) {
    final raw = json['addresses'];
    return Recipient(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      relationship: json['relationship'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      defaultAddressId: json['default_address_id'] as String?,
      imageUrl: json['image_url'] as String?,
      preferences: json['preferences'] is Map<String, dynamic>
          ? json['preferences'] as Map<String, dynamic>
          : const {},
      addresses: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(RecipientAddress.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

/// One shop's own delivery, priced from the delivery zone that covers the
/// recipient's address.
class QuotedShipment {
  const QuotedShipment({
    required this.shopName,
    required this.provider,
    required this.serviceName,
    required this.amount,
    required this.currency,
    required this.estimatedDays,
  });

  final String shopName;
  final String provider;
  final String serviceName;

  /// Minor units, in [currency].
  final int amount;
  final String currency;

  /// Days the shop needs; 0 is same day.
  final int estimatedDays;

  /// The shop cannot get there by [deliveryDate], counted from [today].
  bool arrivesAfter(DateTime deliveryDate, {DateTime? today}) {
    final now = today ?? DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final wanted = DateTime(
      deliveryDate.year,
      deliveryDate.month,
      deliveryDate.day,
    );
    return start.add(Duration(days: estimatedDays)).isAfter(wanted);
  }

  String get summary {
    final days = estimatedDays == 0
        ? ' · same day'
        : ' · $estimatedDays day${estimatedDays == 1 ? '' : 's'}';
    final service = serviceName.isEmpty ? 'Shop delivery' : serviceName;
    return '$shopName · $service$days';
  }

  factory QuotedShipment.fromJson(Map<String, dynamic> json) {
    return QuotedShipment(
      shopName: json['shop_name'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      serviceName: json['service_name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      estimatedDays: (json['estimated_days'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One shop's delivery to the recipient: whether its zones reach them, and
/// if not, why.
class ShopDeliveryCheck {
  const ShopDeliveryCheck({
    required this.shopId,
    required this.shopName,
    required this.available,
    this.reason,
    this.reasonCode,
    this.distanceKm,
    this.farthestKm,
  });

  final String shopId;
  final String shopName;
  final bool available;

  /// The API's own words for why it cannot deliver.
  final String? reason;

  /// NO_ZONES, SHOP_NO_LOCATION, ADDRESS_NO_LOCATION or OUTSIDE_ZONE.
  final String? reasonCode;
  final double? distanceKm;
  final double? farthestKm;

  factory ShopDeliveryCheck.fromJson(Map<String, dynamic> json) {
    final option = json['seller_delivery'];
    final o = option is Map<String, dynamic> ? option : const <String, dynamic>{};
    return ShopDeliveryCheck(
      shopId: json['shop_id'] as String? ?? '',
      shopName: json['shop_name'] as String? ?? '',
      available: o['available'] as bool? ?? false,
      reason: o['reason'] as String?,
      reasonCode: o['reason_code'] as String?,
      distanceKm: (o['distance_km'] as num?)?.toDouble(),
      farthestKm: (o['farthest_km'] as num?)?.toDouble(),
    );
  }
}

/// What delivery costs for the whole cart.
class DeliveryQuote {
  const DeliveryQuote({
    required this.shipments,
    required this.amount,
    required this.currency,
    required this.complete,
    this.unquoted = const [],
    this.shops = const [],
  });

  /// Every shop in the cart, including the ones that cannot deliver.
  final List<ShopDeliveryCheck> shops;

  /// The shops whose delivery zones do not reach the recipient.
  List<ShopDeliveryCheck> get blocked =>
      shops.where((shop) => !shop.available).toList(growable: false);

  final List<QuotedShipment> shipments;
  final int amount;
  final String currency;

  /// False when at least one shop cannot deliver there. The address is
  /// outside its delivery zones, or the shop or address has no map point.
  /// The order cannot be placed until that is fixed.
  final bool complete;
  final List<String> unquoted;

  /// Some shop needs longer than the days left before [deliveryDate].
  bool arrivesAfter(DateTime deliveryDate, {DateTime? today}) => shipments.any(
    (shipment) => shipment.arrivesAfter(deliveryDate, today: today),
  );

  /// Delivery is priced in each shop's zone currency, which is not always the
  /// cart's. Adding the two would be nonsense, so a combined total is only
  /// offered when they agree.
  bool matchesCurrency(String cartCurrency) =>
      currency.toUpperCase() == cartCurrency.toUpperCase();

  factory DeliveryQuote.fromJson(Map<String, dynamic> json) {
    final raw = json['shipments'];
    final unquoted = json['unquoted'];
    return DeliveryQuote(
      shipments: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(QuotedShipment.fromJson)
                .toList(growable: false)
          : const [],
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      complete: json['complete'] as bool? ?? false,
      unquoted: unquoted is List
          ? unquoted.whereType<String>().toList(growable: false)
          : const [],
      shops: json['shops'] is List
          ? (json['shops'] as List)
                .whereType<Map<String, dynamic>>()
                .map(ShopDeliveryCheck.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}
