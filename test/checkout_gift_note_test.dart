import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/cart/presentation/screens/checkout_screen.dart';

import 'support/fake_auth.dart';

void main() {
  testWidgets('checkout offers an optional gift note and keeps what is typed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3400);
    tester.view.devicePixelRatio = 3; // 360 × 1133
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakeAuth(customer: {'email': 'p@test.dev'}),
        ],
        child: const MaterialApp(home: CheckoutScreen()),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final note = find.byKey(const Key('gift-note'));
    await tester.ensureVisible(note);
    expect(find.text('Add a gift note'), findsOneWidget);
    expect(find.text('Optional'), findsOneWidget);

    await tester.enterText(note, 'Hope the new job is wonderful, Mum x');
    await tester.pump();
    expect(
      find.descendant(
        of: note,
        matching: find.text('Hope the new job is wonderful, Mum x'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
