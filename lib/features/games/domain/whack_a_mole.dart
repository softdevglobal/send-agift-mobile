import 'deterministic_rng.dart';
import 'game_engine.dart';

/// Whack-a-Mole rules, read from the config the server issues.
class WhackConfig {
  const WhackConfig({
    this.tickMs = 20,
    this.holes = 9,
    this.moles = 40,
    this.startUpTicks = 46,
    this.minUpTicks = 16,
    this.upStepTicks = 1,
    this.gapTicks = 10,
    this.pointsPerHit = 10,
    this.streakBonus = 4,
    this.missPenalty = 3,
  });

  final int tickMs;
  final int holes;
  final int moles;
  final int startUpTicks;
  final int minUpTicks;
  final int upStepTicks;
  final int gapTicks;
  final int pointsPerHit;
  final int streakBonus;
  final int missPenalty;

  factory WhackConfig.fromJson(Map<String, dynamic> json) {
    const d = WhackConfig();
    int pick(String key, int fallback) {
      final value = readConfigInt(json, key);
      return value > 0 ? value : fallback;
    }

    return WhackConfig(
      tickMs: pick('tick_ms', d.tickMs),
      holes: pick('holes', d.holes),
      moles: pick('moles', d.moles),
      startUpTicks: pick('start_up_ticks', d.startUpTicks),
      minUpTicks: pick('min_up_ticks', d.minUpTicks),
      upStepTicks: pick('up_step_ticks', d.upStepTicks),
      gapTicks: pick('gap_ticks', d.gapTicks),
      pointsPerHit: pick('points_per_hit', d.pointsPerHit),
      streakBonus: pick('streak_bonus', d.streakBonus),
      missPenalty: pick('miss_penalty', d.missPenalty),
    );
  }
}

/// One mole's appearance: the hole, and the tick window it is up for.
class WhackMole {
  const WhackMole({required this.hole, required this.up, required this.down});

  final int hole;
  final int up;
  final int down;
}

/// Whack-a-Mole: moles pop from numbered holes for a window that shrinks as
/// the round goes on. Consecutive hits pay a growing bonus; an empty hole
/// costs, so spamming scores worse than watching.
///
/// Mirrors `internal/games/whack.go` exactly. The whole schedule is drawn
/// from the seed up front, which is what makes the round replayable.
class WhackAMole implements TickGame {
  WhackAMole({required String seed, required this.config})
    : moles = _schedule(seed, config) {
    _hit = List<bool>.filled(moles.length, false);
  }

  final WhackConfig config;
  final List<WhackMole> moles;
  late final List<bool> _hit;
  final List<String> _moves = [];

  int _tick = 0;
  int _hits = 0;
  int _misses = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _score = 0;

  static List<WhackMole> _schedule(String seed, WhackConfig config) {
    final rng = DeterministicRng.fromSeed(seed);
    final out = <WhackMole>[];
    var tick = config.gapTicks;
    for (var i = 0; i < config.moles; i++) {
      var up = config.startUpTicks - config.upStepTicks * i;
      if (up < config.minUpTicks) up = config.minUpTicks;
      final hole = rng.nextInt(config.holes);
      out.add(WhackMole(hole: hole, up: tick, down: tick + up));
      tick = tick + up + config.gapTicks + rng.nextInt(config.gapTicks);
    }
    return out;
  }

  int get hits => _hits;
  int get misses => _misses;
  int get bestStreak => _bestStreak;

  /// When the last mole drops. The length of the whole round.
  int get lastTick => moles.isEmpty ? 0 : moles.last.down;

  /// The mole up right now, or null when every hole is empty.
  int get activeMole => moleAt(_tick);

  /// The index of the mole up at a tick, or -1 when none is.
  int moleAt(int tick) {
    for (var i = 0; i < moles.length; i++) {
      final m = moles[i];
      if (tick >= m.up && tick < m.down) return i;
      if (m.up > tick) break;
    }
    return -1;
  }

  /// Whether a mole has already been whacked.
  bool wasHit(int index) => index >= 0 && index < _hit.length && _hit[index];

  @override
  int get tickMs => config.tickMs;

  @override
  int get tick => _tick;

  @override
  int get score => _score;

  @override
  List<String> get moves => List.unmodifiable(_moves);

  @override
  bool get isOver => _tick >= lastTick;

  @override
  bool get hasProgress => _moves.isNotEmpty;

  @override
  void advance() {
    if (!isOver) _tick++;
  }

  /// Taps a hole at the current tick. Returns true when it caught a mole.
  bool whack(int hole) {
    if (isOver || hole < 0 || hole >= config.holes) return false;
    _moves.add('$_tick:$hole');

    final index = moleAt(_tick);
    if (index < 0 || moles[index].hole != hole || _hit[index]) {
      _misses++;
      _streak = 0;
      _score = _score >= config.missPenalty ? _score - config.missPenalty : 0;
      return false;
    }

    _hit[index] = true;
    _hits++;
    _streak++;
    if (_streak > _bestStreak) _bestStreak = _streak;
    _score += config.pointsPerHit + config.streakBonus * (_streak - 1);
    return true;
  }
}
