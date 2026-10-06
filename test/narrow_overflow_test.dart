import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/cart/data/cart_controller.dart';
import 'package:send_agift_mobile/features/cart/presentation/screens/cart_screen.dart';
import 'package:send_agift_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:send_agift_mobile/features/home/presentation/widgets/games_teaser.dart';
import 'package:send_agift_mobile/features/products/data/catalog_providers.dart';
import 'package:send_agift_mobile/features/products/data/sample_gifts.dart';

import 'support/fake_auth.dart';

void main() {
  testWidgets('cart line does not overflow on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final gift = sampleGifts.first;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogProvider.overrideWith((ref) async => sampleGifts),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              // Populate the cart once the provider container is available,
              // mirroring how a real add-to-cart flow reaches this screen.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ProviderScope.containerOf(context, listen: false)
                    .read(cartProvider.notifier)
                    .add(gift.id);
              });
              return const CartScreen();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  testWidgets('home hero stats do not overflow on a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakeAuth(),
          catalogProvider.overrideWith((ref) async => sampleGifts),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    // Every section on the page enters through FadeSlideIn, which schedules
    // its own Future.delayed; pumping past the longest stagger lets them all
    // fire before the tree is torn down; otherwise the framework fails the
    // test for a timer still pending, unrelated to layout.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('games teaser does not overflow on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: GamesTeaser())),
      ),
    );
    await tester.pump();

    expect(find.text('TAKE A BREAK,\nPLAY A GAME'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
