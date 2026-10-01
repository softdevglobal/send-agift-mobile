import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../checkout/data/checkout_repository.dart';
import '../../../checkout/domain/checkout.dart';
import '../../../checkout/presentation/widgets/new_recipient_sheet.dart';
import '../widgets/account_visuals.dart';

/// Everyone the customer sends gifts to, A to Z. Tapping one opens their
/// details and addresses.
class RecipientsScreen extends ConsumerStatefulWidget {
  const RecipientsScreen({super.key});

  @override
  ConsumerState<RecipientsScreen> createState() => _RecipientsScreenState();
}

class _RecipientsScreenState extends ConsumerState<RecipientsScreen> {
  String _query = '';

  /// Search only earns its space once the list is long.
  static const _searchFrom = 6;

  Future<void> _add() async {
    final created = await showNewRecipientSheet(context);
    if (created != null && mounted) {
      context.push(AppRoutes.recipientPath(created.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipients = ref.watch(recipientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipients'),
        actions: [
          IconButton(
            key: const Key('recipients-add'),
            tooltip: 'Add recipient',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: _add,
          ),
        ],
      ),
      body: SafeArea(
        child: recipients.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Something went wrong',
            description: error is AppException
                ? error.message
                : 'Could not load your recipients.',
            action: OutlinedButton(
              onPressed: () => ref.invalidate(recipientsProvider),
              child: const Text('Retry'),
            ),
          ),
          data: (items) {
            final sorted = [...items]
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
            final q = _query.trim().toLowerCase();
            final shown = q.isEmpty
                ? sorted
                : sorted
                      .where(
                        (r) =>
                            r.name.toLowerCase().contains(q) ||
                            (r.relationship ?? '').toLowerCase().contains(q),
                      )
                      .toList();

            // Group under first letters, the way a phone's contacts read.
            final groups = <String, List<Recipient>>{};
            for (final recipient in shown) {
              final name = recipient.name.trim();
              final letter = name.isEmpty
                  ? '#'
                  : name.characters.first.toUpperCase();
              final key = RegExp(r'[A-Z]').hasMatch(letter) ? letter : '#';
              groups.putIfAbsent(key, () => []).add(recipient);
            }

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(recipientsProvider),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  8,
                  AppTheme.gutter,
                  40,
                ),
                children: [
                  FadeSlideIn(
                    child: _Hero(count: items.length, onAdd: _add),
                  ),
                  if (items.length >= 3) ...[
                    const SizedBox(height: 22),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      child: _AvatarStrip(recipients: sorted),
                    ),
                  ],
                  const SizedBox(height: 22),
                  if (items.isEmpty)
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
                      child: _EmptyHint(onAdd: _add),
                    ),
                  if (items.length >= _searchFrom) ...[
                    TextField(
                      key: const Key('recipients-search'),
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        hintText: 'Search by name or relationship',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (items.isNotEmpty && shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No one matches "$_query".',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  for (final entry in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(entry.key, style: AppTypography.eyebrow),
                    ),
                    for (final recipient in entry.value) ...[
                      _RecipientCard(recipient: recipient),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 8),
                  ],
                  if (items.isNotEmpty)
                    DashedAddCard(
                      label: 'Add someone new',
                      icon: Icons.person_add_alt_1_rounded,
                      onTap: _add,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.count, required this.onAdd});

  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return BrandHero(
      icon: Icons.favorite_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count == 0
                  ? 'Your gifting circle'
                  : count == 1
                  ? '1 person'
                  : '$count people',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your people',
            style: AppTypography.display(26, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Save who you send gifts to, with their address, and checkout '
            'is one tap.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 16),
          HeroButton(
            label: 'Add recipient',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

/// Everyone as a row of avatars, like a phone's favourites.
class _AvatarStrip extends StatelessWidget {
  const _AvatarStrip({required this.recipients});

  final List<Recipient> recipients;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recipients.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final recipient = recipients[index];
          final first = recipient.name.trim().split(RegExp(r'\s+')).first;
          return GestureDetector(
            onTap: () => context.push(AppRoutes.recipientPath(recipient.id)),
            child: SizedBox(
              width: 64,
              child: Column(
                children: [
                  RingAvatar(name: recipient.name, size: 54),
                  const SizedBox(height: 6),
                  Text(
                    first.isEmpty ? '?' : first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.foreground,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecipientCard extends StatelessWidget {
  const _RecipientCard({required this.recipient});

  final Recipient recipient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhone = (recipient.phone ?? '').trim().isNotEmpty;
    final hasEmail = (recipient.email ?? '').trim().isNotEmpty;
    final relationship = (recipient.relationship ?? '').trim();

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        onTap: () => context.push(AppRoutes.recipientPath(recipient.id)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(color: AppColors.border),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              RingAvatar(name: recipient.name, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipient.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (relationship.isNotEmpty) ...[
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: tintFor(recipient.name),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                relationship,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        _ContactDot(icon: Icons.phone_rounded, on: hasPhone),
                        const SizedBox(width: 4),
                        _ContactDot(icon: Icons.mail_rounded, on: hasEmail),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                height: 32,
                width: 32,
                decoration: const BoxDecoration(
                  color: AppColors.muted,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows at a glance whether a phone or email is saved.
class _ContactDot extends StatelessWidget {
  const _ContactDot({required this.icon, required this.on});

  final IconData icon;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      width: 22,
      decoration: BoxDecoration(
        color: on ? AppColors.accent : AppColors.muted,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 12,
        color: on ? AppColors.accentForeground : AppColors.mist,
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          height: 74,
          width: 170,
          child: Stack(
            alignment: Alignment.center,
            children: const [
              Positioned(left: 0, child: RingAvatar(name: 'Amma', size: 50)),
              Positioned(right: 0, child: RingAvatar(name: 'Ravi', size: 50)),
              RingAvatar(name: 'You', size: 62),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('No one here yet', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Add family and friends once, with their address, and send to '
          'them in a tap.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        DashedAddCard(
          label: 'Add your first recipient',
          icon: Icons.person_add_alt_1_rounded,
          onTap: onAdd,
        ),
      ],
    );
  }
}
