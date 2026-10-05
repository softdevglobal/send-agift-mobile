import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import '../../auth/data/auth_controller.dart';
import '../domain/customer_order.dart';
import '../domain/received_gift.dart';

/// The signed-in customer's orders.
class OrdersRepository {
  OrdersRepository(this._client);

  final ApiClient _client;

  Future<List<CustomerOrder>> listOrders() async {
    try {
      final response = await _client.dio.get<dynamic>('/customers/me/orders');
      final data = response.data;
      if (data is! List) return const [];
      final orders = data
          .whereType<Map<String, dynamic>>()
          .map(CustomerOrder.fromJson)
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// Delivered gifts other customers sent to this one, newest first.
  Future<List<ReceivedGift>> listReceivedGifts() async {
    try {
      final response = await _client.dio.get<dynamic>(
        '/customers/me/received-gifts',
      );
      final data = response.data;
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(ReceivedGift.fromJson)
          .toList();
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// One order with its items — each item's id is what an order chat needs.
  Future<CustomerOrder> getOrder(String id) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/customers/me/orders/$id',
      );
      return CustomerOrder.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(apiClientProvider));
});

final customerOrdersProvider = FutureProvider.autoDispose<List<CustomerOrder>>((
  ref,
) async {
  final signedIn = ref.watch(authProvider.select((auth) => auth.isSignedIn));
  if (!signedIn) return const [];
  return ref.watch(ordersRepositoryProvider).listOrders();
});

final customerOrderProvider = FutureProvider.autoDispose
    .family<CustomerOrder, String>((ref, id) {
      return ref.watch(ordersRepositoryProvider).getOrder(id);
    });

final receivedGiftsProvider = FutureProvider.autoDispose<List<ReceivedGift>>((
  ref,
) async {
  final signedIn = ref.watch(authProvider.select((auth) => auth.isSignedIn));
  if (!signedIn) return const [];
  return ref.watch(ordersRepositoryProvider).listReceivedGifts();
});
