import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../auth/data/auth_controller.dart';
import '../../../cart/data/cart_controller.dart';
import '../../../reviews/presentation/screens/product_reviews_screen.dart';
import '../../../reviews/presentation/widgets/product_reviews_section.dart';
import '../../data/catalog_providers.dart';
import '../../domain/gift.dart';
import '../widgets/save_gift_button.dart';
import '../../../../core/widgets/reward_points_badge.dart';

/// Product page: large photo, shop line, price, description and a sticky
/// add-to-cart bar. No sign-in required to reach or use any of it.
class GiftDetailScreen extends ConsumerStatefulWidget {
  const GiftDetailScreen({super.key, required this.giftId, this.heroTag});

  final String giftId;

  /// Tag of the card that opened this screen, so the photo flies in from it.
  /// Null when opened without a source card (a deep link, say).
  final String? heroTag;

  @override
  ConsumerState<GiftDetailScreen> createState() => _GiftDetailScreenState();
}

class _GiftDetailScreenState extends ConsumerState<GiftDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final gift = ref.watch(giftByIdProvider(widget.giftId));

    return Scaffold(
      body: gift.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => _NotFound(),
        data: (gift) => gift == null
            ? _NotFound()
            : _Content(gift: gift, heroTag: widget.heroTag),
      ),
      bottomNavigationBar: gift.valueOrNull == null
          ? null
          : _AddToCartBar(
              gift: gift.value!,
              quantity: _quantity,
              onQuantityChanged: (value) => setState(() => _quantity = value),
            ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.gift, this.heroTag});

  final Gift gift;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final discount = gift.discountPercent;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 340,
          pinned: true,
          backgroundColor: AppColors.background,
          leading: _CircleAction(
            icon: Icons.arrow_back_rounded,
            onTap: () => context.pop(),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: SaveGiftButton(giftId: gift.id, compact: false),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: heroTag == null
                ? AppNetworkImage(url: gift.image)
                : Hero(
                    tag: heroTag!,
                    child: AppNetworkImage(url: gift.image),
                  ),
          ),
        ),
        SliverToBoxAdapter(
          child: FadeSlideIn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                20,
                AppTheme.gutter,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Tag(label: gift.categoryLabel),
                      if (discount != null) ...[
                        const SizedBox(width: 8),
                        _Tag(label: '$discount% off', highlighted: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(gift.name, style: AppTypography.display(26)),
                  ProductRatingBadge(productId: gift.id),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        gift.priceLabel,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                      if (gift.compareAtLabel != null) ...[
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            gift.compareAtLabel!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.mutedForeground,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (gift.rewardPoints > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        RewardPointsBadge(
                          points: gift.rewardPoints,
                          large: true,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'per item, added to your points when you '
                            'order. Spend them on games.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (gift.shopName != null) ...[
                    const SizedBox(height: 20),
                    _ShopRow(gift: gift),
                  ],
                  if (gift.description.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'About this gift',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      gift.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    'Reviews',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  ProductReviewsSection(
                    productId: gift.id,
                    onSeeAll: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => ProductReviewsScreen(
                          productId: gift.id,
                          productName: gift.name,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _DeliveryNotes(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShopRow extends ConsumerWidget {
  const _ShopRow({required this.gift});

  final Gift gift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            clipBehavior: Clip.antiAlias,
            child: gift.shopImageUrl != null
                ? AppNetworkImage(url: gift.shopImageUrl!)
                : const Icon(
                    Icons.storefront_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gift.shopName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Sold and fulfilled by this shop',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {
              final signedIn = ref.read(authProvider).isSignedIn;
              context.push(
                signedIn ? AppRoutes.askAboutGiftPath(gift.id) : AppRoutes.login,
              );
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
            label: const Text('Ask'),
          ),
        ],
      ),
    );
  }
}

class _DeliveryNotes extends StatelessWidget {
  const _DeliveryNotes();

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      color: AppColors.cream,
      child: Column(
        children: const [
          _NoteRow(
            icon: Icons.local_shipping_outlined,
            title: 'Delivered by the shop',
            description:
                'Each shop delivers within its own zones. Search an address '
                'to see what can reach it.',
          ),
          SizedBox(height: 14),
          _NoteRow(
            icon: Icons.refresh_rounded,
            title: 'Easy returns',
            description: 'Clear refund and dispute pathways on every order.',
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddToCartBar extends ConsumerWidget {
  const _AddToCartBar({
    required this.gift,
    required this.quantity,
    required this.onQuantityChanged,
  });

  final Gift gift;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppTheme.gutter,
        12,
        AppTheme.gutter,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          QuantityStepper(quantity: quantity, onChanged: onQuantityChanged),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(cartProvider.notifier).add(gift.id, quantity: quantity);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text('${gift.name} added to cart'),
                      action: SnackBarAction(
                        label: 'View cart',
                        textColor: AppColors.accent,
                        onPressed: () => context.push(AppRoutes.cart),
                      ),
                    ),
                  );
              },
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('Add to cart'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primary : AppColors.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color:
              highlighted ? AppColors.primaryForeground : AppColors.accentForeground,
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            boxShadow: AppTheme.cardShadow,
          ),
          child: Icon(icon, size: 19, color: AppColors.foreground),
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: EmptyState(
        icon: Icons.card_giftcard_outlined,
        title: 'Gift unavailable',
        description: 'This gift is no longer published. Browse what else is new.',
        action: ElevatedButton(
          onPressed: () => context.go(AppRoutes.explore),
          child: const Text('Browse gifts'),
        ),
      ),
    );
  }
}
