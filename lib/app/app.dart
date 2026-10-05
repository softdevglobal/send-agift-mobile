import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/push_notifications.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/data/auth_controller.dart';
import '../features/notifications/data/notifications_repository.dart';

class SendAGiftApp extends ConsumerStatefulWidget {
  const SendAGiftApp({super.key});

  @override
  ConsumerState<SendAGiftApp> createState() => _SendAGiftAppState();
}

class _SendAGiftAppState extends ConsumerState<SendAGiftApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    ref.read(pushNotificationsProvider).start(ref.read(appRouterProvider));
    // Back from the background: a notification may have come in meanwhile,
    // so the bell's count is re-read and anything new is shown.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.invalidate(notificationInboxProvider);
        ref.read(pushNotificationsProvider).catchUp();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    // Once a customer is signed in. On login, sign-up, or when a saved
    // session is restored at launch. This device gets their push
    // notifications.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isSignedIn && previous?.isSignedIn != true) {
        ref.read(pushNotificationsProvider).registerDevice();
      }
    });

    return MaterialApp.router(
      title: 'SendAGift',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
