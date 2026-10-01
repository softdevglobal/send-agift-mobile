import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/pressable_scale.dart';

/// Entry point from the storefront into the skill games.
///
/// Deliberately reads as a game, not a prize draw: no jackpot, no entry fee,
/// no "chance to win" — the app-store and competition rules require that the
/// framing stay about skill.
class GamesTeaser extends StatelessWidget {
  const GamesTeaser({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
      child: PressableScale(
        onTap: () => context.push(AppRoutes.games),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius2xl),
            boxShadow: [
              BoxShadow(
                color: AppColors.teal.withValues(alpha: 0.25),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radius2xl),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B6E68), Color(0xFF14B8B8)],
                ),
              ),
              child: Stack(
                children: [
                  // Game pieces drifting across the card.
                  for (final (icon, right, top, size, angle) in const [
                    (Icons.sports_basketball_rounded, 18.0, 14.0, 34.0, -0.3),
                    (Icons.extension_rounded, 72.0, 46.0, 26.0, 0.4),
                    (Icons.gps_fixed_rounded, 24.0, 70.0, 28.0, 0.0),
                    (Icons.grid_4x4_rounded, 110.0, 10.0, 22.0, 0.2),
                  ])
                    Positioned(
                      right: right,
                      top: top,
                      child: Transform.rotate(
                        angle: angle,
                        child: Icon(
                          icon,
                          size: size,
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.sports_esports_rounded,
                            color: AppColors.accentForeground,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Take a break, play a game',
                                style: AppTypography.display(
                                  18,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Basketball, Stack Tower, Archery, 2048 and '
                                'more. Pure skill.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 34,
                          width: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
