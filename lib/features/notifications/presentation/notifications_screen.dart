import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/data/auth_controller.dart';
import '../data/notifications_repository.dart';

/// The notification inbox: new competitions the customer can play in. Every
/// announcement lands here, whether or not a push reached the phone.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// What was unread when the screen opened. Opening marks everything read,
  /// but these stay highlighted until the customer leaves.
  Set<String>? _unreadOnOpen;

  @override
  void initState() {
    super.initState();
    // Always show the latest, not what the badge last loaded.
    Future.microtask(() => ref.invalidate(notificationInboxProvider));
  }

  void _onLoaded(NotificationInbox inbox) {
    if (_unreadOnOpen != null) return;
    _unreadOnOpen = {
      for (final n in inbox.items)
        if (n.isUnread) n.id,
    };
    if (inbox.unread > 0) {
      ref
          .read(notificationsRepositoryProvider)
          .markAllRead()
          .then((_) => ref.invalidate(notificationInboxProvider))
          .catchError((_) {});
    }
  }

  Future<void> _refresh() async {
    final _ = await ref.refresh(notificationInboxProvider.future);
  }

  void _open(AppNotification n) {
    final id = n.competitionId;
    if (id != null && id.isNotEmpty) {
      context.push(AppRoutes.competitionPath(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authProvider.select((a) => a.isSignedIn));
    final inbox = ref.watch(notificationInboxProvider);
    ref.listen(
      notificationInboxProvider,
      (_, next) => next.whenData(_onLoaded),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Notifications', style: AppTypography.display(22)),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: !signedIn
          ? Center(
              child: EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Sign in for notifications',
                description:
                    'We let you know when a new competition opens in your '
                    'country, and when someone beats your score.',
                action: FilledButton(
                  onPressed: () => context.push(AppRoutes.login),
                  child: const Text('Sign in'),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: inbox.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load notifications',
                      description: 'Pull down to try again.',
                    ),
                  ],
                ),
                data: (data) => data.items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          EmptyState(
                            icon: Icons.notifications_none_rounded,
                            title: 'No notifications yet',
                            description:
                                'New competitions in your country, and '
                                'when someone beats your score, show up here.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.gutter,
                          8,
                          AppTheme.gutter,
                          32,
                        ),
                        itemCount: data.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final n = data.items[i];
                          return _NotificationTile(
                            notification: n,
                            highlighted:
                                _unreadOnOpen?.contains(n.id) ?? n.isUnread,
                            onTap: () => _open(n),
                          );
                        },
                      ),
              ),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.highlighted,
    required this.onTap,
  });

  final AppNotification notification;
  final bool highlighted;
  final VoidCallback onTap;

  /// "Just now", "5m", "3h", "2d", then the date.
  static String _when(DateTime at) {
    final ago = DateTime.now().difference(at);
    if (ago.inMinutes < 1) return 'Just now';
    if (ago.inHours < 1) return '${ago.inMinutes}m';
    if (ago.inDays < 1) return '${ago.inHours}h';
    if (ago.inDays < 7) return '${ago.inDays}d';
    return DateFormat('d MMM').format(at);
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    // Someone beat this player's score: a nudge to play again.
    final overtaken = n.kind == 'competition_overtaken';
    return Material(
      color: highlighted
          ? AppColors.teal.withValues(alpha: 0.08)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted
                  ? AppColors.teal.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: overtaken ? AppColors.purple : const Color(0xFFF97316),
                ),
                child: Icon(
                  overtaken
                      ? Icons.trending_up_rounded
                      : Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _when(n.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (highlighted) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.teal,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(n.body, style: Theme.of(context).textTheme.bodyMedium),
                    if (n.competitionId != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        overtaken ? 'Play again →' : 'View competition →',
                        style: TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
