import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Floating nav rail.
///
/// The tab you are on lights up in ribbon-violet and grows a touch; the rest
/// sit quiet in muted ink. Nothing is drawn behind the glyphs. The colour is
/// the whole signal. And the bar carries no wording, only names for screen
/// readers. One item may be marked [AppBottomNavItem.orb]: it becomes a
/// filled brand circle seated in the middle of the rail, the anchor the eye
/// lands on first.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;
  final List<AppBottomNavItem> items;

  static const double _barHeight = 72;
  static const double _barRadius = 30;
  static const double _pillRadius = 22;
  static const double _iconSize = 22;

  /// Padding and border between the bar's edge and the row of tabs. Slot
  /// widths are measured inside it, so the row always fits.
  static const double _barPadding = 7;
  static const double _barBorder = 1;
  static const double _barInset = _barPadding + _barBorder;

  /// The orb and the slot it sits in.
  static const double _orbSize = 58;
  static const double _orbSlot = 74;

  static const Duration _morph = Duration(milliseconds: 340);
  static const Curve _morphCurve = Curves.easeOutCubic;

  int get _orbIndex => items.indexWhere((item) => item.orb);

  @override
  Widget build(BuildContext context) {
    final orbIndex = _orbIndex;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inner = constraints.maxWidth - (_barInset * 2);
            // The orb keeps its slot until there is not enough rail left for
            // it, and then gives ground rather than overflowing the row.
            final orbWidth = orbIndex >= 0
                ? (inner < _orbSlot ? (inner > 0 ? inner : 0.0) : _orbSlot)
                : 0.0;
            final flatWidth = inner - orbWidth;
            final widths = _slotWidths(flatWidth, orbIndex);

            return Container(
              height: _barHeight,
              padding: const EdgeInsets.symmetric(horizontal: _barPadding),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(_barRadius),
                border: Border.all(
                  color: AppColors.border,
                  width: _barBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: AppColors.cardShadow.withValues(alpha: 0.6),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    if (i == orbIndex)
                      _OrbSlot(
                        item: items[i],
                        width: orbWidth,
                        selected: i == currentIndex,
                        onTap: () => _select(i),
                      )
                    else
                      _NavSlot(
                        item: items[i],
                        width: widths[i],
                        selected: i == currentIndex,
                        onTap: () => _select(i),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Widths for the flat tabs.
  ///
  /// Every tab takes an equal share of its side of the rail, which also keeps
  /// the orb dead centre: the two sides always measure the same.
  ///
  /// The share is floored at zero. The rail is laid out with no width at all
  /// during some transitions, and the orb's fixed slot then leaves less than
  /// nothing to share out. A negative width is not a tight squeeze to a
  /// SizedBox, it is an assertion that takes the screen down.
  List<double> _slotWidths(double flatWidth, int orbIndex) {
    final flatCount = items.length - (orbIndex >= 0 ? 1 : 0);
    if (flatCount == 0) return List<double>.filled(items.length, 0);
    final share = flatWidth / flatCount;
    return List<double>.filled(items.length, share.isFinite && share > 0 ? share : 0);
  }

  void _select(int index) {
    if (index != currentIndex) HapticFeedback.selectionClick();
    onChanged(index);
  }
}

/// One tab: an icon, a label, and an optional count badge.
class AppBottomNavItem {
  const AppBottomNavItem({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
    this.orb = false,
  });

  final IconData icon;

  /// Never drawn. The bar is glyphs only. But read out by screen readers
  /// and used as the tap target's accessible name.
  final String label;

  final int badgeCount;

  /// Draws this tab as the rail's filled brand circle. At most one item
  /// should set it.
  final bool orb;
}

/// The brand circle at the centre of the rail. It keeps its fill whether or
/// not it is the current tab. It is the bar's anchor, not just another tab.
/// and shows selection as a lift in glow and scale.
class _OrbSlot extends StatelessWidget {
  const _OrbSlot({
    required this.item,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavItem item;

  /// Normally the orb's full slot, but narrowed when the rail runs out of
  /// room rather than letting the row overflow.
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Center(
        child: Semantics(
          label: item.label,
          button: true,
          selected: selected,
          child: AnimatedContainer(
            duration: AppBottomNav._morph,
            curve: AppBottomNav._morphCurve,
            height: AppBottomNav._orbSize,
            width: AppBottomNav._orbSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.purple,
              boxShadow: [
                // Violet close in, teal spreading past it: the ribbon and the
                // paper plane, the same pairing the rest of the app uses.
                BoxShadow(
                  color: AppColors.purple
                      .withValues(alpha: selected ? 0.52 : 0.32),
                  blurRadius: selected ? 20 : 12,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color:
                      AppColors.teal.withValues(alpha: selected ? 0.34 : 0.16),
                  blurRadius: selected ? 26 : 16,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: AnimatedScale(
                  duration: AppBottomNav._morph,
                  curve: AppBottomNav._morphCurve,
                  scale: selected ? 1.08 : 1,
                  child: Icon(
                    item.icon,
                    size: 27,
                    color: AppColors.primaryForeground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A flat tab: a glyph that colours in when its page is the one you are on.
/// The whole slot is the tap target, so the reachable area is far wider than
/// the glyph itself.
class _NavSlot extends StatelessWidget {
  const _NavSlot({
    required this.item,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppBottomNav._pillRadius),
          onTap: onTap,
          // The bar shows no wording, so the tab has to announce itself to
          // screen readers.
          child: Semantics(
            label: item.label,
            button: true,
            selected: selected,
            child: Center(child: _SlotIcon(item: item, selected: selected)),
          ),
        ),
      ),
    );
  }
}

/// The tab's glyph, with its count badge and the small bounce it makes on the
/// way in.
class _SlotIcon extends StatelessWidget {
  const _SlotIcon({required this.item, required this.selected});

  final AppBottomNavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: selected ? 0 : 1, end: selected ? 1 : 0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Transform.scale(
          // A touch of overshoot on the way in reads as a small bounce rather
          // than a mechanical snap.
          scale: 1 + (0.2 * _overshoot(t)),
          child: child,
        );
      },
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(
          begin: selected ? AppColors.mutedForeground : AppColors.purple,
          end: selected ? AppColors.purple : AppColors.mutedForeground,
        ),
        duration: const Duration(milliseconds: 220),
        builder: (context, color, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(item.icon, size: AppBottomNav._iconSize, color: color),
            if (item.badgeCount > 0)
              Positioned(
                right: -9,
                top: -5,
                child: _CountBadge(count: item.badgeCount),
              ),
          ],
        ),
      ),
    );
  }

  /// Cheap ease-out-back approximation so the icon settles in with a hint of
  /// spring rather than linearly scaling to size.
  static double _overshoot(double t) {
    const c = 1.7;
    final shifted = t - 1;
    return shifted * shifted * ((c + 1) * shifted + c) + 1;
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surface, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: AppColors.tealForeground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
