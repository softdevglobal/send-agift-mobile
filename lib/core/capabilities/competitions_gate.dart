import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../widgets/empty_state.dart';
import 'competitions_capability.dart';

/// Opens a competition screen only while the server has competitions on.
///
/// Every competition route goes through here, so a deep link, a cold start,
/// a restored screen, an old push notification and a link opened after
/// sign-in all get the same answer.
class CompetitionsGate extends ConsumerWidget {
  const CompetitionsGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(competitionsEnabledProvider);
    return enabled.when(
      data: (on) => on ? child : const CompetitionsUnavailableScreen(),
      error: (_, _) => const CompetitionsUnavailableScreen(),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

/// What an old competition link shows while competitions are switched off.
class CompetitionsUnavailableScreen extends StatelessWidget {
  const CompetitionsUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: EmptyState(
          icon: Icons.card_giftcard_rounded,
          title: 'Competitions are not available at this time.',
          description: 'You can still browse and send gifts as usual.',
          action: FilledButton(
            key: const Key('competitions-unavailable-shop'),
            onPressed: () => context.go(AppRoutes.explore),
            child: const Text('Shop gifts'),
          ),
        ),
      ),
    );
  }
}

/// Sends the router on to [location] as soon as it is shown.
class ForwardTo extends StatefulWidget {
  const ForwardTo(this.location, {super.key});

  final String location;

  @override
  State<ForwardTo> createState() => _ForwardToState();
}

class _ForwardToState extends State<ForwardTo> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(widget.location);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
