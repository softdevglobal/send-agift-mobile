import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/orders/domain/customer_order.dart';
import 'package:send_agift_mobile/features/reviews/domain/review_moods.dart';
import 'package:send_agift_mobile/features/reviews/presentation/screens/write_review_screen.dart';

import 'support/fake_auth.dart';

void main() {
  test('an order carries its breakdown and the sender\'s note', () {
    final order = CustomerOrder.fromJson({
      'id': 'o1',
      'order_number': 'SAG-1',
      'status': 'pending_payment',
      'subtotal_amount': 2500,
      'delivery_amount': 500,
      'total_amount': 3000,
      'currency': 'USD',
      'gift_message': '  Happy birthday!  ',
      'created_at': '2026-10-12T10:00:00Z',
    });
    expect(order.subtotalAmount + order.deliveryAmount, order.totalAmount);
    expect(order.giftMessage, 'Happy birthday!');
    expect(order.deliveryLabel, isNot('Free'));

    final free = CustomerOrder.fromJson({
      'id': 'o2',
      'order_number': 'SAG-2',
      'status': 'paid',
      'total_amount': 2500,
      'subtotal_amount': 2500,
      'gift_message': '   ',
      'created_at': '2026-10-12T10:00:00Z',
    });
    expect(free.deliveryLabel, 'Free');
    expect(free.giftMessage, isNull);
  });

  test('highlights follow the score and the mood answers it', () {
    expect(reviewHighlights(5), contains('Beautifully wrapped'));
    expect(reviewHighlights(1), contains('Arrived late'));
    expect(reviewHighlights(1), isNot(contains('Beautifully wrapped')));
    expect(reviewMood(0).headline, 'Tap a star to begin');
    expect(reviewMood(5).headline, 'Absolutely love it');
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('the review screen fits $width px and answers a star', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [fakeAuth()],
          child: const MaterialApp(
            home: WriteReviewScreen(
              orderItemId: 'item-1',
              productName: 'Chocolate box',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Tell us about Chocolate box.'), findsOneWidget);
      expect(find.text('Tap a star to begin'), findsOneWidget);
      // Nothing can be sent without a score.
      FilledButton submit() =>
          tester.widget(find.byKey(const Key('review-submit')));
      expect(submit().onPressed, isNull);

      // A quick-pick highlight fills the headline until the person types.
      await tester.tap(find.text('Beautifully wrapped'));
      await tester.pump();
      final headline = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Beautifully wrapped'),
      );
      expect(headline.controller!.text, 'Beautifully wrapped');
      expect(tester.takeException(), isNull);
    });
  }
}
