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

/// Horizontally scrolling occasion cards: a tall photo, then the occasion's
/// name and an "explore" cue under it. Tapping one jumps to Explore with
/// that filter already applied.
class CategoryStrip extends ConsumerWidget {
  const CategoryStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 232,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
        itemCount: GiftCategory.all.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = GiftCategory.all[index];
          final tint =
              AppColors.categoryTints[index % AppColors.categoryTints.length];

          return FadeSlideIn(
            delay: Duration(milliseconds: 35 * index),
            child: PressableScale(
              onTap: () {
                ref.read(exploreCategoryProvider.notifier).state = category.id;
                ref.read(exploreQueryProvider.notifier).state = '';
                context.go(AppRoutes.explore);
              },
              child: SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        child: ColoredBox(
                          color: tint,
                          child: SizedBox.expand(
                            child: AppNetworkImage(url: category.image),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.display(14.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Explore now',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                          color: AppColors.foreground,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
