/// The sliding-tile puzzle. A mirror of `internal/games/slide.go`.
///
/// Perfect information: every tile is visible from the first move. The
/// scramble is built by playing legal moves from the solved board, so every
/// seed is solvable. Moves name the direction a TILE travels into the gap.
library;

import 'deterministic_rng.dart';
import 'game_engine.dart';

class SlideConfig {
  const SlideConfig({
    this.size = 4,
    this.shuffleMoves = 140,
    this.solveBase = 14000,
    this.movePenalty = 20,
    this.solvedMinScore = 1000,
    this.maxMoves = 3000,
  });

  /// Mirrors the backend's `withDefaults`.
  factory SlideConfig.fromJson(Map<String, dynamic> json) {
    int read(String key) {
      final value = json[key];
      return value is num ? value.toInt() : 0;
    }

    const d = SlideConfig();
    var size = read('size');
    if (size < 2) size = d.size;
    var shuffle = read('shuffle_moves');
    if (shuffle <= 0) shuffle = d.shuffleMoves;
    var solveBase = read('solve_base');
    if (solveBase <= 0) solveBase = d.solveBase;
    var penalty = read('move_penalty');
    if (penalty < 0) penalty = 0;
    var minScore = read('solved_min_score');
    if (minScore < 0) minScore = 0;
    var maxMoves = read('max_moves');
    if (maxMoves <= 0) maxMoves = d.maxMoves;

    return SlideConfig(
      size: size,
      shuffleMoves: shuffle,
      solveBase: solveBase,
      movePenalty: penalty,
      solvedMinScore: minScore,
      maxMoves: maxMoves,
    );
  }

  final int size;
  final int shuffleMoves;
  final int solveBase;
  final int movePenalty;
  final int solvedMinScore;
  final int maxMoves;
}

class SlidePuzzle implements GameEngine {
  SlidePuzzle({required String seed, SlideConfig? config})
    : config = config ?? const SlideConfig() {
    final n = this.config.size * this.config.size;
    _board = List<int>.generate(n, (i) => i == n - 1 ? 0 : i + 1);
    _blank = n - 1;

    final rng = DeterministicRng.fromSeed(seed);
    var prev = '';
    // Keep going past shuffle_moves if the scramble happened to land solved.
    for (var i = 0; i < this.config.shuffleMoves || solved; i++) {
      final legal = <String>[
        for (final d in Move.all)
          // Never undo the previous scramble move; it wastes the step.
          if (d != Move.opposite(prev) && _tileFor(d) >= 0) d,
      ];
      final d = legal[rng.nextInt(legal.length)];
      _slide(d);
      prev = d;
    }
  }

  final SlideConfig config;
  late final List<int> _board;
  late int _blank;
  final List<String> _moves = <String>[];

  int get size => config.size;

  /// Row-major; 0 is the gap.
  List<int> get board => List<int>.unmodifiable(_board);

  int get blank => _blank;

  @override
  List<String> get moves => List<String>.unmodifiable(_moves);

  @override
  bool get hasProgress => _moves.isNotEmpty;

  @override
  bool get isOver => solved || _moves.length >= config.maxMoves;

  bool get solved {
    final last = _board.length - 1;
    for (var i = 0; i < last; i++) {
      if (_board[i] != i + 1) return false;
    }
    return _board[last] == 0;
  }

  int get tilesInPlace {
    var count = 0;
    for (var i = 0; i < _board.length - 1; i++) {
      if (_board[i] == i + 1) count++;
    }
    return count;
  }

  /// Only a solved board scores: fewer moves, more points.
  @override
  int get score {
    if (!solved) return 0;
    final s = config.solveBase - config.movePenalty * _moves.length;
    return s < config.solvedMinScore ? config.solvedMinScore : s;
  }

  /// The cell holding the tile that would travel in [dir], or -1.
  int _tileFor(String dir) {
    final (dx, dy) = Move.delta(dir);
    // The tile sits on the far side of the gap from where it is heading.
    final tx = _blank % size - dx;
    final ty = _blank ~/ size - dy;
    if (tx < 0 || ty < 0 || tx >= size || ty >= size) return -1;
    return ty * size + tx;
  }

  void _slide(String dir) {
    final t = _tileFor(dir);
    _board[_blank] = _board[t];
    _board[t] = 0;
    _blank = t;
  }

  /// Slides one tile. Returns false when nothing can move that way.
  bool move(String dir) {
    if (isOver || !Move.isDirection(dir) || _tileFor(dir) < 0) return false;
    _slide(dir);
    _moves.add(dir);
    return true;
  }

  /// Handles a tap: any tile in line with the gap slides towards it, pushing
  /// the tiles between along. Each single-tile step is logged separately,
  /// because that is what the server replays.
  bool moveTileAt(int index) {
    if (isOver || index == _blank) return false;
    final tr = index ~/ size;
    final tc = index % size;
    final br = _blank ~/ size;
    final bc = _blank % size;

    final String dir;
    final int steps;
    if (tc == bc) {
      dir = tr > br ? Move.up : Move.down;
      steps = (tr - br).abs();
    } else if (tr == br) {
      dir = tc > bc ? Move.left : Move.right;
      steps = (tc - bc).abs();
    } else {
      return false;
    }

    var moved = false;
    for (var i = 0; i < steps; i++) {
      moved = move(dir) || moved;
    }
    return moved;
  }
}
