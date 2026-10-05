import 'dart:io' show Platform;

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central place for environment-driven configuration.
class AppConfig {
  AppConfig._();

  static const String _fallbackBaseUrl = 'http://localhost:8081/api/v1';

  /// Base URL for the API, resolved for the current platform.
  static String get apiBaseUrl {
    final configured = dotenv.env['API_BASE_URL'];
    final raw = (configured == null || configured.trim().isEmpty)
        ? _fallbackBaseUrl
        : configured.trim();
    return _resolveHost(raw);
  }

  /// Google OAuth web client ID. Google issues the app an ID token for this
  /// client, which the API checks. Empty hides the Google button.
  static String get googleWebClientId => _env('GOOGLE_WEB_CLIENT_ID');

  /// iOS OAuth client ID; only needed on iOS.
  static String get googleIosClientId => _env('GOOGLE_IOS_CLIENT_ID');

  /// Facebook App ID. Empty hides the Facebook button.
  static String get facebookAppId => _env('FACEBOOK_APP_ID');

  /// A value from `.env`, or empty before it has loaded (as in widget tests).
  static String _env(String key) =>
      dotenv.isInitialized ? (dotenv.env[key] ?? '').trim() : '';

  /// On the Android emulator, `localhost` is the emulated device itself. The
  /// host machine is reachable at the 10.0.2.2 alias. Without this rewrite a
  /// backend on the developer's Mac is simply unreachable from Android.
  ///
  /// A physical device needs the machine's LAN IP in `.env`; that is not a
  /// loopback host, so it passes through untouched.
  static String _resolveHost(String url) {
    if (!Platform.isAndroid) return url;

    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    if (uri.host != 'localhost' && uri.host != '127.0.0.1') return url;

    return uri.replace(host: '10.0.2.2').toString();
  }
}
