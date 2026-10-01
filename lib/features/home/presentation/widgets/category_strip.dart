import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../products/data/catalog_providers.dart';
import '../../../products/domain/gift_category.dart';

/// Horizontally scrolling occasion cards — a photo with the occasion's
/// name over a soft fade. Tapping one jumps to Explore with that filter
/// already applied.
class CategoryStrip extends ConsumerWidget {
  const CategoryStrip({super.key});

  static const _accents = [AppColors.purple, AppColors.teal, AppColors.star];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
        itemCount: GiftCategory.all.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = GiftCategory.all[index];
          final accent = _accents[index % _accents.length];

          return FadeSlideIn(
            delay: Duration(milliseconds: 35 * index),
            child: PressableScale(
              onTap: () {
                ref.read(exploreCategoryProvider.notifier).state = category.id;
                ref.read(exploreQueryProvider.notifier).state = '';
                context.go(AppRoutes.explore);
              },
              child: Container(
                width: 116,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(url: category.image),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.35, 1],
                            colors: [Color(0x00000000), Color(0xCC0F1B45)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          height: 8,
                          width: 8,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 10,
                        bottom: 12,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                category.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.display(
                                  16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_outward_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
