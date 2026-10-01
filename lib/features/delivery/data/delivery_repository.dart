import 'dart:math';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/availability.dart';
import '../domain/delivery_intent.dart';
import '../domain/place.dart';

/// The public endpoints behind the gift search: the address lookup and the
/// zone check that says which gifts can reach that address in time. Neither
/// needs a sign-in, so a guest can search before making an account.
class DeliveryRepository {
  DeliveryRepository(this._client);

  final ApiClient _client;

  /// Groups keystrokes and the follow-up details call into one billed
  /// lookup session, the way the web does.
  static String newSessionToken() {
    final random = Random();
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
        '${random.nextInt(1 << 32).toRadixString(36)}';
  }

  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    String? sessionToken,
  }) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/places/autocomplete',
        queryParameters: {
          'input': trimmed,
          'language': 'en',
          'types': 'address',
          'session': ?sessionToken,
        },
      );
      final raw = response.data?['suggestions'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(PlaceSuggestion.fromJson)
          .where((suggestion) => suggestion.placeId.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  Future<PlaceDetails> placeDetails(
    String placeId, {
    String? sessionToken,
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/places/details',
        queryParameters: {
          'place_id': placeId,
          'language': 'en',
          'session': ?sessionToken,
        },
      );
      return PlaceDetails.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// Gifts a shop's delivery zones can bring to this point by [deliveryDate].
  /// Leave the date off for any day. An empty result is a real answer: no
  /// shop delivers there in time.
  Future<GiftAvailability> searchAvailability({
    required double latitude,
    required double longitude,
    DateTime? deliveryDate,
    String customerType = 'personal',
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/availability',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          if (deliveryDate != null)
            'delivery_date': DeliveryIntent.dateOnly(deliveryDate),
          'customer_type': customerType,
        },
      );
      return GiftAvailability.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }
}
