import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import '../../auth/data/auth_controller.dart';
import '../domain/membership.dart';

/// The customer side of memberships, the same endpoints the website uses.
class MembershipRepository {
  MembershipRepository(this._client);

  final ApiClient _client;

  /// One key per attempt to join, so a double tap is one checkout.
  static String newRequestKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return 'join-${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// The packages on sale where the customer lives, and whether they can join.
  Future<MembershipOffers> offers() => _guard(() async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/customers/me/membership/offers',
    );
    return MembershipOffers.fromJson(response.data ?? const {});
  });

  /// The customer's membership. While a payment is still being confirmed the
  /// server checks with the payment provider first.
  Future<MembershipStatus> status() => _guard(() async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/customers/me/membership',
    );
    return MembershipStatus.fromJson(response.data ?? const {});
  });

  /// Starts a checkout for [offerId]; returns where to pay.
  Future<MembershipCheckout> join({
    required String offerId,
    required bool renewalConsent,
    required String idempotencyKey,
  }) => _guard(() async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/customers/me/membership/checkout',
      data: {'offer_id': offerId, 'renewal_consent': renewalConsent},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return MembershipCheckout.fromJson(response.data ?? const {});
  });

  /// Stops renewal; benefits continue to the end of the period paid for.
  Future<MembershipStatus> cancel() => _guard(() async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/customers/me/membership/cancel',
    );
    return MembershipStatus.fromJson(response.data ?? const {});
  });

  /// Sandbox only: confirms a test membership payment.
  Future<MembershipStatus> confirmTestPayment() => _guard(() async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/customers/me/membership/test-payment',
    );
    return MembershipStatus.fromJson(response.data ?? const {});
  });

  /// The percentage off gifts the customer gets on a new order now, in basis
  /// points (100 = 1%). The server prices every order; this only previews it.
  Future<int> memberDiscountBps() => _guard(() async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/customers/me/member-discount',
    );
    final bps = response.data?['discount_bps'];
    return bps is num ? bps.toInt() : 0;
  });
}

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  return MembershipRepository(ref.watch(apiClientProvider));
});

final membershipOffersProvider = FutureProvider.autoDispose<MembershipOffers>(
  (ref) => ref.watch(membershipRepositoryProvider).offers(),
);

/// The signed-in customer's membership, or null for a guest.
final membershipStatusProvider = FutureProvider.autoDispose<MembershipStatus?>((
  ref,
) async {
  final signedIn = ref.watch(authProvider.select((a) => a.isSignedIn));
  if (!signedIn) return null;
  return ref.watch(membershipRepositoryProvider).status();
});

/// The member discount on a new order now; 0 for guests, non-members and
/// when it cannot be read. Kept alive for the cart, which reads it on every
/// change; joining or cancelling invalidates it.
final memberDiscountBpsProvider = FutureProvider<int>((ref) async {
  final signedIn = ref.watch(authProvider.select((a) => a.isSignedIn));
  if (!signedIn) return 0;
  try {
    return await ref.watch(membershipRepositoryProvider).memberDiscountBps();
  } catch (_) {
    return 0;
  }
});

/// A member's saving on a bag, worked out as the server does: on each line's
/// price in minor units, rounded down.
int memberDiscountMinor(Iterable<int> lineTotalsMinor, int bps) {
  if (bps <= 0) return 0;
  return lineTotalsMinor.fold(0, (sum, line) => sum + (line * bps) ~/ 10000);
}
