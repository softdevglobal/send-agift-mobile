import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:send_agift_mobile/features/auth/data/auth_controller.dart';
import 'package:send_agift_mobile/features/auth/data/auth_repository.dart';

/// Who is signed in, without a backend: a guest unless [customer] is given.
/// The real session sits on an API client that reads dotenv, which tests do
/// not load.
Override fakeAuth({Map<String, dynamic>? customer}) => authProvider
    .overrideWith((ref) => AuthController(_FakeAuthRepository(customer)));

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.customer);

  final Map<String, dynamic>? customer;

  @override
  Future<bool> hasSession() async => customer != null;

  @override
  Future<Map<String, dynamic>?> me() async => customer;

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
