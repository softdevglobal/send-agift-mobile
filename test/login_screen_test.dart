import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/auth/presentation/screens/login_screen.dart';

import 'support/fake_auth.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('sign-in matches the sign-up style and fits $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [fakeAuth()],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Good to see you again'), findsNothing);
      expect(find.text('Earn points'), findsOneWidget);
      expect(find.byKey(const Key('login-submit')), findsOneWidget);
      expect(find.byKey(const Key('auth-back')), findsOneWidget);
    });
  }
}
