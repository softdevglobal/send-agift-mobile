import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/section_heading.dart';
import '../../../cart/data/cart_controller.dart';
import '../../../delivery/presentation/widgets/gift_search_bar.dart';
import '../../../products/data/catalog_providers.dart';
import '../../../products/domain/gift.dart';
import '../../../products/presentation/widgets/gift_card.dart';
import '../widgets/category_strip.dart';
import '../widgets/games_teaser.dart';
import '../widgets/feature_bar.dart';
import '../widgets/home_hero.dart';
import '../widgets/offer_banner.dart';
import '../widgets/testimonial_carousel.dart';

/// Storefront landing screen. Opens with no sign-in, exactly like the web.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(catalogProvider);
            await ref.read(catalogProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const _HomeTopBar(),
              // Where and when first, like the top of the web home page.
              // Find gifts opens Explore with only gifts that can get there.
              FadeSlideIn(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.gutter,
                    0,
                    AppTheme.gutter,
                    18,
                  ),
                  child: GiftSearchBar(
                    onSubmitted: () => context.go(AppRoutes.explore),
                  ),
                ),
              ),
              // The hero animates its own entrance in sequence, so it isn't
              // wrapped again here — everything after it cascades in behind.
              const HomeHero(),
              const FadeSlideIn(
                delay: Duration(milliseconds: 60),
                child: FeatureBar(),
              ),
              const SizedBox(height: 34),
              FadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: SectionHeading(
                  title: 'Shop by occasion',
                  actionLabel: 'View all',
                  onAction: () => context.go(AppRoutes.explore),
                ),
              ),
              const CategoryStrip(),
              const SizedBox(height: 34),
              FadeSlideIn(
                delay: const Duration(milliseconds: 180),
                child: SectionHeading(
                  title: 'Fresh from our shops',
                  subtitle: 'Published gifts, ready to send.',
                  actionLabel: 'View all',
                  onAction: () => context.go(AppRoutes.explore),
                ),
              ),
              _GiftShelf(catalog: catalog),
              const SizedBox(height: 34),
              const FadeSlideIn(
                delay: Duration(milliseconds: 220),
                child: GamesTeaser(),
              ),
              const SizedBox(height: 34),
              const FadeSlideIn(
                delay: Duration(milliseconds: 240),
                child: OfferBanner(),
              ),
              const SizedBox(height: 34),
              const FadeSlideIn(
                delay: Duration(milliseconds: 300),
                child: SectionHeading(title: 'What our customers say'),
              ),
              const TestimonialCarousel(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTopBar extends ConsumerWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        8,
        AppTheme.gutter,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandMark(size: 34),
              const SizedBox(width: 9),
              // The wordmark is drawn artwork, so it is shown as supplied
              // rather than re-set in a UI font.
              const BrandWordmark(height: 19),
              const Spacer(),
              // Cart isn't a tab — this is the one place it's always in
              // reach, opening as a panel over whatever's on screen.
              IconButton(
                onPressed: () => context.push(AppRoutes.cart),
                icon: Badge(
                  label: Text('$cartCount'),
                  isLabelVisible: cartCount > 0,
                  backgroundColor: AppColors.teal,
                  textColor: AppColors.tealForeground,
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
                color: AppColors.foreground,
                tooltip: 'Cart',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Read-only: tapping hands off to Explore, which owns the query.
          AppSearchField(
            readOnly: true,
            onTap: () => context.go(AppRoutes.explore),
          ),
        ],
      ),
    );
  }
}

/// Horizontal shelf of the newest published gifts.
class _GiftShelf extends StatelessWidget {
  const _GiftShelf({required this.catalog});

  final AsyncValue<List<Gift>> catalog;

  @override
  Widget build(BuildContext context) {
    return catalog.when(
      loading: () => const SizedBox(
        height: 300,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
        child: Text(
          "We couldn't load gifts just now. Pull to refresh.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      data: (gifts) {
        if (gifts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
            child: Text(
              'No gifts published yet. Shops publish from the seller portal, '
              'and they show up here.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        const cardWidth = 176.0;
        final shelf = gifts.take(6).toList();

        return SizedBox(
          // Same square-photo + text-block sizing the grid uses, so the shelf
          // never clips its cards either.
          height: cardWidth + GiftCard.textBlockHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
            itemCount: shelf.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => FadeSlideIn(
              delay: Duration(milliseconds: 45 * index),
              child: SizedBox(
                width: cardWidth,
                child: GiftCard(gift: shelf[index], heroPrefix: 'home'),
              ),
            ),
          ),
        );
      },
    );
  }
}
