/// Tick-driven Snake. A mirror of `internal/games/snake.go`.
///
/// The board only changes on numbered ticks. A turn is logged against the
/// tick it takes effect on, so the server can replay the exact same game from
/// the seed. The result depends on the player's decisions, not on how smooth
/// their phone is.
library;

import 'deterministic_rng.dart';
import 'game_engine.dart';

class SnakeConfig {
  const SnakeConfig({
    this.gridSize = 15,
    this.startLength = 3,
    this.tickMs = 300,
    this.minTickMs = 70,
    this.speedupMsPerFood = 12,
    this.speedupEveryTicks = 45,
    this.pointsPerFood = 10,
    this.maxTicks = 20000,
  });

  /// Mirrors the backend's `withDefaults`: missing or out-of-range values fall
  /// back the same way on both sides.
  factory SnakeConfig.fromJson(Map<String, dynamic> json) {
    int read(String key) {
      final value = json[key];
      return value is num ? value.toInt() : 0;
    }

    const d = SnakeConfig();
    var grid = read('grid_size');
    if (grid < 5) grid = d.gridSize;
    var startLength = read('start_length');
    if (startLength <= 0) startLength = d.startLength;
    final maxLength = grid ~/ 2 + 1;
    if (startLength > maxLength) startLength = maxLength;
    var tickMs = read('tick_ms');
    if (tickMs <= 0) tickMs = d.tickMs;
    var minTickMs = read('min_tick_ms');
    if (minTickMs <= 0) minTickMs = d.minTickMs;
    var speedup = read('speedup_ms_per_food');
    if (speedup < 0) speedup = 0;
    var drift = read('speedup_every_ticks');
    if (drift < 0) drift = 0;
    var points = read('points_per_food');
    if (points <= 0) points = d.pointsPerFood;
    var maxTicks = read('max_ticks');
    if (maxTicks <= 0) maxTicks = d.maxTicks;

    return SnakeConfig(
      gridSize: grid,
      startLength: startLength,
      tickMs: tickMs,
      minTickMs: minTickMs,
      speedupMsPerFood: speedup,
      speedupEveryTicks: drift,
      pointsPerFood: points,
      maxTicks: maxTicks,
    );
  }

  final int gridSize;
  final int startLength;
  final int tickMs;
  final int minTickMs;

  /// How many ticks pass before the snake quickens by a millisecond on its
  /// own. Zero leaves the pace to the gifts alone.
  final int speedupEveryTicks;
  final int speedupMsPerFood;
  final int pointsPerFood;
  final int maxTicks;
}

/// How long a tick lasts at this point in a round.
///
/// The snake starts at a walk and quickens two ways: every gift eaten takes a
/// few milliseconds off, and time itself takes one off every so often. Both
/// run down to the same floor, so a long round ends up at full pelt whether or
/// not the player is finding gifts.
///
/// The server works the pace out the same way and derives from it the least
/// time a round could have taken. If the two drifted apart, the faster of the
/// pair would have its scores thrown out for arriving too quickly. So this
/// mirrors `SnakeGame.TickIntervalMs` in internal/games/snake.go exactly.
int snakeTickIntervalMs(
  SnakeConfig config, {
  required int foods,
  required int ticks,
}) {
  var ms = config.tickMs - config.speedupMsPerFood * foods;
  if (config.speedupEveryTicks > 0) {
    ms -= ticks ~/ config.speedupEveryTicks;
  }
  return ms < config.minTickMs ? config.minTickMs : ms;
}

class SnakeGame implements GameEngine {
  SnakeGame({required String seed, SnakeConfig? config})
    : config = config ?? const SnakeConfig(),
      _rng = DeterministicRng.fromSeed(seed) {
    final c = this.config.gridSize ~/ 2;
    for (var i = 0; i < this.config.startLength; i++) {
      _body.add(c * this.config.gridSize + (c - i));
    }
    _spawnFood();
  }

  final SnakeConfig config;
  final DeterministicRng _rng;

  /// Head first; cell = y * size + x.
  final List<int> _body = <int>[];
  String _heading = Move.right;
  String? _pending;
  int _food = -1;
  int _foods = 0;
  int _score = 0;
  int _ticks = 0;
  bool _dead = false;
  bool _won = false;

  /// Turns in the order they took effect, as "tick:direction".
  final List<String> _turns = <String>[];

  int get gridSize => config.gridSize;
  List<int> get body => List<int>.unmodifiable(_body);
  int get food => _food;
  String get heading => _heading;
  int get foods => _foods;
  int get ticks => _ticks;
  bool get dead => _dead;
  bool get won => _won;

  @override
  int get score => _score;

  @override
  bool get isOver => _dead || _won || _ticks >= config.maxTicks;

  @override
  bool get hasProgress => _ticks > 0;

  /// The executed turns plus the end marker the server needs to know how many
  /// ticks to replay after the last turn.
  @override
  List<String> get moves => [..._turns, '$_ticks:end'];

  /// How long the next tick lasts. The snake speeds up as it eats.
  /// How long the next tick lasts.
  int get tickIntervalMs =>
      snakeTickIntervalMs(config, foods: _foods, ticks: _ticks);

  /// Queues a turn for the next tick. Going the way you already are, or
  /// reversing into yourself, is ignored. Exactly as the server ignores it.
  bool turn(String dir) {
    if (isOver || !Move.isDirection(dir)) return false;
    if (dir == _heading || dir == Move.opposite(_heading)) return false;
    _pending = dir;
    return true;
  }

  /// Advances one tick. A queued turn is only logged once it takes effect, so
  /// the log never names a tick that was not played.
  void step() {
    if (isOver) return;

    final pending = _pending;
    if (pending != null) {
      _turns.add('$_ticks:$pending');
      _heading = pending;
      _pending = null;
    }
    _ticks++;

    final size = config.gridSize;
    final head = _body.first;
    final (dx, dy) = Move.delta(_heading);
    final nx = head % size + dx;
    final ny = head ~/ size + dy;
    if (nx < 0 || ny < 0 || nx >= size || ny >= size) {
      _dead = true;
      return;
    }
    final next = ny * size + nx;
    final eating = next == _food;

    // The tail moves out of the way this tick unless the snake is growing.
    var limit = _body.length;
    if (!eating) limit--;
    for (var i = 0; i < limit; i++) {
      if (_body[i] == next) {
        _dead = true;
        return;
      }
    }

    _body.insert(0, next);
    if (eating) {
      _foods++;
      _score += config.pointsPerFood;
      _spawnFood();
    } else {
      _body.removeLast();
    }
  }

  /// Food goes on a random empty cell, scanning cells in ascending order just
  /// as the server does.
  void _spawnFood() {
    final occupied = _body.toSet();
    final total = config.gridSize * config.gridSize;
    final empties = <int>[
      for (var i = 0; i < total; i++)
        if (!occupied.contains(i)) i,
    ];
    if (empties.isEmpty) {
      _food = -1;
      _won = true;
      return;
    }
    _food = empties[_rng.nextInt(empties.length)];
  }
}
