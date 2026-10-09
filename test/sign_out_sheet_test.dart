import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:send_agift_mobile/core/theme/app_theme.dart';
import 'package:send_agift_mobile/features/profile/presentation/widgets/sign_out_sheet.dart';

Future<void> _frames(WidgetTester tester, [int ms = 1800]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Opens the sheet from a button and records what it returned.
Future<List<bool?>> _open(
  WidgetTester tester, {
  String? name = 'Sam Perera',
  required Future<void> Function() onSignOut,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final results = <bool?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async => results.add(
                await showSignOutSheet(
                  context,
                  name: name,
                  points: 155,
                  savedCount: 4,
                  orderCount: 7,
                  onSignOut: onSignOut,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await _frames(tester);
  return results;
}

void main() {
  testWidgets('greets by first name and shows what the account keeps', (
    tester,
  ) async {
    await _open(tester, onSignOut: () async {});
    expect(find.text('Leaving so soon, Sam?'), findsOneWidget);
    expect(find.text('155'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('without a name it does not guess one', (tester) async {
    await _open(tester, name: null, onSignOut: () async {});
    expect(find.text('Leaving so soon?'), findsOneWidget);
  });

  testWidgets('staying signed in never signs out', (tester) async {
    var calls = 0;
    final results = await _open(tester, onSignOut: () async => calls++);
    await tester.tap(find.text('Stay signed in'));
    await _frames(tester, 600);
    expect(calls, 0);
    expect(results, [false]);
  });

  testWidgets('signing out shows progress, then closes', (tester) async {
    var signedOut = false;
    final results = await _open(
      tester,
      onSignOut: () async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        signedOut = true;
      },
    );
    await tester.tap(find.text('Sign out'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Signing out…'), findsOneWidget);
    await _frames(tester, 800);
    expect(signedOut, isTrue);
    expect(results, [true]);
  });

  testWidgets('a failed sign-out says so and stays open', (tester) async {
    final results = await _open(
      tester,
      onSignOut: () async => throw Exception('offline'),
    );
    await tester.tap(find.text('Sign out'));
    await _frames(tester, 400);
    expect(find.textContaining('Could not sign out'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(results, isEmpty);
  });
}
