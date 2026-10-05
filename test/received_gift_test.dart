import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/orders/domain/received_gift.dart';

void main() {
  test('ReceivedGift.fromJson reads a delivered gift and its lines', () {
    final gift = ReceivedGift.fromJson({
      'order_id': 'o1',
      'order_number': 'SAG-20261005-1A2B3C4D',
      'sender_name': 'Sam',
      'gift_message': '  Happy birthday!  ',
      'gift_points': 250,
      'delivered_at': '2026-10-09T08:30:00Z',
      'items': [
        {
          'id': 'i1',
          'product_id': 'p1',
          'product_name': 'Sunrise Bouquet',
          'product_image_url': 'https://example.test/b.jpg',
          'shop_name': 'Bloom & Co',
          'quantity': 2,
          'fulfilment_status': 'delivered',
          'review_id': 'r1',
        },
        {
          'id': 'i2',
          'product_id': 'p2',
          'product_name': 'Truffles',
          'shop_name': 'Cocoa Lane',
          'quantity': 1,
          'fulfilment_status': 'dispatched',
        },
      ],
    });

    expect(gift.senderName, 'Sam');
    expect(gift.giftMessage, 'Happy birthday!');
    expect(gift.giftPoints, 250);
    expect(gift.items, hasLength(2));
    expect(gift.items.first.delivered, isTrue);
    expect(gift.items.first.reviewId, 'r1');
    expect(gift.items.last.delivered, isFalse);
    expect(gift.items.last.imageUrl, isNull);
  });

  test('a blank gift message is no message', () {
    final gift = ReceivedGift.fromJson({'gift_message': '   ', 'items': []});
    expect(gift.giftMessage, isNull);
    expect(gift.items, isEmpty);
  });
}
