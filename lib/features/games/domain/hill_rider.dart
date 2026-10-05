/// Hill Rider. A mirror of `internal/games/hillrider.go`.
///
/// Drive as far as you can over rolling hills. Crest a hill too fast and
/// the car takes off; land at an angle that does not match the ground and it
/// crashes. Gas burns fuel; cans along the way refill the tank. Every
/// quantity is a whole number stepped on fixed ticks. Positions and speeds
/// in sixteenths of a unit, heights in whole units. So the server replays
/// the drive exactly.
library;

import 'deterministic_rng.dart';
import 'game_engine.dart';

class HillConfig {
  const HillConfig({
    this.tickMs = 20,
    this.knotSpacing = 200,
    this.knots = 600,
    this.hillAmp = 220,
    this.hillRamp = 7,
    this.startFuel = 800,
    this.fuelCanEvery = 16,
    this.engine = 4,
    this.brake = 4,
    this.slopeGravity = 4,
    this.airGravity = 3,
    this.friction = 1,
    this.maxSpeed = 150,
    this.launchK = 1000000,
    this.crashSlope = 130,
    this.maxTicks = 30000,
  });

  /// Mirrors the backend's `withDefaults`.
  factory HillConfig.fromJson(Map<String, dynamic> json) {
    const d = HillConfig();
    int read(String key, int fallback) {
      final v = readConfigInt(json, key);
      return v <= 0 ? fallback : v;
    }

    var knots = readConfigInt(json, 'knots');
    if (knots < 10) knots = d.knots;
    return HillConfig(
      tickMs: read('tick_ms', d.tickMs),
      knotSpacing: read('knot_spacing', d.knotSpacing),
      knots: knots,
      hillAmp: read('hill_amp', d.hillAmp),
      hillRamp: read('hill_ramp', d.hillRamp),
      startFuel: read('start_fuel', d.startFuel),
      fuelCanEvery: read('fuel_can_every', d.fuelCanEvery),
      engine: read('engine', d.engine),
      brake: read('brake', d.brake),
      slopeGravity: read('slope_gravity', d.slopeGravity),
      airGravity: read('air_gravity', d.airGravity),
      friction: read('friction', d.friction),
      maxSpeed: read('max_speed', d.maxSpeed),
      launchK: read('launch_k', d.launchK),
      crashSlope: read('crash_slope', d.crashSlope),
      maxTicks: read('max_ticks', d.maxTicks),
    );
  }

  final int tickMs;
  final int knotSpacing;
  final int knots;

  /// The biggest rise or fall between two knots, and how fast the course
  /// grows to it from the flat start.
  final int hillAmp;
  final int hillRamp;
  final int startFuel;
  final int fuelCanEvery;
  final int engine;
  final int brake;
  final int slopeGravity;
  final int airGravity;
  final int friction;
  final int maxSpeed;
  final int launchK;
  final int crashSlope;
  final int maxTicks;
}

/// Pedal states, as logged.
class HillPedal {
  HillPedal._();

  static const String gas = 'g';
  static const String brake = 'b';
  static const String neutral = 'n';
}

class HillRider implements TickGame {
  HillRider({required String seed, HillConfig? config})
    : config = config ?? const HillConfig() {
    final c = this.config;
    final rng = DeterministicRng.fromSeed(seed);
    _heights = List<int>.filled(c.knots, 0);
    for (var i = 3; i < c.knots; i++) {
      var amp = 24 + i * c.hillRamp;
      if (amp > c.hillAmp) amp = c.hillAmp;
      var delta = rng.nextInt(2 * amp + 1) - amp;
      if ((_heights[i - 1] + delta).abs() > 1200) delta = -delta;
      _heights[i] = _heights[i - 1] + delta;
    }
    _fuel = c.startFuel;
  }

  final HillConfig config;
  late final List<int> _heights;

  int _x = 0;
  int _y = 0;
  int _v = 0;
  int _vy = 0;
  bool _airborne = false;
  String _input = HillPedal.neutral;
  String? _pending;
  late int _fuel;
  int _nextCan = 0;
  int _cans = 0;
  int _maxX = 0;
  int _airTicks = 0;
  int _ticks = 0;
  bool _crashed = false;
  bool _finished = false;

  /// Ticks shown after the drive ended, so a crash can be watched.
  int _after = 0;
  final List<String> _log = <String>[];

  @override
  int get tickMs => config.tickMs;

  @override
  int get tick => _ticks;

  @override
  int get score => distance + _airTicks ~/ 5;

  @override
  bool get hasProgress => _ticks > 0;

  /// The pedal changes plus the end marker telling the server how many
  /// ticks to replay after the last one.
  @override
  List<String> get moves => [..._log, '$_ticks:end'];

  @override
  bool get isOver => driveOver && _after >= lingerTicks;

  /// Ticks the scene keeps running after the drive ends, before the round
  /// does: long enough to watch a crash play out, shorter for running dry.
  int get lingerTicks => _crashed ? 90 : 45;

  bool get driveOver =>
      _crashed ||
      _finished ||
      _ticks >= config.maxTicks ||
      (_fuel == 0 && _v == 0 && !_airborne);

  /// Chooses the pedal from the next tick on. Only a change that actually
  /// takes effect is logged.
  void setPedal(String pedal) {
    if (!driveOver) _pending = pedal;
  }

  @override
  void advance() {
    if (driveOver) {
      _after++;
      return;
    }
    final pending = _pending;
    if (pending != null) {
      if (pending != _input) {
        _log.add('$_ticks:$pending');
        _input = pending;
      }
      _pending = null;
    }
    _step();
  }

  // ─── What the view needs ───────────────────────────────────────────────

  /// Position and height in whole units.
  double get x => _x / 16;
  double get y => _y / 16;
  int get speed => _v;
  int get verticalSpeed => _vy;
  bool get airborne => _airborne;
  bool get crashed => _crashed;
  bool get finished => _finished;
  int get fuel => _fuel;
  int get cans => _cans;
  int get airTicks => _airTicks;
  String get pedal => _pending ?? _input;

  /// The furthest the car got, in metres (10 units a metre).
  int get distance => _maxX ~/ 16 ~/ 10;

  /// Where fuel can [k] stands, in units.
  int canX(int k) => (k + 1) * config.fuelCanEvery * config.knotSpacing;
  int get nextCan => _nextCan;
  List<int> get heights => _heights;

  int _segment(int x) {
    var i = x ~/ 16 ~/ config.knotSpacing;
    if (i > config.knots - 2) i = config.knots - 2;
    return i;
  }

  int _slope(int i) => _heights[i + 1] - _heights[i];

  /// Ground height, in units, at [xu] units.
  int heightAt(int xu) {
    final s = config.knotSpacing;
    final i = xu ~/ s;
    if (i >= config.knots - 1) return _heights[config.knots - 1];
    return _heights[i] + (_heights[i + 1] - _heights[i]) * (xu - i * s) ~/ s;
  }

  int _groundY(int x) => heightAt(x ~/ 16) * 16;

  static int _towardZero(int v, int by) {
    if (v > by) return v - by;
    if (v < -by) return v + by;
    return 0;
  }

  void _step() {
    final c = config;
    _ticks++;

    var accel = 0;
    if (_input == HillPedal.gas && _fuel > 0) {
      accel = c.engine;
      _fuel--;
    }

    if (!_airborne) {
      final seg = _segment(_x);
      final s = _slope(seg);
      _v += accel - (c.slopeGravity * s) ~/ c.knotSpacing - _v ~/ 64;
      if (accel == 0) _v = _towardZero(_v, c.friction);
      if (_input == HillPedal.brake) _v = _towardZero(_v, c.brake);
      if (_v > c.maxSpeed) _v = c.maxSpeed;
      if (_v < -c.maxSpeed) _v = -c.maxSpeed;
      _x += _v;
      if (_x < 0) {
        _x = 0;
        _v = 0;
      }
      final next = _segment(_x);
      if (next > seg && _v > 0) {
        final drop = s - _slope(next);
        if (drop > 0 && _v * _v * drop > c.launchK) {
          _airborne = true;
          _vy = _v * s ~/ c.knotSpacing;
        }
      }
      if (!_airborne) _y = _groundY(_x);
    } else {
      _airTicks++;
      _vy -= c.airGravity;
      _x += _v;
      _y += _vy;
      final ground = _groundY(_x);
      if (_y <= ground) {
        final v = _v < 1 ? 1 : _v;
        final flight = _vy * c.knotSpacing ~/ v;
        if ((flight - _slope(_segment(_x))).abs() > c.crashSlope) {
          _crashed = true;
        } else {
          _airborne = false;
          _y = ground;
          _v = _v * 7 ~/ 8;
        }
      }
    }

    while (_x ~/ 16 >= (_nextCan + 1) * c.fuelCanEvery * c.knotSpacing) {
      _nextCan++;
      _cans++;
      _fuel = c.startFuel;
    }
    if (_x > _maxX) _maxX = _x;
    if (_x ~/ 16 >= (c.knots - 1) * c.knotSpacing) _finished = true;
  }
}
