import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/auth/data/auth_controller.dart';
import 'package:send_agift_mobile/features/profile/data/account_repository.dart';
import 'package:send_agift_mobile/features/profile/presentation/screens/edit_profile_screen.dart';

import 'support/fake_auth.dart';

class _FakeAccount implements AccountRepository {
  final saved = <String, String?>{};

  @override
  Future<void> updateProfile({
    required String displayName,
    required String phone,
    String? imageUrl,
  }) async {
    saved
      ..['name'] = displayName
      ..['phone'] = phone
      ..['image'] = imageUrl;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a saved phone splits into its country code and number', () {
    expect(splitPhone('+94 77 123 4567'), ('LK', '77 123 4567'));
    expect(splitPhone('+44 7700 900123'), ('GB', '7700 900123'));
    expect(splitPhone(null), ('LK', ''));
    expect(splitPhone('0771234567'), ('LK', '0771234567'));
  });

  testWidgets('edits name and phone, and email stays locked', (tester) async {
    final account = _FakeAccount();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakeAuth(
            customer: {
              'id': 'c1',
              'display_name': 'Pawan Kanchana',
              'email': 'pawan@example.com',
              'phone': '+94 77 123 4567',
            },
          ),
          accountRepositoryProvider.overrideWithValue(account),
        ],
        child: MaterialApp(
          // Watches the session like the Account screen does, so it has
          // loaded by the time Edit profile opens.
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EditProfileScreen(),
                  ),
                ),
                child: Text(
                  ref.watch(authProvider).isSignedIn ? 'open' : 'loading',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('pawan@example.com'), findsOneWidget);
    final email = tester.widget<TextField>(
      find.byKey(const Key('profile-email')),
    );
    expect(email.enabled, isFalse);
    final phone = tester.widget<TextField>(
      find.byKey(const Key('profile-phone')),
    );
    expect(phone.controller!.text, '77 123 4567');

    await tester.enterText(find.byKey(const Key('profile-name')), 'Pawan K');
    await tester.enterText(
      find.byKey(const Key('profile-phone')),
      '71 555 0000',
    );
    await tester.ensureVisible(find.byKey(const Key('profile-save')));
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();

    expect(account.saved['name'], 'Pawan K');
    expect(account.saved['phone'], '+94 71 555 0000');
    // The photo was not touched, so it is not sent.
    expect(account.saved['image'], isNull);
    expect(find.text('Profile saved.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
