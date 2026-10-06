import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'storefront_decor.dart';

/// Uppercase poster title over a solid marker bar, with an optional trailing
/// action. Matches the web's `SectionHeading` component.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.markerColor = const Color(0xFF8EDFDF),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Colour of the bar behind the title. Teal tint by default.
  final Color markerColor;

  /// The violet-tint alternative, for alternating sections.
  static const Color violetMarker = Color(0xFFC9B2F1);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        0,
        AppTheme.gutter,
        16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UnderlineMarker(
                  title.toUpperCase(),
                  style: AppTypography.poster(22),
                  color: markerColor,
                  maxLines: 2,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 12),
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(99),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!.toUpperCase(),
                      style: AppTypography.tag(size: 10.5),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 26,
                      width: 26,
                      decoration: const BoxDecoration(
                        color: AppColors.foreground,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
