import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/products/data/catalog_providers.dart';
import 'package:send_agift_mobile/features/products/domain/shop.dart';
import 'package:send_agift_mobile/features/products/presentation/screens/shop_screen.dart';

import 'support/fake_auth.dart';
import 'support/sample_gifts.dart';

void main() {
  testWidgets('a shop page shows who runs it and what it sells', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const shop = Shop(
      id: 's1',
      sellerId: 'seller-1',
      name: 'Giftora',
      location: 'Kandy, Sri Lanka',
      description: 'Thoughtful gifts and special surprises.',
      verified: true,
      categories: ['flowers-plants'],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakeAuth(),
          shopPageProvider.overrideWith(
            (ref, id) async => (shop, sampleGifts.take(2).toList()),
          ),
        ],
        child: const MaterialApp(home: ShopScreen(shopId: 's1')),
      ),
    );
    // Photos keep a loading spinner going in tests, so pump a fixed time.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Giftora'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    expect(find.text('Kandy, Sri Lanka'), findsOneWidget);
    expect(find.text('Flowers plants'), findsOneWidget);
    expect(find.text('2 GIFTS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
