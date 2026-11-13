import '../../../core/utils/money.dart';

/// What a customer may see of a shipment: who is carrying the parcel and how
/// to follow it. The label, provider ids and customs paperwork stay with the
/// seller.
class OrderItemTracking {
  const OrderItemTracking({
    required this.status,
    required this.deliveryMode,
    this.courierProvider,
    this.trackingNumber,
    this.trackingUrl,
    this.deliveredAt,
    this.shippedAt,
  });

  /// label_created | collected | in_transit | delivered | failed | returned.
  final String status;

  /// `seller_managed` when the shop delivers it inside its own zones,
  /// `courier` when the shop handed it to a courier and recorded the number.
  final String deliveryMode;
  final String? courierProvider;
  final String? trackingNumber;
  final String? trackingUrl;
  final DateTime? deliveredAt;
  final DateTime? shippedAt;

  bool get isDelivered => status == 'delivered';
  bool get isSellerManaged => deliveryMode == 'seller_managed';

  /// Plain English, so a raw enum never reaches the screen.
  String get label => switch (status) {
    'label_created' => 'Ready to collect',
    'collected' => 'Picked up',
    'in_transit' => 'On its way',
    'delivered' => 'Delivered',
    'failed' => 'Delivery problem',
    'returned' => 'Returned to sender',
    _ => 'Shipped',
  };

  String get hint => switch (status) {
    'label_created' =>
      'The shop has printed the label. The courier collects it next.',
    'collected' => 'The courier has the parcel.',
    'in_transit' => 'The parcel is moving through the courier network.',
    'delivered' => 'The courier marked this parcel as delivered.',
    'failed' => 'The courier could not complete delivery. Message the shop.',
    'returned' => 'The parcel is on its way back to the shop.',
    _ => 'This parcel is on its way.',
  };

  factory OrderItemTracking.fromJson(Map<String, dynamic> json) {
    return OrderItemTracking(
      status: json['status'] as String? ?? '',
      deliveryMode: json['delivery_mode'] as String? ?? 'courier',
      courierProvider: json['courier_provider'] as String?,
      trackingNumber: json['tracking_number'] as String?,
      trackingUrl: json['tracking_url'] as String?,
      deliveredAt: DateTime.tryParse(json['delivered_at'] as String? ?? ''),
      shippedAt: DateTime.tryParse(json['shipped_at'] as String? ?? ''),
    );
  }
}

/// One line of an order. A gift from one shop. Its [id] is the
/// `order_item_id` an order chat with that shop is about.
class CustomerOrderItem {
  const CustomerOrderItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.unitAmount,
    required this.totalAmount,
    required this.fulfilmentStatus,
    this.tracking,
    this.gameEntries = 0,
    this.entriesStatus = 'none',
  });

  final String id;
  final String productId;
  final int quantity;
  final int unitAmount;
  final int totalAmount;
  final String fulfilmentStatus;

  /// Present once the line has shipped.
  final OrderItemTracking? tracking;

  /// The game entries this line earns, and where they are: none, reserved
  /// (waiting for the payment), granted, released (never paid) or reversed.
  final int gameEntries;
  final String entriesStatus;

  /// The entries in words, or null when the line has none.
  String? get entriesLabel {
    if (gameEntries <= 0 || entriesStatus == 'none') return null;
    final n = '$gameEntries game ${gameEntries == 1 ? 'entry' : 'entries'}';
    return switch (entriesStatus) {
      'reserved' => 'Earns $n once your payment is confirmed',
      'granted' => '$n added',
      'released' => '$n not earned. The order was not paid',
      'reversed' => '$n taken back after a refund or cancellation',
      _ => n,
    };
  }

  String get fulfilmentLabel =>
      _fulfilmentLabels[fulfilmentStatus] ?? _humanize(fulfilmentStatus);

  factory CustomerOrderItem.fromJson(Map<String, dynamic> json) {
    final rawTracking = json['tracking'];
    return CustomerOrderItem(
      id: json['id'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitAmount: (json['unit_amount'] as num?)?.toInt() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
      fulfilmentStatus: json['fulfilment_status'] as String? ?? 'pending',
      tracking: rawTracking is Map<String, dynamic>
          ? OrderItemTracking.fromJson(rawTracking)
          : null,
      gameEntries: (json['game_entries'] as num?)?.toInt() ?? 0,
      entriesStatus: json['entries_status'] as String? ?? 'none',
    );
  }
}

/// A customer's order, from `GET /customers/me/orders`. Items are only
/// present on the single-order response.
class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    required this.currency,
    required this.createdAt,
    this.updatedAt,
    this.deliveryDate,
    this.subtotalAmount = 0,
    this.deliveryAmount = 0,
    this.memberDiscountAmount = 0,
    this.giftMessage,
    this.items = const [],
    this.orderKind = 'paid',
  });

  final String id;
  final String orderNumber;
  final String status;
  final int totalAmount;
  final String currency;
  final DateTime createdAt;

  /// When the order last changed, which is when its current status began.
  final DateTime? updatedAt;
  final DateTime? deliveryDate;

  /// What the gifts cost and what delivery cost, in minor units: the two
  /// parts of [totalAmount].
  final int subtotalAmount;
  final int deliveryAmount;

  /// A member's discount on the gifts, already taken off [totalAmount].
  final int memberDiscountAmount;

  /// The note the sender attached, or null.
  final String? giftMessage;
  final List<CustomerOrderItem> items;

  /// `paid`, or `free_gift`: the customer's one free gift, where the shop
  /// pays for the gift and the customer pays only its delivery.
  final String orderKind;

  bool get isFreeGift => orderKind == 'free_gift';

  /// Game entries the order's lines carry, whatever state they are in.
  int get gameEntriesTotal => items
      .where((i) => i.entriesStatus != 'none')
      .fold(0, (sum, i) => sum + i.gameEntries);

  /// Whether the entries have reached the customer.
  bool get entriesGranted => items.any((i) => i.entriesStatus == 'granted');

  String get statusLabel => _orderStatusLabels[status] ?? _humanize(status);
  String get totalLabel => Money.format(totalAmount, currency);
  String get subtotalLabel =>
      isFreeGift ? 'Free' : Money.format(subtotalAmount, currency);
  String get deliveryLabel =>
      deliveryAmount > 0 ? Money.format(deliveryAmount, currency) : 'Free';
  String formatAmount(int minorAmount) => Money.format(minorAmount, currency);

  bool get isClosed =>
      status == 'delivered' || status == 'cancelled' || status == 'refunded';

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    return CustomerOrder(
      id: json['id'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? 'Order',
      status: json['status'] as String? ?? '',
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      deliveryDate: DateTime.tryParse(json['delivery_date'] as String? ?? ''),
      subtotalAmount: (json['subtotal_amount'] as num?)?.toInt() ?? 0,
      deliveryAmount: (json['delivery_amount'] as num?)?.toInt() ?? 0,
      memberDiscountAmount:
          (json['member_discount_amount'] as num?)?.toInt() ?? 0,
      giftMessage: switch (json['gift_message']) {
        final String text when text.trim().isNotEmpty => text.trim(),
        _ => null,
      },
      items:
          (json['items'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(CustomerOrderItem.fromJson)
              .toList(growable: false) ??
          const <CustomerOrderItem>[],
      orderKind: json['order_kind'] as String? ?? 'paid',
    );
  }
}

const _orderStatusLabels = {
  'draft': 'Draft',
  'pending_payment': 'Awaiting',
  'paid': 'Paid',
  'confirmed': 'Confirmed',
  'accepted': 'Accepted',
  'preparing': 'Being prepared',
  'dispatched': 'On its way',
  'delivered': 'Delivered',
  'cancelled': 'Cancelled',
  'refunded': 'Refunded',
};

const _fulfilmentLabels = {
  'pending': 'Waiting for the shop',
  'accepted': 'Accepted by the shop',
  'preparing': 'Being prepared',
  'ready': 'Ready to ship',
  'dispatched': 'On its way',
  'delivered': 'Delivered',
  'cancelled': 'Cancelled',
};

String _humanize(String value) {
  if (value.isEmpty) return 'Unknown';
  final spaced = value.replaceAll('_', ' ');
  return spaced[0].toUpperCase() + spaced.substring(1);
}
