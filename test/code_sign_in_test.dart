import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:send_agift_mobile/core/router/app_router.dart';
import 'package:send_agift_mobile/features/auth/data/auth_controller.dart';
import 'package:send_agift_mobile/features/auth/data/auth_repository.dart';
import 'package:send_agift_mobile/features/auth/data/countries_provider.dart';
import 'package:send_agift_mobile/features/auth/domain/code_signup.dart';
import 'package:send_agift_mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:send_agift_mobile/features/auth/presentation/screens/verify_code_screen.dart';
import 'package:send_agift_mobile/features/auth/presentation/widgets/code_sign_in_panel.dart';
import 'package:send_agift_mobile/features/profile/data/account_repository.dart';
import 'package:send_agift_mobile/features/profile/presentation/screens/change_email_screen.dart';

/// Records what the screens send, and answers like the API.
class _FakeAuth implements AuthRepository {
  _FakeAuth({this.customer, this.newcomer = false});

  Map<String, dynamic>? customer;

  /// Nobody uses the phone yet, so verifying asks for a sign-up.
  final bool newcomer;

  final calls = <String, Object?>{};

  @override
  Future<bool> hasSession() async => customer != null;

  @override
  Future<Map<String, dynamic>?> me() async => customer;

  @override
  Future<String> requestLoginCode({
    required CodeChannel channel,
    required String destination,
  }) async {
    calls['sent'] = '${channel.name}:$destination';
    return 'If that is yours, a code is on its way.';
  }

  @override
  Future<CodeSignup?> verifyLoginCode({
    required CodeChannel channel,
    required String destination,
    required String code,
  }) async {
    calls['code'] = code;
    if (newcomer) {
      return const CodeSignup(
        signupToken: 'signup-1',
        channel: CodeChannel.sms,
        destination: '+94771234567',
      );
    }
    customer = {'id': 'c1', 'email': 'sam@example.com'};
    return null;
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String countryId,
    required String phone,
    String customerType = 'individual',
    String? signupToken,
  }) async {
    calls['register'] = {'phone': phone, 'token': signupToken};
  }

  @override
  Future<void> replaceToken(String token) async {
    calls['token'] = token;
    customer = {...?customer, 'email': 'new@example.com'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccount implements AccountRepository {
  final calls = <String, Object?>{};

  @override
  Future<void> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    calls['change'] = '$newEmail/$currentPassword';
  }

  @override
  Future<EmailChangeResult> confirmEmailChange(String code) async {
    calls['confirm'] = code;
    return EmailChangeResult(
      email: 'new@example.com',
      token: 'fresh-token',
      redemptionLockedUntil: DateTime(2026, 10, 19),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  /// The panel on a home route, with the real verify-code route above it.
  Future<({bool signedIn, CodeSignup? signup})> runPanel(
    WidgetTester tester,
    _FakeAuth auth,
    String code,
  ) async {
    var signedIn = false;
    CodeSignup? signup;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: ListView(
              children: [
                CodeSignInPanel(
                  onSignedIn: () => signedIn = true,
                  onNeedsSignup: (pending) => signup = pending,
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.verifyCode,
          builder: (context, state) =>
              VerifyCodeScreen(target: state.extra! as CodeTarget),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          authProvider.overrideWith((ref) => AuthController(auth)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('code-destination')),
      '77 123 4567',
    );
    await tester.ensureVisible(find.byKey(const Key('code-submit')));
    await tester.tap(find.byKey(const Key('code-submit')));
    await tester.pumpAndSettle();

    // The code goes in on its own screen.
    expect(find.byType(VerifyCodeScreen), findsOneWidget);
    expect(find.text('Resend in 60s'), findsOneWidget);
    // The sixth digit signs in without another tap.
    await tester.enterText(find.byKey(const Key('code-input')), code);
    await tester.pumpAndSettle();
    expect(find.byType(VerifyCodeScreen), findsNothing);
    return (signedIn: signedIn, signup: signup);
  }

  testWidgets('a code by text signs a known customer in', (tester) async {
    final auth = _FakeAuth();
    final result = await runPanel(tester, auth, '325217');

    expect(auth.calls['sent'], 'sms:+94 77 123 4567');
    expect(auth.calls['code'], '325217');
    expect(result.signedIn, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new phone carries on to sign-up', (tester) async {
    final result = await runPanel(tester, _FakeAuth(newcomer: true), '111111');

    expect(result.signedIn, isFalse);
    expect(result.signup?.signupToken, 'signup-1');
  });

  testWidgets('sign-up keeps the verified phone and sends its token', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = _FakeAuth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => AuthController(auth)),
          countriesProvider.overrideWith(
            (ref) async => const [
              Country(id: 'lk', name: 'Sri Lanka', isoCode: 'LK'),
            ],
          ),
        ],
        child: const MaterialApp(
          home: RegisterScreen(
            codeSignup: CodeSignup(
              signupToken: 'signup-1',
              channel: CodeChannel.sms,
              destination: '+94771234567',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('code-signup')), findsOneWidget);
    final phone = tester.widget<TextFormField>(
      find.byKey(const Key('register-phone')),
    );
    expect(phone.controller!.text, '771234567');
    expect(phone.enabled, isFalse);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Sam');
    await tester.enterText(fields.at(1), 'sam@example.com');
    await tester.enterText(fields.at(3), 'Gift-Giver-2026!');
    await tester.enterText(fields.at(4), 'Gift-Giver-2026!');
    final country = find.byType(DropdownButtonFormField<String>).first;
    await tester.ensureVisible(country);
    await tester.pumpAndSettle();
    await tester.tap(country);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sri Lanka (LK)').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pumpAndSettle();

    expect(auth.calls['register'], {
      'phone': '+94 771234567',
      'token': 'signup-1',
    });
  });

  testWidgets('changing email checks a code and keeps the app signed in', (
    tester,
  ) async {
    final auth = _FakeAuth(customer: {'id': 'c1', 'email': 'sam@example.com'});
    final account = _FakeAccount();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => AuthController(auth)),
          accountRepositoryProvider.overrideWithValue(account),
        ],
        child: const MaterialApp(home: ChangeEmailScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('email-new')),
      'new@example.com',
    );
    await tester.enterText(find.byKey(const Key('email-password')), 'secret');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('email-send-code')));
    await tester.tap(find.byKey(const Key('email-send-code')));
    await tester.pumpAndSettle();
    expect(account.calls['change'], 'new@example.com/secret');

    await tester.enterText(find.byKey(const Key('email-code')), '123456');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('email-confirm')));
    await tester.tap(find.byKey(const Key('email-confirm')));
    await tester.pumpAndSettle();

    expect(account.calls['confirm'], '123456');
    expect(auth.calls['token'], 'fresh-token');
    expect(find.byKey(const Key('email-changed')), findsOneWidget);
    expect(find.textContaining('until 19 October'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
