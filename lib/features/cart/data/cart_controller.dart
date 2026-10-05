import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../products/data/catalog_providers.dart';
import '../domain/cart_item.dart';
import 'cart_storage.dart';

final cartStorageProvider = Provider<CartStorage>((ref) => CartStorage());

/// Guest-first cart. Items live on the device until checkout, so browsing and
/// building a cart never require an account.
class CartController extends StateNotifier<List<CartItem>> {
  CartController(this._storage) : super(const []) {
    _restore();
  }

  final CartStorage _storage;

  /// Loads the saved cart. Reading storage is asynchronous, so a customer can
  /// tap "add to cart" before it lands. The restore must not then overwrite
  /// what they just added, so anything already in state wins and is merged
  /// back into storage.
  Future<void> _restore() async {
    final stored = await _storage.read();
    if (state.isEmpty) {
      state = stored;
      return;
    }

    final byId = {for (final item in stored) item.giftId: item};
    for (final item in state) {
      byId[item.giftId] = item;
    }
    final merged = byId.values.toList(growable: false);
    state = merged;
    await _storage.write(merged);
  }

  void add(String giftId, {int quantity = 1}) {
    final existing = state.where((item) => item.giftId == giftId).toList();
    if (existing.isEmpty) {
      _persist([...state, CartItem(giftId: giftId, quantity: quantity)]);
      return;
    }
    setQuantity(giftId, existing.first.quantity + quantity);
  }

  void setQuantity(String giftId, int quantity) {
    if (quantity <= 0) {
      remove(giftId);
      return;
    }
    _persist([
      for (final item in state)
        if (item.giftId == giftId) item.copyWith(quantity: quantity) else item,
    ]);
  }

  void remove(String giftId) {
    _persist(state.where((item) => item.giftId != giftId).toList());
  }

  void clear() => _persist(const []);

  bool contains(String giftId) => state.any((item) => item.giftId == giftId);

  void _persist(List<CartItem> next) {
    state = next;
    _storage.write(next);
  }
}

final cartProvider =
    StateNotifierProvider<CartController, List<CartItem>>((ref) {
  return CartController(ref.watch(cartStorageProvider));
});

/// Total number of units in the cart. Drives the bottom-nav badge.
final cartCountProvider = Provider<int>((ref) {
  return ref
      .watch(cartProvider)
      .fold<int>(0, (total, item) => total + item.quantity);
});

/// Cart entries joined with their catalog gifts. Items whose gift is no longer
/// published simply drop out of the list.
final cartLinesProvider = Provider<AsyncValue<List<CartLine>>>((ref) {
  final items = ref.watch(cartProvider);
  final catalog = ref.watch(catalogProvider);

  return catalog.whenData((gifts) {
    final byId = {for (final gift in gifts) gift.id: gift};
    return [
      for (final item in items)
        if (byId[item.giftId] case final gift?)
          CartLine(gift: gift, quantity: item.quantity),
    ];
  });
});

/// Cart money summary in minor units, using the first line's currency.
///
/// There is no delivery line: the API has no customer-facing rate endpoint,
/// and an order is created with delivery_amount = 0, so [total] is the
/// subtotal. Quoting a flat fee here would show a charge that is never made.
class CartSummary {
  const CartSummary({required this.subtotal, required this.currency});

  final int subtotal;
  final String currency;

  int get total => subtotal;
}

final cartSummaryProvider = Provider<CartSummary>((ref) {
  final lines = ref.watch(cartLinesProvider).valueOrNull ?? const [];
  if (lines.isEmpty) {
    return const CartSummary(subtotal: 0, currency: 'USD');
  }

  return CartSummary(
    subtotal: lines.fold<int>(0, (sum, line) => sum + line.lineTotalAmount),
    currency: lines.first.gift.currency,
  );
});
