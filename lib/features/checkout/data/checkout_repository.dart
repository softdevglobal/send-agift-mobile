import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import '../../auth/data/auth_controller.dart';
import '../../cart/domain/cart_item.dart';
import '../domain/checkout.dart';

/// Recipients, delivery pricing and order placement.
class CheckoutRepository {
  CheckoutRepository(this._client);

  final ApiClient _client;

  /// Saved recipients. Names only — addresses come from [getRecipient].
  Future<List<Recipient>> listRecipients() async {
    try {
      final response = await _client.dio.get<dynamic>(
        '/customers/me/recipients',
      );
      final data = response.data;
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(Recipient.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// One recipient with their addresses.
  Future<Recipient> getRecipient(String id) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/customers/me/recipients/$id',
      );
      return Recipient.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// Saves someone new to send gifts to, with the one address the gift goes
  /// to. Its map point is what shop delivery zones are priced against, so it
  /// is sent whenever the address was picked from the lookup.
  Future<Recipient> createRecipient({
    required String name,
    required String countryId,
    required String line1,
    required String city,
    String? email,
    String? phone,
    String? line2,
    String? region,
    String? postalCode,
    double? latitude,
    double? longitude,
    String? label,
    String addressType = 'shipping',
    bool isDefault = true,
  }) async {
    String? optional(String? value) =>
        value == null || value.trim().isEmpty ? null : value.trim();
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/customers/me/recipients',
        data: {
          'name': name.trim(),
          'email': optional(email),
          'phone': optional(phone),
          'addresses': [
            {
              'country_id': countryId,
              'label': optional(label),
              'address_type': optional(addressType) ?? 'shipping',
              'line1': line1.trim(),
              'line2': optional(line2),
              'city': city.trim(),
              'region': optional(region),
              'postal_code': optional(postalCode),
              'latitude': latitude,
              'longitude': longitude,
              'is_default': isDefault,
            },
          ],
        },
      );
      return Recipient.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// Prices delivery before the order exists, from each shop's own delivery
  /// zones and the distance to the recipient's address.
  Future<DeliveryQuote> quoteDelivery({
    required String recipientId,
    required DateTime deliveryDate,
    required List<CartLine> lines,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/customers/me/shipping/quote',
        data: {
          'recipient_id': recipientId,
          'delivery_date': _dateOnly(deliveryDate),
          'items': [
            for (final line in lines)
              {'product_id': line.gift.id, 'quantity': line.quantity},
          ],
        },
      );
      return DeliveryQuote.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// Places the order. A recipient is required: the server prices delivery
  /// from each shop's zones to their address, and ignores any amount the app
  /// could send.
  Future<String> placeOrder({
    required String countryId,
    required DateTime deliveryDate,
    required List<CartLine> lines,
    required String recipientId,
    String? giftMessage,
    int giftPoints = 0,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/customers/me/orders',
        data: {
          'country_id': countryId,
          'customer_type': 'personal',
          'delivery_date': _dateOnly(deliveryDate),
          'recipient_id': recipientId,
          if (giftMessage != null && giftMessage.trim().isNotEmpty)
            'gift_message': giftMessage.trim(),
          // Points from the customer's own balance, sent with the gift. The
          // server checks the balance and the recipient's email.
          if (giftPoints > 0) 'gift_points': giftPoints,
          'items': [
            for (final line in lines)
              {'product_id': line.gift.id, 'quantity': line.quantity},
          ],
        },
      );
      return response.data?['id'] as String? ?? '';
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// The customer's own country, used as the order's country when a recipient
  /// address does not supply one.
  Future<String> myCountryId() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/customers/me',
      );
      return response.data?['country_id'] as String? ?? '';
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return CheckoutRepository(ref.watch(apiClientProvider));
});

final recipientsProvider = FutureProvider.autoDispose<List<Recipient>>((
  ref,
) async {
  final signedIn = ref.watch(authProvider.select((auth) => auth.isSignedIn));
  if (!signedIn) return const [];
  return ref.watch(checkoutRepositoryProvider).listRecipients();
});

/// One recipient with addresses, fetched once someone is actually picked.
final recipientDetailsProvider = FutureProvider.autoDispose
    .family<Recipient, String>((ref, id) {
      return ref.watch(checkoutRepositoryProvider).getRecipient(id);
    });
