/// Sling Shot. A mirror of `internal/games/sling.go`.
///
/// Pull back the sling and knock the target blocks off their structure.
/// Wood breaks and slows the shot, stone stops it, and anything left
/// unsupported falls. Far enough, and it breaks. The flight and the
/// collapse are integer physics, so the server replays exactly the shot the
/// player took.
library;

import 'deterministic_rng.dart';
import 'game_engine.dart';

class SlingConfig {
  const SlingConfig({
    this.tickMs = 20,
    this.levels = 8,
    this.shotsPerLevel = 3,
    this.gravity = 6,
    this.launchScale = 3,
    this.maxPull = 100,
    this.maxFlightTicks = 360,
    this.targetPoints = 500,
    this.woodPoints = 50,
    this.shotBonus = 300,
  });

  /// Mirrors the backend's `withDefaults`.
  factory SlingConfig.fromJson(Map<String, dynamic> json) {
    const d = SlingConfig();
    int read(String key, int fallback) {
      final v = readConfigInt(json, key);
      return v <= 0 ? fallback : v;
    }

    return SlingConfig(
      tickMs: read('tick_ms', d.tickMs),
      levels: read('levels', d.levels),
      shotsPerLevel: read('shots_per_level', d.shotsPerLevel),
      gravity: read('gravity', d.gravity),
      launchScale: read('launch_scale', d.launchScale),
      maxPull: read('max_pull', d.maxPull),
      maxFlightTicks: read('max_flight_ticks', d.maxFlightTicks),
      targetPoints: read('target_points', d.targetPoints),
      woodPoints: read('wood_points', d.woodPoints),
      shotBonus: read('shot_bonus', d.shotBonus),
    );
  }

  final int tickMs;
  final int levels;
  final int shotsPerLevel;
  final int gravity;
  final int launchScale;
  final int maxPull;
  final int maxFlightTicks;
  final int targetPoints;
  final int woodPoints;
  final int shotBonus;
}

/// One block: T target, W wood, S stone.
class SlingBlock {
  SlingBlock({
    required this.id,
    required this.x,
    required this.y,
    required this.kind,
    this.alive = true,
  });

  final int id;
  final int x;
  int y;
  final String kind;
  bool alive;

  int get w => SlingShot.cell;
  int get h => SlingShot.cell;

  SlingBlock copy() => SlingBlock(id: id, x: x, y: y, kind: kind, alive: alive);
}

/// The shot hit a block during its flight.
class SlingHit {
  const SlingHit(this.tick, this.blockId, this.broke);

  final int tick;
  final int blockId;
  final bool broke;
}

/// A block fell once the shot was over.
class SlingFall {
  const SlingFall(this.blockId, this.fromY, this.toY, this.broke);

  final int blockId;
  final int fromY;
  final int toY;
  final bool broke;
}

/// Everything the board needs to replay one shot on screen.
class SlingShotResult {
  const SlingShotResult({
    required this.path,
    required this.hits,
    required this.falls,
    required this.blocksBefore,
    required this.points,
    required this.levelCleared,
    required this.bonus,
  });

  /// The projectile per tick, in sixteenths of a unit.
  final List<(int, int)> path;
  final List<SlingHit> hits;
  final List<SlingFall> falls;

  /// The structure as it stood when the shot was taken.
  final List<SlingBlock> blocksBefore;
  final int points;
  final bool levelCleared;
  final int bonus;
}

class SlingShot implements GameEngine {
  SlingShot({required String seed, SlingConfig? config})
    : config = config ?? const SlingConfig(),
      _rng = DeterministicRng.fromSeed(seed) {
    _buildLevel();
  }

  static const int cell = 50;
  static const int radius = 14;
  static const int startX = 100;
  static const int startY = 150;
  static const int worldWidth = 1000;

  /// Structures, rows top to bottom. The same list, in the same order, as
  /// `slingTemplates` on the backend.
  static const List<List<String>> templates = [
    ['.T.', '.W.', 'WWW'],
    ['T.T', 'W.W', 'WSW'],
    ['.T.', 'WTW', 'WWW', 'W.W'],
    ['..T..', '.WWW.', '.W.W.', 'SW.WS'],
    ['T...T', 'S...S', 'S.T.S', 'SSSSS'],
    ['...T...', '..WWW..', '.WTWTW.', 'SSSSSSS'],
  ];

  final SlingConfig config;
  final DeterministicRng _rng;

  int _level = 0;
  int _cleared = 0;
  int _shotsLeft = 0;
  int _shots = 0;
  int _targets = 0;
  List<SlingBlock> _blocks = <SlingBlock>[];
  int _score = 0;
  bool _over = false;
  bool _won = false;
  final List<String> _log = <String>[];

  void _buildLevel() {
    var choices = _level + 2;
    if (choices > templates.length) choices = templates.length;
    final tpl = templates[_rng.nextInt(choices)];
    final width = tpl[0].length * cell;
    final baseX = 980 - width - _rng.nextInt(4) * 30;
    final blocks = <SlingBlock>[];
    var id = 0;
    for (var r = 0; r < tpl.length; r++) {
      final y = (tpl.length - 1 - r) * cell;
      final row = tpl[r];
      for (var c = 0; c < row.length; c++) {
        if (row[c] == '.') continue;
        blocks.add(SlingBlock(id: id, x: baseX + c * cell, y: y, kind: row[c]));
        id++;
      }
    }
    _blocks = blocks;
    _shotsLeft = config.shotsPerLevel;
  }

  @override
  int get score => _score;

  @override
  bool get isOver => _over;

  @override
  bool get hasProgress => _shots > 0;

  @override
  List<String> get moves => List<String>.unmodifiable(_log);

  List<SlingBlock> get blocks => _blocks;
  int get level => _level;
  int get levelsCleared => _cleared;
  int get shotsLeft => _shotsLeft;
  int get shots => _shots;
  int get targets => _targets;
  bool get won => _won;

  int get targetsLeft => _blocks.where((b) => b.alive && b.kind == 'T').length;

  bool validPull(int dx, int dy) =>
      dx >= 1 &&
      dy.abs() <= config.maxPull &&
      dx * dx + dy * dy <= config.maxPull * config.maxPull;

  bool _collides(SlingBlock b, int px, int py) =>
      px >= (b.x - radius) * 16 &&
      px <= (b.x + b.w + radius) * 16 &&
      py >= (b.y - radius) * 16 &&
      py <= (b.y + b.h + radius) * 16;

  int _destroy(SlingBlock b) {
    b.alive = false;
    switch (b.kind) {
      case 'T':
        _score += config.targetPoints;
        _targets++;
        return config.targetPoints;
      case 'W':
        _score += config.woodPoints;
        return config.woodPoints;
    }
    return 0;
  }

  /// The launch path for a pull, for the aiming preview. Does not change
  /// the game.
  List<(int, int)> previewPath(int dx, int dy, int ticks) {
    var px = startX * 16;
    var py = startY * 16;
    var vx = dx * config.launchScale;
    var vy = dy * config.launchScale;
    final out = <(int, int)>[];
    for (var t = 0; t < ticks; t++) {
      vy -= config.gravity;
      px += vx;
      py += vy;
      out.add((px, py));
    }
    return out;
  }

  /// Launches with velocity ([dx], [dy]); up is positive [dy]. Null when
  /// the pull is not one the sling can make or the game is over.
  SlingShotResult? shoot(int dx, int dy) {
    if (_over || !validPull(dx, dy)) return null;
    final before = [for (final b in _blocks) b.copy()];
    final scoreBefore = _score;

    var px = startX * 16;
    var py = startY * 16;
    var vx = dx * config.launchScale;
    var vy = dy * config.launchScale;
    final path = <(int, int)>[];
    final hits = <SlingHit>[];
    for (var t = 0; t < config.maxFlightTicks; t++) {
      vy -= config.gravity;
      px += vx;
      py += vy;
      path.add((px, py));

      var stop = false;
      for (final b in _blocks) {
        if (!b.alive || !_collides(b, px, py)) continue;
        switch (b.kind) {
          case 'T':
            _destroy(b);
            vx = vx * 3 ~/ 4;
            vy = vy * 3 ~/ 4;
            hits.add(SlingHit(t, b.id, true));
          case 'W':
            _destroy(b);
            vx = vx ~/ 2;
            vy = vy ~/ 2;
            hits.add(SlingHit(t, b.id, true));
          default:
            stop = true;
            hits.add(SlingHit(t, b.id, false));
        }
        break;
      }
      if (stop ||
          py <= radius * 16 ||
          px > 1100 * 16 ||
          px < -100 * 16 ||
          vx.abs() + vy.abs() < 8) {
        break;
      }
    }

    final falls = _collapse();
    _shots++;
    _shotsLeft--;
    _log.add('$dx:$dy');

    var bonus = 0;
    var cleared = false;
    if (targetsLeft == 0) {
      cleared = true;
      bonus = config.shotBonus * _shotsLeft;
      _score += bonus;
      _cleared++;
      _level++;
      if (_level >= config.levels) {
        _won = true;
        _over = true;
      } else {
        _buildLevel();
      }
    } else if (_shotsLeft == 0) {
      _over = true;
    }

    return SlingShotResult(
      path: path,
      hits: hits,
      falls: falls,
      blocksBefore: before,
      points: _score - scoreBefore,
      levelCleared: cleared,
      bonus: bonus,
    );
  }

  /// Every unsupported block falls onto whatever is below it, lowest first,
  /// until nothing moves.
  List<SlingFall> _collapse() {
    final falls = <SlingFall>[];
    var changed = true;
    while (changed) {
      changed = false;
      for (final i in _byHeight()) {
        final b = _blocks[i];
        if (!b.alive) continue;
        var support = 0;
        for (var j = 0; j < _blocks.length; j++) {
          final o = _blocks[j];
          if (j == i || !o.alive || o.x >= b.x + b.w || o.x + o.w <= b.x) {
            continue;
          }
          final top = o.y + o.h;
          if (top <= b.y && top > support) support = top;
        }
        if (support < b.y) {
          final fall = b.y - support;
          final from = b.y;
          b.y = support;
          changed = true;
          final broke =
              (b.kind == 'T' && fall >= cell ~/ 2) ||
              (b.kind == 'W' && fall >= cell);
          if (broke) _destroy(b);
          falls.add(SlingFall(b.id, from, support, broke));
        }
      }
    }
    return falls;
  }

  /// Alive block indices, lowest first, then left to right. The same
  /// insertion sort as the backend.
  List<int> _byHeight() {
    final order = <int>[
      for (var i = 0; i < _blocks.length; i++)
        if (_blocks[i].alive) i,
    ];
    for (var i = 1; i < order.length; i++) {
      for (var j = i; j > 0; j--) {
        final a = _blocks[order[j - 1]];
        final b = _blocks[order[j]];
        if (a.y < b.y || (a.y == b.y && a.x <= b.x)) break;
        final tmp = order[j - 1];
        order[j - 1] = order[j];
        order[j] = tmp;
      }
    }
    return order;
  }
}
