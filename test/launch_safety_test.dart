import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/core/capabilities/competitions_capability.dart';
import 'package:send_agift_mobile/core/capabilities/competitions_gate.dart';
import 'package:send_agift_mobile/core/errors/app_exception.dart';
import 'package:send_agift_mobile/features/auth/data/auth_controller.dart';
import 'package:send_agift_mobile/features/auth/data/auth_repository.dart';
import 'package:send_agift_mobile/features/cart/presentation/screens/checkout_screen.dart';
import 'package:send_agift_mobile/features/checkout/domain/checkout.dart';
import 'package:send_agift_mobile/features/auth/data/countries_provider.dart';
import 'package:send_agift_mobile/features/delivery/data/delivery_providers.dart';
import 'package:send_agift_mobile/features/delivery/data/delivery_repository.dart';
import 'package:send_agift_mobile/features/delivery/domain/delivery_intent.dart';
import 'package:send_agift_mobile/features/delivery/domain/place.dart';
import 'package:send_agift_mobile/features/game_entries/presentation/state_picker.dart';
import 'package:send_agift_mobile/features/games/data/games_providers.dart';

import 'support/fake_games_repository.dart';

void main() {
  group('competitions capability', () {
    test('only an explicit, known "enabled" turns competitions on', () {
      expect(
        competitionsAllowed({
          'competitions': {'enabled': true, 'policyVersion': 1},
        }),
        isTrue,
      );
      for (final body in <Object?>[
        null,
        'enabled',
        <String, dynamic>{},
        {'competitions': null},
        {
          'competitions': {'enabled': false, 'policyVersion': 1},
        },
        {
          'competitions': {'enabled': 'true', 'policyVersion': 1},
        },
        // A newer policy this build does not understand stays hidden.
        {
          'competitions': {'enabled': true, 'policyVersion': 2},
        },
        {
          'competitions': {'enabled': true},
        },
      ]) {
        expect(competitionsAllowed(body), isFalse, reason: '$body');
      }
    });

    Future<void> pumpGate(WidgetTester tester, {required bool on}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            competitionsEnabledProvider.overrideWith((_) async => on),
          ],
          child: const MaterialApp(
            home: CompetitionsGate(child: Text('the competition')),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('an old competition link shows a neutral screen when off', (
      tester,
    ) async {
      await pumpGate(tester, on: false);
      expect(find.text('the competition'), findsNothing);
      expect(
        find.text('Competitions are not available at this time.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('competitions-unavailable-shop')),
        findsOneWidget,
      );
    });

    testWidgets('the competition opens when the server has them on', (
      tester,
    ) async {
      await pumpGate(tester, on: true);
      expect(find.text('the competition'), findsOneWidget);
    });
  });

  group('searched address matching', () {
    RecipientAddress saved(
      String line1, {
      String city = 'Colombo',
      String? postalCode = '00300',
      double? latitude,
      double? longitude,
    }) => RecipientAddress(
      id: line1,
      countryId: 'lk',
      line1: line1,
      city: city,
      postalCode: postalCode,
      latitude: latitude,
      longitude: longitude,
    );

    test('the same street and postcode match', () {
      const intent = DeliveryIntent(
        line1: '12 Main Street',
        city: 'Colombo',
        postalCode: '00300',
      );
      expect(searchedAddressMatches(intent, saved('12 Main Street')), isTrue);
    });

    test('part of a street number is a different address', () {
      const intent = DeliveryIntent(
        line1: '12 Main Street',
        city: 'Colombo',
        postalCode: '00300',
      );
      expect(searchedAddressMatches(intent, saved('112 Main Street')), isFalse);
    });

    test('being close on the map is not the same address', () {
      const intent = DeliveryIntent(
        line1: '7 Lake Road',
        city: 'Kandy',
        postalCode: '20000',
        latitude: 6.9271,
        longitude: 79.8612,
      );
      // About 50 m away, different street and city.
      final nextDoor = saved(
        '9 Hill Street',
        city: 'Colombo',
        latitude: 6.9275,
        longitude: 79.8614,
      );
      expect(searchedAddressMatches(intent, nextDoor), isFalse);
    });

    test('a different postcode on the same street does not match', () {
      const intent = DeliveryIntent(
        address: '12 Main Street, Colombo 00500',
        city: 'Colombo',
        postalCode: '00500',
      );
      expect(searchedAddressMatches(intent, saved('12 Main Street')), isFalse);
    });
  });

  testWidgets('the state is searched on Google within the country', (
    tester,
  ) async {
    final delivery = _FakeDelivery();
    String? chosen;
    bool? required;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deliveryRepositoryProvider.overrideWithValue(delivery),
          gamesRepositoryProvider.overrideWithValue(FakeGamesRepository()),
          countriesProvider.overrideWith(
            (ref) async => const [
              Country(id: 'au', name: 'Australia', isoCode: 'AU'),
            ],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => StatePicker(
                countryId: 'au',
                value: chosen,
                onChanged: (id) => setState(() => chosen = id),
                onRequired: (r) => required = r,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(required, isTrue);

    await tester.enterText(find.byKey(const Key('state-search')), 'New S');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(delivery.searches.single, 'states:AU:New S');

    await tester.tap(find.text('New South Wales'));
    await tester.pumpAndSettle();
    expect(chosen, 'state-nsw');

    // Typing over it un-chooses it.
    await tester.enterText(find.byKey(const Key('state-search')), 'Vic');
    await tester.pump(const Duration(milliseconds: 350));
    expect(chosen, isNull);
  });

  group('restoring a session', () {
    test(
      'a network failure keeps the session instead of signing out',
      () async {
        final repository = _ScriptedAuth([const NetworkException()]);
        final controller = AuthController(repository);
        addTearDown(controller.dispose);
        await pumpEventQueue();

        expect(controller.state.offline, isTrue);
        expect(controller.state.isLoading, isFalse);
        expect(repository.cleared, isFalse);
      },
    );

    test('a rejected token signs out', () async {
      // The repository clears the token and answers null on a 401.
      final repository = _ScriptedAuth([null]);
      final controller = AuthController(repository);
      addTearDown(controller.dispose);
      await pumpEventQueue();

      expect(controller.state.isSignedIn, isFalse);
      expect(controller.state.offline, isFalse);
    });

    test('the profile loads once the connection is back', () async {
      final repository = _ScriptedAuth([
        const NetworkException(),
        {'id': 'c1', 'display_name': 'Pawan'},
      ]);
      final controller = AuthController(repository);
      addTearDown(controller.dispose);
      await pumpEventQueue();
      expect(controller.state.offline, isTrue);

      await controller.refresh();
      expect(controller.state.isSignedIn, isTrue);
      expect(controller.state.offline, isFalse);
    });
  });
}

/// Answers each me() with the next scripted result: a profile, null, or an
/// error to throw.
class _ScriptedAuth implements AuthRepository {
  _ScriptedAuth(this.answers);

  final List<Object?> answers;
  bool cleared = false;

  @override
  Future<bool> hasSession() async => !cleared;

  @override
  Future<Map<String, dynamic>?> me() async {
    final next = answers.isEmpty ? null : answers.removeAt(0);
    if (next is AppException) throw next;
    return next as Map<String, dynamic>?;
  }

  @override
  Future<void> logout() async => cleared = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A state search that answers from a fixed list instead of Google.
class _FakeDelivery implements DeliveryRepository {
  final List<String> searches = [];

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    String? sessionToken,
    String types = 'address',
    String? countryCode,
  }) async {
    searches.add('$types:$countryCode:$input');
    return const [
      PlaceSuggestion(
        placeId: 'nsw',
        description: 'New South Wales, Australia',
        mainText: 'New South Wales',
        secondaryText: 'Australia',
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
