import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// What each score means, shown live while picking so the number is never the
/// only feedback.
const _ratingWords = <String>[
  'Drag or tap a star',
  'Not what I hoped',
  'It was okay',
  'Good, with niggles',
  'Really pleased',
  'Absolutely love it',
];

String ratingWord(int value) => _ratingWords[value.clamp(0, 5)];

/// Read-only stars with a *fractional* fill: 4.3 looks like 4.3 rather than
/// rounding to a flat 4, which is the whole point of showing a decimal.
///
/// Two identical rows are stacked. Outlines underneath, gold on top clipped
/// to the score's width. So any fraction is exact at any size without needing
/// half-star icons.
class StarMeter extends StatelessWidget {
  const StarMeter({
    super.key,
    required this.value,
    this.size = 14,
    this.showValue = false,
    this.count,
  });

  final double value;
  final double size;
  final bool showValue;

  /// Adds "(12 reviews)". Pass 0 for "No reviews yet".
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safe = value.clamp(0.0, 5.0);
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: size < 14 ? 11 : 12,
      color: AppColors.mutedForeground,
    );

    Widget row(Color color) {
      final stars = List.generate(
        5,
        (index) => Padding(
          padding: EdgeInsets.only(right: index == 4 ? 0 : size * 0.12),
          child: Icon(Icons.star_rounded, size: size, color: color),
        ),
      );
      return Row(mainAxisSize: MainAxisSize.min, children: stars);
    }

    return Semantics(
      label: '${safe.toStringAsFixed(1)} out of 5 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              row(AppColors.mist),
              ClipRect(
                clipper: _FractionClipper(safe / 5),
                child: row(AppColors.star),
              ),
            ],
          ),
          if (showValue && safe > 0) ...[
            SizedBox(width: size * 0.4),
            Text(
              safe.toStringAsFixed(1),
              style: textStyle?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ],
          if (count != null) ...[
            SizedBox(width: size * 0.3),
            Text(
              count == 0
                  ? 'No reviews yet'
                  : '($count ${count == 1 ? 'review' : 'reviews'})',
              style: textStyle,
            ),
          ],
        ],
      ),
    );
  }
}

/// Clips a row of stars to a horizontal fraction of its width.
class _FractionClipper extends CustomClipper<Rect> {
  const _FractionClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction.clamp(0.0, 1.0), size.height);

  @override
  bool shouldReclip(_FractionClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

/// The rating control a customer actually touches.
///
/// It can be tapped *or* dragged across, which is the quickest way to land on
/// a score one-handed; each change fires a selection haptic and springs the
/// star past its size on the way in, so the rating feels physical rather than
/// like ticking a box.
class StarPicker extends StatefulWidget {
  const StarPicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.starSize = 40,
    this.showWord = false,
    this.enabled = true,
  });

  final int value;
  final ValueChanged<int> onChanged;

  /// Read out by screen readers, e.g. "Delivery".
  final String label;
  final double starSize;
  final bool showWord;
  final bool enabled;

  @override
  State<StarPicker> createState() => _StarPickerState();
}

class _StarPickerState extends State<StarPicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  /// Which star is mid-spring. Only the star that was chosen animates.
  /// popping the whole row on every change turns a small confirmation into
  /// noise.
  int _popIndex = -1;

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  double get _slot => widget.starSize + widget.starSize * 0.14;

  void _setFromOffset(Offset local) {
    if (!widget.enabled) return;
    final index = (local.dx / _slot).floor().clamp(0, 4);
    _select(index + 1);
  }

  void _select(int next) {
    if (next == widget.value && _popIndex == next - 1) return;
    HapticFeedback.selectionClick();
    setState(() => _popIndex = next - 1);
    _pop.forward(from: 0);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Honour the OS "reduce motion" setting: the spring and glow are
    // decoration, and the rating still reads without them.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: widget.label,
          value: '${widget.value} of 5',
          slider: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _setFromOffset(details.localPosition),
            onHorizontalDragStart: (details) =>
                _setFromOffset(details.localPosition),
            onHorizontalDragUpdate: (details) =>
                _setFromOffset(details.localPosition),
            child: Opacity(
              opacity: widget.enabled ? 1 : 0.5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final lit = index < widget.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == 4 ? 0 : widget.starSize * 0.14,
                    ),
                    child: AnimatedBuilder(
                      animation: _pop,
                      builder: (context, child) {
                        final active = _popIndex == index && !reduceMotion;
                        final t = active ? _pop.value : 1.0;
                        // Overshoot then settle. A spring, not a fade.
                        final scale = active ? 1 + _spring(t) : 1.0;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            if (active && t < 1)
                              Container(
                                width: widget.starSize * (0.6 + t * 1.5),
                                height: widget.starSize * (0.6 + t * 1.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.star.withValues(
                                    alpha: 0.35 * (1 - t),
                                  ),
                                ),
                              ),
                            Transform.scale(scale: scale, child: child),
                          ],
                        );
                      },
                      child: _Star(size: widget.starSize, lit: lit),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        if (widget.showWord) ...[
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              ratingWord(widget.value),
              key: ValueKey(widget.value),
              style: theme.textTheme.titleSmall?.copyWith(
                color: widget.value > 0
                    ? AppColors.foreground
                    : AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Scale offset over the life of the pop: out past 1.0, then back.
  static double _spring(double t) {
    if (t >= 1) return 0;
    return Curves.easeOut.transform((1 - (t - 0.35).abs() * 2.2).clamp(0, 1)) *
        0.22;
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.size, required this.lit});

  final double size;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      lit ? Icons.star_rounded : Icons.star_outline_rounded,
      size: size,
      color: lit ? AppColors.star : AppColors.mist,
    );
    return icon;
  }
}

/// The 5→1 distribution, so a 4.6 made of forty 5s reads differently to one
/// made of 4s. Bars grow in on first build so the shape registers.
class RatingBars extends StatelessWidget {
  const RatingBars({
    super.key,
    required this.breakdown,
    required this.total,
  });

  final Map<int, int> breakdown;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final stars in const [5, 4, 3, 2, 1])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    '$stars★',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: total == 0
                            ? 0
                            : (breakdown[stars] ?? 0) / total,
                      ),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      builder: (context, fraction, _) => LinearProgressIndicator(
                        value: fraction,
                        minHeight: 7,
                        backgroundColor: AppColors.muted,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.star,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 30,
                  child: Text(
                    '${breakdown[stars] ?? 0}',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
