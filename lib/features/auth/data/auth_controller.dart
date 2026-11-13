import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';

import '../../../core/network/providers.dart';
import '../../../core/notifications/push_notifications.dart';
import '../domain/code_signup.dart';
import '../domain/social_signup.dart';
import 'auth_repository.dart';
import 'social_sign_in.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  );
});

/// Signed-in customer, or null for a guest.
class AuthState {
  const AuthState({
    this.customer,
    this.isLoading = false,
    this.offline = false,
  });

  final Map<String, dynamic>? customer;
  final bool isLoading;

  /// A saved session that could not be checked (no connection, or the
  /// server failed). The token is kept and checked again shortly; only a
  /// 401 from the server signs the customer out.
  final bool offline;

  bool get isSignedIn => customer != null;

  String get displayName {
    final name = customer?['display_name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return customer?['email'] as String? ?? 'Customer';
  }

  String? get email => customer?['email'] as String?;

  String? get phone => _text('phone');

  /// The saved phone was proved with a text code, so it can sign in.
  bool get phoneVerified => _text('phone_verified_at') != null;

  /// The profile photo, when one is set.
  String? get imageUrl => _text('image_url');

  /// An account made for a gift recipient, still on the temporary password
  /// emailed with their gift.
  bool get passwordChangeRequired =>
      customer?['password_change_required'] == true;

  String? _text(String key) {
    final value = customer?[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }
}

/// Session state. Guests are the default: nothing here blocks browsing, and
/// the app only asks for credentials at checkout or order history.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository, {Future<void> Function()? beforeSignOut})
    : _beforeSignOut = beforeSignOut,
      super(const AuthState(isLoading: true)) {
    _restore();
  }

  final AuthRepository _repository;

  /// Runs while the session is still valid, so the device can be removed
  /// from push notifications before the token is cleared.
  final Future<void> Function()? _beforeSignOut;

  Timer? _retry;
  int _retries = 0;

  Future<void> _restore() async {
    if (!await _repository.hasSession()) {
      state = const AuthState();
      return;
    }
    await _loadProfile();
  }

  /// Reads the profile for the saved session. Offline, the session is kept
  /// and tried again with a growing pause, rather than dropped.
  Future<void> _loadProfile() async {
    _retry?.cancel();
    try {
      state = AuthState(customer: await _repository.me());
      _retries = 0;
    } on AppException {
      if (!await _repository.hasSession()) {
        state = const AuthState();
        return;
      }
      state = AuthState(customer: state.customer, offline: true);
      const waits = [3, 10, 30, 60];
      final wait = waits[_retries < waits.length ? _retries : waits.length - 1];
      _retries++;
      _retry = Timer(Duration(seconds: wait), () {
        if (mounted) _loadProfile();
      });
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthState(isLoading: true);
    try {
      await _repository.login(email: email, password: password);
      await _loadProfile();
    } catch (_) {
      state = const AuthState();
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String countryId,
    required String phone,
    String? stateId,
    String customerType = 'individual',
    String? signupToken,
  }) async {
    state = const AuthState(isLoading: true);
    try {
      await _repository.register(
        email: email,
        password: password,
        displayName: displayName,
        countryId: countryId,
        stateId: stateId,
        phone: phone,
        customerType: customerType,
        signupToken: signupToken,
      );
      await _loadProfile();
    } catch (_) {
      state = const AuthState();
      rethrow;
    }
  }

  /// Checks a one-time sign-in code. Returns the sign-up still to finish for
  /// someone new, or null once they are signed in.
  Future<CodeSignup?> verifyLoginCode({
    required CodeChannel channel,
    required String destination,
    required String code,
  }) async {
    final pending = await _repository.verifyLoginCode(
      channel: channel,
      destination: destination,
      code: code,
    );
    if (pending == null) await _loadProfile();
    return pending;
  }

  /// Swaps in the token an email change answered with, and re-reads the
  /// profile so the new address shows everywhere.
  Future<void> replaceToken(String token) async {
    await _repository.replaceToken(token);
    await _loadProfile();
  }

  /// Signs in with a provider token. Returns the sign-up still to finish for
  /// a new customer, or null once they are signed in.
  Future<SocialSignup?> socialSignIn(ProviderToken provider) async {
    final pending = await _repository.socialSignIn(provider);
    if (pending == null) await _loadProfile();
    return pending;
  }

  /// Finishes a social sign-up and signs the new customer in.
  Future<void> completeSocialSignup({
    required SocialSignup signup,
    required String countryId,
    required String phone,
    required String displayName,
    String? stateId,
    String customerType = 'individual',
  }) async {
    await _repository.completeSocialSignup(
      signup: signup,
      countryId: countryId,
      stateId: stateId,
      phone: phone,
      displayName: displayName,
      customerType: customerType,
    );
    await _loadProfile();
  }

  /// Re-reads the profile after it was edited, so every screen shows the
  /// new name, phone and photo.
  Future<void> refresh() async {
    if (!state.isSignedIn && !state.offline) return;
    await _loadProfile();
  }

  Future<void> logout() async {
    _retry?.cancel();
    await _beforeSignOut?.call();
    await _repository.logout();
    state = const AuthState();
  }

  /// Forgets the session after the account was deleted. The server has
  /// already removed this device and revoked every token, so nothing is sent.
  Future<void> forgetDeletedAccount() async {
    await _repository.logout();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(authRepositoryProvider),
    beforeSignOut: () => ref.read(pushNotificationsProvider).unregisterDevice(),
  );
});
