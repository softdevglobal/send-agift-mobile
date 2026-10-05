import 'dart:io' show Platform;

import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';

/// A token from the provider's own sign-in, ready for the API to verify.
typedef ProviderToken = ({String provider, String token, String tokenType});

/// Opens Google's or Facebook's sign-in and hands back their token. Returns
/// null when the person closes the provider's sheet.
class SocialSignInClient {
  static bool _googleReady = false;

  static bool get googleEnabled => AppConfig.googleWebClientId.isNotEmpty;
  static bool get facebookEnabled => AppConfig.facebookAppId.isNotEmpty;

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
      return (provider: 'google', token: idToken, tokenType: 'id_token');
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
        return (provider: 'facebook', token: token, tokenType: 'access_token');
      case LoginStatus.cancelled:
        return null;
      case LoginStatus.failed:
      case LoginStatus.operationInProgress:
        throw AppException(result.message ?? 'Facebook sign-in failed.');
    }
  }
}
