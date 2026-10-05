/// A delivered gift another customer sent to the signed-in one. It carries
/// no prices. It's a gift.
class ReceivedGift {
  const ReceivedGift({
    required this.orderId,
    required this.orderNumber,
    required this.senderName,
    required this.deliveredAt,
    required this.items,
    this.giftMessage,
    this.giftPoints = 0,
  });

  final String orderId;
  final String orderNumber;
  final String senderName;
  final String? giftMessage;
  final int giftPoints;
  final DateTime deliveredAt;
  final List<ReceivedGiftItem> items;

  factory ReceivedGift.fromJson(Map<String, dynamic> json) {
    final message = json['gift_message'];
    return ReceivedGift(
      orderId: json['order_id'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? 'Someone',
      giftMessage: message is String && message.trim().isNotEmpty
          ? message.trim()
          : null,
      giftPoints: (json['gift_points'] as num?)?.toInt() ?? 0,
      deliveredAt:
          DateTime.tryParse(json['delivered_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      items: (json['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ReceivedGiftItem.fromJson)
          .toList(),
    );
  }
}

class ReceivedGiftItem {
  const ReceivedGiftItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.shopName,
    required this.quantity,
    required this.fulfilmentStatus,
    this.imageUrl,
    this.reviewId,
  });

  final String id;
  final String productId;
  final String productName;
  final String shopName;
  final int quantity;
  final String fulfilmentStatus;
  final String? imageUrl;

  /// Set once the line has a review. The recipient's, or the sender's.
  final String? reviewId;

  bool get delivered => fulfilmentStatus == 'delivered';

  factory ReceivedGiftItem.fromJson(Map<String, dynamic> json) {
    final image = json['product_image_url'];
    return ReceivedGiftItem(
      id: json['id'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      productName: json['product_name'] as String? ?? 'Gift',
      shopName: json['shop_name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      fulfilmentStatus: json['fulfilment_status'] as String? ?? '',
      imageUrl: image is String && image.isNotEmpty ? image : null,
      reviewId: json['review_id'] as String?,
    );
  }
}
