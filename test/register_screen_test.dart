import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/core/errors/app_exception.dart';
import 'package:send_agift_mobile/features/auth/data/auth_controller.dart';
import 'package:send_agift_mobile/features/auth/data/auth_repository.dart';
import 'package:send_agift_mobile/features/auth/data/countries_provider.dart';
import 'package:send_agift_mobile/features/auth/presentation/screens/register_screen.dart';

import 'support/fake_auth.dart';

void main() {
  registerTakenEmailTest();
  Future<void> pumpRegister(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakeAuth(),
          countriesProvider.overrideWith(
            (ref) async => const [
              Country(id: 'lk', name: 'Sri Lanka', isoCode: 'LK'),
            ],
          ),
        ],
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sign-up asks only for the essentials and fits a narrow phone', (
    tester,
  ) async {
    await pumpRegister(tester, const Size(320, 1400));

    expect(tester.takeException(), isNull);
    expect(find.text('Your name'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    // A photo and addresses come later, from the Account tab.
    expect(find.textContaining('Address'), findsNothing);
    expect(find.textContaining('Photo'), findsNothing);
  });

  testWidgets('choosing who you gift as, and the password meter', (
    tester,
  ) async {
    await pumpRegister(tester, const Size(390, 1400));

    await tester.tap(find.byKey(const Key('gifting-as-business')));
    await tester.pump();
    // Picking a card doesn't break the form.
    expect(tester.takeException(), isNull);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(3), 'short');
    await tester.pump();
    expect(find.text('Too short'), findsOneWidget);

    await tester.enterText(fields.at(3), 'Gift-Giver-2026!');
    await tester.enterText(fields.at(4), 'Gift-Giver-2026!');
    await tester.pump();
    expect(find.text('Excellent'), findsOneWidget);
    expect(find.text('Matches'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TakenEmailRepository implements AuthRepository {
  @override
  Future<bool> hasSession() async => false;

  @override
  Future<Map<String, dynamic>?> me() async => null;

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String countryId,
    required String phone,
    String customerType = 'individual',
  }) async {
    throw const AppException('email already registered', statusCode: 409);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void registerTakenEmailTest() {
  testWidgets('an email that already has an account gets a way forward', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => AuthController(_TakenEmailRepository()),
          ),
          countriesProvider.overrideWith(
            (ref) async => const [
              Country(id: 'lk', name: 'Sri Lanka', isoCode: 'LK'),
            ],
          ),
        ],
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Sam');
    await tester.enterText(fields.at(1), 'sam@example.com');
    await tester.enterText(fields.at(2), '771234567');
    await tester.enterText(fields.at(3), 'Gift-Giver-2026!');
    await tester.enterText(fields.at(4), 'Gift-Giver-2026!');
    final countryDropdown = find.byType(DropdownButtonFormField<String>).first;
    await tester.ensureVisible(countryDropdown);
    await tester.pumpAndSettle();
    await tester.tap(countryDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sri Lanka (LK)').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('email-taken')), findsOneWidget);
    expect(find.textContaining('sam@example.com already has'), findsOneWidget);
    expect(find.text('Sign in instead'), findsOneWidget);
    expect(find.text('email already registered'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
