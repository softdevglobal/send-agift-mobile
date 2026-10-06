import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';

/// The four trust promises the web home page runs under its hero: a solid
/// ink band with teal icon chips, the storefront's equivalent of a logo strip.
class FeatureBar extends StatelessWidget {
  const FeatureBar({super.key});

  static const _features = <({IconData icon, String title, String description})>[
    (
      icon: Icons.local_shipping_outlined,
      title: 'Country delivery',
      description: 'Gifts filtered by active countries.',
    ),
    (
      icon: Icons.shield_outlined,
      title: 'Secure payments',
      description: 'Provider-approved checkout.',
    ),
    (
      icon: Icons.refresh_rounded,
      title: 'Easy returns',
      description: 'Clear refund pathways.',
    ),
    (
      icon: Icons.headset_mic_outlined,
      title: '24/7 support',
      description: 'Help with any order.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.foreground,
      child: SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.gutter,
            vertical: 20,
          ),
          itemCount: _features.length,
          separatorBuilder: (context, index) => const SizedBox(width: 22),
          itemBuilder: (context, index) {
            final feature = _features[index];
            return SizedBox(
              width: 196,
              child: Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(feature.icon, size: 19, color: AppColors.foreground),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature.title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.tag(size: 10.5, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          feature.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11.5,
                                height: 1.3,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
