import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/orders/data/orders_repository.dart';
import 'package:send_agift_mobile/features/orders/domain/customer_order.dart';
import 'package:send_agift_mobile/features/orders/presentation/screens/order_list_screen.dart';
import 'package:send_agift_mobile/features/products/data/catalog_providers.dart';
import 'package:send_agift_mobile/features/products/domain/gift.dart';
import 'package:send_agift_mobile/features/reviews/data/reviews_repository.dart';
import 'package:send_agift_mobile/features/reviews/domain/product_review.dart';
import 'package:send_agift_mobile/features/reviews/presentation/screens/my_reviews_screen.dart';
import 'package:send_agift_mobile/features/saved/data/saved_controller.dart';
import 'package:send_agift_mobile/features/saved/presentation/screens/saved_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth.dart';

final _now = DateTime.now();

CustomerOrder _order(String n, String status, {int daysAhead = 2}) =>
    CustomerOrder(
      id: n,
      orderNumber: 'SAG-2026-$n',
      status: status,
      totalAmount: 3000,
      currency: 'USD',
      createdAt: _now.subtract(const Duration(days: 3)),
      deliveryDate: _now.add(Duration(days: daysAhead)),
    );

const _gifts = [
  Gift(
    id: 'g1',
    name: 'Perfume with a very long name that keeps going',
    priceAmount: 2500,
    currency: 'USD',
    image: '',
    shopName: 'PD Gifts',
    occasionTags: ['birthday', 'love'],
    rewardPoints: 250,
    rating: 4.5,
  ),
  Gift(
    id: 'g2',
    name: 'Roses',
    priceAmount: 1500,
    currency: 'USD',
    image: '',
    occasionTags: ['love'],
  ),
];

ProductReview _review(String id, int rating, {String? reply}) => ProductReview(
  id: id,
  productId: 'g1',
  orderItemId: 'oi$id',
  rating: rating,
  productQualityRating: rating,
  shippingRating: 0,
  sellerServiceRating: 0,
  isAnonymous: false,
  helpfulCount: 2,
  createdAt: _now,
  title: 'Lovely',
  body: 'Arrived on time and smelled wonderful.',
  sellerReply: reply,
);

Future<void> _pump(WidgetTester tester, Widget screen) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fakeAuth(customer: {'id': 'c1', 'name': 'Pawan'}),
        customerOrdersProvider.overrideWith(
          (ref) async => [
            _order('001', 'dispatched'),
            _order('002', 'delivered'),
            _order('003', 'cancelled'),
            _order('004', 'preparing', daysAhead: 1),
          ],
        ),
        catalogProvider.overrideWith((ref) async => _gifts),
        myReviewsProvider.overrideWith(
          (ref) async => [
            _review('r1', 5, reply: 'Thank you!'),
            _review('r2', 4),
            _review('r3', 2),
          ],
        ),
        savedGiftListProvider.overrideWith(
          (ref) => const AsyncValue.data(_gifts),
        ),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  // Gift cards keep a loading shimmer running, so pump a fixed time rather
  // than waiting for everything to settle.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('orders show counts, a tracker, and filter by tile', (
    tester,
  ) async {
    await _pump(tester, const OrderListScreen());
    expect(find.text('4 orders'), findsOneWidget);
    expect(find.text('Next arrival tomorrow'), findsOneWidget);

    await tester.tap(find.text('Delivered').first);
    await tester.pump(const Duration(milliseconds: 500));
    // Only one order is left, so the whole list is built.
    expect(find.text('SAG-2026-002', skipOffstage: false), findsOneWidget);
    expect(find.text('SAG-2026-003', skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reviews show the average and filter by stars', (tester) async {
    await _pump(tester, const MyReviewsScreen());
    expect(find.text('3.7'), findsOneWidget);
    expect(find.text('3 reviews · 6 helpful votes'), findsOneWidget);

    await tester.tap(find.text('5 stars'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Thank you!', skipOffstage: false), findsOneWidget);
    expect(find.text('No reviews here.', skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved gifts total their worth and filter by occasion', (
    tester,
  ) async {
    await _pump(tester, const SavedScreen());
    expect(find.text('2 gifts'), findsWidgets);
    expect(find.textContaining('earn up to 250 points'), findsOneWidget);

    await tester.ensureVisible(find.text('Birthday · 1'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Birthday · 1'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1 gift'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
