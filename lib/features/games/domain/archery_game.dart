/// Archery. A mirror of `internal/games/archery.go`.
///
/// Ten arrows at a target. The player aims by dragging and shoots by letting
/// go. The sight sways in a fixed figure. A pure function of the tick. And
/// the wind for each arrow is shown before it is shot, so reading the wind
/// and releasing at a steady moment are the skill.
library;

import 'deterministic_rng.dart';
import 'game_engine.dart';

class ArcheryConfig {
  const ArcheryConfig({
    this.tickMs = 30,
    this.arrows = 10,
    this.ringWidth = 10,
    this.maxWind = 25,
    this.swayAmplitude = 16,
    this.swayPeriodX = 46,
    this.swayPeriodY = 64,
    this.reloadTicks = 30,
    this.maxTicks = 20000,
  });

  /// Mirrors the backend's `withDefaults`.
  factory ArcheryConfig.fromJson(Map<String, dynamic> json) {
    const d = ArcheryConfig();
    int read(String key, int fallback) {
      final v = readConfigInt(json, key);
      return v <= 0 ? fallback : v;
    }

    return ArcheryConfig(
      tickMs: read('tick_ms', d.tickMs),
      arrows: read('arrows', d.arrows),
      ringWidth: read('ring_width', d.ringWidth),
      maxWind: read('max_wind', d.maxWind),
      swayAmplitude: read('sway_amplitude', d.swayAmplitude),
      swayPeriodX: evenAtLeast(read('sway_period_x', d.swayPeriodX), 4),
      swayPeriodY: evenAtLeast(read('sway_period_y', d.swayPeriodY), 4),
      reloadTicks: read('reload_ticks', d.reloadTicks),
      maxTicks: read('max_ticks', d.maxTicks),
    );
  }

  final int tickMs;
  final int arrows;
  final int ringWidth;
  final int maxWind;
  final int swayAmplitude;
  final int swayPeriodX;
  final int swayPeriodY;
  final int reloadTicks;
  final int maxTicks;
}

/// One arrow: where it was aimed, the wind it flew in, and where it hit.
class ArcheryArrow {
  const ArcheryArrow({
    required this.tick,
    required this.aimX,
    required this.aimY,
    required this.wind,
    required this.impactX,
    required this.impactY,
    required this.points,
    required this.inner,
  });

  final int tick;
  final int aimX;
  final int aimY;
  final int wind;
  final int impactX;
  final int impactY;
  final int points;

  /// Inside the inner ten. The tie-breaking "X".
  final bool inner;
}

class ArcheryGame implements TickGame {
  ArcheryGame({required String seed, ArcheryConfig? config})
    : config = config ?? const ArcheryConfig(),
      _rng = DeterministicRng.fromSeed(seed) {
    _wind = _drawWind();
  }

  /// How far off the target centre an aim may be.
  static const int aimLimit = 150;

  final ArcheryConfig config;
  final DeterministicRng _rng;

  late int _wind;
  int _tick = 0;
  int _lastTick = -1;
  int _tens = 0;
  int _xs = 0;
  int _score = 0;
  final List<String> _log = <String>[];
  final List<ArcheryArrow> _history = <ArcheryArrow>[];

  int _drawWind() => _rng.nextInt(2 * config.maxWind + 1) - config.maxWind;

  /// Scores an impact: 10 in the centre ring down to 1 in the outer one,
  /// 0 off the target.
  static int pointsFor(int x, int y, int ringWidth) {
    final d2 = x * x + y * y;
    for (var r = 1; r <= 10; r++) {
      final limit = r * ringWidth;
      if (d2 <= limit * limit) return 11 - r;
    }
    return 0;
  }

  @override
  int get tickMs => config.tickMs;

  @override
  int get tick => _tick;

  @override
  int get score => _score;

  @override
  List<String> get moves => List<String>.unmodifiable(_log);

  @override
  bool get hasProgress => _history.isNotEmpty;

  /// Over once every arrow is shot and the last one has landed.
  @override
  bool get isOver =>
      (_history.length >= config.arrows &&
          _tick >= _lastTick + config.reloadTicks) ||
      _tick >= config.maxTicks;

  @override
  void advance() {
    if (!isOver) _tick++;
  }

  /// The wind the next arrow will fly in. Negative blows left.
  int get wind => _wind;
  int get arrowsShot => _history.length;
  int get arrowsLeft => config.arrows - _history.length;
  int get tens => _tens;
  int get xs => _xs;
  List<ArcheryArrow> get history => List.unmodifiable(_history);
  ArcheryArrow? get lastArrow => _history.isEmpty ? null : _history.last;

  /// Ticks since the last arrow was loosed, or null before the first.
  int? get ticksSinceShot => _lastTick < 0 ? null : _tick - _lastTick;

  /// How far the sight has drifted from the aim at a tick.
  (int, int) sway(int atTick) => (
    triangleWave(atTick, config.swayPeriodX, config.swayAmplitude),
    triangleWave(
      atTick + config.swayPeriodY ~/ 4,
      config.swayPeriodY,
      config.swayAmplitude,
    ),
  );

  bool get canShoot =>
      _history.length < config.arrows &&
      _tick <= config.maxTicks &&
      (_lastTick < 0 || _tick >= _lastTick + config.reloadTicks);

  /// Looses an arrow aimed at ([aimX], [aimY]). Null when none is nocked.
  ArcheryArrow? shoot(int aimX, int aimY) {
    if (!canShoot) return null;
    final ax = aimX.clamp(-aimLimit, aimLimit);
    final ay = aimY.clamp(-aimLimit, aimLimit);
    final (sx, sy) = sway(_tick);
    final ix = ax + sx + _wind;
    final iy = ay + sy;
    final points = pointsFor(ix, iy, config.ringWidth);
    final half = config.ringWidth ~/ 2;
    final inner = ix * ix + iy * iy <= half * half;

    final arrow = ArcheryArrow(
      tick: _tick,
      aimX: ax,
      aimY: ay,
      wind: _wind,
      impactX: ix,
      impactY: iy,
      points: points,
      inner: inner,
    );
    _score += points;
    if (points == 10) _tens++;
    if (inner) _xs++;
    _lastTick = _tick;
    _log.add('$_tick:$ax:$ay');
    _history.add(arrow);
    _wind = _drawWind();
    return arrow;
  }
}
