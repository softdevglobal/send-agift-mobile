import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:send_agift_mobile/features/delivery/data/delivery_providers.dart';
import 'package:send_agift_mobile/features/delivery/domain/availability.dart';
import 'package:send_agift_mobile/features/delivery/domain/delivery_intent.dart';
import 'package:send_agift_mobile/features/products/data/catalog_providers.dart';
import 'package:send_agift_mobile/features/products/domain/gift.dart';

const _colombo = DeliveryIntent(
  address: '12 Galle Road, Colombo',
  line1: '12 Galle Road',
  city: 'Colombo',
  countryCode: 'LK',
  latitude: 6.9271,
  longitude: 79.8612,
);

final _availability = GiftAvailability.fromJson({
  'latitude': 6.9271,
  'longitude': 79.8612,
  'shops': [
    {
      'shop_id': 's1',
      'shop_name': 'Bloom Atelier',
      'distance_km': 0.8,
      'max_km': 10,
      'price_amount': 500,
      'currency': 'LKR',
      'is_free': false,
      'estimated_days': 1,
      'estimated_delivery_date': '2026-10-02',
      'products': [
        {
          'id': 'p1',
          'shop_id': 's1',
          'name': 'Sunset Peony Bouquet',
          'price_amount': 4800,
          'currency': 'LKR',
          'occasion_tags': ['flowers'],
          'status': 'published',
        },
        {
          'id': 'p2',
          'shop_id': 's1',
          'name': 'Birthday Balloon Box',
          'price_amount': 3900,
          'currency': 'LKR',
          'occasion_tags': ['birthday'],
          'status': 'published',
        },
      ],
    },
  ],
});

const _everyGift = [
  Gift(
    id: 'x',
    name: 'Pocket Photo Printer',
    priceAmount: 7900,
    currency: 'USD',
    image: '',
  ),
];

ProviderContainer _container({
  DeliveryIntent? intent,
  GiftAvailability? availability,
}) {
  final controller = DeliveryIntentController(restore: false);
  if (intent != null) controller.set(intent);
  final container = ProviderContainer(
    overrides: [
      deliveryIntentProvider.overrideWith((ref) => controller),
      catalogProvider.overrideWith((ref) async => _everyGift),
      giftAvailabilityProvider.overrideWith((ref) async {
        final current = ref.watch(deliveryIntentProvider);
        return current?.hasPoint ?? false ? availability : null;
      }),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('DeliveryIntent', () {
    test('survives a round trip through storage', () {
      final intent = _colombo.withDate(DateTime(2026, 10, 5));
      final back = DeliveryIntent.fromJson(
        jsonDecode(jsonEncode(intent.toJson())) as Map<String, dynamic>,
      );
      expect(back.address, '12 Galle Road, Colombo');
      expect(back.latitude, 6.9271);
      expect(back.longitude, 79.8612);
      expect(back.date, DateTime(2026, 10, 5));
      expect(back.toJson()['date'], '2026-10-05');
    });

    test('a typed address with no map point cannot filter gifts', () {
      const typed = DeliveryIntent(address: 'Somewhere in Kandy');
      expect(typed.hasAddress, isTrue);
      expect(typed.hasPoint, isFalse);
    });

    test('reads like the web one-line summary', () {
      expect(
        _colombo.withDate(DateTime(2026, 10, 5)).describe(),
        '12 Galle Road, Colombo · arrives 5 Oct',
      );
      expect(
        DeliveryIntent(date: DateTime(2026, 10, 5)).describe(),
        'arrives 5 Oct',
      );
    });

    test('clearing the address keeps the date', () {
      final cleared = _colombo.withDate(DateTime(2026, 10, 5)).withoutAddress();
      expect(cleared.hasAddress, isFalse);
      expect(cleared.hasPoint, isFalse);
      expect(cleared.date, DateTime(2026, 10, 5));
    });
  });

  group('DeliveryIntentController', () {
    test('remembers the search for next launch', () async {
      final controller = DeliveryIntentController(restore: false);
      controller.set(_colombo);
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('delivery_intent_v1');
      expect(stored, isNotNull);
      expect(jsonDecode(stored!)['city'], 'Colombo');

      controller.clear();
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('delivery_intent_v1'), isNull);
    });

    test('restores the search, dropping a day that has passed', () async {
      SharedPreferences.setMockInitialValues({
        'delivery_intent_v1': jsonEncode({
          ..._colombo.toJson(),
          'date': '2020-01-01',
        }),
      });
      final controller = DeliveryIntentController();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.state?.city, 'Colombo');
      expect(controller.state?.date, isNull);
    });

    test('an empty search is not kept', () {
      final controller = DeliveryIntentController(restore: false);
      controller.set(const DeliveryIntent());
      expect(controller.state, isNull);
    });
  });

  group('availability', () {
    test('labels each gift with the shop that can deliver it', () {
      final shop = _availability.shops.single;
      expect(shop.shopName, 'Bloom Atelier');
      expect(shop.estimatedDays, 1);
      expect(shop.estimatedDeliveryDate, DateTime(2026, 10, 2));
      expect(_availability.gifts.map((gift) => gift.shopName).toSet(), {
        'Bloom Atelier',
      });
    });

    test('a picked address narrows explore to deliverable gifts', () async {
      final container = _container(
        intent: _colombo,
        availability: _availability,
      );
      await container.read(giftAvailabilityProvider.future);

      final gifts = container.read(filteredGiftsProvider).value!;
      expect(gifts.map((gift) => gift.id), ['p1', 'p2']);

      // Occasion and text filters still apply on top.
      container.read(exploreCategoryProvider.notifier).state = 'flowers';
      expect(container.read(filteredGiftsProvider).value!.single.id, 'p1');
    });

    test(
      'no shop reaching the address is an empty shelf, not every gift',
      () async {
        final container = _container(
          intent: _colombo,
          availability: const GiftAvailability(shops: []),
        );
        await container.read(giftAvailabilityProvider.future);
        expect(container.read(filteredGiftsProvider).value, isEmpty);
      },
    );

    test('without a picked address the whole catalog shows', () async {
      final container = _container(
        intent: const DeliveryIntent(address: 'Typed only'),
        availability: _availability,
      );
      await container.read(giftAvailabilityProvider.future);
      await container.read(catalogProvider.future);
      expect(container.read(filteredGiftsProvider).value!.single.id, 'x');
    });
  });
}
