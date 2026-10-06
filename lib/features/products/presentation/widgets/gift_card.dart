import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../cart/data/cart_controller.dart';
import '../../domain/gift.dart';
import 'save_gift_button.dart';
import '../../../../core/widgets/reward_points_badge.dart';

/// Grid card for a gift: photo, shop line, price, and a one-tap add to cart.
class GiftCard extends ConsumerWidget {
  const GiftCard({super.key, required this.gift, this.heroPrefix});

  final Gift gift;

  /// Names the surface this card sits on ('home', 'explore', 'saved').
  ///
  /// The tab shell keeps every branch mounted at once, so the same gift can be
  /// on screen in several places simultaneously. Hero tags must be unique
  /// within the navigator, hence the prefix; a null prefix opts out of the
  /// transition entirely.
  final String? heroPrefix;

  String? get _heroTag =>
      heroPrefix == null ? null : '$heroPrefix-gift-${gift.id}';

  // Styles are named so the height measurement below and the widgets that
  // render them can never drift apart.
  static const TextStyle _shopStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppColors.mutedForeground,
    letterSpacing: 1.1,
  );
  static const TextStyle _compareAtStyle = TextStyle(
    fontSize: 11.5,
    color: AppColors.mutedForeground,
    decoration: TextDecoration.lineThrough,
  );
  static const TextStyle _priceStyle = TextStyle(
    fontSize: 16.5,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.4,
    color: AppColors.foreground,
  );

  static const EdgeInsets _textPadding = EdgeInsets.fromLTRB(4, 10, 4, 0);
  static const double _shopToNameGap = 3;
  static const double _nameToPriceGap = 6;
  static const double _addButtonSize = 34;
  static const int _nameMaxLines = 2;

  /// Height the text block under the photo needs, at the current text scale.
  ///
  /// Callers add this to the square photo's height to size a grid cell exactly.
  /// It is measured rather than guessed: a fixed aspect ratio overflowed on
  /// Android, whose text renders taller than iOS for the same style, and a
  /// scaled constant still broke at large system font sizes.
  static double textBlockHeight(BuildContext context) {
    final nameStyle = Theme.of(context).textTheme.titleSmall;
    final scaler = MediaQuery.textScalerOf(context);

    double lineHeight(TextStyle? style) {
      final painter = TextPainter(
        // Ascender + descender sample, so the measured line box matches what
        // real text occupies.
        text: TextSpan(text: 'Ag', style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      return painter.height;
    }

    final priceColumnHeight =
        lineHeight(_compareAtStyle) + lineHeight(_priceStyle);

    return _textPadding.vertical +
        lineHeight(_shopStyle) +
        _shopToNameGap +
        lineHeight(nameStyle) * _nameMaxLines +
        _nameToPriceGap +
        // The row is as tall as the taller of its two sides.
        (priceColumnHeight > _addButtonSize
            ? priceColumnHeight
            : _addButtonSize);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discount = gift.discountPercent;

    return PressableScale(
      onTap: () =>
          context.push(AppRoutes.giftDetailPath(gift.id, heroTag: _heroTag)),
      // Outlined so each card's area reads clearly. The inset is equal on
      // all sides, so the square photo shrinks by exactly what the padding
      // adds and the measured cell height still fits.
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(
            color: AppColors.foreground.withValues(alpha: 0.22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: _heroTag == null
                        ? AppNetworkImage(url: gift.image)
                        : Hero(
                            tag: _heroTag!,
                            child: AppNetworkImage(url: gift.image),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: SaveGiftButton(giftId: gift.id),
                  ),
                  if (discount != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _Badge(label: '$discount% OFF'),
                    ),
                  if (gift.rewardPoints > 0)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: RewardPointsBadge(points: gift.rewardPoints),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: _textPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (gift.shopName != null)
                      Text(
                        gift.shopName!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _shopStyle,
                      ),
                    const SizedBox(height: _shopToNameGap),
                    // Flexible (not Spacer) absorbs the leftover space, so a
                    // long name ellipsizes instead of overflowing the card
                    // while the price row stays pinned to the bottom.
                    Flexible(
                      child: Text(
                        gift.name,
                        maxLines: _nameMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: _nameToPriceGap),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Prices stay on one line: a wrapped price both
                              // reads badly and makes the column taller than
                              // the measured cell height allows.
                              if (gift.compareAtLabel != null)
                                Text(
                                  gift.compareAtLabel!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _compareAtStyle,
                                ),
                              Text(
                                gift.priceLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _priceStyle,
                              ),
                            ],
                          ),
                        ),
                        _AddToCartButton(gift: gift),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddToCartButton extends ConsumerWidget {
  const _AddToCartButton({required this.gift});

  /// Kept in sync with GiftCard's height measurement.
  static const double size = GiftCard._addButtonSize;

  final Gift gift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inCart = ref
        .watch(cartProvider)
        .any((item) => item.giftId == gift.id);

    return GestureDetector(
      onTap: () {
        ref.read(cartProvider.notifier).add(gift.id);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('${gift.name} added to cart'),
              duration: const Duration(milliseconds: 1600),
              action: SnackBarAction(
                label: 'View cart',
                textColor: AppColors.accent,
                onPressed: () => context.push(AppRoutes.cart),
              ),
            ),
          );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: _AddToCartButton.size,
        width: _AddToCartButton.size,
        decoration: BoxDecoration(
          color: inCart ? AppColors.teal : AppColors.foreground,
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        ),
        child: Icon(
          inCart ? Icons.check_rounded : Icons.add_rounded,
          size: 18,
          color: inCart ? AppColors.foreground : AppColors.primaryForeground,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.purple,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
