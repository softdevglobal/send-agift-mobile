import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/checkout/data/checkout_repository.dart';
import 'package:send_agift_mobile/features/checkout/domain/checkout.dart';
import 'package:send_agift_mobile/features/profile/data/account_repository.dart';
import 'package:send_agift_mobile/features/profile/presentation/screens/addresses_screen.dart';
import 'package:send_agift_mobile/features/profile/presentation/screens/recipient_detail_screen.dart';
import 'package:send_agift_mobile/features/profile/presentation/screens/recipients_screen.dart';

const _home = RecipientAddress(
  id: 'a1',
  countryId: 'lk',
  line1: '12 Ampitiya-Gurudeniya Road',
  city: 'Kandy',
  region: 'Central Province',
  postalCode: '20000',
  latitude: 7.28,
  longitude: 80.63,
  label: 'Home',
  isDefault: true,
);

const _office = RecipientAddress(
  id: 'a2',
  countryId: 'lk',
  line1: 'Kandy General Hospital, a rather long building name for wrapping',
  city: 'Kandy',
  label: 'Office',
);

final _people = [
  for (final name in [
    'Amaya Perera',
    'Ravi Silva',
    'Nimali',
    'Kasun Fernando',
    'Dilani Jayasinghe',
    'Bob',
  ])
    Recipient(id: name, name: name, relationship: 'Friend', phone: '+94 77'),
];

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        recipientsProvider.overrideWith((ref) async => _people),
        recipientDetailsProvider('r1').overrideWith(
          (ref) async => const Recipient(
            id: 'r1',
            name: 'Amaya Perera',
            relationship: 'Best friend',
            phone: '+94 77 123 4567',
            email: 'amaya@example.com',
            defaultAddressId: 'a1',
            addresses: [_home, _office],
          ),
        ),
        myAddressesProvider.overrideWith((ref) async => const [_home, _office]),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('recipients list groups people A to Z', (tester) async {
    await _pump(tester, const RecipientsScreen());
    expect(find.text('Your people'), findsOneWidget);
    expect(find.text('6 people'), findsOneWidget);
    expect(find.byKey(const Key('recipients-search')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recipient page shows contact actions and addresses', (
    tester,
  ) async {
    await _pump(tester, const RecipientDetailScreen(recipientId: 'r1'));
    expect(find.text('Find a gift for Amaya'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Office'), 200);
    expect(find.text('Make default'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('addresses puts the default first', (tester) async {
    await _pump(tester, const AddressesScreen());
    expect(find.text('HOME BASE'), findsOneWidget);
    expect(find.text('2 saved addresses'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
