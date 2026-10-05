import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/reviews_repository.dart';
import '../../domain/product_review.dart';
import 'review_card.dart';
import 'star_rating.dart';
import 'review_summary_panel.dart';

/// The reviews block on a gift page: the score, the distribution, and the
/// first few reviews with a way through to the rest.
class ProductReviewsSection extends ConsumerWidget {
  const ProductReviewsSection({
    super.key,
    required this.productId,
    required this.onSeeAll,
    this.previewCount = 3,
  });

  final String productId;
  final VoidCallback onSeeAll;
  final int previewCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(productReviewSummaryProvider(productId));
    final reviews = ref.watch(productReviewsProvider(productId));

    return summary.when(
      // A gift page should not wait on its reviews, and a failed summary
      // should not break it. Both fall back to showing nothing.
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data.reviewCount == 0) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: AppColors.border,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.rate_review_outlined,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(height: 8),
                Text('No reviews yet', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Reviews come from delivered orders, so the first one lands '
                  'once someone has received this gift.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReviewSummaryPanel(summary: data),
            const SizedBox(height: 12),
            reviews.maybeWhen(
              data: (page) => Column(
                children: [
                  for (final review in page.items.take(previewCount))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ReviewCard(review: review),
                    ),
                ],
              ),
              orElse: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            if (data.reviewCount > previewCount)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onSeeAll,
                  child: Text('See all ${data.reviewCount} reviews'),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The compact score shown next to a gift's name.
///
/// Renders nothing until the summary arrives and nothing at all when there are
/// no reviews: an empty row of grey stars under a new gift reads as "rated
/// zero" rather than "not rated yet".
class ProductRatingBadge extends ConsumerWidget {
  const ProductRatingBadge({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(productReviewSummaryProvider(productId));
    return summary.maybeWhen(
      data: (data) => data.reviewCount == 0
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 8),
              child: StarMeterWithCount(summary: data),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Small helper so the badge and the list header agree on the same layout.
class StarMeterWithCount extends StatelessWidget {
  const StarMeterWithCount({super.key, required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StarMeter(value: summary.avgRating, size: 15, showValue: true),
        const SizedBox(width: 6),
        Text(
          '(${summary.reviewCount})',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}
