import 'deterministic_rng.dart';
import 'game_engine.dart';

/// Memory Match rules, read from the config the server issues.
class MemoryConfig {
  const MemoryConfig({
    this.pairs = 24,
    this.columns = 7,
    this.pointsPerMatch = 20,
    this.streakBonus = 10,
    this.turnPenalty = 1,
    this.maxTurns = 240,
  });

  final int pairs;
  final int columns;
  final int pointsPerMatch;
  final int streakBonus;
  final int turnPenalty;
  final int maxTurns;

  factory MemoryConfig.fromJson(Map<String, dynamic> json) {
    const d = MemoryConfig();
    int pick(String key, int fallback) {
      final value = readConfigInt(json, key);
      return value > 0 ? value : fallback;
    }

    return MemoryConfig(
      pairs: pick('pairs', d.pairs),
      columns: pick('columns', d.columns),
      pointsPerMatch: pick('points_per_match', d.pointsPerMatch),
      streakBonus: pick('streak_bonus', d.streakBonus),
      turnPenalty: pick('turn_penalty', d.turnPenalty),
      maxTurns: pick('max_turns', d.maxTurns),
    );
  }
}

/// Memory Match: a grid of face-down gift cards holding pairs. Two flips make
/// a turn; matches stay up and a run of them pays a growing bonus.
///
/// Mirrors `internal/games/memory.go` exactly. Same deal from the seed, same
/// scoring. So the score shown while playing matches the server's replay.
class MemoryMatch implements GameEngine {
  MemoryMatch({required String seed, required this.config})
    : _cards = _deal(seed, config) {
    _matched = List<bool>.filled(_cards.length, false);
  }

  final MemoryConfig config;
  final List<int> _cards;
  late final List<bool> _matched;
  final List<String> _moves = [];

  int _pending = -1;
  int _turns = 0;
  int _matches = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _score = 0;

  /// Fisher-Yates from the seed, walking downwards exactly as the Go deal
  /// does. The draw order is what has to match, not just the shuffle.
  static List<int> _deal(String seed, MemoryConfig config) {
    final count = config.pairs * 2;
    final cards = List<int>.generate(count, (i) => i ~/ 2);
    final rng = DeterministicRng.fromSeed(seed);
    for (var i = count - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = cards[i];
      cards[i] = cards[j];
      cards[j] = tmp;
    }
    return cards;
  }

  int get cardCount => _cards.length;

  /// How many rows the grid occupies. Rounded up, because a deal that does
  /// not divide evenly into the columns still takes a final, partial row.
  /// a 7-wide board of 48 cards is seven rows, not six.
  int get rows => (_cards.length + config.columns - 1) ~/ config.columns;
  int get matches => _matches;
  int get turns => _turns;
  int get bestStreak => _bestStreak;
  int get pending => _pending;
  bool get complete => _matches == config.pairs;

  /// The face value on a card.
  int faceOf(int index) => _cards[index];

  /// Whether a card has already been paired off.
  bool isMatched(int index) => _matched[index];

  /// Whether a card is currently showing: matched, or the pending flip.
  bool isFaceUp(int index) => _matched[index] || _pending == index;

  @override
  int get score => _score;

  @override
  List<String> get moves => List.unmodifiable(_moves);

  @override
  bool get isOver => complete || _turns >= config.maxTurns;

  @override
  bool get hasProgress => _moves.isNotEmpty;

  /// Turns a card face up. Returns true when it completed a matching pair.
  bool flip(int index) {
    if (isOver ||
        index < 0 ||
        index >= _cards.length ||
        _matched[index] ||
        index == _pending) {
      return false;
    }
    _moves.add('$index');

    if (_pending < 0) {
      _pending = index;
      return false;
    }

    final first = _pending;
    _pending = -1;
    _turns++;

    if (_cards[first] != _cards[index]) {
      _streak = 0;
      _score = _score >= config.turnPenalty ? _score - config.turnPenalty : 0;
      return false;
    }

    _matched[first] = true;
    _matched[index] = true;
    _matches++;
    _streak++;
    if (_streak > _bestStreak) _bestStreak = _streak;
    _score += config.pointsPerMatch + config.streakBonus * (_streak - 1);
    return true;
  }
}
