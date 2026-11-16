import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The game entries a promoted gift earns. Nothing shows for zero.
///
/// [compact] is the small chip on a gift card ("+3 entries"); otherwise it
/// says it in full ("Earn 3 game entries").
class EntriesBadge extends StatelessWidget {
  const EntriesBadge({
    super.key,
    required this.entries,
    this.large = false,
    this.compact = false,
  });

  final int entries;
  final bool large;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (entries <= 0) return const SizedBox.shrink();
    final label = compact
        ? '+$entries ${entries == 1 ? 'entry' : 'entries'}'
        : 'Earn $entries game ${entries == 1 ? 'entry' : 'entries'}';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : (compact ? 7 : 8),
        vertical: large ? 6 : (compact ? 3 : 4),
      ),
      decoration: BoxDecoration(
        color: compact ? AppColors.foreground : AppColors.accent,
        borderRadius: BorderRadius.circular(compact ? 99 : 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.confirmation_number_rounded,
            size: large ? 16 : (compact ? 12 : 13),
            color: compact ? AppColors.goldLight : AppColors.accentForeground,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: large ? 13 : (compact ? 10.5 : 11),
                fontWeight: FontWeight.w800,
                color: compact ? Colors.white : AppColors.accentForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The gold label every promoted gift carries, wherever it is listed.
class SponsoredLabel extends StatelessWidget {
  const SponsoredLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 11, color: AppColors.goldInk),
          SizedBox(width: 3),
          Text(
            'SPONSORED',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
              color: AppColors.goldInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// On a sponsored gift's page: what buying it earns, as a slim gold strip.
class EntriesRewardCard extends StatelessWidget {
  const EntriesRewardCard({
    super.key,
    required this.entries,
    this.available = true,
  });

  final int entries;

  /// False when the customer's state does not let them earn entries: the
  /// strip then says so instead of promising them.
  final bool available;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final earns = entries > 0 && available;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          // The ticket: how many entries, at a glance.
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: earns
                ? Text(
                    '+$entries',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.goldInk,
                    ),
                  )
                : const Icon(
                    Icons.star_rounded,
                    size: 24,
                    color: AppColors.goldInk,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        earns
                            ? 'Earn $entries game ${entries == 1 ? 'entry' : 'entries'}'
                            : 'A promoted gift',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const SponsoredLabel(),
                  ],
                ),
                if (!available && entries > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Game entries are not available where you live yet.',
                    maxLines: 2,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
                if (earns) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Added once your payment is confirmed.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
