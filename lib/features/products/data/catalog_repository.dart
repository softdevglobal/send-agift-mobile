import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/gift.dart';
import '../domain/shop.dart';
import 'sample_gifts.dart';

/// Reads the public marketplace: every active shop and its published products.
///
/// These endpoints are unauthenticated, which is what lets the app open
/// straight into a browsable catalog with no sign-in.
class CatalogRepository {
  CatalogRepository(this._client);

  final ApiClient _client;

  static const Duration _cacheTtl = Duration(seconds: 30);

  List<Gift>? _cache;
  DateTime? _cachedAt;

  bool get _cacheIsFresh =>
      _cache != null &&
      _cachedAt != null &&
      DateTime.now().difference(_cachedAt!) < _cacheTtl;

  /// Loads the marketplace catalog. Falls back to [sampleGifts] when the
  /// backend is unreachable or no shop has published yet, so the storefront
  /// never renders empty on a cold start.
  Future<List<Gift>> loadCatalog({bool forceRefresh = false}) async {
    if (!forceRefresh && _cacheIsFresh) return _cache!;

    try {
      final shops = await _fetchShops();
      final gifts = <Gift>[];

      final results = await Future.wait(
        shops.map((shop) => _fetchShopProducts(shop)),
      );
      for (final products in results) {
        gifts.addAll(products);
      }

      // A successful-but-empty response is real information: no shop has
      // published yet. Substituting samples there would hide the true state of
      // the catalog, so only an unreachable backend falls back.
      _cache = gifts;
      _cachedAt = DateTime.now();
      return gifts;
    } on DioException {
      // The backend is unreachable. Show the clearly-placeholder sample shelf
      // rather than an empty app.
      _cache = sampleGifts;
      _cachedAt = DateTime.now();
      return sampleGifts;
    }
  }

  /// Resolves one product for a detail screen.
  ///
  /// The catalog usually already holds it. Detail screens are opened from a
  /// list. A reel is the exception: it links straight to a product that may
  /// not be on the loaded shelf, so a miss falls through to the public
  /// product endpoint rather than showing "gift not found".
  Future<Gift?> giftById(String id) async {
    final catalog = await loadCatalog();
    for (final gift in catalog) {
      if (gift.id == id) return gift;
    }
    return _fetchPublicProduct(id);
  }

  Future<Gift?> _fetchPublicProduct(String id) async {
    try {
      final response = await _client.dio.get<dynamic>('/products/$id');
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;

      // The public product carries its shop inline, which is what the detail
      // screen shows as the seller line.
      final shopJson = data['shop'];
      final shop = shopJson is Map<String, dynamic> ? Shop.fromJson(shopJson) : null;
      return Gift.fromJson(data, shop: shop);
    } on DioException {
      return null;
    }
  }

  Future<List<Shop>> _fetchShops() async {
    final response = await _client.dio.get<dynamic>('/shops');
    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Shop.fromJson)
        .toList(growable: false);
  }

  Future<List<Gift>> _fetchShopProducts(
    Shop shop, {
    String customerType = 'personal',
  }) async {
    try {
      final response = await _client.dio.get<dynamic>(
        '/shops/${shop.id}/products',
        queryParameters: {'customer_type': customerType},
      );
      final data = response.data;
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map((json) => Gift.fromJson(json, shop: shop))
          .toList(growable: false);
    } on DioException {
      // One failing shop should not empty the whole shelf.
      return const [];
    }
  }
}
