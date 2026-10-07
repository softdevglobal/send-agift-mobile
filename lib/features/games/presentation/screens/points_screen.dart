import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/box_tabs.dart';
import '../../data/games_providers.dart';
import '../../domain/competition.dart';
import '../competition_format.dart';

/// The customer's SendAgift Points: the balance plays are paid from, where
/// it came from, and every change to it. Nothing here is hidden. A purchase
/// reward, a gift, a play and a refund each show with the balance after it.
class PointsScreen extends ConsumerStatefulWidget {
  const PointsScreen({super.key});

  @override
  ConsumerState<PointsScreen> createState() => _PointsScreenState();
}

/// Which history lines to show.
enum _Filter { all, earned, spent }

class _PointsScreenState extends ConsumerState<PointsScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(pointsWalletProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My points')),
      body: wallet.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Could not load your points',
          description: '$error',
          action: FilledButton(
            onPressed: () => ref.invalidate(pointsWalletProvider),
            child: const Text('Try again'),
          ),
        ),
        data: (w) => RefreshIndicator(
          onRefresh: () => ref.refresh(pointsWalletProvider.future),
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
              _Totals(totals: w.totals),
              const SizedBox(height: 12),
              _HowToEarn(
                rule: ref.watch(pointsEarningRuleProvider).valueOrNull,
              ),
              const SizedBox(height: 8),
              Text(
                'Each competition play costs the points shown on its Play '
                'button, and a play that is voided or a round that is '
                'cancelled gives them back.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
                      (_Filter.spent, 'Spent'),
                    ],
                    selected: _filter,
                    onSelected: (f) => setState(() => _filter = f),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._history(w.entries),
            ],
          ),
        ),
      ),
    );
  }
}

extension on _PointsScreenState {
  List<Widget> _history(List<PointsEntry> all) {
    final shown = switch (_filter) {
      _Filter.all => all,
      _Filter.earned => all.where((e) => e.isCredit).toList(),
      _Filter.spent => all.where((e) => !e.isCredit).toList(),
    };
    if (shown.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('No points activity yet.')),
        ),
      ];
    }
    return [for (final e in shown) _EntryRow(entry: e)];
  }
}

/// Where the points came from and went, as four small tiles.
class _Totals extends StatelessWidget {
  const _Totals({required this.totals});

  final PointsTotals totals;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (
        'From purchases',
        totals.fromPurchases,
        Icons.shopping_bag_rounded,
        AppColors.purple,
      ),
      (
        'Gifts received',
        totals.fromGifts,
        Icons.card_giftcard_rounded,
        const Color(0xFFDB2777),
      ),
      (
        'Prizes won',
        totals.fromPrizes,
        Icons.emoji_events_rounded,
        AppColors.star,
      ),
      (
        'Spent on games',
        totals.spentOnGames,
        Icons.sports_esports_rounded,
        AppColors.accentForeground,
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

/// How points are earned in the customer's country, from its earning rule.
class _HowToEarn extends StatelessWidget {
  const _HowToEarn({required this.rule});

  final PointsEarningRule? rule;

  @override
  Widget build(BuildContext context) {
    final r = rule;
    const always =
        'Gifts marked "Earn points" add their points as soon as you '
        'order, and points friends send with a gift land here too.';
    final String text;
    if (r != null && r.earnsOnOrders) {
      text =
          '$always You also earn ${r.pointsPerUnit} '
          '${r.pointsPerUnit == 1 ? 'point' : 'points'} for every '
          '${r.currency} 1 you spend. Points from an order that is refunded '
          'are taken back.';
    } else {
      text = always;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.stars_rounded, color: AppColors.purple),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.wallet});

  final PointsWallet wallet;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: Colors.white.withValues(alpha: 0.85));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6D28D9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Balance', style: muted),
          Text(
            '${wallet.balance} points',
            style: AppTypography.display(34, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            '${wallet.lifetimeEarned} received · ${wallet.lifetimeSpent} spent',
            style: muted,
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final PointsEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final positive = e.amountDelta > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color:
                  (positive
                          ? AppColors.accentForeground
                          : AppColors.destructive)
                      .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _icon(e),
              size: 18,
              color: positive
                  ? AppColors.accentForeground
                  : AppColors.destructive,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  [
                    formatDateTime(e.createdAt),
                    if (e.reason != null &&
                        e.entryType != 'play_debit' &&
                        e.reason != e.label)
                      e.reason!,
                  ].join(' · '),
                  maxLines: 2,
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
                '${positive ? '+' : ''}${e.amountDelta}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: positive
                      ? AppColors.accentForeground
                      : AppColors.destructive,
                ),
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

IconData _icon(PointsEntry e) => switch (e.category) {
  'PRODUCT_PURCHASE' => Icons.shopping_bag_rounded,
  'GIFT_REWARD' =>
    e.entryType == 'prize_points'
        ? Icons.emoji_events_rounded
        : Icons.card_giftcard_rounded,
  'GIFT_SENT' => Icons.send_rounded,
  'GAME_ENTRY' => Icons.sports_esports_rounded,
  'REFUND' => Icons.undo_rounded,
  _ => e.isCredit ? Icons.add_rounded : Icons.remove_rounded,
};
