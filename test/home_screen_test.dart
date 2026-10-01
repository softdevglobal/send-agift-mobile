import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/games/data/games_providers.dart';
import 'package:send_agift_mobile/features/games/domain/competition.dart';
import 'package:send_agift_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:send_agift_mobile/features/products/data/catalog_providers.dart';
import 'package:send_agift_mobile/features/products/data/sample_gifts.dart';
import 'package:send_agift_mobile/features/products/domain/gift.dart';

import 'support/fake_auth.dart';

void main() {
  testWidgets('home greets the customer and shows their points', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const rewarding = Gift(
      id: 'pts',
      name: 'Points hamper',
      priceAmount: 4000,
      currency: 'USD',
      image: '',
      rewardPoints: 300,
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
          pointsWalletProvider.overrideWith(
            (ref) async => const PointsWallet(
              balance: 200,
              lifetimeEarned: 250,
              lifetimeSpent: 50,
              entries: [],
            ),
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
    expect(find.text('200 pts'), findsOneWidget);
    expect(find.text('The right gift, on the right day.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Gifts that pay you back'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Gifts that pay you back'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Let the carousel's timer go before the tree is torn down.
    await tester.pumpWidget(const SizedBox());
  });
}
