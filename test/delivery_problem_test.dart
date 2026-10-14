import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/checkout/domain/checkout.dart';
import 'package:send_agift_mobile/features/checkout/presentation/widgets/delivery_problem_card.dart';

void main() {
  final quote = DeliveryQuote.fromJson({
    'amount': 0,
    'currency': 'AUD',
    'complete': false,
    'shops': [
      {
        'shop_id': 's1',
        'shop_name': 'Nike',
        'seller_delivery': {
          'available': false,
          'reason_code': 'OUTSIDE_ZONE',
          'reason':
              'This address is 3,215 km away. The shop delivers up to 25 km',
          'distance_km': 3214.55,
          'farthest_km': 25,
        },
      },
      {
        'shop_id': 's2',
        'shop_name': 'Bloom',
        'seller_delivery': {'available': true, 'price_amount': 500},
      },
    ],
  });

  test('the quote names each shop that cannot deliver', () {
    expect(quote.shops, hasLength(2));
    expect(quote.blocked.single.shopName, 'Nike');
    expect(quote.blocked.single.reasonCode, 'OUTSIDE_ZONE');
  });

  test('each reason reads as plain English', () {
    final far = DeliveryProblemCopy.of(quote.blocked.single);
    expect(far.title, 'Nike doesn’t deliver this far');
    expect(far.body, contains('3,215 km from the shop'));
    expect(far.body, contains('up to 25 km'));

    final unpinned = DeliveryProblemCopy.of(
      const ShopDeliveryCheck(
        shopId: 's1',
        shopName: 'Nike',
        available: false,
        reasonCode: 'ADDRESS_NO_LOCATION',
      ),
    );
    expect(unpinned.title, 'This address isn’t on the map');

    final setup = DeliveryProblemCopy.of(
      const ShopDeliveryCheck(
        shopId: 's1',
        shopName: 'Nike',
        available: false,
        reasonCode: 'NO_ZONES',
      ),
    );
    expect(setup.title, 'Nike isn’t delivering yet');
  });

  testWidgets('the card offers the fixes', (tester) async {
    var changed = false;
    var removed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeliveryProblemCard(
            shop: quote.blocked.single,
            giftCount: 2,
            onChangeRecipient: () => changed = true,
            onRemoveShopGifts: () => removed = true,
          ),
        ),
      ),
    );
    expect(find.text('Nike doesn’t deliver this far'), findsOneWidget);
    await tester.tap(find.text('Send to someone else'));
    await tester.tap(find.text('Remove 2 gifts from Nike'));
    expect(changed, isTrue);
    expect(removed, isTrue);
  });
}
