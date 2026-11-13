import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/section_tag.dart';
import '../../data/catalog_providers.dart';
import '../../domain/gift.dart';
import '../../domain/shop.dart';
import '../widgets/gift_grid.dart';

/// A shop's own page, opened from a gift: who runs it, where it is, and
/// every gift it sells.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(shopPageProvider(shopId));
    return Scaffold(
      body: page.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            _Missing(onRetry: () => ref.invalidate(shopPageProvider(shopId))),
        data: (value) {
          if (value == null) {
            return _Missing(
              onRetry: () => ref.invalidate(shopPageProvider(shopId)),
            );
          }
          final (shop, gifts) = value;
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.refresh(shopPageProvider(shopId).future),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _ShopHeader(shop: shop, count: gifts.length),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.gutter,
                    22,
                    AppTheme.gutter,
                    12,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SectionTag(
                      label: gifts.isEmpty
                          ? 'Gifts'
                          : '${gifts.length} ${gifts.length == 1 ? 'gift' : 'gifts'}',
                      icon: Icons.card_giftcard_rounded,
                      color: AppColors.purple,
                    ),
                  ),
                ),
                if (gifts.isEmpty)
                  const SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Nothing on sale yet',
                      description: 'This shop has not published a gift yet.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.gutter,
                      0,
                      AppTheme.gutter,
                      32,
                    ),
                    sliver: GiftGrid(
                      gifts: _sponsoredFirst(gifts),
                      sliver: true,
                      heroPrefix: 'shop',
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Promoted gifts lead, as everywhere else in the app.
  static List<Gift> _sponsoredFirst(List<Gift> gifts) => [
    ...gifts.where((g) => g.sponsored),
    ...gifts.where((g) => !g.sponsored),
  ];
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.shop, required this.count});

  final Shop shop;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final photo = shop.sellerImageUrl ?? shop.imageUrl;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A flat brand band, with room for the photo to overlap it.
            Container(height: 150 + top, color: AppColors.purple),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                58,
                AppTheme.gutter,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          shop.name,
                          style: AppTypography.poster(28),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (shop.verified) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.verified_rounded,
                          size: 22,
                          color: AppColors.teal,
                        ),
                      ],
                    ],
                  ),
                  if (shop.location != null &&
                      shop.location!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: AppColors.mutedForeground,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            shop.location!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (shop.description != null &&
                      shop.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      shop.description!.trim(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.foreground.withValues(alpha: 0.78),
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (shop.categories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in shop.categories)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              _label(c),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentForeground,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        // The seller's photo, straddling the band.
        Positioned(
          left: AppTheme.gutter,
          top: 150 + top - 46,
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 4),
            ),
            clipBehavior: Clip.antiAlias,
            child: photo != null
                ? AppNetworkImage(url: photo)
                : const Icon(
                    Icons.storefront_rounded,
                    size: 36,
                    color: AppColors.primary,
                  ),
          ),
        ),
        Positioned(
          left: 12,
          top: top + 8,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/'),
            ),
          ),
        ),
      ],
    );
  }

  /// "flowers-plants" → "Flowers plants".
  static String _label(String raw) {
    final words = raw.replaceAll(RegExp(r'[-_]+'), ' ').trim();
    if (words.isEmpty) return raw;
    return words[0].toUpperCase() + words.substring(1);
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: EmptyState(
          icon: Icons.storefront_outlined,
          title: 'Shop not found',
          description: 'It may have closed, or the connection dropped.',
          action: FilledButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ),
      ),
    );
  }
}
