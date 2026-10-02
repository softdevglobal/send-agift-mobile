import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/push_notifications.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/data/auth_controller.dart';

class SendAGiftApp extends ConsumerStatefulWidget {
  const SendAGiftApp({super.key});

  @override
  ConsumerState<SendAGiftApp> createState() => _SendAGiftAppState();
}

class _SendAGiftAppState extends ConsumerState<SendAGiftApp> {
  @override
  void initState() {
    super.initState();
    ref.read(pushNotificationsProvider).start(ref.read(appRouterProvider));
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    // Once a customer is signed in — on login, sign-up, or when a saved
    // session is restored at launch — this device gets their push
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
