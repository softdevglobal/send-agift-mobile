import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// The top of every bottom sheet: a grab bar, the title, and a close button,
/// so a sheet can always be dismissed with a visible tap. Not only by
/// swiping down or tapping outside, which many people never try.
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    this.title,
    this.subtitle,
    this.titleStyle,
    this.onClose,
    this.showHandle = true,
  });

  final String? title;
  final String? subtitle;

  /// Defaults to the display face used by sheet titles across the app.
  final TextStyle? titleStyle;

  /// Defaults to popping the sheet with no result.
  final VoidCallback? onClose;

  /// Off when the sheet already draws the platform drag handle.
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final close = SheetCloseButton(onPressed: onClose);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHandle)
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.mist,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        SizedBox(height: showHandle ? 12 : 0),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: title == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title!,
                            style: titleStyle ?? AppTypography.display(22),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            close,
          ],
        ),
      ],
    );
  }
}

/// The round close button at the top right of a sheet, for sheets that
/// build their own header row.
class SheetCloseButton extends StatelessWidget {
  const SheetCloseButton({super.key, this.onPressed});

  /// Defaults to popping the sheet with no result.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('sheet-close'),
      tooltip: 'Close',
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.muted,
        foregroundColor: AppColors.foreground,
        minimumSize: const Size(36, 36),
        fixedSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      ),
      icon: const Icon(Icons.close_rounded, size: 20),
    );
  }
}
