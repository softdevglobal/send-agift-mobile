import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/stat_hero.dart';
import '../../../products/data/catalog_providers.dart';
import '../../../products/domain/gift.dart';
import '../../data/reviews_repository.dart';
import '../../domain/product_review.dart';
import '../widgets/review_card.dart';
import 'write_review_screen.dart';

/// Which reviews to show.
enum _Filter { all, five, four, low, photos, replied }

extension on ProductReview {
  bool matches(_Filter filter) => switch (filter) {
    _Filter.all => true,
    _Filter.five => rating >= 5,
    _Filter.four => rating == 4,
    _Filter.low => rating <= 3,
    _Filter.photos => media.isNotEmpty,
    _Filter.replied => (sellerReply ?? '').trim().isNotEmpty,
  };
}

/// Everything the signed-in customer has written, newest first, with a way to
/// edit or take one down.
class MyReviewsScreen extends ConsumerStatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  ConsumerState<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends ConsumerState<MyReviewsScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final reviews = ref.watch(myReviewsProvider);
    // Reviews carry only a product id; the catalog gives the gift's name and
    // photo for the card header.
    final gifts = {
      for (final gift in ref.watch(catalogProvider).valueOrNull ?? const [])
        gift.id: gift,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My reviews')),
      body: SafeArea(
        child: reviews.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load your reviews",
            description: error is AppException
                ? error.message
                : 'Could not load reviews.',
            action: OutlinedButton(
              onPressed: () => ref.invalidate(myReviewsProvider),
              child: const Text('Try again'),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return EmptyState(
                icon: Icons.star_outline_rounded,
                title: 'No reviews yet',
                description:
                    'Once a gift is delivered you can review it from the '
                    'order. Your rating helps the next person choose.',
                action: OutlinedButton(
                  onPressed: () => context.push(AppRoutes.orders),
                  child: const Text('Go to my orders'),
                ),
              );
            }
            final shown = items.where((r) => r.matches(_filter)).toList();
            return RefreshIndicator(
              onRefresh: () => ref.refresh(myReviewsProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  16,
                  AppTheme.gutter,
                  32,
                ),
                children: [
                  _Hero(reviews: items),
                  const SizedBox(height: 12),
                  StatGrid(
                    tiles: [
                      StatTile(
                        label: 'With photos',
                        value:
                            '${items.where((r) => r.media.isNotEmpty).length}',
                        icon: Icons.photo_library_rounded,
                        color: AppColors.purple,
                        selected: _filter == _Filter.photos,
                        onTap: () => _toggle(_Filter.photos),
                      ),
                      StatTile(
                        label: 'Seller replies',
                        value:
                            '${items.where((r) => _Filter.replied.test(r)).length}',
                        icon: Icons.storefront_rounded,
                        color: AppColors.accentForeground,
                        selected: _filter == _Filter.replied,
                        onTap: () => _toggle(_Filter.replied),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Distribution(
                    reviews: items,
                    selected: _filter,
                    onSelect: _toggle,
                  ),
                  const SizedBox(height: 20),
                  Text('YOUR REVIEWS', style: AppTypography.eyebrow),
                  const SizedBox(height: 10),
                  FilterChipRow<_Filter>(
                    options: const [
                      (_Filter.all, 'All'),
                      (_Filter.five, '5 stars'),
                      (_Filter.four, '4 stars'),
                      (_Filter.low, '3 and below'),
                      (_Filter.photos, 'With photos'),
                      (_Filter.replied, 'Replied'),
                    ],
                    selected: _filter,
                    onSelected: (value) => setState(() => _filter = value),
                  ),
                  const SizedBox(height: 14),
                  if (shown.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: Text('No reviews here.')),
                    ),
                  for (var i = 0; i < shown.length; i++) ...[
                    FadeSlideIn(
                      delay: Duration(milliseconds: 30 * i.clamp(0, 6)),
                      child: ReviewCard(
                        review: shown[i],
                        header: _GiftHeader(
                          gift: gifts[shown[i].productId],
                          rating: shown[i].rating,
                        ),
                        onEdit: () => _edit(context, ref, shown[i]),
                        onDelete: () => _confirmDelete(context, ref, shown[i]),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Tapping the active filter again clears it.
  void _toggle(_Filter filter) =>
      setState(() => _filter = _filter == filter ? _Filter.all : filter);

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ProductReview review,
  ) async {
    await Navigator.of(context).push<ProductReview>(
      MaterialPageRoute(
        builder: (_) => WriteReviewScreen(
          orderItemId: review.orderItemId,
          existing: review,
        ),
      ),
    );
    ref.invalidate(myReviewsProvider);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ProductReview review,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this review?'),
        content: const Text(
          'It will be removed from the gift straight away. You can write a '
          'new one for the same order later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(reviewsRepositoryProvider).delete(review.id);
      ref.invalidate(myReviewsProvider);
      ref.invalidate(productReviewsProvider(review.productId));
      ref.invalidate(productReviewSummaryProvider(review.productId));
      messenger.showSnackBar(const SnackBar(content: Text('Review deleted.')));
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

extension on _Filter {
  bool test(ProductReview review) => review.matches(this);
}

class _Hero extends StatelessWidget {
  const _Hero({required this.reviews});

  final List<ProductReview> reviews;

  @override
  Widget build(BuildContext context) {
    final average =
        reviews.fold<int>(0, (sum, r) => sum + r.rating) / reviews.length;
    final helpful = reviews.fold<int>(0, (sum, r) => sum + r.helpfulCount);
    return StatHero(
      label: 'Your average rating',
      icon: Icons.reviews_rounded,
      value: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(average.toStringAsFixed(1)),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= average.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 20,
                    color: i <= average.round()
                        ? AppColors.star
                        : Colors.white.withValues(alpha: 0.6),
                  ),
              ],
            ),
          ),
        ],
      ),
      caption:
          '${reviews.length} ${reviews.length == 1 ? 'review' : 'reviews'} · '
          '$helpful helpful ${helpful == 1 ? 'vote' : 'votes'}',
    );
  }
}

/// How the ratings spread from 5 to 1. Tapping a bar filters to it.
class _Distribution extends StatelessWidget {
  const _Distribution({
    required this.reviews,
    required this.selected,
    required this.onSelect,
  });

  final List<ProductReview> reviews;
  final _Filter selected;
  final ValueChanged<_Filter> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = List<int>.filled(6, 0);
    for (final review in reviews) {
      counts[review.rating.clamp(1, 5)]++;
    }
    final most = counts.reduce((a, b) => a > b ? a : b);

    _Filter? filterFor(int stars) => switch (stars) {
      5 => _Filter.five,
      4 => _Filter.four,
      _ => _Filter.low,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var stars = 5; stars >= 1; stars--)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onSelect(filterFor(stars)!),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text('$stars', style: theme.textTheme.labelLarge),
                    ),
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: AppColors.star,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Stack(
                          children: [
                            Container(height: 8, color: AppColors.muted),
                            FractionallySizedBox(
                              widthFactor: most == 0 ? 0 : counts[stars] / most,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: selected == filterFor(stars)
                                        ? const [
                                            AppColors.purple,
                                            AppColors.purple,
                                          ]
                                        : const [
                                            AppColors.star,
                                            Color(0xFFF6C66B),
                                          ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${counts[stars]}',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The gift a review is about, with the star score as a badge.
class _GiftHeader extends StatelessWidget {
  const _GiftHeader({required this.gift, required this.rating});

  final Gift? gift;
  final int rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = gift;
    final content = Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: g == null || g.image.isEmpty
              ? Container(
                  height: 48,
                  width: 48,
                  color: AppColors.cream,
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: AppColors.purple,
                  ),
                )
              : AppNetworkImage(url: g.image, width: 48, height: 48),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                g?.name ?? 'A delivered gift',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              if ((g?.shopName ?? '').isNotEmpty)
                Text(g!.shopName!, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.star.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, size: 14, color: AppColors.star),
              const SizedBox(width: 3),
              Text(
                '$rating',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF9A5B0F),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (g == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      onTap: () => context.push(AppRoutes.giftDetailPath(g.id)),
      child: content,
    );
  }
}
