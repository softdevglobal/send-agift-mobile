import 'deterministic_rng.dart';
import 'game_engine.dart';

/// How many fruits the board knows how to draw.
const fruitKinds = 6;

/// Each fruit's size against the base radius, in percent: watermelon,
/// orange, apple, lemon, coconut, plum. Mirrors `fruitKindScale` in Go.
const fruitKindScale = [128, 100, 100, 94, 110, 88];

/// Fruit Slice rules, read from the config the server issues.
///
/// Everything is measured on a [width] x [height] field with y pointing up
/// from the bottom edge, in whole units.
class FruitConfig {
  const FruitConfig({
    this.tickMs = 20,
    this.width = 1000,
    this.height = 1800,
    this.volleys = 50,
    this.startFlightTicks = 120,
    this.minFlightTicks = 80,
    this.flightStepTicks = 1,
    this.staggerTicks = 8,
    this.gapTicks = 20,
    this.maxVolley = 5,
    this.volleyGrowEvery = 6,
    this.bombFromVolley = 3,
    this.bombChance = 3,
    this.fruitRadius = 86,
    this.bombRadius = 76,
    this.minPeak = 1250,
    this.maxPeak = 1650,
    this.margin = 150,
    this.drift = 250,
    this.lives = 3,
    this.pointsPerFruit = 10,
    this.comboBonus = 5,
    this.comboWindowTicks = 15,
  });

  final int tickMs;
  final int width;
  final int height;
  final int volleys;
  final int startFlightTicks;
  final int minFlightTicks;
  final int flightStepTicks;
  final int staggerTicks;
  final int gapTicks;
  final int maxVolley;
  final int volleyGrowEvery;
  final int bombFromVolley;
  final int bombChance;
  final int fruitRadius;
  final int bombRadius;
  final int minPeak;
  final int maxPeak;
  final int margin;
  final int drift;
  final int lives;
  final int pointsPerFruit;
  final int comboBonus;
  final int comboWindowTicks;

  factory FruitConfig.fromJson(Map<String, dynamic> json) {
    const d = FruitConfig();
    int pick(String key, int fallback) {
      final value = readConfigInt(json, key);
      return value > 0 ? value : fallback;
    }

    final width = pick('width', d.width);
    final minPeak = pick('min_peak', d.minPeak);
    var maxPeak = pick('max_peak', d.maxPeak);
    if (maxPeak < minPeak) maxPeak = minPeak;
    var margin = pick('margin', d.margin);
    if (2 * margin >= width) margin = width ~/ 4;

    return FruitConfig(
      tickMs: pick('tick_ms', d.tickMs),
      width: width,
      height: pick('height', d.height),
      volleys: pick('volleys', d.volleys),
      startFlightTicks: pick('start_flight_ticks', d.startFlightTicks),
      minFlightTicks: pick('min_flight_ticks', d.minFlightTicks),
      flightStepTicks: pick('flight_step_ticks', d.flightStepTicks),
      staggerTicks: pick('stagger_ticks', d.staggerTicks),
      gapTicks: pick('gap_ticks', d.gapTicks),
      maxVolley: pick('max_volley', d.maxVolley),
      volleyGrowEvery: pick('volley_grow_every', d.volleyGrowEvery),
      bombFromVolley: pick('bomb_from_volley', d.bombFromVolley),
      bombChance: pick('bomb_chance', d.bombChance),
      fruitRadius: pick('fruit_radius', d.fruitRadius),
      bombRadius: pick('bomb_radius', d.bombRadius),
      minPeak: minPeak,
      maxPeak: maxPeak,
      margin: margin,
      drift: pick('drift', d.drift),
      lives: pick('lives', d.lives),
      pointsPerFruit: pick('points_per_fruit', d.pointsPerFruit),
      comboBonus: pick('combo_bonus', d.comboBonus),
      comboWindowTicks: pick('combo_window_ticks', d.comboWindowTicks),
    );
  }
}

/// One thing tossed into the air: it rises from below the bottom edge at
/// [x0], peaks [peak] units up, and falls back out at [x1].
class FruitThrow {
  const FruitThrow({
    required this.enter,
    required this.exit,
    required this.x0,
    required this.x1,
    required this.peak,
    required this.radius,
    required this.bomb,
    required this.kind,
  });

  final int enter;
  final int exit;
  final int x0;
  final int x1;
  final int peak;
  final int radius;
  final bool bomb;
  final int kind;

  /// Where the throw is at a tick inside its flight, in whole units. The
  /// exact position the server tests a swipe against.
  (int, int) pos(int tick) {
    final f = exit - enter;
    final s = tick - enter;
    final x = x0 + ((x1 - x0) * s) ~/ f;
    final y = -radius + (4 * (peak + radius) * s * (f - s)) ~/ (f * f);
    return (x, y);
  }

  /// The same curve at a fractional tick, for drawing smoothly between ticks.
  (double, double) smoothPos(double tick) {
    final f = (exit - enter).toDouble();
    final s = tick - enter;
    final x = x0 + (x1 - x0) * s / f;
    final y = -radius + 4 * (peak + radius) * s * (f - s) / (f * f);
    return (x, y);
  }
}

/// What one swipe piece did, for the board to animate.
class FruitCut {
  const FruitCut({
    required this.index,
    required this.combo,
    required this.points,
  });

  final int index;

  /// This fruit's place in the stroke's combo: 1 for the first, and so on.
  /// Zero for a bomb.
  final int combo;
  final int points;
}

/// Whether [segment] passes within [r] of a point. Integer-only, mirroring
/// `segmentHits` in Go: the squared distance is compared scaled by the
/// segment's squared length rather than divided through by it.
bool fruitSegmentHits(int x1, int y1, int x2, int y2, int cx, int cy, int r) {
  final dx = x2 - x1, dy = y2 - y1;
  final fx = cx - x1, fy = cy - y1;
  final r2 = r * r;
  final len2 = dx * dx + dy * dy;
  final dot = fx * dx + fy * dy;
  if (len2 == 0 || dot <= 0) return fx * fx + fy * fy <= r2;
  if (dot >= len2) {
    final ex = cx - x2, ey = cy - y2;
    return ex * ex + ey * ey <= r2;
  }
  return (fx * fx + fy * fy) * len2 - dot * dot <= r2 * len2;
}

/// Fruit Slice: fruit is tossed up from below in volleys and the player draws
/// a blade across the screen to cut it. Several fruit in one stroke pay a
/// growing combo; a fruit that falls back uncut costs a life, and cutting a
/// bomb ends the round outright.
///
/// Mirrors `internal/games/fruitslice.go` exactly.
class FruitSlice implements TickGame {
  FruitSlice({required String seed, required this.config})
    : throws = _schedule(seed, config) {
    _cut = List<bool>.filled(throws.length, false);
    _landed = List<bool>.filled(throws.length, false);
    var last = 0;
    for (final t in throws) {
      if (t.exit > last) last = t.exit;
    }
    lastTick = last;
  }

  final FruitConfig config;
  final List<FruitThrow> throws;
  late final List<bool> _cut;
  late final List<bool> _landed;
  final List<String> _moves = [];

  /// When the final throw lands. The length of the whole round.
  late final int lastTick;

  int _tick = 0;
  int _settledTo = 0;
  int _stroke = 0;
  int _strokeRun = 0;
  int _strokeAt = -1;

  int _sliced = 0;
  int _bestCombo = 0;
  int _dropped = 0;
  int _score = 0;
  bool _over = false;
  bool _bombed = false;

  /// Throws that fell out uncut since the board last asked, so it can mark
  /// where each one was lost.
  final List<int> _newDrops = [];

  static List<FruitThrow> _schedule(String seed, FruitConfig c) {
    final rng = DeterministicRng.fromSeed(seed);
    final out = <FruitThrow>[];
    var tick = c.gapTicks;
    for (var v = 0; v < c.volleys; v++) {
      var flight = c.startFlightTicks - c.flightStepTicks * v;
      if (flight < c.minFlightTicks) flight = c.minFlightTicks;
      var most = 1 + v ~/ c.volleyGrowEvery;
      if (most > c.maxVolley) most = c.maxVolley;
      final size = 1 + rng.nextInt(most);
      var bombAt = -1;
      if (v >= c.bombFromVolley && rng.nextInt(c.bombChance) == 0) {
        bombAt = rng.nextInt(size);
      }
      for (var k = 0; k < size; k++) {
        final kind = rng.nextInt(fruitKinds);
        final bomb = k == bombAt;
        final radius = bomb
            ? c.bombRadius
            : c.fruitRadius * fruitKindScale[kind] ~/ 100;
        final x0 = c.margin + rng.nextInt(c.width - 2 * c.margin + 1);
        var x1 = x0 + rng.nextInt(2 * c.drift + 1) - c.drift;
        if (x1 < radius) x1 = radius;
        if (x1 > c.width - radius) x1 = c.width - radius;
        final peak = c.minPeak + rng.nextInt(c.maxPeak - c.minPeak + 1);
        final enter = tick + k * c.staggerTicks;
        out.add(
          FruitThrow(
            enter: enter,
            exit: enter + flight,
            x0: x0,
            x1: x1,
            peak: peak,
            radius: radius,
            bomb: bomb,
            kind: kind,
          ),
        );
      }
      tick +=
          (size - 1) * c.staggerTicks +
          flight * 3 ~/ 4 +
          rng.nextInt(c.gapTicks);
    }
    return out;
  }

  int get sliced => _sliced;
  int get bestCombo => _bestCombo;
  int get dropped => _dropped;
  int get livesLeft => (config.lives - _dropped).clamp(0, config.lives);

  /// Whether the round ended on a bomb (as opposed to lost fruit or time).
  bool get bombed => _bombed;

  bool wasCut(int index) => _cut[index] && !_landed[index];

  /// The throws still in the air, for the board to draw.
  List<int> get airborne {
    final out = <int>[];
    for (var i = _settledTo; i < throws.length; i++) {
      final t = throws[i];
      if (t.enter > _tick) break;
      if (!_cut[i] && _tick < t.exit) out.add(i);
    }
    return out;
  }

  /// Throws that fell uncut since the last call.
  List<int> takeDrops() {
    final out = List<int>.of(_newDrops);
    _newDrops.clear();
    return out;
  }

  @override
  int get tickMs => config.tickMs;

  @override
  int get tick => _tick;

  @override
  int get score => _score;

  @override
  List<String> get moves => List.unmodifiable(_moves);

  @override
  bool get isOver => _over || _tick >= lastTick;

  @override
  bool get hasProgress => _moves.isNotEmpty;

  @override
  void advance() {
    if (isOver) return;
    _tick++;
    _settle();
  }

  void _settle() {
    for (var i = _settledTo; i < throws.length; i++) {
      final t = throws[i];
      if (t.enter > _tick) break;
      if (_cut[i] || t.exit > _tick) continue;
      _cut[i] = true;
      _landed[i] = true;
      if (!t.bomb) {
        _dropped++;
        _newDrops.add(i);
        if (_dropped >= config.lives) _over = true;
      }
    }
    while (_settledTo < throws.length && _cut[_settledTo]) {
      _settledTo++;
    }
  }

  /// Draws one piece of blade stroke [stroke] from (x1,y1) to (x2,y2) at the
  /// current tick. The piece is only logged when it cuts something. A swipe
  /// through thin air changes nothing, so the server needn't see it.
  List<FruitCut> slice(int stroke, int x1, int y1, int x2, int y2) {
    if (isOver || stroke < _stroke) return const [];
    final pad = config.width ~/ 2;
    int clampX(int x) => x.clamp(-pad, config.width + pad);
    int clampY(int y) => y.clamp(-pad, config.height + pad);
    x1 = clampX(x1);
    x2 = clampX(x2);
    y1 = clampY(y1);
    y2 = clampY(y2);

    final cuts = <FruitCut>[];
    var strokeRun = stroke == _stroke ? _strokeRun : 0;
    var strokeAt = stroke == _stroke ? _strokeAt : -1;
    var bombed = false;
    for (var i = _settledTo; i < throws.length; i++) {
      final t = throws[i];
      if (t.enter > _tick) break;
      if (_cut[i] || _tick >= t.exit) continue;
      final (cx, cy) = t.pos(_tick);
      if (!fruitSegmentHits(x1, y1, x2, y2, cx, cy, t.radius)) continue;
      if (t.bomb) {
        cuts.add(FruitCut(index: i, combo: 0, points: 0));
        bombed = true;
        break;
      }
      if (strokeAt < 0 || _tick - strokeAt > config.comboWindowTicks) {
        strokeRun = 0;
      }
      strokeRun++;
      strokeAt = _tick;
      cuts.add(
        FruitCut(
          index: i,
          combo: strokeRun,
          points: config.pointsPerFruit + config.comboBonus * (strokeRun - 1),
        ),
      );
    }
    if (cuts.isEmpty) return const [];

    // Something was cut: commit, exactly as the server will on replay.
    _moves.add('$_tick:$stroke:$x1:$y1:$x2:$y2');
    if (stroke != _stroke) _stroke = stroke;
    _strokeRun = strokeRun;
    _strokeAt = strokeAt;
    for (final cut in cuts) {
      _cut[cut.index] = true;
      if (throws[cut.index].bomb) continue;
      _sliced++;
      _score += cut.points;
      if (cut.combo > _bestCombo) _bestCombo = cut.combo;
    }
    if (bombed) {
      _over = true;
      _bombed = true;
    }
    return cuts;
  }
}
