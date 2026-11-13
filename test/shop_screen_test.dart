import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/core/layout/responsive.dart';
import 'package:send_agift_mobile/features/products/data/catalog_providers.dart';
import 'package:send_agift_mobile/features/products/presentation/widgets/gift_card.dart';
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
      website: 'https://www.giftora.com',
      workingDays: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
      pickupEnabled: true,
      giftOptions: ['message', 'wrapping'],
      returnsPolicy: 'Damaged items are replaced.',
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
    expect(find.text('GIFTS'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('giftora.com'), findsOneWidget);
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Gift wrapping'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Returns policy'), 300);
    expect(find.text('Returns policy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('iPad', const Size(1024, 1366)),
  ]) {
    testWidgets('on a $name the gifts line up with the page', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      const shop = Shop(id: 's1', sellerId: 'x', name: 'Giftora');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fakeAuth(),
            shopPageProvider.overrideWith(
              (ref, id) async => (shop, sampleGifts.take(3).toList()),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => TabletScale(child: child!),
            home: const ResponsiveFrame(
              maxWidth: ContentWidth.browse,
              child: ShopScreen(shopId: 's1'),
            ),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      final tagLeft = tester.getTopLeft(find.text('GIFTS')).dx;
      final cardLeft = tester.getTopLeft(find.byType(GiftCard).first).dx;
      expect(cardLeft, closeTo(tagLeft, 0.5));
      // The shop card rides over the cover and is drawn on top of it:
      // its name is visible and can be tapped, not hidden by the photo.
      expect(find.text('Giftora').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Back').hitTestable(), findsOneWidget);
    });
  }
}
