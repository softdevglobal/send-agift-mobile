import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The big call-to-action on game screens, a solid block of the game's
/// main colour.
/// Greys out when [onPressed] is null.
class GameActionButton extends StatelessWidget {
  const GameActionButton({
    required this.label,
    required this.colors,
    required this.onPressed,
    this.icon = Icons.play_arrow_rounded,
    super.key,
  });

  final String label;
  final List<Color> colors;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled ? Colors.white : AppColors.mutedForeground;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            color: enabled ? colors[colors.length > 1 ? 1 : 0] : AppColors.muted,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
