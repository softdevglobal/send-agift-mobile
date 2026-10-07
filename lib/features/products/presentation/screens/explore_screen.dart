import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/storefront_decor.dart';
import '../../../delivery/data/delivery_providers.dart';
import '../../../delivery/presentation/widgets/gift_search_bar.dart';
import '../../data/catalog_providers.dart';
import '../../domain/gift.dart';
import '../../domain/gift_category.dart';
import '../widgets/gift_grid.dart';

enum _Sort { recommended, priceLow, priceHigh, rating, points }

const _sortLabels = {
  _Sort.recommended: 'Recommended',
  _Sort.priceLow: 'Lowest price',
  _Sort.priceHigh: 'Highest price',
  _Sort.rating: 'Top rated',
  _Sort.points: 'Most points',
};

/// Full catalog with search, occasion filters and sorting.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  late final TextEditingController _searchController;
  _Sort _sort = _Sort.recommended;

  List<Gift> _sorted(List<Gift> gifts) {
    if (_sort == _Sort.recommended) return gifts;
    return [...gifts]..sort(
      (a, b) => switch (_sort) {
        _Sort.priceLow => a.priceAmount.compareTo(b.priceAmount),
        _Sort.priceHigh => b.priceAmount.compareTo(a.priceAmount),
        _Sort.rating => b.rating.compareTo(a.rating),
        _Sort.points => b.rewardPoints.compareTo(a.rewardPoints),
        _Sort.recommended => 0,
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(exploreQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(filteredGiftsProvider);
    final category = ref.watch(exploreCategoryProvider);
    final query = ref.watch(exploreQueryProvider);
    // A picked address narrows the list to gifts that can reach it.
    final byDelivery = ref.watch(deliveryIntentProvider)?.hasPoint ?? false;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            if (byDelivery) {
              ref.invalidate(giftAvailabilityProvider);
              await ref.read(giftAvailabilityProvider.future);
              return;
            }
            ref.invalidate(catalogProvider);
            await ref.read(catalogProvider.future);
          },
          child: CustomScrollView(
            slivers: [
              // Runs edge to edge; the controls below sit in the gutter.
              SliverToBoxAdapter(
                child: FadeSlideIn(child: _ShopBanner(categoryId: category)),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.gutter,
                      16,
                      AppTheme.gutter,
                      14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The same search as home, so where and when can be
                        // changed without going back for them.
                        const GiftSearchBar(),
                        const SizedBox(height: 12),
                        const DeliveryIntentSummary(),
                        const SizedBox(height: 12),
                        AppSearchField(
                          controller: _searchController,
                          onChanged: (value) =>
                              ref.read(exploreQueryProvider.notifier).state =
                                  value,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 70),
                  child: SizedBox(
                    height: 46,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.gutter,
                      ),
                      children: [
                        _OccasionChip(
                          label: 'All gifts',
                          selected: category == 'all',
                          onTap: () =>
                              ref.read(exploreCategoryProvider.notifier).state =
                                  'all',
                        ),
                        for (final item in GiftCategory.all)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _OccasionChip(
                              label: item.name,
                              image: item.image,
                              selected: category == item.id,
                              onTap: () =>
                                  ref
                                      .read(exploreCategoryProvider.notifier)
                                      .state = item
                                      .id,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              ...results.when(
                loading: () => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                          if (byDelivery) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Checking which gifts can be delivered there…',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                error: (error, stack) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: byDelivery
                          ? "Couldn't check delivery there"
                          : "Couldn't load gifts",
                      description:
                          'Check your connection and pull down to try again.',
                    ),
                  ),
                ],
                data: (gifts) {
                  if (gifts.isEmpty && byDelivery) {
                    return [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.wrong_location_outlined,
                          title: 'No gifts can reach there in time',
                          description:
                              'No shop delivers to that address by that day. '
                              'Try a later day, or clear the search to see '
                              'every gift.',
                          action: ElevatedButton(
                            onPressed: () => ref
                                .read(deliveryIntentProvider.notifier)
                                .clear(),
                            child: const Text('Clear delivery search'),
                          ),
                        ),
                      ),
                    ];
                  }
                  if (gifts.isEmpty) {
                    return [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No gifts match that search',
                          description:
                              'Try a different name or occasion, or clear the '
                              'filters to see everything.',
                          action: ElevatedButton(
                            onPressed: () {
                              _searchController.clear();
                              ref.read(exploreQueryProvider.notifier).state =
                                  '';
                              ref.read(exploreCategoryProvider.notifier).state =
                                  'all';
                            },
                            child: const Text('Show all gifts'),
                          ),
                        ),
                      ),
                    ];
                  }

                  return [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.gutter,
                          16,
                          AppTheme.gutter,
                          12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${gifts.length} gift${gifts.length == 1 ? '' : 's'}'
                                '${byDelivery ? ' that can be delivered there' : ''}'
                                '${query.isEmpty ? '' : ' matching “$query”'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: _SortButton(
                                value: _sort,
                                onChanged: (value) =>
                                    setState(() => _sort = value),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GiftGrid(
                      gifts: _sorted(gifts),
                      sliver: true,
                      heroPrefix: 'explore',
                    ),
                    // Clears the floating tab bar.
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An occasion filter with its photo in a small circle.
class _OccasionChip extends StatelessWidget {
  const _OccasionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.image,
  });

  final String label;
  final String? image;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.fromLTRB(image == null ? 16 : 5, 5, 16, 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.foreground : AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 34,
                  width: 34,
                  child: AppNetworkImage(url: image!),
                ),
              ),
              const SizedBox(width: 8),
            ] else if (selected) ...[
              const Icon(Icons.apps_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? Colors.white : AppColors.foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.value, required this.onChanged});

  final _Sort value;
  final ValueChanged<_Sort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Sort>(
      key: const Key('explore-sort'),
      tooltip: 'Sort',
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final entry in _sortLabels.entries)
          PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.swap_vert_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _sortLabels[value]!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flat lilac banner naming what is on the shelf, with the occasion (or
/// "gifts") set on a violet marker block.
class _ShopBanner extends StatelessWidget {
  const _ShopBanner({required this.categoryId});

  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    String? name;
    for (final item in GiftCategory.all) {
      if (item.id == categoryId) name = item.name;
    }
    final headline = AppTypography.poster(32);

    return SizedBox(
      width: double.infinity,
      child: ColoredBox(
        color: AppColors.cream,
        child: Stack(
          children: [
            const Positioned(
              right: 22,
              top: 20,
              child: Sparkle(size: 24, color: AppColors.purple),
            ),
            const Positioned(
              right: 60,
              bottom: 22,
              child: Sparkle(size: 14, color: AppColors.teal),
            ),
            const Positioned(right: 64, top: 30, child: Dot(size: 8)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TagChip('The gift shop'),
                  const SizedBox(height: 14),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: name == null
                          ? [
                              Text('ALL ', style: headline),
                              Marker('GIFTS', style: headline),
                            ]
                          : [
                              Marker(name.toUpperCase(), style: headline),
                              Text(' GIFTS', style: headline),
                            ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tell us where and when, and we only show gifts that can '
                    'get there.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.foreground.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
