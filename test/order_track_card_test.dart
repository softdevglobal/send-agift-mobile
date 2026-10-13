import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/orders/data/orders_repository.dart';
import 'package:send_agift_mobile/features/orders/domain/customer_order.dart';
import 'package:send_agift_mobile/features/orders/presentation/screens/order_detail_screen.dart';

import 'support/fake_auth.dart';

CustomerOrder _order(String status) => CustomerOrder.fromJson({
  'id': 'o1',
  'order_number': 'SAG-20261013-0A3F46D2',
  'status': status,
  'total_amount': 38500,
  'currency': 'AUD',
  'created_at': '2026-10-13T09:06:22Z',
  'updated_at': '2026-10-13T09:10:00Z',
  'delivery_date': '2026-10-14T00:00:00Z',
  'items': const [],
});

Future<void> _open(WidgetTester tester, CustomerOrder order) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 3; // 360 × 1066
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fakeAuth(customer: {'email': 'p@test.dev'}),
        customerOrderProvider('o1').overrideWith((ref) async => order),
      ],
      child: const MaterialApp(home: OrderDetailScreen(orderId: 'o1')),
    ),
  );
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('a paid order shows its journey step by step, as on the web', (
    tester,
  ) async {
    await _open(tester, _order('paid'));

    expect(find.text('Track this gift'), findsOneWidget);
    expect(find.text('Order placed'), findsOneWidget);
    expect(find.text('Payment received'), findsOneWidget);
    expect(find.text('Seller accepted'), findsOneWidget);
    expect(find.text('Preparing gift'), findsOneWidget);
    expect(find.text('On the way'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(
      find.text('Payment is confirmed. Waiting for the seller to accept.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cancelled order stops the journey where it ended', (
    tester,
  ) async {
    await _open(tester, _order('cancelled'));

    expect(find.text('Order placed'), findsOneWidget);
    expect(find.text('Seller accepted'), findsNothing);
    expect(find.text('This order was cancelled.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
