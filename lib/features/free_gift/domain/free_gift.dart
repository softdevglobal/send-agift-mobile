import '../../../core/utils/money.dart';

/// The first free gift program: every customer has one free gift to send.
/// The seller's marketing budget pays for the gift itself; the customer pays
/// only its delivery. The app never decides who is eligible, it shows what
/// the API says.

/// A product that can be sent as a free gift right now.
class FreeGiftOffer {
  const FreeGiftOffer({
    required this.productId,
    required this.name,
    required this.priceAmount,
    required this.currency,
    required this.shopId,
    required this.shopName,
    this.description,
    this.imageUrl,
    this.countryId,
  });

  final String productId;
  final String name;
  final String? description;
  final String? imageUrl;

  /// What the seller funds, in minor units. The customer pays nothing for it.
  final int priceAmount;
  final String currency;
  final String shopId;
  final String shopName;
  final String? countryId;

  String get valueLabel => Money.format(priceAmount, currency);

  factory FreeGiftOffer.fromJson(Map<String, dynamic> json) {
    String? optional(String key) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    return FreeGiftOffer(
      productId: json['product_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Gift',
      description: optional('description'),
      imageUrl: optional('image_url'),
      priceAmount: (json['price_amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      shopId: json['shop_id'] as String? ?? '',
      shopName: json['shop_name'] as String? ?? '',
      countryId: optional('country_id'),
    );
  }
}

/// Why a recipient cannot be sent a free gift.
enum FreeGiftRecipientReason {
  selfGift('SELF_GIFT'),
  contactRequired('RECIPIENT_CONTACT_REQUIRED'),
  alreadyUsed('RECIPIENT_ALREADY_USED');

  const FreeGiftRecipientReason(this.code);
  final String code;

  static FreeGiftRecipientReason? fromCode(String? code) {
    for (final reason in values) {
      if (reason.code == code) return reason;
    }
    return null;
  }

  String get message => switch (this) {
    selfGift =>
      'Your free gift is for someone else. This recipient has your own email '
          'or phone number.',
    contactRequired =>
      'This recipient needs both an email address and a phone number before '
          'they can be sent a free gift.',
    alreadyUsed =>
      'This recipient has already received a free gift. Each person can '
          'receive one.',
  };
}

/// Whether one recipient can still be sent a free gift.
class FreeGiftRecipientCheck {
  const FreeGiftRecipientCheck({
    required this.id,
    required this.canReceive,
    this.reason,
  });

  final String id;
  final bool canReceive;
  final FreeGiftRecipientReason? reason;

  String get problem =>
      reason?.message ?? 'This recipient cannot be sent a free gift.';

  factory FreeGiftRecipientCheck.fromJson(Map<String, dynamic> json) {
    return FreeGiftRecipientCheck(
      id: json['id'] as String? ?? '',
      canReceive: json['can_receive'] as bool? ?? false,
      reason: FreeGiftRecipientReason.fromCode(json['reason'] as String?),
    );
  }
}

/// Where the customer stands: is the free gift still there, and what is in
/// the way of sending it.
class FreeGiftStatus {
  const FreeGiftStatus({
    required this.available,
    required this.used,
    this.missing = const [],
    this.locked = false,
    this.recipient,
  });

  /// Still there, and nothing stands in the way of sending it.
  final bool available;
  final bool used;

  /// "email", "phone" or both, when they are not verified.
  final List<String> missing;

  /// On hold for a few days after an email change.
  final bool locked;
  final FreeGiftRecipientCheck? recipient;

  bool get needsEmail => missing.contains('email');
  bool get needsPhone => missing.contains('phone');

  factory FreeGiftStatus.fromJson(Map<String, dynamic> json) {
    final missing = json['missing'];
    final recipient = json['recipient'];
    return FreeGiftStatus(
      available: json['available'] as bool? ?? false,
      used: json['used'] as bool? ?? false,
      missing: missing is List
          ? missing.whereType<String>().toList(growable: false)
          : const [],
      locked: json['locked'] as bool? ?? false,
      recipient: recipient is Map<String, dynamic>
          ? FreeGiftRecipientCheck.fromJson(recipient)
          : null,
    );
  }
}

/// The order a sent free gift made. With a delivery to pay it waits for
/// payment like any order; with none it is confirmed at once.
class SentFreeGift {
  const SentFreeGift({
    required this.orderId,
    required this.status,
    required this.totalAmount,
  });

  final String orderId;
  final String status;

  /// What the customer pays: the delivery only.
  final int totalAmount;

  bool get needsPayment => status == 'pending_payment' && totalAmount > 0;

  factory SentFreeGift.fromJson(Map<String, dynamic> json) {
    return SentFreeGift(
      orderId: json['id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
    );
  }
}
