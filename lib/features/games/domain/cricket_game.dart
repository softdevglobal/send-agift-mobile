/// Cricket. A mirror of `internal/games/cricket.go`.
///
/// Twelve balls, three wickets. Every delivery (pace and line) and the field
/// for each over are drawn from the seed before the first ball and shown on
/// screen. The batter taps to swing: timing against the ball's arrival
/// decides how well it is struck, and where the tap lands aims the shot.
/// Deliveries run on a fixed tick schedule, so a ball the batter lets go
/// resolves the same way whenever it is replayed.
library;

import 'deterministic_rng.dart';
import 'game_engine.dart';

class CricketConfig {
  const CricketConfig({
    this.tickMs = 20,
    this.balls = 12,
    this.wickets = 3,
    this.ballCycleTicks = 160,
    this.runupTicks = 45,
    this.minTravelTicks = 38,
    this.maxTravelTicks = 62,
    this.perfectWindow = 1,
    this.goodWindow = 3,
    this.edgeWindow = 6,
    this.earlyTicks = 12,
    this.lateTicks = 8,
    this.fielders = 5,
    this.fielderReach = 10,
    this.maxAngle = 80,
  });

  /// Mirrors the backend's `withDefaults`.
  factory CricketConfig.fromJson(Map<String, dynamic> json) {
    const d = CricketConfig();
    int read(String key, int fallback) {
      final v = readConfigInt(json, key);
      return v <= 0 ? fallback : v;
    }

    final runup = read('runup_ticks', d.runupTicks);
    final minTravel = read('min_travel_ticks', d.minTravelTicks);
    var maxTravel = read('max_travel_ticks', d.maxTravelTicks);
    if (maxTravel < minTravel) maxTravel = minTravel;
    final late = read('late_ticks', d.lateTicks);
    var cycle = read('ball_cycle_ticks', d.ballCycleTicks);
    final need = runup + maxTravel + late + 10;
    if (cycle < need) cycle = need;

    return CricketConfig(
      tickMs: read('tick_ms', d.tickMs),
      balls: read('balls', d.balls),
      wickets: read('wickets', d.wickets),
      ballCycleTicks: cycle,
      runupTicks: runup,
      minTravelTicks: minTravel,
      maxTravelTicks: maxTravel,
      perfectWindow: read('perfect_window', d.perfectWindow),
      goodWindow: read('good_window', d.goodWindow),
      edgeWindow: read('edge_window', d.edgeWindow),
      earlyTicks: read('early_ticks', d.earlyTicks),
      lateTicks: late,
      fielders: read('fielders', d.fielders),
      fielderReach: read('fielder_reach', d.fielderReach),
      maxAngle: read('max_angle', d.maxAngle),
    );
  }

  final int tickMs;
  final int balls;
  final int wickets;
  final int ballCycleTicks;
  final int runupTicks;
  final int minTravelTicks;
  final int maxTravelTicks;
  final int perfectWindow;
  final int goodWindow;
  final int edgeWindow;
  final int earlyTicks;
  final int lateTicks;
  final int fielders;
  final int fielderReach;
  final int maxAngle;
}

/// One delivery: how long it takes to reach the bat, and its line
/// (-1 outside off, 0 at the stumps, 1 down leg).
class CricketBall {
  const CricketBall(this.travel, this.line);

  final int travel;
  final int line;

  @override
  String toString() => '{$travel $line}';
}

/// What happened to one ball.
class CricketOutcome {
  const CricketOutcome({
    required this.ball,
    required this.runs,
    required this.wicket,
    required this.timing,
    required this.blocked,
    required this.swung,
    required this.angle,
    required this.tick,
  });

  final int ball;
  final int runs;
  final bool wicket;

  /// 3 perfect, 2 good, 1 edge, 0 missed or no shot.
  final int timing;
  final bool blocked;
  final bool swung;
  final int angle;

  /// When it was decided. The swing, or the end of the ball's window.
  final int tick;
}

class CricketGame implements TickGame {
  CricketGame({required String seed, CricketConfig? config})
    : config = config ?? const CricketConfig() {
    final rng = DeterministicRng.fromSeed(seed);
    final c = this.config;
    for (var k = 0; k < c.balls; k++) {
      final travel =
          c.minTravelTicks +
          rng.nextInt(c.maxTravelTicks - c.minTravelTicks + 1);
      final line = rng.nextInt(3) - 1;
      _balls.add(CricketBall(travel, line));
    }
    final overs = (c.balls + 5) ~/ 6;
    for (var o = 0; o < overs; o++) {
      _fielders.add([
        for (var f = 0; f < c.fielders; f++)
          rng.nextInt(2 * c.maxAngle + 1) - c.maxAngle,
      ]);
    }
  }

  final CricketConfig config;
  final List<CricketBall> _balls = <CricketBall>[];
  final List<List<int>> _fielders = <List<int>>[];

  int _tick = 0;
  int _next = 0;
  int _runs = 0;
  int _fours = 0;
  int _sixes = 0;
  int _wickets = 0;
  int _swings = 0;
  int _endTick = 0;
  final List<String> _log = <String>[];
  final List<CricketOutcome> _outcomes = <CricketOutcome>[];

  @override
  int get tickMs => config.tickMs;

  @override
  int get tick => _tick;

  @override
  int get score => _runs;

  @override
  List<String> get moves => List<String>.unmodifiable(_log);

  @override
  bool get hasProgress => _swings > 0;

  /// Over a second after the innings ends, so the last ball can be watched.
  @override
  bool get isOver => inningsOver && _tick >= _endTick + 50;

  @override
  void advance() {
    _tick++;
    _settle();
  }

  List<CricketBall> get balls => List.unmodifiable(_balls);
  List<List<int>> get fielders => _fielders;
  List<CricketOutcome> get outcomes => List.unmodifiable(_outcomes);
  CricketOutcome? get lastOutcome => _outcomes.isEmpty ? null : _outcomes.last;
  int get runs => _runs;
  int get fours => _fours;
  int get sixes => _sixes;
  int get wickets => _wickets;
  int get nextBall => _next;
  int get ballsLeft => config.balls - _next;

  bool get inningsOver => _wickets >= config.wickets || _next >= config.balls;

  /// The tick ball [k] reaches the bat.
  int arrival(int k) =>
      k * config.ballCycleTicks + config.runupTicks + _balls[k].travel;

  /// The tick ball [k] is released by the bowler.
  int release(int k) => k * config.ballCycleTicks + config.runupTicks;

  /// The fielders for ball [k]'s over.
  List<int> fieldFor(int k) => _fielders[k ~/ 6];

  int _timing(int delta) {
    final d = delta.abs();
    if (d <= config.perfectWindow) return 3;
    if (d <= config.goodWindow) return 2;
    if (d <= config.edgeWindow) return 1;
    return 0;
  }

  bool _blocked(int k, int angle) =>
      fieldFor(k).any((f) => (angle - f).abs() <= config.fielderReach);

  CricketOutcome _resolve(int k, bool swung, int tick, int angle) {
    var timing = 0;
    var blocked = false;
    if (swung) {
      timing = _timing(tick - arrival(k));
      blocked = _blocked(k, angle);
    }
    var runs = 0;
    var wicket = false;
    switch (timing) {
      case 3:
        runs = 6;
        _sixes++;
      case 2:
        if (blocked) {
          runs = 1;
        } else {
          runs = 4;
          _fours++;
        }
      case 1:
        if (blocked) {
          wicket = true;
        } else {
          runs = 1;
        }
      default:
        wicket = _balls[k].line == 0;
    }
    _runs += runs;
    if (wicket) _wickets++;
    _next = k + 1;
    final outcome = CricketOutcome(
      ball: k,
      runs: runs,
      wicket: wicket,
      timing: timing,
      blocked: blocked,
      swung: swung,
      angle: angle,
      tick: _tick,
    );
    _outcomes.add(outcome);
    if (inningsOver) _endTick = _tick;
    return outcome;
  }

  /// A ball the batter let go resolves once its window has passed.
  void _settle() {
    while (!inningsOver && _tick > arrival(_next) + config.lateTicks) {
      _resolve(_next, false, 0, 0);
    }
  }

  /// Whether a swing now would meet the ball.
  bool get canSwing {
    if (inningsOver) return false;
    final k = _tick ~/ config.ballCycleTicks;
    if (k != _next) return false;
    final a = arrival(k);
    return _tick >= a - config.earlyTicks && _tick <= a + config.lateTicks;
  }

  /// Swings now, aimed at [angle] (negative off side, positive leg side).
  /// Null when no ball is there to hit.
  CricketOutcome? swing(int angle) {
    if (!canSwing) return null;
    final a = angle.clamp(-config.maxAngle, config.maxAngle);
    _swings++;
    _log.add('$_tick:$a');
    return _resolve(_tick ~/ config.ballCycleTicks, true, _tick, a);
  }
}
