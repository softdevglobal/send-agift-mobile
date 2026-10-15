import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';

/// A token from the provider's own sign-in, ready for the API to verify.
/// [nonce] and [name] are only used by Apple: the raw value the sign-in was
/// started with, and the name Apple gives the app once, on the first sign-in.
typedef ProviderToken = ({
  String provider,
  String token,
  String tokenType,
  String? nonce,
  String? name,
});

/// Opens Google's, Facebook's or Apple's sign-in and hands back their token.
/// Returns null when the person closes the provider's sheet.
class SocialSignInClient {
  static bool _googleReady = false;

  static bool get googleEnabled => AppConfig.googleWebClientId.isNotEmpty;
  static bool get facebookEnabled => AppConfig.facebookAppId.isNotEmpty;

  /// Sign in with Apple is part of iOS itself, so it needs no key from us.
  /// Apple requires it wherever another provider's sign-in is offered.
  static bool get appleEnabled => Platform.isIOS;

  /// A one-time value that ties Apple's token to this sign-in, so a token
  /// captured elsewhere cannot be replayed.
  static String _newNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Future<ProviderToken?> apple() async {
    final nonce = _newNonce();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        // Apple puts the SHA-256 of this in the token; the API checks it
        // against the raw value sent alongside.
        nonce: sha256.convert(utf8.encode(nonce)).toString(),
      );
      final token = credential.identityToken;
      if (token == null || token.isEmpty) {
        throw const AppException('Apple did not return a sign-in token.');
      }
      final name = [
        credential.givenName,
        credential.familyName,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
      return (
        provider: 'apple',
        token: token,
        tokenType: 'id_token',
        nonce: nonce,
        name: name.isEmpty ? null : name,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) return null;
      throw AppException(
        'Sign in with Apple is not available right now. ${error.message}'
            .trim(),
      );
    }
  }

  Future<ProviderToken?> google() async {
    try {
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize(
          // The ID token is issued for the web client, which the API knows.
          serverClientId: AppConfig.googleWebClientId,
          clientId: Platform.isIOS && AppConfig.googleIosClientId.isNotEmpty
              ? AppConfig.googleIosClientId
              : null,
        );
        _googleReady = true;
      }
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AppException('Google did not return a sign-in token.');
      }
      return (
        provider: 'google',
        token: idToken,
        tokenType: 'id_token',
        nonce: null,
        name: null,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw AppException(
        'Google sign-in is not available right now. '
                '${error.description ?? ''}'
            .trim(),
      );
    }
  }

  Future<ProviderToken?> facebook() async {
    final result = await FacebookAuth.instance.login(
      permissions: const ['public_profile', 'email'],
      // A full access token, which the API can check with Facebook.
      loginTracking: LoginTracking.enabled,
    );
    switch (result.status) {
      case LoginStatus.success:
        final token = result.accessToken?.tokenString;
        if (token == null || token.isEmpty) {
          throw const AppException('Facebook did not return a sign-in token.');
        }
        return (
          provider: 'facebook',
          token: token,
          tokenType: 'access_token',
          nonce: null,
          name: null,
        );
      case LoginStatus.cancelled:
        return null;
      case LoginStatus.failed:
      case LoginStatus.operationInProgress:
        throw AppException(result.message ?? 'Facebook sign-in failed.');
    }
  }
}
