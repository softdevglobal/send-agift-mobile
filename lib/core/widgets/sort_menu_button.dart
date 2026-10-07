import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Box-template sort control: an ink icon tile beside a small "Sort by"
/// eyebrow and the current choice, all in an ash-outlined box. Opens a menu
/// that ticks the active option.
class SortMenuButton<T> extends StatelessWidget {
  const SortMenuButton({
    super.key,
    required this.labels,
    required this.value,
    required this.onChanged,
  });

  final Map<T, String> labels;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: 'Sort',
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusBox),
        side: const BorderSide(color: AppColors.boxBorder, width: 1.5),
      ),
      itemBuilder: (_) => [
        for (final entry in labels.entries)
          PopupMenuItem<T>(
            value: entry.key,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontFamily: AppTypography.sansFamily,
                      fontSize: 14,
                      fontWeight: entry.key == value
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                if (entry.key == value)
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppColors.purple,
                  ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: AppTheme.box(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: AppColors.foreground,
                borderRadius: BorderRadius.circular(AppTheme.radiusBoxSm),
              ),
              child: const Icon(
                Icons.swap_vert_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SORT BY',
                    style: AppTheme.boxLabel.copyWith(
                      fontSize: 9,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  Text(
                    labels[value]!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.sansFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.foreground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: AppColors.foreground,
            ),
          ],
        ),
      ),
    );
  }
}
