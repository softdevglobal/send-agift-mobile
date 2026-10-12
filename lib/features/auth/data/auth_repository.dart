import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/token_storage.dart';
import '../domain/code_signup.dart';
import '../domain/social_signup.dart';
import 'social_sign_in.dart';

/// Customer authentication. The mobile app is customer-only, so it talks to
/// the customer endpoints exclusively. Seller and admin logins live on web.
class AuthRepository {
  AuthRepository(this._client, this._tokenStorage);

  final ApiClient _client;
  final TokenStorage _tokenStorage;

  /// [email] may also be the phone saved on the account.
  Future<void> login({required String email, required String password}) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/customers/login',
        data: {'email': email, 'password': password},
      );

      final token = response.data?['token'] as String?;
      if (token == null || token.isEmpty) {
        throw const AppException('Sign in failed. Please try again.');
      }
      await _tokenStorage.saveTokens(accessToken: token);
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String countryId,
    required String phone,
    String customerType = 'individual',
    String? signupToken,
  }) async {
    try {
      await _client.dio.post<Map<String, dynamic>>(
        '/customers/register',
        data: {
          'email': email,
          'password': password,
          'display_name': displayName,
          'country_id': countryId,
          'phone': phone,
          'customer_type': customerType,
          'signup_token': ?signupToken,
        },
      );
      await login(email: email, password: password);
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// Sends a 6-digit sign-in code. The answer is the same whether or not an
  /// account uses [destination], so it returns the server's wording.
  Future<String> requestLoginCode({
    required CodeChannel channel,
    required String destination,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/customers/login/code',
        data: {'channel': channel.name, 'destination': destination},
      );
      return response.data?['message'] as String? ??
          'If that is yours, a code is on its way.';
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// Checks the code. Returns null when the customer is now signed in, or the
  /// sign-up to finish when nobody uses that phone or email yet.
  Future<CodeSignup?> verifyLoginCode({
    required CodeChannel channel,
    required String destination,
    required String code,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/customers/login/code/verify',
        data: {
          'channel': channel.name,
          'destination': destination,
          'code': code,
        },
      );
      final data = response.data ?? const {};
      if (data['status'] == 'needs_signup') return CodeSignup.fromJson(data);
      await _saveToken(data);
      return null;
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// Keeps this device signed in with a fresh token, e.g. after an email
  /// change stopped every older one working.
  Future<void> replaceToken(String token) => _saveToken({'token': token});

  /// Sends a provider's token to the API. Returns null when the customer is
  /// now signed in, or the sign-up still to finish for a new customer.
  Future<SocialSignup?> socialSignIn(ProviderToken provider) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/auth/social',
        data: {
          'provider': provider.provider,
          'token': provider.token,
          'token_type': provider.tokenType,
        },
      );
      final data = response.data ?? const {};
      if (data['status'] == 'needs_profile') return SocialSignup.fromJson(data);
      await _saveToken(data);
      return null;
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// Makes the account for a new social customer and signs them in.
  Future<void> completeSocialSignup({
    required SocialSignup signup,
    required String countryId,
    required String phone,
    required String displayName,
    String customerType = 'individual',
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/auth/social/complete',
        data: {
          'signup_token': signup.signupToken,
          'country_id': countryId,
          'phone': phone,
          'display_name': displayName,
          'customer_type': customerType,
        },
      );
      await _saveToken(response.data ?? const {});
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  Future<void> _saveToken(Map<String, dynamic> data) async {
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const AppException('Sign in failed. Please try again.');
    }
    await _tokenStorage.saveTokens(accessToken: token);
  }

  Future<Map<String, dynamic>?> me() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/customers/me',
      );
      return response.data;
    } on DioException {
      return null;
    }
  }

  Future<void> logout() => _tokenStorage.clear();

  Future<bool> hasSession() async {
    final token = await _tokenStorage.accessToken;
    return token != null && token.isNotEmpty;
  }
}
