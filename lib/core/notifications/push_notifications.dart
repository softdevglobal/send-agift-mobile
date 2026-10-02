import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/providers.dart';
import '../router/app_router.dart';
import '../../features/notifications/data/notifications_repository.dart';

/// The Android channel competition announcements arrive on. The backend sends
/// to this id, so the two must match.
const _competitionsChannel = AndroidNotificationChannel(
  'competitions',
  'Competitions',
  description: 'New competitions you can play and win.',
  importance: Importance.high,
);

const _notificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'competitions',
    'Competitions',
    channelDescription: 'New competitions you can play and win.',
    importance: Importance.high,
    priority: Priority.high,
  ),
  iOS: DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  ),
);

/// Inbox notifications already shown on this phone, so none shows twice.
const _shownKey = 'shown_notification_ids';

/// How often the inbox is checked while the app is open and Firebase push is
/// not available.
const _pollEvery = Duration(seconds: 45);

/// Whether Firebase started. It does not until the Firebase config files
/// (google-services.json, GoogleService-Info.plist) are added.
bool _firebaseReady = false;

/// Starts Firebase before the app runs. Never throws: without the config
/// files, the app still shows notifications itself (see [PushNotifications]).
Future<void> initPushNotifications() async {
  try {
    await Firebase.initializeApp();
    _firebaseReady = true;
  } catch (error) {
    debugPrint('Firebase push is off: $error');
  }
}

/// Phone notifications for new competitions.
///
/// With Firebase set up, the backend pushes them: they arrive even when the
/// app is closed, and signing in re-sends anything missed while signed out.
///
/// Without Firebase, the app shows them itself from the inbox: right after
/// signing in, whenever it comes back to the foreground, and every 45
/// seconds while it is open. Either way, tapping one opens the competition,
/// and each notification is shown once.
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
  Timer? _poll;
  bool _started = false;
  bool _signedIn = false;
  bool _catchingUp = false;

  bool get _mobile => Platform.isAndroid || Platform.isIOS;

  /// Firebase is delivering this phone's notifications.
  bool get _pushActive => _firebaseReady && _token != null;

  /// Hooks up display and tap handling. Call once, with the app's router.
  Future<void> start(GoRouter router) async {
    _router = router;
    if (!_mobile || _started) return;
    _started = true;

    try {
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

      // The app was launched by tapping one of its own notifications.
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final id = launch!.notificationResponse?.payload;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _openCompetition(id),
        );
      }
    } catch (error) {
      debugPrint('Local notifications are off: $error');
    }

    if (!_firebaseReady) return;
    final messaging = FirebaseMessaging.instance;
    // iOS shows notifications that arrive while the app is open itself.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android does not show them while the app is open, so this does.
    FirebaseMessaging.onMessage.listen((message) async {
      _ref.invalidate(notificationInboxProvider);
      final id = message.data['notification_id'];
      if (id != null) await _markShown([id]);
      final n = message.notification;
      if (n == null || !Platform.isAndroid) return;
      await _show(
        id: message.hashCode,
        title: n.title ?? '',
        body: n.body ?? '',
        competitionId: message.data['competition_id'],
      );
    });

    // Tapped while the app was in the background.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _ref.invalidate(notificationInboxProvider);
      _openCompetition(message.data['competition_id']);
    });

    // Tapped while the app was closed: it launched because of this.
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openCompetition(initial.data['competition_id']),
      );
    }
  }

  /// The customer signed in (or a saved session was restored): ask for
  /// permission, register for push, and show anything that arrived while
  /// they were away.
  Future<void> registerDevice() async {
    if (!_mobile) return;
    _signedIn = true;
    await _requestPermission();

    if (_firebaseReady) {
      try {
        final messaging = FirebaseMessaging.instance;
        final token = await messaging.getToken();
        if (token != null) {
          // The backend re-sends anything missed while signed out.
          await _send(token);
          await _refresh?.cancel();
          _refresh = messaging.onTokenRefresh.listen(_send);
        }
      } catch (error) {
        debugPrint('Could not register for push notifications: $error');
      }
    }

    if (!_pushActive) {
      await catchUp();
      _poll?.cancel();
      _poll = Timer.periodic(_pollEvery, (_) => catchUp());
    }
  }

  /// Shows, as phone notifications, inbox entries this phone has not shown
  /// yet. Used when Firebase push is not delivering them.
  Future<void> catchUp() async {
    if (!_mobile || !_signedIn || _pushActive || _catchingUp) return;
    _catchingUp = true;
    try {
      final inbox = await _ref.read(notificationsRepositoryProvider).inbox();
      final prefs = await SharedPreferences.getInstance();
      final shown = (prefs.getStringList(_shownKey) ?? const []).toSet();
      final fresh = inbox.items
          .where((n) => n.isUnread && !shown.contains(n.id))
          .toList(growable: false);
      if (fresh.isEmpty) return;

      // Oldest first, so the newest ends up on top.
      for (final n in fresh.take(5).toList().reversed) {
        await _show(
          id: n.id.hashCode,
          title: n.title,
          body: n.body,
          competitionId: n.competitionId,
        );
      }
      await _markShown(fresh.map((n) => n.id));
      _ref.invalidate(notificationInboxProvider);
    } catch (error) {
      debugPrint('Could not check for notifications: $error');
    } finally {
      _catchingUp = false;
    }
  }

  /// Stops notifications to this device. Called before the session is
  /// cleared, while the request can still be signed.
  Future<void> unregisterDevice() async {
    _signedIn = false;
    _poll?.cancel();
    _poll = null;
    await _refresh?.cancel();
    _refresh = null;
    final token = _token;
    _token = null;
    if (!_firebaseReady || token == null) return;
    try {
      await _api.dio.delete<void>(
        '/customers/me/push-devices',
        data: {'token': token},
      );
    } catch (error) {
      debugPrint('Could not unregister from push notifications: $error');
    }
  }

  Future<void> _requestPermission() async {
    try {
      if (_firebaseReady) {
        await FirebaseMessaging.instance.requestPermission();
        return;
      }
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _local
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (error) {
      debugPrint('Could not ask for notification permission: $error');
    }
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    String? competitionId,
  }) async {
    await _local.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _notificationDetails,
      payload: competitionId,
    );
  }

  Future<void> _markShown(Iterable<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getStringList(_shownKey) ?? <String>[];
    shown.addAll(ids.where((id) => !shown.contains(id)));
    // Only the latest few hundred matter.
    final keep = shown.length > 300 ? shown.sublist(shown.length - 300) : shown;
    await prefs.setStringList(_shownKey, keep);
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
