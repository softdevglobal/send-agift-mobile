import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../reviews/data/reviews_repository.dart';
import '../../../reviews/domain/product_review.dart';
import '../../../reviews/presentation/screens/write_review_screen.dart';
import '../../data/orders_repository.dart';
import '../../domain/received_gift.dart';

/// Gifts other people sent you, once delivered. Each line can be reviewed.
class ReceivedGiftsScreen extends ConsumerWidget {
  const ReceivedGiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gifts = ref.watch(receivedGiftsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gifts received')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(receivedGiftsProvider.future),
        child: gifts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 80),
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load your gifts',
                description: 'Pull down to try again.',
              ),
            ],
          ),
          data: (list) => list.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.card_giftcard_rounded,
                      title: 'No gifts yet',
                      description:
                          'When someone sends you a gift, it shows up here '
                          "once it's delivered.",
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.gutter,
                    12,
                    AppTheme.gutter,
                    32,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 18),
                  itemBuilder: (context, i) => _GiftCard(gift: list[i]),
                ),
        ),
      ),
    );
  }
}

class _GiftCard extends StatelessWidget {
  const _GiftCard({required this.gift});

  final ReceivedGift gift;

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFDB2777), Color(0xFFF59E0B)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DELIVERED ${material.formatMediumDate(gift.deliveredAt).toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'From ${gift.senderName}',
                  style: AppTypography.display(24, color: Colors.white),
                ),
                if (gift.giftPoints > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '★ ${gift.giftPoints} points included',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (gift.giftMessage != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F0),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: const Color(0xFFFBD5C0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '“${gift.giftMessage}”',
                    style: AppTypography.display(
                      17,
                      weight: FontWeight.w500,
                      color: const Color(0xFF431407),
                      height: 1.4,
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ',  ${gift.senderName}',
                    style: const TextStyle(
                      color: Color(0xFF9D174D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          for (final item in gift.items)
            _GiftLine(item: item, senderName: gift.senderName),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _GiftLine extends ConsumerWidget {
  const _GiftLine({required this.item, required this.senderName});

  final ReceivedGiftItem item;
  final String senderName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref
        .watch(myReviewsByOrderItemProvider(null))
        .valueOrNull?[item.id];
    final reviewedBySender = item.reviewId != null && mine == null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: SizedBox(
              width: 60,
              height: 60,
              child: item.imageUrl != null
                  ? AppNetworkImage(url: item.imageUrl!, width: 60, height: 60)
                  : const ColoredBox(
                      color: AppColors.cream,
                      child: Icon(
                        Icons.card_giftcard_rounded,
                        color: AppColors.purple,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'from ${item.shopName} · ×${item.quantity}',
                  style: const TextStyle(
                    color: AppColors.mutedForeground,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                if (reviewedBySender)
                  Text(
                    '$senderName already reviewed this one.',
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 12,
                    ),
                  )
                else if (item.delivered)
                  mine == null
                      ? FilledButton.tonalIcon(
                          onPressed: () => _open(context, ref, null),
                          icon: const Icon(Icons.star_rounded, size: 18),
                          label: const Text('Write a review'),
                        )
                      : OutlinedButton.icon(
                          onPressed: () => _open(context, ref, mine),
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: const Text('Edit your review'),
                        ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ProductReview? existing,
  ) async {
    await Navigator.of(context).push<ProductReview>(
      MaterialPageRoute(
        builder: (_) => WriteReviewScreen(
          orderItemId: item.id,
          existing: existing,
          productName: item.productName,
        ),
      ),
    );
    ref.invalidate(myReviewsProvider);
    ref.invalidate(receivedGiftsProvider);
  }
}
