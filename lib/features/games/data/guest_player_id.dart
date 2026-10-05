import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A stable per-device id so people can play without an account.
///
/// The API identifies a player by either a customer bearer token or an
/// `X-Guest-Token`, and it prefers the token when both are sent. So this id is
/// simply always attached: signed-in players are still recorded as themselves,
/// and everyone else keeps their scores and personal best on this device.
///
/// It is not a security boundary. It only decides whose score is whose. The
/// server still validates every round on its own.
class GuestPlayerId {
  GuestPlayerId._();

  static const String _key = 'games_guest_token_v1';

  static String? _cached;

  /// Reads the device's id, creating one on first play.
  static Future<String> read() async {
    final cached = _cached;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }

    final created = _randomUuidV4();
    await prefs.setString(_key, created);
    _cached = created;
    return created;
  }

  /// A random v4 UUID, which is the format the API requires.
  ///
  /// Hand-rolled rather than pulling in a package for one call.
  static String _randomUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Version 4 and the RFC 4122 variant bits.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}
