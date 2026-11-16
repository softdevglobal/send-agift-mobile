import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central place for environment-driven configuration.
class AppConfig {
  AppConfig._();

  static const String _fallbackBaseUrl = 'http://localhost:8081/api/v1';

  /// The live API. A store build always talks to it unless `.env` names
  /// another HTTPS server.
  static const String productionBaseUrl = 'https://api.sendagift.win/api/v1';

  /// Base URL for the API, resolved for the current platform.
  static String get apiBaseUrl => _resolveHost(
    chooseApiBaseUrl(dotenv.env['API_BASE_URL'], release: kReleaseMode),
  );

  /// The API address from `.env`. In a release build anything but an HTTPS
  /// address (a laptop's LAN IP, localhost, a blank line) is a development
  /// setting left behind, and shipping it would leave every customer
  /// unable to reach the server, so the live API is used instead.
  @visibleForTesting
  static String chooseApiBaseUrl(String? configured, {required bool release}) {
    final value = configured?.trim() ?? '';
    if (release) {
      final uri = Uri.tryParse(value);
      final https = uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
      return https ? value : productionBaseUrl;
    }
    return value.isEmpty ? _fallbackBaseUrl : value;
  }

  /// The website, where the policy pages live. `WEB_BASE_URL` when set;
  /// otherwise the API's own host without its `api.` prefix
  /// (api.sendagift.win → sendagift.win), else the live site.
  static String get webBaseUrl {
    final configured = _env('WEB_BASE_URL');
    if (configured.isNotEmpty) return configured.replaceAll(RegExp(r'/+$'), '');
    final api = Uri.tryParse(apiBaseUrl);
    if (api != null && api.host.startsWith('api.')) {
      return '${api.scheme}://${api.host.substring(4)}';
    }
    return 'https://sendagift.win';
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
