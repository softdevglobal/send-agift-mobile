import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/orders/data/orders_repository.dart';
import 'package:send_agift_mobile/features/orders/domain/customer_order.dart';
import 'package:send_agift_mobile/features/orders/presentation/screens/order_detail_screen.dart';

import 'support/fake_auth.dart';

void main() {
  testWidgets('the order hero and points card fit a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3; // 360 × 800
    addTearDown(tester.view.reset);

    final order = CustomerOrder.fromJson({
      'id': 'o1',
      'order_number': 'SAG-20260929-ABCDEF12',
      'status': 'pending_payment',
      'total_amount': 2500,
      'currency': 'AUD',
      'created_at': '2026-09-29T05:04:30Z',
      'delivery_date': '2026-10-06T00:00:00Z',
      'gift_points': 25,
      'gift_points_status': 'held',
      'items': const [],
    });
    final withReward = CustomerOrder(
      id: order.id,
      orderNumber: order.orderNumber,
      status: order.status,
      totalAmount: order.totalAmount,
      currency: order.currency,
      createdAt: order.createdAt,
      deliveryDate: order.deliveryDate,
      giftPoints: 25,
      giftPointsStatus: 'held',
      // Item cards need the catalog and chat; the hero and points card
      // are what is under test.
      items: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakeAuth(customer: {'email': 'p@test.dev'}),
          customerOrderProvider('o1').overrideWith((ref) async => withReward),
        ],
        child: const MaterialApp(home: OrderDetailScreen(orderId: 'o1')),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('SAG-20260929-ABCDEF12'), findsOneWidget);
    expect(find.text('POINTS FROM THIS ORDER'), findsOneWidget);
    expect(
      find.text('25 points are travelling with this gift.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
