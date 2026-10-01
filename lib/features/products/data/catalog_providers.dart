import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';
import '../../delivery/data/delivery_providers.dart';
import '../domain/gift.dart';
import 'catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(apiClientProvider));
});

/// The full marketplace catalog, shared by home, explore and detail screens.
final catalogProvider = FutureProvider<List<Gift>>((ref) {
  return ref.watch(catalogRepositoryProvider).loadCatalog();
});

/// Looks a gift up for a detail screen. The loaded catalog answers this in the
/// normal case; a product reached from a reel may not be on it, so the
/// repository falls back to the public product endpoint.
final giftByIdProvider = FutureProvider.family<Gift?, String>((ref, id) {
  return ref.watch(catalogRepositoryProvider).giftById(id);
});

/// Active search text on the explore screen.
final exploreQueryProvider = StateProvider<String>((ref) => '');

/// Active category filter on the explore screen; `all` means unfiltered.
final exploreCategoryProvider = StateProvider<String>((ref) => 'all');

/// Catalog narrowed by the current query and category filters.
///
/// A picked delivery address owns the shelf: only gifts a shop's delivery
/// zones can bring there in time are listed, the same as the web.
final filteredGiftsProvider = Provider<AsyncValue<List<Gift>>>((ref) {
  final deliverable = ref.watch(deliverableGiftsProvider);
  final catalog = switch (deliverable) {
    AsyncData(value: final gifts?) => AsyncValue.data(gifts),
    AsyncData() => ref.watch(catalogProvider),
    AsyncError(:final error, :final stackTrace) =>
      AsyncValue<List<Gift>>.error(error, stackTrace),
    _ => const AsyncValue<List<Gift>>.loading(),
  };
  final query = ref.watch(exploreQueryProvider);
  final category = ref.watch(exploreCategoryProvider);

  return catalog.whenData((gifts) {
    return gifts.where((gift) {
      final matchesCategory = category == 'all' || gift.categoryId == category;
      return matchesCategory && gift.matchesQuery(query);
    }).toList(growable: false);
  });
});
