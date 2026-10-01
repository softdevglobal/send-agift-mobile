import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/providers.dart';
import '../../products/domain/gift.dart';
import '../domain/availability.dart';
import '../domain/delivery_intent.dart';
import 'delivery_repository.dart';

final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  return DeliveryRepository(ref.watch(apiClientProvider));
});

/// Remembers the gift search across launches, like the web keeps it in
/// local storage. Storage failing only costs the shopper that convenience.
class DeliveryIntentController extends StateNotifier<DeliveryIntent?> {
  DeliveryIntentController({bool restore = true}) : super(null) {
    if (restore) _restore();
  }

  static const _key = 'delivery_intent_v1';

  /// Set once a search was made in this session, so a slow restore never
  /// overwrites what the shopper just picked.
  bool _touched = false;

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || _touched) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final intent = DeliveryIntent.fromJson(decoded);
      state = _fresh(intent);
    } catch (_) {
      // Unreadable or missing: start with no remembered search.
    }
  }

  /// A remembered day that has already passed is no longer a request anyone
  /// can meet, so it is dropped and the address kept.
  static DeliveryIntent? _fresh(DeliveryIntent intent) {
    final date = intent.date;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next = date != null && date.isBefore(today)
        ? intent.withDate(null)
        : intent;
    return next.isEmpty ? null : next;
  }

  void set(DeliveryIntent? next) {
    _touched = true;
    state = next == null || next.isEmpty ? null : next;
    _persist();
  }

  void clear() => set(null);

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final intent = state;
      if (intent == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, jsonEncode(intent.toJson()));
      }
    } catch (_) {
      // Not saved for next launch; this session still has it.
    }
  }
}

final deliveryIntentProvider =
    StateNotifierProvider<DeliveryIntentController, DeliveryIntent?>((ref) {
      return DeliveryIntentController();
    });

/// The zone check for the remembered address and day. Null when no picked
/// place is remembered, which means the whole catalog is shown instead.
final giftAvailabilityProvider = FutureProvider<GiftAvailability?>((ref) {
  final intent = ref.watch(deliveryIntentProvider);
  final latitude = intent?.latitude;
  final longitude = intent?.longitude;
  if (latitude == null || longitude == null) return Future.value(null);
  return ref
      .watch(deliveryRepositoryProvider)
      .searchAvailability(
        latitude: latitude,
        longitude: longitude,
        deliveryDate: intent?.date,
      );
});

/// Gifts that can reach the remembered address in time, or null when there
/// is no address to check against.
final deliverableGiftsProvider = Provider<AsyncValue<List<Gift>?>>((ref) {
  return ref
      .watch(giftAvailabilityProvider)
      .whenData((availability) => availability?.gifts);
});
