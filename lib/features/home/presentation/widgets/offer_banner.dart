import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/storefront_decor.dart';

/// Seasonal promotion: a full-width solid teal band with a poster headline,
/// matching the web's promo band.
class OfferBanner extends StatelessWidget {
  const OfferBanner({super.key});

  static const _image =
      'https://images.unsplash.com/photo-1513885535751-8b9238bd345a?auto=format&fit=crop&w=1000&q=80';

  @override
  Widget build(BuildContext context) {
    final headline = AppTypography.poster(34);

    return ColoredBox(
      color: AppColors.teal,
      child: Stack(
        children: [
          const Positioned(
            right: 34,
            top: 30,
            child: Sparkle(size: 26, color: Colors.white),
          ),
          const Positioned(
            right: 90,
            top: 84,
            child: Dot(size: 9, color: AppColors.foreground),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              30,
              AppTheme.gutter,
              30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Marker(
                  'GIFT SETS',
                  style: headline,
                  color: Colors.white,
                  textColor: AppColors.foreground,
                ),
                const SizedBox(height: 4),
                Text('UP TO 50% OFF', style: headline),
                const SizedBox(height: 14),
                Text(
                  'Seasonal hampers, keepsakes, and wellness gifts, with bonus '
                  'points on eligible checkouts.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.foreground.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                          child: const AppNetworkImage(url: _image),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: -18,
                        child: Transform.rotate(
                          angle: 0.2,
                          child: Container(
                            height: 72,
                            width: 72,
                            decoration: const BoxDecoration(
                              color: AppColors.foreground,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '50%',
                                  style: AppTypography.poster(
                                    20,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'OFF',
                                  style: AppTypography.tag(
                                    size: 9,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () => context.go(AppRoutes.explore),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  iconAlignment: IconAlignment.end,
                  label: const Text('SHOP THE SALE'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
