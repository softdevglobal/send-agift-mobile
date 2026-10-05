import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/competition.dart';
import '../domain/game.dart';
import 'guest_player_id.dart';

/// The skill-game collection.
///
/// Reading the catalog is public. Playing needs a player identity, which is
/// either the signed-in customer's bearer token. [ApiClient] attaches that on
/// its own. Or this device's guest id. Both are sent; the API prefers the
/// token, so signing in later does not cost anyone their identity mid-session.
class GamesRepository {
  GamesRepository(this._client);

  final ApiClient _client;

  /// Options carrying the device's guest id, so people can play signed out.
  Future<Options> _playerOptions() async {
    return Options(headers: {'X-Guest-Token': await GuestPlayerId.read()});
  }

  /// Every game the platform currently offers.
  Future<List<Game>> listGames() => _guard(() async {
    final response = await _client.dio.get<dynamic>('/games');
    return Game.listFromJson(_map(response.data)['items']);
  });

  /// One game and the rules its current version runs.
  Future<Game> getGame(String slug) => _guard(() async {
    final response = await _client.dio.get<dynamic>('/games/$slug');
    return Game.fromJson(_map(response.data));
  });

  /// Opens a play and returns the server-issued seed.
  ///
  /// The seed comes from the backend so a player cannot restart until they are
  /// dealt an easy board, and so the same game can be replayed at scoring time.
  ///
  /// [level] asks for a harder board on games with level progression (only
  /// Memory Match, currently). The server scales the config and bakes it
  /// into the session, so it plays back exactly as dealt regardless of level.
  Future<GameSession> startSession(String slug, {int level = 1}) =>
      _guard(() async {
        final response = await _client.dio.post<dynamic>(
          '/games/$slug/sessions',
          queryParameters: level > 1 ? {'level': level} : null,
          options: await _playerOptions(),
        );
        return GameSession.fromJson(_map(response.data));
      });

  /// Submits the moves that were played and returns the server's score.
  ///
  /// [clientScore] is what the app had on screen. It is sent only so the
  /// backend can spot a disagreement. The score that counts is the one the
  /// server computes by replaying [moves] itself. Null for a game whose score
  /// only the server can know (the quiz).
  Future<GameScoreResult> submitScore(
    String sessionId, {
    required List<String> moves,
    required int? clientScore,
  }) => _guard(() async {
    final response = await _client.dio.post<dynamic>(
      '/games/sessions/$sessionId/submit',
      data: {'moves': moves, 'client_score': ?clientScore},
      options: await _playerOptions(),
    );
    return GameScoreResult.fromJson(_map(response.data));
  });

  /// The public board, plus this customer's best when they are signed in.
  Future<Leaderboard> leaderboard(String slug, {int limit = 20}) =>
      _guard(() async {
        final response = await _client.dio.get<dynamic>(
          '/games/$slug/leaderboard',
          queryParameters: {'limit': limit},
          // Identity is optional here; it only adds this player's own best.
          options: await _playerOptions(),
        );
        return Leaderboard.fromJson(_map(response.data));
      });

  // ─── Competitions ───────────────────────────────────────────────────────
  // Browsing is public; the signed-in customer's bearer token (attached by
  // [ApiClient]) adds their attempts, eligibility and rank. Entering and
  // claiming need a signed-in, verified customer.

  /// Published competitions. The customer's own country when signed in.
  Future<List<Competition>> listCompetitions() => _guard(() async {
    final response = await _client.dio.get<dynamic>('/competitions');
    return Competition.listFromJson(_map(response.data)['items']);
  });

  /// One competition with its rules, prize, disclosures and winners.
  Future<Competition> getCompetition(String id) => _guard(() async {
    final response = await _client.dio.get<dynamic>('/competitions/$id');
    return Competition.fromJson(_map(response.data));
  });

  /// The live board, plus this customer's own row.
  Future<CompetitionLeaderboard> competitionLeaderboard(
    String id, {
    int limit = 50,
  }) => _guard(() async {
    final response = await _client.dio.get<dynamic>(
      '/competitions/$id/leaderboard',
      queryParameters: {'limit': limit},
    );
    return CompetitionLeaderboard.fromJson(_map(response.data));
  });

  /// A fresh idempotency key for one intended play.
  static String newPlayKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Plays once: spends the round's points, grows its prize and opens the
  /// official session, all in one server transaction. Its score is submitted
  /// through [submitScore] like any other game.
  ///
  /// [playKey] identifies this one intended play. Retrying with the same key
  /// (after a timeout, say) returns the original play and never charges
  /// twice, so a caller keeps the key until the play has come back.
  Future<AttemptStart> startAttempt(
    String competitionId, {
    required String playKey,
  }) => _guard(() async {
    final response = await _client.dio.post<dynamic>(
      '/competitions/$competitionId/plays',
      data: {'client_request_id': playKey},
      options: Options(
        headers: {
          'Idempotency-Key': playKey,
          // This install's id and platform, for the per-device play limit
          // and the fraud signals (several accounts on one device).
          'X-Device-Id': await GuestPlayerId.read(),
          'X-App-Platform': defaultTargetPlatform.name,
        },
      ),
    );
    return AttemptStart.fromJson(_map(response.data));
  });

  /// How the signed-in customer earns points in their country.
  Future<PointsEarningRule> pointsEarningRule() => _guard(() async {
    final response = await _client.dio.get<dynamic>(
      '/customers/me/points/earning',
    );
    return PointsEarningRule.fromJson(_map(response.data));
  });

  /// The signed-in customer's points balance and history.
  Future<PointsWallet> pointsWallet() => _guard(() async {
    final response = await _client.dio.get<dynamic>('/customers/me/points');
    return PointsWallet.fromJson(_map(response.data));
  });

  /// The round's live prize, as it changes (Server-Sent Events).
  ///
  /// A dropped connection is retried with a growing pause; screens still
  /// re-read the round now and then, because the stream is only a display
  /// optimisation.
  Stream<LivePrize> livePrize(String competitionId) async* {
    var backoff = const Duration(seconds: 2);
    while (true) {
      try {
        final response = await _client.dio.get<ResponseBody>(
          '/competitions/$competitionId/events',
          options: Options(
            responseType: ResponseType.stream,
            headers: {'Accept': 'text/event-stream'},
            // The server sends a keep-alive every 15 seconds.
            receiveTimeout: const Duration(seconds: 45),
          ),
        );
        final body = response.data;
        if (body == null) return;
        backoff = const Duration(seconds: 2);
        var data = StringBuffer();
        await for (final line
            in body.stream
                .cast<List<int>>()
                .transform(utf8.decoder)
                .transform(const LineSplitter())) {
          if (line.startsWith('data:')) {
            data.write(line.substring(5).trim());
          } else if (line.isEmpty && data.isNotEmpty) {
            final raw = data.toString();
            data = StringBuffer();
            try {
              final decoded = jsonDecode(raw);
              if (decoded is Map<String, dynamic> &&
                  decoded['current_prize_cents'] is num) {
                yield LivePrize.fromJson(decoded);
              }
            } on FormatException {
              // A garbled event is skipped; the next one carries the state.
            }
          }
        }
      } on DioException catch (error) {
        // A round that is gone or not published will not come back.
        final status = error.response?.statusCode;
        if (status == 404 || status == 401) return;
      }
      await Future<void>.delayed(backoff);
      if (backoff < const Duration(seconds: 30)) backoff *= 2;
    }
  }

  /// The signed-in customer's saved addresses, for prize delivery.
  Future<List<DeliveryAddress>> deliveryAddresses() => _guard(() async {
    final response = await _client.dio.get<dynamic>('/customers/me');
    return DeliveryAddress.listFromJson(_map(response.data)['addresses']);
  });

  /// A winner accepts the prize terms and picks a delivery address.
  Future<void> claimPrize(String competitionId, {required String addressId}) =>
      _guard(() async {
        await _client.dio.post<dynamic>(
          '/competitions/$competitionId/claim',
          data: {'address_id': addressId, 'accept_terms': true},
        );
      });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  static Map<String, dynamic> _map(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    throw const AppException('Unexpected response from the server.');
  }
}
