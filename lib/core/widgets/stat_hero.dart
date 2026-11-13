import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'storefront_decor.dart';

/// The card at the top of the "my" pages: a small label, one big figure, a
/// line under it, and the page's icon as a tilted sticker. Flat brand colour
/// with a few sparkles, like the storefront.
class StatHero extends StatelessWidget {
  const StatHero({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.trailing,
    this.color = AppColors.purple,
    this.stickerColor = AppColors.purple,
  });

  final String label;

  /// The headline figure, e.g. "12 orders".
  final Widget value;
  final String? caption;

  /// Shown on a white sticker in the corner.
  final IconData? icon;

  /// Sits under the caption, e.g. a progress bar or a button.
  final Widget? trailing;

  /// The card's colour: purple by default, ink for game entries.
  final Color color;

  /// The icon's colour on its white sticker.
  final Color stickerColor;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: Colors.white.withValues(alpha: 0.85));
    // Full width wherever it sits: in a start-aligned column it would
    // otherwise shrink to its content.
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: ColoredBox(
        color: color,
        child: SizedBox(
          width: double.infinity,
          child: Stack(
            children: [
              Positioned(
                right: -36,
                bottom: -46,
                child: Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              const Positioned(
                right: 96,
                top: 18,
                child: Sparkle(size: 14, color: AppColors.teal),
              ),
              Positioned(
                right: 26,
                bottom: 22,
                child: Sparkle(
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              Positioned(
                right: 120,
                bottom: 30,
                child: Dot(size: 6, color: Colors.white.withValues(alpha: 0.5)),
              ),
              if (icon != null)
                Positioned(
                  right: 20,
                  top: 20,
                  child: Transform.rotate(
                    angle: 0.12,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, size: 28, color: stickerColor),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: muted.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      // Clear of the sticker.
                      padding: EdgeInsets.only(right: icon != null ? 72 : 0),
                      child: DefaultTextStyle.merge(
                        style: AppTypography.display(36, color: Colors.white),
                        child: value,
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 8),
                      Text(caption!, style: muted),
                    ],
                    if (trailing != null) ...[
                      const SizedBox(height: 14),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One small figure: a solid icon circle on a soft tint of its colour.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  /// Outlines the tile when it is the active filter.
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: selected ? 0.16 : 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.22),
              width: selected ? 2 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, size: 19, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: AppTypography.poster(20),
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
      ),
    );
  }
}

/// [StatTile]s two to a row.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: tiles,
    );
  }
}

/// A row of box filter chips, as on the website: ash-outlined boxes, the
/// selected one a solid ink block. Scrolls sideways when it runs out of room.
class FilterChipRow<T> extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (value, label) = options[index];
          return BoxChip(
            label: label,
            selected: value == selected,
            onTap: () => onSelected(value),
          );
        },
      ),
    );
  }
}

/// One box filter chip.
class BoxChip extends StatelessWidget {
  const BoxChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// An icon or thumbnail before the label.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(leading == null ? 14 : 5, 0, 14, 0),
          decoration: BoxDecoration(
            color: selected ? AppColors.foreground : AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusBoxSm),
            border: Border.all(
              color: selected ? AppColors.foreground : AppColors.boxBorder,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTypography.sansFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
