/// Basketball. A mirror of `internal/games/basketball.go`.
///
/// A timed shoot-out. Each shot is aimed sideways and thrown with a power,
/// both whole numbers. The ball flies for a fixed number of ticks, so once
/// the hoop starts moving the player has to lead it. The hoop's position is
/// a pure function of the tick, so the server replays exactly what the
/// player saw.
library;

import 'dart:math' as math;

import 'deterministic_rng.dart';
import 'game_engine.dart';

class BasketballConfig {
  const BasketballConfig({
    this.tickMs = 50,
    this.roundTicks = 900,
    this.flightTicks = 14,
    this.shotCooldownTicks = 20,
    this.aimTolerance = 12,
    this.powerTolerance = 7,
    this.swishAimTolerance = 4,
    this.swishPowerTolerance = 3,
    this.makesPerLevel = 4,
  });

  /// Mirrors the backend's `withDefaults`.
  factory BasketballConfig.fromJson(Map<String, dynamic> json) {
    const d = BasketballConfig();
    int read(String key, int fallback) {
      final v = readConfigInt(json, key);
      return v <= 0 ? fallback : v;
    }

    final flight = read('flight_ticks', d.flightTicks);
    final cooldown = read('shot_cooldown_ticks', d.shotCooldownTicks);
    return BasketballConfig(
      tickMs: read('tick_ms', d.tickMs),
      roundTicks: read('round_ticks', d.roundTicks),
      flightTicks: flight,
      shotCooldownTicks: cooldown < flight ? flight : cooldown,
      aimTolerance: read('aim_tolerance', d.aimTolerance),
      powerTolerance: read('power_tolerance', d.powerTolerance),
      swishAimTolerance: read('swish_aim_tolerance', d.swishAimTolerance),
      swishPowerTolerance: read('swish_power_tolerance', d.swishPowerTolerance),
      makesPerLevel: read('makes_per_level', d.makesPerLevel),
    );
  }

  final int tickMs;
  final int roundTicks;
  final int flightTicks;
  final int shotCooldownTicks;
  final int aimTolerance;
  final int powerTolerance;
  final int swishAimTolerance;
  final int swishPowerTolerance;
  final int makesPerLevel;
}

/// The outcome of one shot, with everything the court needs to animate it.
class BasketballShot {
  const BasketballShot({
    required this.tick,
    required this.aim,
    required this.power,
    required this.distance,
    required this.hoopX,
    required this.made,
    required this.swish,
    required this.points,
    required this.onFire,
    required this.level,
  });

  final int tick;

  /// The level when the ball was thrown. The hoop moves to that level's
  /// rhythm until the ball has landed.
  final int level;
  final int aim;
  final int power;
  final int distance;

  /// Where the hoop was when the ball arrived.
  final int hoopX;
  final bool made;
  final bool swish;
  final int points;

  /// Whether this basket was scored on fire (counted double).
  final bool onFire;

  int get aimError => aim - hoopX;
  int get powerError => power - BasketballGame.requiredPower(distance);
}

class BasketballGame implements TickGame {
  BasketballGame({required String seed, BasketballConfig? config})
    : config = config ?? const BasketballConfig(),
      _rng = DeterministicRng.fromSeed(seed) {
    _phase = _rng.nextInt(97);
    _distance = _rng.nextInt(spots);
  }

  static const int aimLimit = 100;
  static const int maxPower = 100;

  /// Shooting spots, nearest to farthest. The farthest is a three-pointer.
  static const int spots = 4;

  /// The power that lands a shot from a spot.
  static int requiredPower(int distance) => 40 + 15 * distance;

  final BasketballConfig config;
  final DeterministicRng _rng;

  late final int _phase;
  late int _distance;
  int _tick = 0;
  int _lastTick = -1;
  int _makes = 0;
  int _shots = 0;
  int _swishes = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _score = 0;
  final List<String> _log = <String>[];
  final List<BasketballShot> _history = <BasketballShot>[];

  @override
  int get tickMs => config.tickMs;

  @override
  int get tick => _tick;

  @override
  int get score => _score;

  @override
  List<String> get moves => List<String>.unmodifiable(_log);

  @override
  bool get hasProgress => _shots > 0;

  /// The round ends at the buzzer; the last shot still gets to land.
  @override
  bool get isOver => _tick >= config.roundTicks + config.flightTicks;

  @override
  void advance() {
    if (!isOver) _tick++;
  }

  int get distance => _distance;
  int get makes => _makes;
  int get shots => _shots;
  int get swishes => _swishes;
  int get streak => _streak;
  int get bestStreak => _bestStreak;
  bool get onFire => _streak >= 3;
  int get level => _makes ~/ config.makesPerLevel;
  int get ticksLeft => math.max(0, config.roundTicks - _tick);
  List<BasketballShot> get history => List.unmodifiable(_history);
  BasketballShot? get lastShot => _history.isEmpty ? null : _history.last;

  /// The score without a basket still in the air, so the scoreboard ticks up
  /// when the ball drops rather than when it leaves the hand.
  int get settledScore {
    final s = lastShot;
    if (s != null && _tick < s.tick + config.flightTicks) {
      return _score - s.points;
    }
    return _score;
  }

  /// Where the hoop is at a tick, at the current level.
  int hoopX(int atTick) => hoopXFor(atTick, level);

  /// Where the hoop is at a tick, at a given level.
  int hoopXFor(int atTick, int lvl) {
    if (lvl == 0) return 0;
    final amp = math.min(20 * lvl, 70);
    final period = math.max(120 - 16 * lvl, 48);
    return triangleWave(atTick + _phase + 13 * lvl, period, amp);
  }

  bool get canShoot =>
      _tick < config.roundTicks &&
      (_lastTick < 0 || _tick >= _lastTick + config.shotCooldownTicks);

  /// Throws the ball now. Returns null when no ball is ready.
  BasketballShot? shoot(int aim, int power) {
    if (!canShoot) return null;
    final a = aim.clamp(-aimLimit, aimLimit);
    final p = power.clamp(0, maxPower);

    final lvl = level;
    final hoop = hoopXFor(_tick + config.flightTicks, lvl);
    final aimErr = (a - hoop).abs();
    final powerErr = (p - requiredPower(_distance)).abs();
    final made =
        aimErr <= config.aimTolerance && powerErr <= config.powerTolerance;
    final swish =
        made &&
        aimErr <= config.swishAimTolerance &&
        powerErr <= config.swishPowerTolerance;

    var points = 0;
    final wasOnFire = _streak >= 3;
    if (made) {
      points = _distance == spots - 1 ? 3 : 2;
      if (swish) points++;
      if (wasOnFire) points *= 2;
      _score += points;
      _makes++;
      _streak++;
      if (swish) _swishes++;
      if (_streak > _bestStreak) _bestStreak = _streak;
    } else {
      _streak = 0;
    }

    final shot = BasketballShot(
      tick: _tick,
      aim: a,
      power: p,
      distance: _distance,
      hoopX: hoop,
      made: made,
      swish: swish,
      points: points,
      onFire: made && wasOnFire,
      level: lvl,
    );
    _shots++;
    _lastTick = _tick;
    _log.add('$_tick:$a:$p');
    _history.add(shot);
    _distance = _rng.nextInt(spots);
    return shot;
  }
}
