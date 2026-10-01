import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../delivery/data/delivery_providers.dart';
import '../../../delivery/presentation/widgets/gift_search_bar.dart';
import '../../data/catalog_providers.dart';
import '../../domain/gift_category.dart';
import '../widgets/gift_grid.dart';

/// Full catalog with search and occasion filters.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: ref.read(exploreQueryProvider));
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
    final byDelivery =
        ref.watch(deliveryIntentProvider)?.hasPoint ?? false;

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
                        const SizedBox(height: 6),
                        Text(
                          'Every published gift from our shops. Filter by '
                          'occasion or search by name, shop, or tag.',
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
                          onChanged: (value) => ref
                              .read(exploreQueryProvider.notifier)
                              .state = value,
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
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.gutter,
                      ),
                      children: [
                        SelectablePill(
                          label: 'All gifts',
                          selected: category == 'all',
                          onTap: () => ref
                              .read(exploreCategoryProvider.notifier)
                              .state = 'all',
                        ),
                        for (final item in GiftCategory.all)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: SelectablePill(
                              label: item.name,
                              selected: category == item.id,
                              onTap: () => ref
                                  .read(exploreCategoryProvider.notifier)
                                  .state = item.id,
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
                              ref.read(exploreQueryProvider.notifier).state = '';
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
                        child: Text(
                          '${gifts.length} gift${gifts.length == 1 ? '' : 's'}'
                          '${byDelivery ? ' that can be delivered there' : ''}'
                          '${query.isEmpty ? '' : ' matching “$query”'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    GiftGrid(gifts: gifts, sliver: true, heroPrefix: 'explore'),
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
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
