import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import '../../auth/data/auth_controller.dart';
import '../../delivery/domain/delivery_intent.dart';
import '../domain/free_gift.dart';

/// The customer side of the free gift program, the same endpoints the web's
/// free gift page uses.
class FreeGiftRepository {
  FreeGiftRepository(this._client);

  final ApiClient _client;

  /// The code the server answers with while the program is switched off.
  static const disabledCode = 'FREE_GIFT_DISABLED';

  static bool isDisabled(Object error) =>
      error is AppException && error.code == disabledCode;

  /// One key per confirm screen, so a retry or a double tap is one order.
  static String newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Gifts that can be sent free right now. With a map point only those a
  /// shop can deliver there; with a day only those that can arrive by then.
  /// Public: a guest sees the same list.
  Future<List<FreeGiftOffer>> listOffers({
    double? latitude,
    double? longitude,
    DateTime? deliveryDate,
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/free-gifts/products',
        queryParameters: {
          if (latitude != null && longitude != null) ...{
            'latitude': latitude,
            'longitude': longitude,
          },
          if (deliveryDate != null)
            'delivery_date': DeliveryIntent.dateOnly(deliveryDate),
        },
      );
      final raw = response.data?['items'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(FreeGiftOffer.fromJson)
          .where((offer) => offer.productId.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// Whether the customer still has their free gift, and, with
  /// [recipientId], whether that person can receive one.
  Future<FreeGiftStatus> status({String? recipientId}) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/customers/me/free-gift',
        queryParameters: {
          if (recipientId != null && recipientId.isNotEmpty)
            'recipient_id': recipientId,
        },
      );
      return FreeGiftStatus.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// Sends the free gift and creates its order. There is no price and no
  /// quantity: the server reads the price, and it is always one.
  Future<SentFreeGift> send({
    required String productId,
    required String recipientId,
    required String countryId,
    required DateTime deliveryDate,
    required String idempotencyKey,
    String? giftMessage,
  }) async {
    final note = giftMessage?.trim() ?? '';
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/customers/me/free-gifts',
        data: {
          'product_id': productId,
          'recipient_id': recipientId,
          'country_id': countryId,
          'delivery_date': DeliveryIntent.dateOnly(deliveryDate),
          if (note.isNotEmpty) 'gift_message': note,
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return SentFreeGift.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }
}

final freeGiftRepositoryProvider = Provider<FreeGiftRepository>((ref) {
  return FreeGiftRepository(ref.watch(apiClientProvider));
});

/// The signed-in customer's free gift, or null for a guest. Kept for the
/// whole session so the home banner and account row do not refetch.
final freeGiftStatusProvider = FutureProvider<FreeGiftStatus?>((ref) async {
  final signedIn = ref.watch(authProvider.select((auth) => auth.isSignedIn));
  if (!signedIn) return null;
  return ref.watch(freeGiftRepositoryProvider).status();
});

/// Whether anything can be sent free at all. False while the program is off
/// or no seller has a gift in it, which hides the entry points.
final freeGiftOnOfferProvider = FutureProvider<bool>((ref) async {
  try {
    final offers = await ref.watch(freeGiftRepositoryProvider).listOffers();
    return offers.isNotEmpty;
  } on AppException {
    return false;
  }
});
