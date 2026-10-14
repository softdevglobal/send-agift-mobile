import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:send_agift_mobile/features/checkout/data/checkout_repository.dart';
import 'package:send_agift_mobile/features/auth/data/countries_provider.dart';
import 'package:send_agift_mobile/features/checkout/domain/checkout.dart';
import 'package:send_agift_mobile/features/checkout/presentation/widgets/new_recipient_sheet.dart';
import 'package:send_agift_mobile/features/delivery/data/delivery_providers.dart';
import 'package:send_agift_mobile/features/free_gift/data/free_gift_repository.dart';
import 'package:send_agift_mobile/features/free_gift/domain/free_gift.dart';
import 'package:send_agift_mobile/features/free_gift/presentation/screens/free_gift_screen.dart';
import 'package:send_agift_mobile/features/orders/domain/customer_order.dart';

import 'support/fake_auth.dart';

const _offer = FreeGiftOffer(
  productId: 'p1',
  name: 'Sunset Peony Bouquet',
  priceAmount: 4800,
  currency: 'GBP',
  shopId: 's1',
  shopName: 'Bloom Atelier',
);

const _recipient = Recipient(
  id: 'r1',
  name: 'Nimali Perera',
  email: 'nimali@test.dev',
  phone: '+94771234567',
  addresses: [
    RecipientAddress(
      id: 'a1',
      countryId: 'lk',
      line1: '12 Galle Road',
      city: 'Colombo',
      latitude: 6.9271,
      longitude: 79.8612,
    ),
  ],
);

class _FakeFreeGifts implements FreeGiftRepository {
  _FakeFreeGifts({
    required this.me,
    this.recipientCheck,
    this.offers = const [_offer],
  });

  final List<FreeGiftOffer> offers;

  final FreeGiftStatus me;
  final FreeGiftRecipientCheck? recipientCheck;
  final sent = <Map<String, Object?>>[];

  @override
  Future<List<FreeGiftOffer>> listOffers({
    double? latitude,
    double? longitude,
    DateTime? deliveryDate,
  }) async => offers;

  @override
  Future<FreeGiftStatus> status({String? recipientId}) async => FreeGiftStatus(
    available: me.available,
    used: me.used,
    missing: me.missing,
    locked: me.locked,
    recipient: recipientId == null ? null : recipientCheck,
  );

  @override
  Future<SentFreeGift> send({
    required String productId,
    required String recipientId,
    required String countryId,
    required DateTime deliveryDate,
    required String idempotencyKey,
    String? giftMessage,
  }) async {
    sent.add({
      'product': productId,
      'recipient': recipientId,
      'country': countryId,
      'key': idempotencyKey,
    });
    return const SentFreeGift(
      orderId: 'o1',
      status: 'pending_payment',
      totalAmount: 500,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCheckout implements CheckoutRepository {
  int quotes = 0;

  @override
  Future<List<Recipient>> listRecipients() async => const [_recipient];

  @override
  Future<Recipient> getRecipient(String id) async => _recipient;

  @override
  Future<DeliveryQuote> quoteItems({
    required String recipientId,
    required DateTime deliveryDate,
    required List<(String productId, int quantity)> items,
  }) async {
    quotes++;
    return DeliveryQuote.fromJson({
      'amount': 500,
      'currency': 'GBP',
      'complete': true,
      'shipments': [
        {'shop_name': 'Bloom Atelier', 'amount': 500, 'currency': 'GBP'},
      ],
    });
  }

  // Card payments not set up, so sending lands straight on the order.
  @override
  Future<InAppPaymentSheet?> startInAppPayment(String orderId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _open(
  WidgetTester tester, {
  Map<String, dynamic>? customer,
  required _FakeFreeGifts gifts,
  _FakeCheckout? checkout,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 2600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/free-gift',
    routes: [
      GoRoute(
        path: '/free-gift',
        builder: (context, state) => const FreeGiftScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) =>
            Scaffold(body: Text('order ${state.pathParameters['id']}')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fakeAuth(customer: customer),
        freeGiftRepositoryProvider.overrideWithValue(gifts),
        checkoutRepositoryProvider.overrideWithValue(
          checkout ?? _FakeCheckout(),
        ),
        deliveryIntentProvider.overrideWith(
          (ref) => DeliveryIntentController(restore: false),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await _settle(tester);
}

Future<void> _chooseRecipient(WidgetTester tester) async {
  await tester.tap(find.text('Choose a recipient'));
  await _settle(tester);
  await tester.tap(find.text('Nimali Perera').last);
  await _settle(tester);
}

void main() {
  group('models', () {
    test('reads the status, with what is missing and the recipient', () {
      final status = FreeGiftStatus.fromJson({
        'available': false,
        'used': false,
        'missing': ['email', 'phone'],
        'locked': false,
        'recipient': {
          'id': 'r1',
          'can_receive': false,
          'reason': 'RECIPIENT_ALREADY_USED',
        },
      });
      expect(status.needsEmail, isTrue);
      expect(status.needsPhone, isTrue);
      expect(status.recipient?.canReceive, isFalse);
      expect(status.recipient?.reason, FreeGiftRecipientReason.alreadyUsed);
      expect(status.recipient?.problem, contains('already received'));
    });

    test('an order with delivery to pay waits for payment', () {
      expect(
        SentFreeGift.fromJson({
          'id': 'o1',
          'status': 'pending_payment',
          'total_amount': 500,
        }).needsPayment,
        isTrue,
      );
      expect(
        SentFreeGift.fromJson({
          'id': 'o2',
          'status': 'confirmed',
          'total_amount': 0,
        }).needsPayment,
        isFalse,
      );
    });

    test('a free gift order shows the gift as free', () {
      final order = CustomerOrder.fromJson({
        'id': 'o1',
        'order_number': 'SAG-1',
        'status': 'confirmed',
        'order_kind': 'free_gift',
        'subtotal_amount': 4800,
        'delivery_amount': 500,
        'total_amount': 500,
        'currency': 'GBP',
      });
      expect(order.isFreeGift, isTrue);
      expect(order.subtotalLabel, 'Free');
      expect(order.deliveryLabel, '£5.00');
      expect(order.totalLabel, '£5.00');
      expect(order.statusLabel, 'Confirmed');
    });

    test('each confirm screen gets its own retry-safe key', () {
      final a = FreeGiftRepository.newIdempotencyKey();
      final b = FreeGiftRepository.newIdempotencyKey();
      expect(a, hasLength(32));
      expect(a, isNot(b));
    });
  });

  group('screen', () {
    testWidgets('a guest sees the gifts and is asked to sign in', (
      tester,
    ) async {
      await _open(
        tester,
        gifts: _FakeFreeGifts(
          me: const FreeGiftStatus(available: true, used: false),
        ),
      );
      expect(find.text('Send one gift, free'), findsOneWidget);
      expect(find.text('Create an account to send yours'), findsOneWidget);
      expect(find.text('Sunset Peony Bouquet'), findsOneWidget);
      expect(find.text('Sign in to send yours'), findsOneWidget);
      expect(find.text('Who is it for?'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unverified customer verifies before choosing', (
      tester,
    ) async {
      await _open(
        tester,
        customer: {'email': 'p@test.dev', 'phone': '+94770000000'},
        gifts: _FakeFreeGifts(
          me: const FreeGiftStatus(
            available: false,
            used: false,
            missing: ['email', 'phone'],
          ),
        ),
      );
      expect(find.text('First, verify your account'), findsOneWidget);
      expect(find.byKey(const Key('verify-email')), findsOneWidget);
      expect(find.byKey(const Key('verify-phone')), findsOneWidget);
      expect(find.text('Who is it for?'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a used gift points to the orders instead', (tester) async {
      await _open(
        tester,
        customer: {'email': 'p@test.dev'},
        gifts: _FakeFreeGifts(
          me: const FreeGiftStatus(available: false, used: true),
        ),
      );
      expect(find.text('You have sent your free gift'), findsOneWidget);
      expect(find.text('Who is it for?'), findsNothing);
    });

    testWidgets('the gift is free and only delivery is paid', (tester) async {
      final gifts = _FakeFreeGifts(
        me: const FreeGiftStatus(available: true, used: false),
        recipientCheck: const FreeGiftRecipientCheck(
          id: 'r1',
          canReceive: true,
        ),
      );
      await _open(tester, customer: {'email': 'p@test.dev'}, gifts: gifts);
      expect(find.text('Choose who it is for'), findsOneWidget);

      await _chooseRecipient(tester);
      expect(find.text('They can receive your free gift.'), findsOneWidget);
      expect(find.text('Pick a gift'), findsOneWidget);

      await tester.tap(find.byKey(const Key('free-gift-offer-p1')));
      await _settle(tester);

      final summary = find.byKey(const Key('free-gift-summary'));
      expect(
        find.descendant(of: summary, matching: find.text('Free')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: summary, matching: find.text('£5.00')),
        findsNWidgets(2),
      );
      expect(find.text('Send free gift · £5.00 delivery'), findsOneWidget);

      await tester.tap(find.byKey(const Key('free-gift-send')));
      await _settle(tester);

      expect(gifts.sent, hasLength(1));
      expect(gifts.sent.single['product'], 'p1');
      expect(gifts.sent.single['recipient'], 'r1');
      expect(gifts.sent.single['country'], 'lk');
      // Card payments are off in the fake, so it waits on its order page.
      expect(find.text('order o1'), findsOneWidget);
    });

    testWidgets('a recipient who already had one cannot be sent another', (
      tester,
    ) async {
      await _open(
        tester,
        customer: {'email': 'p@test.dev'},
        gifts: _FakeFreeGifts(
          me: const FreeGiftStatus(available: true, used: false),
          recipientCheck: const FreeGiftRecipientCheck(
            id: 'r1',
            canReceive: false,
            reason: FreeGiftRecipientReason.alreadyUsed,
          ),
        ),
      );
      await _chooseRecipient(tester);
      expect(
        find.textContaining('already received a free gift'),
        findsOneWidget,
      );
      expect(find.text('Choose another recipient'), findsOneWidget);
    });
    testWidgets('with nothing on offer it says so, as the web does', (
      tester,
    ) async {
      await _open(
        tester,
        gifts: _FakeFreeGifts(
          me: const FreeGiftStatus(available: true, used: false),
          offers: const [],
        ),
      );
      expect(find.text('No free gifts right now'), findsOneWidget);
      expect(find.text('Browse all gifts'), findsOneWidget);
    });

    testWidgets('a free gift recipient must have an email and a phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 2600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            countriesProvider.overrideWith((ref) async => const []),
            deliveryIntentProvider.overrideWith(
              (ref) => DeliveryIntentController(restore: false),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showNewRecipientSheet(context, requireContact: true),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(find.text('Email'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('new-recipient-name')),
        'Nimali',
      );
      final save = find.byKey(const Key('new-recipient-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await _settle(tester);
      expect(
        find.text('Enter their email. A free gift needs it.'),
        findsOneWidget,
      );
    });
  });
}
