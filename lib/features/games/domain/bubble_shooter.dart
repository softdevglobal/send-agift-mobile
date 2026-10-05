import 'dart:ui' show Offset;

import 'deterministic_rng.dart';
import 'game_engine.dart';

/// Bubble Shooter rules, read from the config the server issues.
class BubbleConfig {
  const BubbleConfig({
    this.columns = 7,
    this.rows = 11,
    this.startRows = 4,
    this.colors = 4,
    this.minCluster = 3,
    this.pointsPerBubble = 10,
    this.comboBonus = 5,
    this.maxShots = 200,
  });

  final int columns;
  final int rows;
  final int startRows;
  final int colors;
  final int minCluster;
  final int pointsPerBubble;
  final int comboBonus;
  final int maxShots;

  factory BubbleConfig.fromJson(Map<String, dynamic> json) {
    const d = BubbleConfig();
    int pick(String key, int fallback) {
      final value = readConfigInt(json, key);
      return value > 0 ? value : fallback;
    }

    final rows = pick('rows', d.rows);
    var startRows = pick('start_rows', d.startRows);
    if (startRows >= rows) startRows = rows - 1;
    return BubbleConfig(
      columns: pick('columns', d.columns),
      rows: rows,
      startRows: startRows,
      colors: pick('colors', d.colors),
      minCluster: pick('min_cluster', d.minCluster),
      pointsPerBubble: pick('points_per_bubble', d.pointsPerBubble),
      comboBonus: pick('combo_bonus', d.comboBonus),
      maxShots: pick('max_shots', d.maxShots),
    );
  }
}

/// One point along a shot's flight, in cell coordinates, for drawing the aim.
class BubbleTrace {
  const BubbleTrace({required this.path, required this.row, required this.col, required this.ok});

  /// The flight in cells: x across, y down, both fractional.
  final List<Offset> path;

  /// The cell the bubble comes to rest in, when [ok].
  final int row;
  final int col;

  /// False when the shot has nowhere to land, which means the wall has won.
  final bool ok;
}

/// Fixed-point units used to fly a shot. These mirror `bubble.go`. The flight
/// has to be integer arithmetic, because a float could round differently here
/// than on the server and put the bubble in another cell.
const _bubbleScale = 1000;
const _bubbleStep = 100;
const bubbleMaxAim = 4000;
const _bubbleMaxSteps = 20000;

/// The log entry for exchanging the two queued colours.
const bubbleSwapMove = 's';

/// Bubble Shooter: aim the loaded colour anywhere across the board and fire.
/// The bubble flies until it meets the wall or the ceiling, banking off the
/// sides on the way. Landing it against enough of its own colour pops the
/// cluster, and anything left unsupported falls with it. Which is where the
/// chains come from. Two colours are queued and may be swapped.
///
/// Mirrors `internal/games/bubble.go` exactly.
class BubbleShooter implements GameEngine {
  BubbleShooter({required String seed, required this.config})
    : _rng = DeterministicRng.fromSeed(seed) {
    _grid = List.generate(
      config.rows,
      (_) => List<int>.filled(config.columns, -1),
    );
    for (var r = 0; r < config.startRows; r++) {
      for (var c = 0; c < config.columns; c++) {
        _grid[r][c] = _rng.nextInt(config.colors);
      }
    }
    _next = _rng.nextInt(config.colors);
    _after = _rng.nextInt(config.colors);
  }

  final BubbleConfig config;
  final DeterministicRng _rng;
  late final List<List<int>> _grid;
  final List<String> _moves = [];

  int _next = 0;
  int _after = 0;
  int _shots = 0;
  int _swaps = 0;
  int _pops = 0;
  int _bestCombo = 0;
  int _score = 0;
  bool _over = false;

  /// The colour loaded and ready to fire.
  int get next => _next;

  /// The colour queued behind it, which can be swapped in.
  int get after => _after;
  int get pops => _pops;
  int get shots => _shots;
  int get bestCombo => _bestCombo;

  /// The colour in a cell, or -1 when empty.
  int at(int row, int col) {
    if (row < 0 || row >= config.rows || col < 0 || col >= config.columns) {
      return -1;
    }
    return _grid[row][col];
  }

  /// Holds an aim inside what the engine accepts, so a wild drag means the
  /// same thing here as it will on the server.
  static int clampAim(int dx) {
    if (dx > bubbleMaxAim) return bubbleMaxAim;
    if (dx < -bubbleMaxAim) return -bubbleMaxAim;
    return dx;
  }

  /// Flies a shot aimed at [dx] sideways per 1000 units of rise and reports
  /// where it lands, along with the path it took so the aim can be drawn.
  ///
  /// The arithmetic matches `BubbleGame.Trace` step for step, so the line the
  /// player sees is the flight the server will replay.
  BubbleTrace trace(int dx) {
    dx = clampAim(dx);
    const dy = -_bubbleScale;

    var m = dx.abs();
    if (_bubbleScale > m) m = _bubbleScale;
    var sx = dx * _bubbleStep ~/ m;
    var sy = dy * _bubbleStep ~/ m;

    final width = config.columns * _bubbleScale;
    var x = width ~/ 2;
    var y = config.rows * _bubbleScale;

    final path = <Offset>[Offset(x / _bubbleScale, y / _bubbleScale)];
    var lastRow = -1;
    var lastCol = -1;
    var haveLast = false;

    for (var step = 0; step < _bubbleMaxSteps; step++) {
      x += sx;
      y += sy;

      while (x < 0 || x >= width) {
        if (x < 0) x = -x;
        if (x >= width) x = 2 * (width - 1) - x;
        sx = -sx;
        path.add(Offset(x / _bubbleScale, y / _bubbleScale));
      }

      if (y <= 0) {
        var c = x ~/ _bubbleScale;
        if (c < 0) c = 0;
        if (c >= config.columns) c = config.columns - 1;
        if (_grid[0][c] < 0) {
          path.add(Offset(c + 0.5, 0.5));
          return BubbleTrace(path: path, row: 0, col: c, ok: true);
        }
        if (haveLast) {
          path.add(Offset(lastCol + 0.5, lastRow + 0.5));
          return BubbleTrace(path: path, row: lastRow, col: lastCol, ok: true);
        }
        return BubbleTrace(path: path, row: 0, col: 0, ok: false);
      }

      final r = y ~/ _bubbleScale;
      final c = x ~/ _bubbleScale;
      if (r < 0 || r >= config.rows || c < 0 || c >= config.columns) continue;
      if (_grid[r][c] >= 0) {
        if (haveLast) {
          path.add(Offset(lastCol + 0.5, lastRow + 0.5));
          return BubbleTrace(path: path, row: lastRow, col: lastCol, ok: true);
        }
        return BubbleTrace(path: path, row: 0, col: 0, ok: false);
      }
      lastRow = r;
      lastCol = c;
      haveLast = true;
    }

    if (haveLast) {
      return BubbleTrace(path: path, row: lastRow, col: lastCol, ok: true);
    }
    return BubbleTrace(path: path, row: 0, col: 0, ok: false);
  }

  @override
  int get score => _score;

  @override
  List<String> get moves => List.unmodifiable(_moves);

  @override
  bool get isOver => _over || _shots >= config.maxShots;

  @override
  bool get hasProgress => _moves.isNotEmpty;

  /// Exchanges the loaded colour with the one behind it. Nothing new is drawn
  /// from the seed, so swapping can never fish for a better colour.
  bool swap() {
    if (isOver || _swaps >= config.maxShots) return false;
    final held = _next;
    _next = _after;
    _after = held;
    _swaps++;
    _moves.add(bubbleSwapMove);
    return true;
  }

  /// Fires the loaded colour at an aim of [dx] sideways per 1000 of rise.
  /// Returns the cells that popped, so the board can show them bursting.
  List<List<int>> shoot(int dx) {
    if (isOver) return const [];
    dx = clampAim(dx);

    final shot = trace(dx);
    _moves.add('$dx');
    _shots++;
    if (!shot.ok) {
      _over = true;
      return const [];
    }

    final row = shot.row;
    final col = shot.col;
    _grid[row][col] = _next;

    var burst = <List<int>>[];
    final group = _cluster(row, col);
    if (group.length >= config.minCluster) {
      for (final cell in group) {
        _grid[cell[0]][cell[1]] = -1;
      }
      burst = [...group];
      final dropped = _dropFloaters(burst);
      final popped = group.length + dropped;
      _pops += popped;
      final combo = popped ~/ config.minCluster;
      if (combo > _bestCombo) _bestCombo = combo;
      _score += popped * config.pointsPerBubble + config.comboBonus * combo;
    }

    for (var c = 0; c < config.columns; c++) {
      if (_grid[config.rows - 1][c] >= 0) {
        _over = true;
        break;
      }
    }

    _next = _after;
    _after = _rng.nextInt(config.colors);
    return burst;
  }

  /// Every cell of one colour reachable from a starting cell.
  List<List<int>> _cluster(int row, int col) {
    final color = at(row, col);
    if (color < 0) return const [];
    final seen = <String>{'$row,$col'};
    final queue = <List<int>>[
      [row, col],
    ];
    final out = <List<int>>[
      [row, col],
    ];
    while (queue.isNotEmpty) {
      final cell = queue.removeAt(0);
      for (final step in const [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ]) {
        final nr = cell[0] + step[0];
        final nc = cell[1] + step[1];
        final key = '$nr,$nc';
        if (seen.contains(key) || at(nr, nc) != color) continue;
        seen.add(key);
        queue.add([nr, nc]);
        out.add([nr, nc]);
      }
    }
    return out;
  }

  /// Clears anything no longer hanging from the ceiling, which is what turns
  /// a pop into a cascade instead of leaving islands.
  int _dropFloaters(List<List<int>> burst) {
    final attached = List.generate(
      config.rows,
      (_) => List<bool>.filled(config.columns, false),
    );
    final queue = <List<int>>[];
    for (var c = 0; c < config.columns; c++) {
      if (_grid[0][c] >= 0) {
        attached[0][c] = true;
        queue.add([0, c]);
      }
    }
    while (queue.isNotEmpty) {
      final cell = queue.removeAt(0);
      for (final step in const [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ]) {
        final nr = cell[0] + step[0];
        final nc = cell[1] + step[1];
        if (nr < 0 || nr >= config.rows || nc < 0 || nc >= config.columns) {
          continue;
        }
        if (attached[nr][nc] || _grid[nr][nc] < 0) continue;
        attached[nr][nc] = true;
        queue.add([nr, nc]);
      }
    }

    var dropped = 0;
    for (var r = 0; r < config.rows; r++) {
      for (var c = 0; c < config.columns; c++) {
        if (_grid[r][c] >= 0 && !attached[r][c]) {
          _grid[r][c] = -1;
          burst.add([r, c]);
          dropped++;
        }
      }
    }
    return dropped;
  }
}
