import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:send_agift_mobile/core/errors/app_exception.dart';
import 'package:send_agift_mobile/features/auth/data/auth_controller.dart';
import 'package:send_agift_mobile/features/profile/data/account_repository.dart';
import 'package:send_agift_mobile/features/profile/presentation/widgets/delete_account_sheet.dart';

import 'support/fake_auth.dart';

class _FakeAccounts implements AccountRepository {
  _FakeAccounts({this.failure});

  final AppException? failure;
  int deletes = 0;

  @override
  Future<void> deleteAccount() async {
    deletes++;
    if (failure != null) throw failure!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(ProviderContainer, ValueNotifier<DeleteAccountResult?>)> _open(
  WidgetTester tester,
  _FakeAccounts accounts,
) async {
  tester.view.physicalSize = const Size(390 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      fakeAuth(customer: {'id': 'c1', 'email': 'jane@example.test'}),
      accountRepositoryProvider.overrideWithValue(accounts),
    ],
  );
  addTearDown(container.dispose);
  // Signed in before the sheet opens, as on the Account screen.
  container.read(authProvider);
  await tester.pump();
  final result = ValueNotifier<DeleteAccountResult?>(null);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result.value = await showDeleteAccountSheet(
              context,
              points: 240,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (container, result);
}

void main() {
  testWidgets('says what is lost and needs DELETE typed first', (tester) async {
    final accounts = _FakeAccounts();
    final (container, result) = await _open(tester, accounts);

    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.textContaining('240 points are lost'), findsOneWidget);
    expect(find.textContaining('kept as the law requires'), findsOneWidget);

    final submit = find.byKey(const Key('delete-account-submit'));
    await tester.tap(submit);
    await tester.pump();
    expect(accounts.deletes, 0, reason: 'nothing happens before DELETE');

    await tester.enterText(
      find.byKey(const Key('delete-account-confirm')),
      'delete',
    );
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(accounts.deletes, 1);
    expect(result.value, DeleteAccountResult.deleted);
    expect(container.read(authProvider).isSignedIn, isFalse);
  });

  testWidgets('a gift on its way stops it and points to the orders', (
    tester,
  ) async {
    final accounts = _FakeAccounts(
      failure: const AppException(
        'you have a gift on its way',
        statusCode: 409,
        code: 'ACTIVE_ORDERS',
      ),
    );
    final (container, result) = await _open(tester, accounts);

    await tester.enterText(
      find.byKey(const Key('delete-account-confirm')),
      'DELETE',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('delete-account-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('A gift is still on its way'), findsOneWidget);
    expect(container.read(authProvider).isSignedIn, isTrue);

    await tester.tap(find.byKey(const Key('delete-account-view-orders')));
    await tester.pumpAndSettle();
    expect(result.value, DeleteAccountResult.viewOrders);
  });
}
