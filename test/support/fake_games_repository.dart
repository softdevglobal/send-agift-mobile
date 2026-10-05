import 'package:send_agift_mobile/core/errors/app_exception.dart';
import 'package:send_agift_mobile/features/games/data/games_repository.dart';
import 'package:send_agift_mobile/features/games/domain/competition.dart';
import 'package:send_agift_mobile/features/games/domain/game.dart';

/// Stands in for the API so game screens can be driven without a backend.
class FakeGamesRepository implements GamesRepository {
  FakeGamesRepository({this.seed = 'cafebabe'});

  /// Fixed so every board. And which moves do something. Is predictable.
  final String seed;

  int startCount = 0;
  final List<int> startLevels = [];
  final List<List<String>> submissions = [];

  List<String>? get lastMoves => submissions.isEmpty ? null : submissions.last;

  static const games = [
    Game(
      slug: '2048',
      name: '2048',
      gameType: 'puzzle',
      version: '1.0.0',
      config: {},
    ),
    Game(
      slug: 'snake',
      name: 'Snake',
      gameType: 'timing',
      version: '1.0.0',
      config: {},
    ),
    Game(
      slug: 'slide-puzzle',
      name: 'Slide Puzzle',
      gameType: 'puzzle',
      version: '1.0.0',
      config: {},
    ),
    // The rest of the catalog, so a screen test lays out every tile and every
    // piece of artwork rather than only the first three.
    Game(
      slug: 'basketball',
      name: 'Basketball',
      gameType: 'precision',
      version: '1.0.0',
      config: {},
    ),
    Game(
      slug: 'stack-tower',
      name: 'Stack Tower',
      gameType: 'timing',
      version: '1.0.0',
      config: {},
    ),
    Game(
      slug: 'archery',
      name: 'Archery',
      gameType: 'precision',
      version: '1.0.0',
      config: {},
    ),
    Game(
      slug: 'cricket',
      name: 'Cricket',
      gameType: 'timing',
      version: '1.0.0',
      config: {},
    ),
    Game(
      slug: 'block-blast',
      name: 'Block Blast',
      gameType: 'puzzle',
      version: '1.0.0',
      config: {},
    ),
    Game(
      slug: 'sling-shot',
      name: 'Sling Shot',
      gameType: 'precision',
      version: '1.0.0',
      config: {},
    ),
    Game(
      slug: 'hill-rider',
      name: 'Hill Rider',
      gameType: 'timing',
      version: '1.0.0',
      config: {},
    ),
    Game(
      slug: 'memory-match',
      name: 'Memory Match',
      gameType: 'memory',
      version: '1.0.0',
      config: {},
    ),
    Game(
      slug: 'whack-a-mole',
      name: 'Whack-a-Mole',
      gameType: 'timing',
      version: '1.0.0',
      config: {},
    ),
    Game(
      slug: 'bubble-shooter',
      name: 'Bubble Shooter',
      gameType: 'puzzle',
      version: '1.0.0',
      config: {},
    ),
    Game(
      slug: 'tower-blocks',
      name: 'Tower Blocks',
      gameType: 'puzzle',
      version: '1.0.0',
      config: {},
    ),
    Game(
      slug: 'fruit-slice',
      name: 'Fruit Slice',
      gameType: 'timing',
      version: '1.0.0',
      config: {},
    ),
    Game(
      slug: 'doodle-jump',
      name: 'Doodle Jump',
      gameType: 'precision',
      version: '1.0.0',
      config: {},
    ),
  ];

  @override
  Future<GameSession> startSession(String slug, {int level = 1}) async {
    startCount++;
    startLevels.add(level);
    return GameSession(
      sessionId: 'session-$startCount',
      gameSlug: slug,
      version: '1.0.0',
      mode: 'practice',
      seed: seed,
      config: const {},
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<GameScoreResult> submitScore(
    String sessionId, {
    required List<String> moves,
    required int? clientScore,
  }) async {
    submissions.add(moves);
    clientScores.add(clientScore);
    final score = clientScore ?? quizScore;
    return GameScoreResult(
      score: score,
      movesCount: moves.length,
      won: false,
      gameOver: true,
      personalBest: score,
      isPersonalBest: score > 0,
      accepted: true,
      stats: {'moves': moves.length},
    );
  }

  @override
  Future<List<Game>> listGames() async => games;

  @override
  Future<Game> getGame(String slug) async =>
      games.firstWhere((g) => g.slug == slug);

  @override
  Future<Leaderboard> leaderboard(String slug, {int limit = 20}) async =>
      const Leaderboard(entries: []);

  /// Competitions the fake serves; tests set these up as they need.
  List<Competition> competitions = const [];
  CompetitionLeaderboard board = const CompetitionLeaderboard(
    status: 'live',
    isFinal: false,
    entries: [],
    totalPlayers: 0,
  );
  int attemptCount = 0;
  final List<String> claims = [];
  List<DeliveryAddress> addresses = const [];

  @override
  Future<List<DeliveryAddress>> deliveryAddresses() async => addresses;

  @override
  Future<List<Competition>> listCompetitions() async => competitions;

  @override
  Future<Competition> getCompetition(String id) async =>
      competitions.firstWhere((c) => c.id == id);

  @override
  Future<CompetitionLeaderboard> competitionLeaderboard(
    String id, {
    int limit = 50,
  }) async => board;

  /// Every idempotency key a play was started with, in order.
  final List<String> playKeys = [];

  /// Failures the next plays throw, one per call, before any succeed.
  final List<AppException> playFailures = [];

  /// Points the signed-in customer holds, for [pointsWallet].
  int pointsBalance = 100;

  @override
  Stream<LivePrize> livePrize(String competitionId) => const Stream.empty();

  @override
  Future<PointsEarningRule> pointsEarningRule() async =>
      const PointsEarningRule(
        enabled: true,
        pointsPerUnit: 2,
        signupBonus: 0,
        currency: 'NZD',
        earningAllowed: true,
      );

  @override
  Future<PointsWallet> pointsWallet() async => PointsWallet(
    balance: pointsBalance,
    lifetimeEarned: pointsBalance,
    lifetimeSpent: 0,
    entries: const [],
  );

  @override
  Future<AttemptStart> startAttempt(
    String competitionId, {
    required String playKey,
  }) async {
    playKeys.add(playKey);
    if (playFailures.isNotEmpty) throw playFailures.removeAt(0);
    attemptCount++;
    final competition = competitions.firstWhere((c) => c.id == competitionId);
    return AttemptStart(
      attemptNumber: attemptCount,
      attemptsRemaining: competition.maxAttempts - attemptCount,
      session: GameSession(
        sessionId: 'official-$attemptCount',
        gameSlug: competition.gameSlug,
        version: '1.0.0',
        mode: 'official',
        seed: seed,
        config: officialConfig,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
      pointsSpent: competition.pointsPerAttempt,
      walletPointsRemaining: pointsBalance - competition.pointsPerAttempt,
      result: chanceResult,
    );
  }

  /// The config official sessions are dealt (a quiz's questions, say).
  Map<String, dynamic> officialConfig = const {};

  /// What the "server" scores a quiz at, since the device sends none.
  int quizScore = 0;

  /// The client score sent with each submission (null for the quiz).
  final List<int?> clientScores = [];

  /// The outcome a chance play comes back with.
  ChanceResult? chanceResult;

  @override
  Future<void> claimPrize(
    String competitionId, {
    required String addressId,
  }) async {
    claims.add(addressId);
  }
}
