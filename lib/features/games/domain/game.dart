/// One playable game in the collection.
///
/// [config] is kept raw: its shape belongs to each game's engine, which parses
/// it the same way the backend does.
class Game {
  const Game({
    required this.slug,
    required this.name,
    required this.gameType,
    required this.version,
    required this.config,
    this.description,
    this.playCostPoints = 0,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    final rawConfig = json['config'];
    return Game(
      playCostPoints: (json['play_cost_points'] as num?)?.toInt() ?? 0,
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      gameType: json['game_type'] as String? ?? '',
      version: json['version'] as String? ?? '',
      config: rawConfig is Map<String, dynamic> ? rawConfig : const {},
    );
  }

  static List<Game> listFromJson(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Game.fromJson)
        .toList(growable: false);
  }

  final String slug;
  final String name;
  final String? description;
  final String gameType;
  final String version;
  final Map<String, dynamic> config;

  /// Points one play costs, taken on the server when the game starts.
  final int playCostPoints;
}

/// A play the server has opened. [seed] is what makes the board reproducible:
/// the app builds its game from it, and the backend replays the same one.
class GameSession {
  const GameSession({
    required this.sessionId,
    required this.gameSlug,
    required this.version,
    required this.mode,
    required this.seed,
    required this.config,
    required this.expiresAt,
    this.pointsCharged = 0,
    this.pointsBalance,
  });

  factory GameSession.fromJson(Map<String, dynamic> json) {
    final rawConfig = json['config'];
    return GameSession(
      pointsCharged: (json['points_charged'] as num?)?.toInt() ?? 0,
      pointsBalance: (json['points_balance'] as num?)?.toInt(),
      sessionId: json['session_id'] as String? ?? '',
      gameSlug: json['game_slug'] as String? ?? '',
      version: json['version'] as String? ?? '',
      mode: json['mode'] as String? ?? 'practice',
      seed: json['seed'] as String? ?? '0',
      config: rawConfig is Map<String, dynamic> ? rawConfig : const {},
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now().add(const Duration(hours: 1)),
    );
  }

  final String sessionId;
  final String gameSlug;
  final String version;
  final String mode;
  final String seed;
  final Map<String, dynamic> config;
  final DateTime expiresAt;

  /// What starting this play cost, and the balance it left.
  final int pointsCharged;
  final int? pointsBalance;
}

/// The outcome of a submitted game.
///
/// [score] is the server's own number, recomputed from the submitted moves.
/// not whatever the app had on screen. They match when everything is healthy.
class GameScoreResult {
  const GameScoreResult({
    required this.score,
    required this.movesCount,
    required this.won,
    required this.gameOver,
    required this.personalBest,
    required this.isPersonalBest,
    required this.accepted,
    this.stats = const {},
    this.competitionId,
    this.rank,
    this.attemptsRemaining,
  });

  factory GameScoreResult.fromJson(Map<String, dynamic> json) {
    final rawStats = json['stats'];
    return GameScoreResult(
      score: (json['score'] as num?)?.toInt() ?? 0,
      movesCount: (json['moves_count'] as num?)?.toInt() ?? 0,
      won: json['won'] as bool? ?? false,
      gameOver: json['game_over'] as bool? ?? false,
      personalBest: (json['personal_best'] as num?)?.toInt() ?? 0,
      isPersonalBest: json['is_personal_best'] as bool? ?? false,
      accepted: json['accepted'] as bool? ?? false,
      competitionId: json['competition_id'] as String?,
      rank: (json['rank'] as num?)?.toInt(),
      attemptsRemaining: (json['attempts_remaining'] as num?)?.toInt(),
      stats: rawStats is Map
          ? {
              for (final e in rawStats.entries)
                if (e.value is num) '${e.key}': (e.value as num).toInt(),
            }
          : const {},
    );
  }

  final int score;
  final int movesCount;
  final bool won;
  final bool gameOver;
  final int personalBest;
  final bool isPersonalBest;

  /// False when the server held the score for review, which happens when the
  /// submission looks tampered with or the app is out of date.
  final bool accepted;

  /// Game-specific details, e.g. `highest_tile` for 2048 or `length` for Snake.
  final Map<String, int> stats;

  /// Set only for official competition attempts.
  final String? competitionId;

  /// Where this player now stands on the competition board.
  final int? rank;
  final int? attemptsRemaining;

  bool get isOfficial => competitionId != null;
}

/// One row of a public board: rank, shortened name ("Sarah M."), country,
/// score and time. Players level on score and time share a rank.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.displayName,
    required this.score,
    this.countryCode,
    this.countryName,
    this.durationMs = 0,
    this.status = 'verified',
    this.isMe = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final country = json['country_name'] as String?;
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      displayName: json['display_name'] as String? ?? 'Player',
      score: (json['score'] as num?)?.toInt() ?? 0,
      countryCode: json['country_code'] as String?,
      countryName: country == null || country.isEmpty ? null : country,
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'verified',
      isMe: json['is_me'] as bool? ?? false,
    );
  }

  static List<LeaderboardEntry> listFromJson(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(LeaderboardEntry.fromJson)
        .toList(growable: false);
  }

  final int rank;
  final String displayName;
  final int score;
  final String? countryCode;
  final String? countryName;

  /// Server-measured play time, the tie-breaker. Lower is better.
  final int durationMs;

  /// provisional, verified or under_review.
  final String status;
  final bool isMe;

  bool get underReview => status == 'under_review';
}

/// The practice board plus this player's own row and best, when identified.
class Leaderboard {
  const Leaderboard({
    required this.entries,
    this.myBest,
    this.me,
    this.totalPlayers = 0,
  });

  factory Leaderboard.fromJson(Map<String, dynamic> json) {
    final rawMe = json['me'];
    return Leaderboard(
      entries: LeaderboardEntry.listFromJson(json['entries']),
      myBest: (json['my_best'] as num?)?.toInt(),
      me: rawMe is Map<String, dynamic>
          ? LeaderboardEntry.fromJson(rawMe)
          : null,
      totalPlayers: (json['total_players'] as num?)?.toInt() ?? 0,
    );
  }

  final List<LeaderboardEntry> entries;
  final int? myBest;

  /// This player's row, even when they rank outside [entries].
  final LeaderboardEntry? me;
  final int totalPlayers;
}
