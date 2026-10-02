import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';
import '../../../core/notifications/push_notifications.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  );
});

/// Signed-in customer, or null for a guest.
class AuthState {
  const AuthState({this.customer, this.isLoading = false});

  final Map<String, dynamic>? customer;
  final bool isLoading;

  bool get isSignedIn => customer != null;

  String get displayName {
    final name = customer?['display_name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return customer?['email'] as String? ?? 'Customer';
  }

  String? get email => customer?['email'] as String?;

  String? get phone => _text('phone');

  /// The profile photo, when one is set.
  String? get imageUrl => _text('image_url');

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

  Future<void> _restore() async {
    if (!await _repository.hasSession()) {
      state = const AuthState();
      return;
    }
    state = AuthState(customer: await _repository.me());
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthState(isLoading: true);
    try {
      await _repository.login(email: email, password: password);
      state = AuthState(customer: await _repository.me());
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
  }) async {
    state = const AuthState(isLoading: true);
    try {
      await _repository.register(
        email: email,
        password: password,
        displayName: displayName,
        countryId: countryId,
      );
      state = AuthState(customer: await _repository.me());
    } catch (_) {
      state = const AuthState();
      rethrow;
    }
  }

  /// Re-reads the profile after it was edited, so every screen shows the
  /// new name, phone and photo.
  Future<void> refresh() async {
    if (!state.isSignedIn) return;
    state = AuthState(customer: await _repository.me());
  }

  Future<void> logout() async {
    await _beforeSignOut?.call();
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
