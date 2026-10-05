/// The deterministic 2048 engine.
///
/// This file is a line-for-line mirror of `internal/games/game2048.go` on the
/// backend. When a game ends the app sends only the moves that were played;
/// the server replays them from the same seed and computes the score itself.
/// If these two implementations ever drift apart, honest players get their
/// scores flagged. So any change here must be made on both sides, behind a
/// new game version.
library;

import 'deterministic_rng.dart';
import 'game_engine.dart';

export 'deterministic_rng.dart';
export 'game_engine.dart';

/// The rules the server enforces and this engine runs. Delivered with every
/// session so the two never disagree about how a game is played.
class GameConfig2048 {
  const GameConfig2048({
    this.boardSize = 4,
    this.startTiles = 2,
    this.spawnFourPercent = 10,
    this.winTile = 2048,
    this.maxMoves = 5000,
  });

  factory GameConfig2048.fromJson(Map<String, dynamic> json) {
    int read(String key, int fallback) {
      final value = json[key];
      return value is num && value > 0 ? value.toInt() : fallback;
    }

    const defaults = GameConfig2048();
    return GameConfig2048(
      boardSize: read('board_size', defaults.boardSize),
      startTiles: read('start_tiles', defaults.startTiles),
      spawnFourPercent: read('spawn_four_percent', defaults.spawnFourPercent),
      winTile: read('win_tile', defaults.winTile),
      maxMoves: read('max_moves', defaults.maxMoves),
    );
  }

  final int boardSize;
  final int startTiles;
  final int spawnFourPercent;
  final int winTile;
  final int maxMoves;
}

/// One tile's journey during a single move, so the board can slide it rather
/// than redraw it in its new home.
///
/// This is presentation only. It is derived from the same collapse the score
/// comes out of, so it cannot describe a move the engine did not make, and
/// nothing here reaches the move log or the server.
class Tile2048Slide {
  const Tile2048Slide({
    required this.from,
    required this.to,
    required this.value,
    required this.merged,
  });

  /// Board indices, flat and row-major, before and after the move.
  final int from;
  final int to;

  /// The tile's value as it was before the move.
  final int value;

  /// This tile ran into an equal one and the pair became a single tile at
  /// [to] worth double.
  final bool merged;
}

/// A 2048 game driven entirely by a server-issued seed.
class Game2048 implements GameEngine {
  Game2048({required String seed, GameConfig2048? config})
    : config = config ?? const GameConfig2048(),
      _rng = DeterministicRng.fromSeed(seed) {
    _board = List<int>.filled(this.config.boardSize * this.config.boardSize, 0);
    for (var i = 0; i < this.config.startTiles; i++) {
      _spawn();
    }
  }

  final GameConfig2048 config;
  final DeterministicRng _rng;

  late List<int> _board;
  int _score = 0;

  /// Every move that changed the board, in order. This is what gets
  /// submitted. The server derives the score from it.
  final List<String> _moves = <String>[];

  List<Tile2048Slide> _slides = const [];
  int _spawnedAt = -1;

  /// How every tile travelled during the last move that changed anything.
  List<Tile2048Slide> get lastSlides => List.unmodifiable(_slides);

  /// Where the last move's new tile appeared, or -1 if none did.
  int get lastSpawn => _spawnedAt;

  /// The flat, row-major board: `board[row * size + col]`.
  List<int> get board => List<int>.unmodifiable(_board);

  @override
  int get score => _score;

  @override
  List<String> get moves => List<String>.unmodifiable(_moves);

  @override
  bool get isOver => isGameOver || reachedMoveLimit;

  @override
  bool get hasProgress => _moves.isNotEmpty;

  int get size => config.boardSize;

  int get highestTile => _board.fold(0, (best, v) => v > best ? v : best);

  bool get won => highestTile >= config.winTile;

  /// True while a legal move remains: an empty cell, or two equal neighbours.
  bool get hasMoves {
    for (var i = 0; i < _board.length; i++) {
      final v = _board[i];
      if (v == 0) return true;
      final row = i ~/ size;
      final col = i % size;
      if (col + 1 < size && _board[i + 1] == v) return true;
      if (row + 1 < size && _board[i + size] == v) return true;
    }
    return false;
  }

  bool get isGameOver => !hasMoves;

  /// Whether the move budget is spent; submitting more would be rejected.
  bool get reachedMoveLimit => _moves.length >= config.maxMoves;

  /// Places one tile on a random empty cell.
  ///
  /// The position is drawn FIRST and the value second. Swapping those two
  /// lines desyncs this engine from the server's.
  void _spawn() {
    final empties = <int>[];
    for (var i = 0; i < _board.length; i++) {
      if (_board[i] == 0) empties.add(i);
    }
    if (empties.isEmpty) return;

    final cell = empties[_rng.nextInt(empties.length)];
    final value = _rng.nextInt(100) < config.spawnFourPercent ? 4 : 2;
    _board[cell] = value;
    _spawnedAt = cell;
  }

  /// The board index of the cell [pos] places along line [index], read in the
  /// direction of travel. One mapping for reading, writing and reporting where
  /// a tile slid, so those three can never disagree.
  int _cellAt(String dir, int index, int pos) {
    switch (dir) {
      case Move.left:
        return index * size + pos;
      case Move.right:
        return index * size + (size - 1 - pos);
      case Move.up:
        return pos * size + index;
      case Move.down:
        return (size - 1 - pos) * size + index;
    }
    return index * size + pos;
  }

  /// Reads one row or column in the direction of travel, so all four
  /// directions reuse the same "slide towards index 0" logic.
  List<int> _line(String dir, int index) {
    final out = List<int>.filled(size, 0);
    for (var i = 0; i < size; i++) {
      out[i] = _board[_cellAt(dir, index, i)];
    }
    return out;
  }

  void _writeLine(String dir, int index, List<int> values) {
    for (var i = 0; i < size; i++) {
      _board[_cellAt(dir, index, i)] = values[i];
    }
  }

  /// Slides one line towards index 0 and merges equal neighbours. A tile may
  /// merge at most once per move, resolved from the leading edge inwards.
  ///
  /// [travel] collects, for each tile that survived, the position it started
  /// at, the position it ended at, and whether it merged on arrival. The
  /// values and the score are worked out exactly as before. The bookkeeping
  /// only watches.
  List<int> _collapse(List<int> input, [List<List<int>>? travel]) {
    final packed = <int>[];
    final source = <int>[];
    for (var i = 0; i < input.length; i++) {
      if (input[i] != 0) {
        packed.add(input[i]);
        source.add(i);
      }
    }

    final merged = <int>[];
    for (var i = 0; i < packed.length; i++) {
      final slot = merged.length;
      if (i + 1 < packed.length && packed[i] == packed[i + 1]) {
        final sum = packed[i] * 2;
        merged.add(sum);
        _score += sum;
        // Both tiles travel to the same slot; the pair becomes one there.
        travel?.add([source[i], slot, packed[i], 1]);
        travel?.add([source[i + 1], slot, packed[i + 1], 1]);
        i++; // the consumed neighbour cannot merge again this move
        continue;
      }
      merged.add(packed[i]);
      travel?.add([source[i], slot, packed[i], 0]);
    }

    while (merged.length < input.length) {
      merged.add(0);
    }
    return merged;
  }

  /// Applies one swipe. Returns whether the board changed.
  ///
  /// A new tile appears only when something actually moved, which is what
  /// keeps this engine's random stream aligned with the server's.
  bool move(String dir) {
    if (isOver || !Move.isDirection(dir)) return false;

    var changed = false;
    final slides = <Tile2048Slide>[];
    for (var i = 0; i < size; i++) {
      final before = _line(dir, i);
      final travel = <List<int>>[];
      final after = _collapse(before, travel);
      for (final t in travel) {
        slides.add(
          Tile2048Slide(
            from: _cellAt(dir, i, t[0]),
            to: _cellAt(dir, i, t[1]),
            value: t[2],
            merged: t[3] == 1,
          ),
        );
      }
      for (var j = 0; j < before.length; j++) {
        if (before[j] != after[j]) {
          changed = true;
          break;
        }
      }
      _writeLine(dir, i, after);
    }

    if (changed) {
      _slides = slides;
      _spawnedAt = -1;
      _spawn();
      // Only record moves that did something. A no-op move would replay as a
      // no-op on the server too, so sending it just adds noise to the log.
      _moves.add(dir);
    }
    return changed;
  }
}
