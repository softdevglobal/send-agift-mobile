import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:send_agift_mobile/features/products/data/catalog_providers.dart';
import 'support/sample_gifts.dart';
import 'package:send_agift_mobile/features/products/domain/gift.dart';
import 'package:send_agift_mobile/features/products/presentation/widgets/gift_card.dart';
import 'package:send_agift_mobile/features/products/presentation/widgets/gift_grid.dart';

import 'support/fake_auth.dart';

void main() {
  testWidgets('home greets the customer and shows the reward shelf', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const rewarding = Gift(
      id: 'pts',
      name: 'Sponsored hamper',
      priceAmount: 4000,
      currency: 'USD',
      image: '',
      gameEntries: 3,
      sponsored: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakeAuth(
            customer: {
              'id': 'c1',
              'first_name': 'Pawan',
              'name': 'Pawan Kanchana',
            },
          ),
          catalogProvider.overrideWith(
            (ref) async => [...sampleGifts, rewarding],
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    // Sections fade in on staggered timers; pump past the longest.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.textContaining('Hi, '), findsOneWidget);
    expect(find.text('Orders'), findsNothing);
    expect(find.text('UNFORGETTABLE'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('GIFTS THAT EARN GAME ENTRIES'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('GIFTS THAT EARN GAME ENTRIES'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Let the carousel's timer go before the tree is torn down.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('home lists up to 10 new gifts down the page, then View all', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final gifts = [
      for (var i = 0; i < 12; i++)
        Gift(
          id: 'g$i',
          name: 'Gift $i',
          priceAmount: 1000,
          currency: 'LKR',
          image: '',
        ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakeAuth(),
          catalogProvider.overrideWith((ref) async => gifts),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.scrollUntilVisible(
      find.text('View all gifts'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      find.descendant(
        of: find.byType(GiftGrid),
        matching: find.byType(GiftCard),
      ),
      findsNWidgets(10),
    );
    expect(find.text('Gift 10'), findsNothing);
    expect(find.text('View all gifts'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
