/// Stack Tower. A mirror of `internal/games/stack.go`.
///
/// A floor slides back and forth over the tower and the player drops it.
/// Whatever overhangs is sliced off; a drop inside the perfect window snaps
/// into place, and a run of them grows the floor back. Missing the tower
/// entirely ends the game. The sliding position is a pure function of the
/// tick, so the server replays exactly the drop the player made.
library;

import 'dart:math' as math;

import 'deterministic_rng.dart';
import 'game_engine.dart';

class StackConfig {
  const StackConfig({
    this.tickMs = 20,
    this.baseSize = 100,
    this.travel = 130,
    this.startPeriodTicks = 150,
    this.minPeriodTicks = 66,
    this.periodStepTicks = 4,
    this.perfectTolerance = 4,
    this.pointsPerFloor = 10,
    this.perfectBonus = 5,
    this.growEveryPerfects = 4,
    this.growAmount = 6,
    this.maxFloors = 500,
    this.maxTicks = 90000,
  });

  /// Mirrors the backend's `withDefaults`.
  factory StackConfig.fromJson(Map<String, dynamic> json) {
    const d = StackConfig();
    int read(String key, int fallback) {
      final v = readConfigInt(json, key);
      return v <= 0 ? fallback : v;
    }

    final minPeriod = evenAtLeast(
      read('min_period_ticks', d.minPeriodTicks),
      2,
    );
    return StackConfig(
      tickMs: read('tick_ms', d.tickMs),
      baseSize: read('base_size', d.baseSize),
      travel: read('travel', d.travel),
      startPeriodTicks: evenAtLeast(
        read('start_period_ticks', d.startPeriodTicks),
        minPeriod,
      ),
      minPeriodTicks: minPeriod,
      periodStepTicks: read('period_step_ticks', d.periodStepTicks),
      perfectTolerance: read('perfect_tolerance', d.perfectTolerance),
      pointsPerFloor: read('points_per_floor', d.pointsPerFloor),
      perfectBonus: read('perfect_bonus', d.perfectBonus),
      growEveryPerfects: read('grow_every_perfects', d.growEveryPerfects),
      growAmount: read('grow_amount', d.growAmount),
      maxFloors: read('max_floors', d.maxFloors),
      maxTicks: read('max_ticks', d.maxTicks),
    );
  }

  final int tickMs;
  final int baseSize;
  final int travel;
  final int startPeriodTicks;
  final int minPeriodTicks;
  final int periodStepTicks;
  final int perfectTolerance;
  final int pointsPerFloor;
  final int perfectBonus;
  final int growEveryPerfects;
  final int growAmount;
  final int maxFloors;
  final int maxTicks;
}

/// One floor's footprint: x0..x1 by z0..z1.
class StackBlock {
  const StackBlock(this.x0, this.x1, this.z0, this.z1);

  final int x0;
  final int x1;
  final int z0;
  final int z1;

  int get width => x1 - x0;
  int get depth => z1 - z0;

  StackBlock shifted({required bool alongX, required int by}) => alongX
      ? StackBlock(x0 + by, x1 + by, z0, z1)
      : StackBlock(x0, x1, z0 + by, z1 + by);

  @override
  bool operator ==(Object other) =>
      other is StackBlock &&
      other.x0 == x0 &&
      other.x1 == x1 &&
      other.z0 == z0 &&
      other.z1 == z1;

  @override
  int get hashCode => Object.hash(x0, x1, z0, z1);

  @override
  String toString() => 'StackBlock($x0..$x1, $z0..$z1)';
}

/// One drop, with what the view needs to animate it.
class StackDrop {
  const StackDrop({
    required this.tick,
    required this.floor,
    required this.offset,
    required this.perfect,
    required this.fell,
    required this.points,
    required this.streak,
    this.placed,
    this.cut,
  });

  final int tick;

  /// Which floor this drop was for (1 is the first above the base).
  final int floor;
  final int offset;
  final bool perfect;
  final bool fell;
  final int points;
  final int streak;

  /// The floor that stayed on the tower; null when it fell.
  final StackBlock? placed;

  /// The piece that was sliced off. Or the whole floor, when it fell.
  final StackBlock? cut;
}

class StackTower implements TickGame {
  StackTower({required String seed, StackConfig? config})
    : config = config ?? const StackConfig(),
      _rng = DeterministicRng.fromSeed(seed) {
    final half = this.config.baseSize ~/ 2;
    final far = this.config.baseSize - half;
    _floors.add(StackBlock(-half, far, -half, far));
    _startFloor(0);
  }

  final StackConfig config;
  final DeterministicRng _rng;

  final List<StackBlock> _floors = <StackBlock>[];
  int _side = 1;
  int _layerStart = 0;
  int _tick = 0;
  int _perfects = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _score = 0;
  bool _fell = false;
  int _fellTick = 0;
  StackDrop? _lastDrop;
  final List<String> _log = <String>[];

  void _startFloor(int tick) {
    _layerStart = tick;
    _side = _rng.nextInt(2) == 0 ? -1 : 1;
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
  bool get hasProgress => _log.isNotEmpty;

  /// Over once the tower has fallen. After a moment to watch it go.
  @override
  bool get isOver =>
      (_fell && _tick >= _fellTick + 30) ||
      floorCount >= config.maxFloors ||
      _tick >= config.maxTicks;

  @override
  void advance() {
    if (!isOver) _tick++;
  }

  List<StackBlock> get floors => List.unmodifiable(_floors);
  StackBlock get top => _floors.last;
  int get floorCount => _floors.length - 1;
  int get perfects => _perfects;
  int get streak => _streak;
  int get bestStreak => _bestStreak;
  bool get fell => _fell;
  StackDrop? get lastDrop => _lastDrop;
  bool get slidesAlongX => _floors.length.isOdd;

  /// How many ticks the moving floor takes to slide there and back.
  int get period => evenAtLeast(
    config.startPeriodTicks - config.periodStepTicks * (_floors.length - 1),
    config.minPeriodTicks,
  );

  /// How far the moving floor is from sitting squarely on the tower.
  int offsetAt(int atTick) {
    final u = math.max(0, atTick - _layerStart);
    return _side * triangleWave(u, period, config.travel);
  }

  /// The moving floor at a tick.
  StackBlock movingAt(int atTick) =>
      top.shifted(alongX: slidesAlongX, by: offsetAt(atTick));

  /// Drops the moving floor now. Null when a drop is not possible yet. A
  /// second tap inside the same tick, say.
  StackDrop? drop() {
    if (_fell ||
        _tick <= _layerStart ||
        _tick > config.maxTicks ||
        floorCount >= config.maxFloors) {
      return null;
    }

    var offset = offsetAt(_tick);
    final perfect = offset.abs() <= config.perfectTolerance;
    if (perfect) offset = 0;

    final t = top;
    final alongX = slidesAlongX;
    final a0 = alongX ? t.x0 : t.z0;
    final a1 = alongX ? t.x1 : t.z1;
    final floor = _floors.length;
    _log.add('$_tick');

    if ((a1 - a0) - offset.abs() <= 0) {
      _fell = true;
      _fellTick = _tick;
      _streak = 0;
      return _lastDrop = StackDrop(
        tick: _tick,
        floor: floor,
        offset: offset,
        perfect: false,
        fell: true,
        points: 0,
        streak: 0,
        cut: t.shifted(alongX: alongX, by: offset),
      );
    }

    var n0 = a0;
    var n1 = a1;
    StackBlock? cut;
    if (offset > 0) {
      n0 = a0 + offset;
      cut = _withAxis(t, alongX, a1, a1 + offset);
    } else if (offset < 0) {
      n1 = a1 + offset;
      cut = _withAxis(t, alongX, a0 + offset, a0);
    }

    var bonus = 0;
    if (perfect) {
      _perfects++;
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;
      bonus = config.perfectBonus * math.min(_streak, 5);
      if (_streak % config.growEveryPerfects == 0) {
        n1 += config.growAmount;
        if (n1 - n0 > config.baseSize) n1 = n0 + config.baseSize;
      }
    } else {
      _streak = 0;
    }

    final placed = _withAxis(t, alongX, n0, n1);
    final points = config.pointsPerFloor + bonus;
    _score += points;
    _floors.add(placed);
    final drop = StackDrop(
      tick: _tick,
      floor: floor,
      offset: offset,
      perfect: perfect,
      fell: false,
      points: points,
      streak: _streak,
      placed: placed,
      cut: cut,
    );
    _startFloor(_tick);
    return _lastDrop = drop;
  }

  static StackBlock _withAxis(StackBlock b, bool alongX, int a0, int a1) =>
      alongX ? StackBlock(a0, a1, b.z0, b.z1) : StackBlock(b.x0, b.x1, a0, a1);
}
