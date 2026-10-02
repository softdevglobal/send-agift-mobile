import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../network/api_client.dart';
import '../network/providers.dart';
import '../router/app_router.dart';

/// The Android channel competition announcements arrive on. The backend sends
/// to this id, so the two must match.
const _competitionsChannel = AndroidNotificationChannel(
  'competitions',
  'Competitions',
  description: 'New competitions you can play and win.',
  importance: Importance.high,
);

/// Whether Firebase started. It does not until the Firebase config files
/// (google-services.json, GoogleService-Info.plist) are added; until then
/// the app runs normally with push turned off.
bool _firebaseReady = false;

/// Starts Firebase before the app runs. Never throws: without the config
/// files, push stays off and nothing else changes.
Future<void> initPushNotifications() async {
  try {
    await Firebase.initializeApp();
    _firebaseReady = true;
  } catch (error) {
    debugPrint('Push notifications are off: $error');
  }
}

/// Push notifications: registers this device with the backend for the
/// signed-in customer, shows notifications while the app is open, and opens
/// the right screen when one is tapped — including one tapped while the app
/// was closed. When the app is in the background or closed, Android and iOS
/// show the notification themselves.
class PushNotifications {
  PushNotifications(this._ref);

  final Ref _ref;

  // Read only when a request is made, so starting up (and widget tests,
  // which load no config) never builds the API client.
  ApiClient get _api => _ref.read(apiClientProvider);
  final _local = FlutterLocalNotificationsPlugin();
  GoRouter? _router;
  String? _token;
  StreamSubscription<String>? _refresh;
  bool _started = false;

  bool get _enabled => _firebaseReady && (Platform.isAndroid || Platform.isIOS);

  /// Hooks up display and tap handling. Call once, with the app's router.
  Future<void> start(GoRouter router) async {
    _router = router;
    if (!_enabled || _started) return;
    _started = true;

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is asked on sign-in, not at launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _openCompetition(response.payload),
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_competitionsChannel);

    final messaging = FirebaseMessaging.instance;
    // iOS shows notifications that arrive while the app is open itself.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android does not show them while the app is open, so this does.
    FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n == null || !Platform.isAndroid) return;
      _local.show(
        id: message.hashCode,
        title: n.title,
        body: n.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _competitionsChannel.id,
            _competitionsChannel.name,
            channelDescription: _competitionsChannel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: message.data['competition_id'],
      );
    });

    // Tapped while the app was in the background.
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _openCompetition(message.data['competition_id']),
    );

    // Tapped while the app was closed: it launched because of this.
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openCompetition(initial.data['competition_id']),
      );
    }
  }

  /// Asks for permission if needed and registers this device for the
  /// signed-in customer. Safe to call on every sign-in.
  Future<void> registerDevice() async {
    if (!_enabled) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token == null) return;
      await _send(token);

      await _refresh?.cancel();
      _refresh = messaging.onTokenRefresh.listen(_send);
    } catch (error) {
      debugPrint('Could not register for push notifications: $error');
    }
  }

  /// Stops notifications to this device. Called before the session is
  /// cleared, while the request can still be signed.
  Future<void> unregisterDevice() async {
    await _refresh?.cancel();
    _refresh = null;
    final token = _token;
    _token = null;
    if (!_enabled || token == null) return;
    try {
      await _api.dio.delete<void>(
        '/customers/me/push-devices',
        data: {'token': token},
      );
    } catch (error) {
      debugPrint('Could not unregister from push notifications: $error');
    }
  }

  Future<void> _send(String token) async {
    _token = token;
    await _api.dio.post<void>(
      '/customers/me/push-devices',
      data: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
    );
  }

  void _openCompetition(String? id) {
    if (id == null || id.isEmpty) return;
    _router?.push(AppRoutes.competitionPath(id));
  }
}

final pushNotificationsProvider = Provider<PushNotifications>((ref) {
  return PushNotifications(ref);
});
