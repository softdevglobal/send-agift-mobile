import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// "Earn 3 game entries" on a promoted gift. Nothing shows for zero.
class EntriesBadge extends StatelessWidget {
  const EntriesBadge({super.key, required this.entries, this.large = false});

  final int entries;
  final bool large;

  @override
  Widget build(BuildContext context) {
    if (entries <= 0) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical: large ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            size: large ? 16 : 13,
            color: AppColors.accentForeground,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Earn $entries game ${entries == 1 ? 'entry' : 'entries'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: large ? 13 : 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accentForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The label every promoted gift carries, wherever it is listed.
class SponsoredLabel extends StatelessWidget {
  const SponsoredLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.foreground.withValues(alpha: 0.3)),
      ),
      child: const Text(
        'SPONSORED',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
