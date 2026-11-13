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
import '../../../../core/widgets/storefront_decor.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../auth/data/auth_controller.dart';
import '../../../cart/data/cart_controller.dart';
import '../../../reviews/presentation/screens/product_reviews_screen.dart';
import '../../../reviews/presentation/widgets/product_reviews_section.dart';
import '../../data/catalog_providers.dart';
import '../../domain/gift.dart';
import '../widgets/gift_gallery.dart';
import '../widgets/save_gift_button.dart';
import '../../../../core/widgets/entries_badge.dart';
import '../../../../core/widgets/section_tag.dart';

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

class _Content extends StatefulWidget {
  const _Content({required this.gift, this.heroTag});

  final Gift gift;
  final String? heroTag;

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  final _gallery = GiftGalleryController();

  @override
  void dispose() {
    _gallery.dispose();
    super.dispose();
  }

  Gift get gift => widget.gift;
  String? get heroTag => widget.heroTag;

  @override
  Widget build(BuildContext context) {
    final discount = gift.discountPercent;
    // Every photo and video: photos first from the cover, then videos.
    final media = gift.gallery;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 340,
          pinned: true,
          backgroundColor: AppColors.cream,
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
            background: GiftGalleryView(
              media: media,
              controller: _gallery,
              heroTag: heroTag,
            ),
          ),
        ),
        // Every photo and video in one row under the main image.
        if (media.length > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: GiftGalleryThumbnails(media: media, controller: _gallery),
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
                  Text(
                    gift.name,
                    style: AppTypography.display(30, height: 1.05),
                  ),
                  ProductRatingBadge(productId: gift.id),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        gift.priceLabel,
                        style: AppTypography.poster(
                          30,
                          color: AppColors.purple,
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
                  if (gift.sponsored) ...[
                    const SizedBox(height: 16),
                    EntriesRewardCard(entries: gift.gameEntries),
                  ],
                  if (gift.shopName != null) ...[
                    const SizedBox(height: 20),
                    _ShopRow(gift: gift),
                  ],
                  if (gift.description.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    const SectionTag(
                      label: 'About this gift',
                      icon: Icons.auto_awesome_rounded,
                      color: AppColors.purple,
                    ),
                    const SizedBox(height: 10),
                    _AboutCard(text: gift.description),
                  ],
                  const SizedBox(height: 26),
                  const SectionTag(
                    label: 'Reviews',
                    icon: Icons.star_rounded,
                    color: AppColors.teal,
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
    // Tapping the seller's photo or the shop name opens the shop's page.
    final shopId = gift.shopId;
    void openShop() {
      if (shopId != null && shopId.isNotEmpty) {
        context.push(AppRoutes.shopPath(shopId));
      }
    }

    return AppPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const Key('gift-open-shop'),
              onTap: openShop,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Row(
                children: [
                  // The seller's own photo, round; else the shop's logo; else an icon.
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: gift.sellerImageUrl != null
                          ? BoxShape.circle
                          : BoxShape.rectangle,
                      borderRadius: gift.sellerImageUrl != null
                          ? null
                          : BorderRadius.circular(AppTheme.radiusMd),
                      border: gift.sellerImageUrl != null
                          ? Border.all(color: AppColors.teal, width: 2)
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: gift.sellerImageUrl != null
                        ? AppNetworkImage(url: gift.sellerImageUrl!)
                        : gift.shopImageUrl != null
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
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {
              final signedIn = ref.read(authProvider).isSignedIn;
              context.push(
                signedIn
                    ? AppRoutes.askAboutGiftPath(gift.id)
                    : AppRoutes.login,
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

/// A gift's description in a card, folded to a few lines when it is long.
class _AboutCard extends StatefulWidget {
  const _AboutCard({required this.text});

  final String text;

  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  static const _folded = 5;
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.foreground.withValues(alpha: 0.78),
      height: 1.55,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          // Only offer "Read more" when the text really runs past the fold.
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: style),
            maxLines: _folded,
            textDirection: Directionality.of(context),
          )..layout(maxWidth: box.maxWidth);
          final long = painter.didExceedMaxLines;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                alignment: Alignment.topCenter,
                child: Text(
                  widget.text,
                  style: style,
                  maxLines: _open ? null : _folded,
                  overflow: _open ? null : TextOverflow.fade,
                ),
              ),
              if (long)
                TextButton.icon(
                  key: const Key('about-read-more'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => setState(() => _open = !_open),
                  icon: Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                  ),
                  label: Text(_open ? 'Show less' : 'Read more'),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// How the gift reaches someone, as two tiles side by side.
class _DeliveryNotes extends StatelessWidget {
  const _DeliveryNotes();

  @override
  Widget build(BuildContext context) {
    return const IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _NoteTile(
              icon: Icons.local_shipping_rounded,
              color: AppColors.teal,
              title: 'Shop delivery',
              description: 'Delivered by the shop within its own zones.',
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _NoteTile(
              icon: Icons.verified_user_rounded,
              color: AppColors.purple,
              title: 'Easy returns',
              description: 'Clear refund and dispute steps on every order.',
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 3),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.mutedForeground,
              height: 1.35,
            ),
          ),
        ],
      ),
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
                ref
                    .read(cartProvider.notifier)
                    .add(gift.id, quantity: quantity);
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
    return TagChip(
      label,
      color: highlighted ? AppColors.purple : AppColors.teal,
      textColor: highlighted ? Colors.white : AppColors.foreground,
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
        description:
            'This gift is no longer published. Browse what else is new.',
        action: ElevatedButton(
          onPressed: () => context.go(AppRoutes.explore),
          child: const Text('Browse gifts'),
        ),
      ),
    );
  }
}
