import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../auth/data/auth_controller.dart';
import '../../data/messages_providers.dart';
import '../../domain/chat.dart';
import '../widgets/conversation_label.dart';

/// The customer's conversations with shops.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authProvider.select((auth) => auth.isSignedIn));

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: SafeArea(
        child: FadeSlideIn(
          child: signedIn ? const _Inbox() : const _SignInPrompt(),
        ),
      ),
    );
  }
}

enum _Filter { all, questions, orders }

extension on _Filter {
  String get label => switch (this) {
    _Filter.all => 'All',
    _Filter.questions => 'Gift questions',
    _Filter.orders => 'Orders',
  };

  bool matches(ChatConversation conversation) => switch (this) {
    _Filter.all => true,
    _Filter.questions => conversation.type == 'product_inquiry',
    _Filter.orders => conversation.type == 'order',
  };
}

class _Inbox extends ConsumerStatefulWidget {
  const _Inbox();

  @override
  ConsumerState<_Inbox> createState() => _InboxState();
}

class _InboxState extends ConsumerState<_Inbox> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(inboxProvider);

    return inbox.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (error, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load messages",
        description: error.toString(),
        action: OutlinedButton(
          onPressed: () => ref.read(inboxProvider.notifier).refresh(),
          child: const Text('Try again'),
        ),
      ),
      data: (conversations) {
        if (conversations.isEmpty) return const _EmptyInbox();

        final needle = _search.text.trim().toLowerCase();
        final entries = [
          for (final conversation in conversations)
            (
              conversation: conversation,
              label: watchConversationLabel(
                ref,
                type: conversation.type,
                productId: conversation.productId,
                supportCase: conversation.supportCase,
              ),
            ),
        ];
        final visible = entries
            .where(
              (entry) =>
                  _filter.matches(entry.conversation) &&
                  (needle.isEmpty || entry.label.searchText.contains(needle)),
            )
            .toList();
        final fresh = visible
            .where((entry) => entry.conversation.unreadCount > 0)
            .toList();
        final earlier = visible
            .where((entry) => entry.conversation.unreadCount == 0)
            .toList();
        final counts = {
          for (final filter in _Filter.values)
            filter: conversations.where(filter.matches).length,
        };

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.read(inboxProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              4,
              AppTheme.gutter,
              28,
            ),
            children: [
              _SearchField(controller: _search),
              const SizedBox(height: 12),
              _FilterChips(
                selected: _filter,
                counts: counts,
                onChanged: (filter) => setState(() => _filter = filter),
              ),
              const SizedBox(height: 20),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    needle.isEmpty
                        ? 'Nothing here yet.'
                        : 'No chats match “${_search.text.trim()}”.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              if (fresh.isNotEmpty) ...[
                _SectionHeader(
                  title: 'New replies',
                  count: fresh.length,
                  highlight: true,
                ),
                for (final entry in fresh)
                  _ConversationCard(
                    conversation: entry.conversation,
                    label: entry.label,
                  ),
                const SizedBox(height: 14),
              ],
              if (earlier.isNotEmpty) ...[
                _SectionHeader(
                  title: fresh.isEmpty ? 'Your conversations' : 'Earlier',
                ),
                for (final entry in earlier)
                  _ConversationCard(
                    conversation: entry.conversation,
                    label: entry.label,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search shops or gifts',
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: AppColors.mutedForeground,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: controller.clear,
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Clear search',
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          borderSide: const BorderSide(color: AppColors.purple),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final _Filter selected;
  final Map<_Filter, int> counts;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _Filter.values) ...[
            _Chip(
              label: filter.label,
              count: counts[filter] ?? 0,
              selected: filter == selected,
              onTap: () => onChanged(filter),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.foreground;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.foreground : AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          border: Border.all(
            color: selected ? AppColors.foreground : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: foreground.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.count,
    this.highlight = false,
  });

  final String title;
  final int? count;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (highlight) ...[
            Container(
              height: 8,
              width: 8,
              decoration: const BoxDecoration(
                color: AppColors.teal,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(title.toUpperCase(), style: AppTypography.eyebrow),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.purple,
              ),
            ),
          ],
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}

/// One chat as a gift card: the gift's photo with the shop's badge on its
/// corner, the shop and gift names, and pills for the kind of chat and any
/// unread replies.
class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.conversation, required this.label});

  final ChatConversation conversation;
  final ConversationLabel label;

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadCount;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(
            color: unread > 0
                ? AppColors.purple.withValues(alpha: 0.35)
                : AppColors.border,
          ),
          boxShadow: unread > 0
              ? [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : AppTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(AppRoutes.chatPath(conversation.id)),
            child: Stack(
              children: [
                if (unread > 0)
                  Positioned(
                    left: 0,
                    top: 14,
                    bottom: 14,
                    child: Container(
                      width: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.purple,
                        borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(
                    children: [
                      _Thumbnail(label: label),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: unread > 0
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatInboxTime(conversation.activityAt),
                                  style: textTheme.labelSmall?.copyWith(
                                    color: unread > 0
                                        ? AppColors.purple
                                        : AppColors.mutedForeground,
                                    fontWeight: unread > 0
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label.isSupport
                                  ? label.subtitle
                                  : (label.giftName ?? label.subtitle),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _TypePill(type: conversation.type),
                                if (!conversation.isOpen)
                                  const _Pill(
                                    label: 'Closed',
                                    background: AppColors.muted,
                                    foreground: AppColors.mutedForeground,
                                  ),
                                if (unread > 0)
                                  _Pill(
                                    label: unread == 1
                                        ? 'New reply'
                                        : '${unread > 99 ? '99+' : unread} new replies',
                                    background: AppColors.purple,
                                    foreground: Colors.white,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.mutedForeground,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The gift's photo, with the shop's avatar tucked on its corner.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.label});

  final ConversationLabel label;

  @override
  Widget build(BuildContext context) {
    if (label.isSupport) {
      return Container(
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: const Icon(
          Icons.support_agent_rounded,
          color: AppColors.primaryForeground,
        ),
      );
    }

    final giftImage = label.giftImageUrl ?? label.imageUrl;
    return SizedBox(
      height: 66,
      width: 66,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: SizedBox(
              height: 60,
              width: 60,
              child: giftImage == null
                  ? Container(
                      color: AppColors.cream,
                      child: const Icon(
                        Icons.card_giftcard_rounded,
                        color: AppColors.purple,
                      ),
                    )
                  : AppNetworkImage(url: giftImage),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: ChatAvatar(
                label: ConversationLabel(
                  title: label.title,
                  subtitle: '',
                  imageUrl: label.shopImageUrl,
                ),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      'order' => const _Pill(
        label: 'Order',
        icon: Icons.inventory_2_outlined,
        background: AppColors.accent,
        foreground: AppColors.accentForeground,
      ),
      'support' => const _Pill(
        label: 'Support',
        icon: Icons.support_agent_rounded,
        background: AppColors.muted,
        foreground: AppColors.mutedForeground,
      ),
      _ => const _Pill(
        label: 'Gift question',
        icon: Icons.card_giftcard_rounded,
        background: AppColors.cream,
        foreground: AppColors.purple,
      ),
    };
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'No messages yet',
      description:
          "Tap Ask on a gift's page, or Message the shop on one of your "
          'orders. Replies show up here.',
      action: ElevatedButton(
        onPressed: () => context.go(AppRoutes.explore),
        child: const Text('Browse gifts'),
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'Sign in to message shops',
      description:
          'Conversations with shops are tied to your account, so replies '
          'follow you across devices.',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () => context.push(AppRoutes.login),
            child: const Text('Sign in'),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () => context.push(AppRoutes.register),
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }
}
