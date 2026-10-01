import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
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
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.gutter,
                      10,
                      AppTheme.gutter,
                      14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('All gifts', style: AppTypography.display(28)),
                        const SizedBox(height: 4),
                        Text(
                          'Tell us where and when, and we only show gifts '
                          'that can get there.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
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
                            Flexible(
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
          gradient: selected
              ? const LinearGradient(colors: AppColors.brandGradient)
              : null,
          color: selected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image != null) ...[
              ClipOval(
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
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
