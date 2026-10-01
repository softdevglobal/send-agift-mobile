import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// The four trust promises the web home page runs under its hero. Each tile
/// takes a different brand hue, so the strip reads as a set rather than four
/// copies of the same card.
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

  static const _chipColors = [AppColors.primary, AppColors.purple, AppColors.teal];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Tall enough for the icon, the title and two lines of description;
      // a Spacer here once overflowed on small phones.
      height: 138,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
        itemCount: _features.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final feature = _features[index];
          final chipColor = _chipColors[index % _chipColors.length];
          final chipTint =
              AppColors.categoryTints[index % AppColors.categoryTints.length];

          return Container(
            width: 158,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: chipTint,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(feature.icon, size: 17, color: chipColor),
                ),
                const SizedBox(height: 12),
                Text(
                  feature.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  feature.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
