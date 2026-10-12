import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// One choice in a [BoxToggle].
class BoxToggleOption {
  const BoxToggleOption(this.label, {this.icon, this.key});

  final String label;
  final IconData? icon;
  final Key? key;
}

/// A box-template switch: a tinted track with a solid ink block that slides
/// under the chosen option. Tap an option, or swipe the track, to switch.
class BoxToggle extends StatelessWidget {
  const BoxToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<BoxToggleOption> options;
  final int selected;
  final ValueChanged<int>? onChanged;

  static const _duration = Duration(milliseconds: 280);
  static const _curve = Curves.easeOutCubic;

  void _select(int index) {
    if (index == selected || onChanged == null) return;
    onChanged!(index.clamp(0, options.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final count = options.length;
    final x = count == 1 ? 0.0 : -1 + 2 * selected / (count - 1);

    return Semantics(
      container: true,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 200) _select(selected + 1);
          if (velocity < -200) _select(selected - 1);
        },
        child: Container(
          height: 48,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.boxTrack,
            borderRadius: BorderRadius.circular(AppTheme.radiusBoxSm + 2),
          ),
          child: Stack(
            children: [
              // The sliding ink block.
              AnimatedAlign(
                duration: _duration,
                curve: _curve,
                alignment: Alignment(x, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.foreground,
                      borderRadius: BorderRadius.circular(AppTheme.radiusBoxSm),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.foreground.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(child: _label(options[i], i == selected, i)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(BoxToggleOption option, bool active, int index) {
    final color = active
        ? Colors.white
        : AppColors.foreground.withValues(alpha: 0.6);
    return Semantics(
      selected: active,
      button: true,
      child: GestureDetector(
        key: option.key,
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(index),
        child: Center(
          child: TweenAnimationBuilder<Color?>(
            duration: _duration,
            curve: _curve,
            tween: ColorTween(end: color),
            builder: (context, value, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.icon != null) ...[
                  Icon(option.icon, size: 17, color: value),
                  const SizedBox(width: 7),
                ],
                Flexible(
                  child: Text(
                    option.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.boxLabel.copyWith(color: value),
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
