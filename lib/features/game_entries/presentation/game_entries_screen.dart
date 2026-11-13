import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/box_tabs.dart';
import '../../../core/widgets/empty_state.dart';
import '../../games/data/games_providers.dart';
import '../../games/domain/game_entries.dart';
import '../../games/presentation/competition_format.dart';
import 'state_picker.dart';

/// The customer's game entries: what they hold, where each came from, and
/// whether games are open where they live. Entries are earned by buying
/// promoted products. They cannot be bought or sent to anyone.
class GameEntriesScreen extends ConsumerStatefulWidget {
  const GameEntriesScreen({super.key});

  @override
  ConsumerState<GameEntriesScreen> createState() => _GameEntriesScreenState();
}

enum _Filter { all, earned, used }

class _GameEntriesScreenState extends ConsumerState<GameEntriesScreen> {
  _Filter _filter = _Filter.all;
  bool _claiming = false;

  Future<void> _claimFree() async {
    setState(() => _claiming = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await ref
          .read(gamesRepositoryProvider)
          .claimFreeEntries();
      messenger.showSnackBar(SnackBar(content: Text(message)));
      ref.invalidate(gameEntriesProvider);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(gameEntriesProvider);
    final state = ref.watch(myStateProvider).valueOrNull;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Game entries')),
      body: wallet.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.confirmation_number_outlined,
          title: 'Could not load your game entries',
          description: '$error',
          action: FilledButton(
            onPressed: () => ref.invalidate(gameEntriesProvider),
            child: const Text('Try again'),
          ),
        ),
        data: (w) {
          final blocked = (w.play != null && !w.play!.allowed)
              ? w.play
              : (w.earn != null && !w.earn!.allowed)
              ? w.earn
              : null;
          final free = (w.earn?.allowed ?? false)
              ? w.earn!.freeEntriesPerDay
              : 0;
          final shown = switch (_filter) {
            _Filter.all => w.history,
            _Filter.earned => w.history.where((e) => e.isCredit).toList(),
            _Filter.used => w.history.where((e) => !e.isCredit).toList(),
          };
          return RefreshIndicator(
            onRefresh: () {
              ref.invalidate(myStateProvider);
              return ref.refresh(gameEntriesProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                16,
                AppTheme.gutter,
                32,
              ),
              children: [
                _Balance(wallet: w),
                const SizedBox(height: 12),
                if (blocked != null)
                  _Notice(
                    icon: Icons.place_outlined,
                    text:
                        blocked.message ??
                        'Games are not available where you live.',
                    action: blocked.needsState && state != null
                        ? TextButton(
                            onPressed: () => askForState(context, ref, state),
                            child: const Text('Add my state'),
                          )
                        : null,
                  )
                else
                  _Notice(
                    icon: Icons.sports_esports_outlined,
                    text:
                        'Use your entries on the games and competitions open where you live.'
                        '${(w.play?.minAge ?? 0) > 0 ? ' You must be ${w.play!.minAge} or older.' : ''}',
                    action: TextButton(
                      onPressed: () => context.push(AppRoutes.games),
                      child: const Text('Play'),
                    ),
                  ),
                const SizedBox(height: 12),
                _Totals(totals: w.totals),
                if (free > 0) ...[
                  const SizedBox(height: 12),
                  _Notice(
                    icon: Icons.card_giftcard_rounded,
                    text:
                        'No purchase needed: ${entriesLabel(free)} free once a day.',
                    action: TextButton(
                      onPressed: _claiming ? null : _claimFree,
                      child: const Text('Claim'),
                    ),
                  ),
                ],
                if (state != null &&
                    (state.state != null || state.stateRequired)) ...[
                  const SizedBox(height: 12),
                  _StateRow(state: state),
                ],
                if ((w.play?.officialRules ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Official rules where you live'),
                    children: [Text(w.play!.officialRules!)],
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text('HISTORY', style: AppTypography.eyebrow),
                    ),
                    BoxTabs<_Filter>(
                      options: const [
                        (_Filter.all, 'All'),
                        (_Filter.earned, 'Earned'),
                        (_Filter.used, 'Used'),
                      ],
                      selected: _filter,
                      onSelected: (f) => setState(() => _filter = f),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (shown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Nothing here yet. Buy a product marked "Earn game entries" and they '
                      'appear here once your payment is confirmed.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  for (final e in shown) _EntryRow(entry: e),
                const SizedBox(height: 16),
                Text(
                  'Game entries cannot be bought, sent to someone else or exchanged for money. '
                  'If an order is refunded or cancelled, the entries it earned are taken back.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.wallet});

  final GameEntriesWallet wallet;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: Colors.white.withValues(alpha: 0.85));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Available to play', style: muted),
          Text(
            '${wallet.balance} ${wallet.balance == 1 ? 'entry' : 'entries'}',
            style: AppTypography.display(34, color: Colors.white),
          ),
          if (wallet.totals.pending > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${wallet.totals.pending} more arrive when your payment is confirmed.',
              style: muted,
            ),
          ],
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.totals});

  final GameEntriesTotals totals;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Earned', totals.earned, Icons.shopping_bag_rounded, AppColors.purple),
      (
        'Used on games',
        totals.spent,
        Icons.sports_esports_rounded,
        AppColors.accentForeground,
      ),
      (
        'Waiting for payment',
        totals.pending,
        Icons.hourglass_bottom_rounded,
        AppColors.star,
      ),
      (
        'Taken back',
        totals.reversed,
        Icons.undo_rounded,
        AppColors.mutedForeground,
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: [
        for (final (label, value, icon, color) in tiles)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$value',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.purple),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
          ?action,
        ],
      ),
    );
  }
}

class _StateRow extends ConsumerWidget {
  const _StateRow({required this.state});

  final CustomerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = state.state;
    final until = state.canChangeAt;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s?.name ?? 'Your state or region',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  s == null
                      ? 'Needed before you can use games and game entries.'
                      : state.locked && until != null
                      ? 'Can be changed again on ${until.day}/${until.month}/${until.year}.'
                      : 'Changing it needs a verified phone number.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (!state.locked)
            TextButton(
              onPressed: () => askForState(context, ref, state),
              child: Text(s == null ? 'Add' : 'Change'),
            ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final GameEntryRow entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final color = e.isCredit
        ? AppColors.accentForeground
        : AppColors.destructive;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              switch (e.entryType) {
                'purchase_grant' => Icons.shopping_bag_rounded,
                'purchase_reversal' => Icons.undo_rounded,
                'play_debit' => Icons.sports_esports_rounded,
                'play_refund' => Icons.replay_rounded,
                'free_entry' => Icons.card_giftcard_rounded,
                _ => e.isCredit ? Icons.add_rounded : Icons.remove_rounded,
              },
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  [
                    formatDateTime(e.createdAt),
                    if (e.orderNumber != null) 'Order ${e.orderNumber}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${e.isCredit ? '+' : ''}${e.delta}',
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
              Text(
                '= ${e.balanceAfter}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
