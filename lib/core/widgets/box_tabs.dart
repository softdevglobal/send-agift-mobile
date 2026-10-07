import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The website's box tab bar: a tinted track holding the options, with the
/// active one as a solid ink block and the rest as faded ink labels.
class BoxTabs<T> extends StatelessWidget {
  const BoxTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.expand = false,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Shares the full width out evenly instead of sizing to the labels.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      for (final (value, label) in options)
        _BoxTab(
          label: label,
          active: value == selected,
          onTap: () => onSelected(value),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.boxTrack,
        borderRadius: BorderRadius.circular(AppTheme.radiusBoxSm + 3),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [for (final tab in tabs) expand ? Expanded(child: tab) : tab],
      ),
    );
  }
}

class _BoxTab extends StatelessWidget {
  const _BoxTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.foreground : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusBoxSm),
          ),
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.boxLabel.copyWith(
              color: active
                  ? Colors.white
                  : AppColors.foreground.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
