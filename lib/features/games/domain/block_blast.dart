/// Block Blast. A mirror of `internal/games/blockblast.go`.
///
/// Place pieces from a hand of three; full rows and columns clear. A new
/// hand is dealt from the seed when the last piece is placed. Like 2048's
/// tile spawns, identical for everyone who shares the seed.
library;

import 'deterministic_rng.dart';
import 'game_engine.dart';

class BlockBlastConfig {
  const BlockBlastConfig({
    this.boardSize = 8,
    this.handSize = 3,
    this.pointsPerCell = 1,
    this.pointsPerLine = 10,
    this.comboBonus = 5,
    this.maxMoves = 3000,
  });

  /// Mirrors the backend's `withDefaults`.
  factory BlockBlastConfig.fromJson(Map<String, dynamic> json) {
    const d = BlockBlastConfig();
    int read(String key, int fallback) {
      final v = readConfigInt(json, key);
      return v <= 0 ? fallback : v;
    }

    var size = readConfigInt(json, 'board_size');
    if (size < 5 || size > 12) size = d.boardSize;
    return BlockBlastConfig(
      boardSize: size,
      handSize: read('hand_size', d.handSize),
      pointsPerCell: read('points_per_cell', d.pointsPerCell),
      pointsPerLine: read('points_per_line', d.pointsPerLine),
      comboBonus: read('combo_bonus', d.comboBonus),
      maxMoves: read('max_moves', d.maxMoves),
    );
  }

  final int boardSize;
  final int handSize;
  final int pointsPerCell;
  final int pointsPerLine;
  final int comboBonus;
  final int maxMoves;
}

/// The piece catalog as (row, col) cells. The same list, in the same order,
/// as `BlockShapes` on the backend. The seed picks pieces by index.
const List<List<(int, int)>> blockShapes = [
  [(0, 0)],
  [(0, 0), (0, 1)],
  [(0, 0), (1, 0)],
  [(0, 0), (0, 1), (0, 2)],
  [(0, 0), (1, 0), (2, 0)],
  [(0, 0), (0, 1), (0, 2), (0, 3)],
  [(0, 0), (1, 0), (2, 0), (3, 0)],
  [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)],
  [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)],
  [(0, 0), (0, 1), (1, 0), (1, 1)],
  [
    (0, 0), (0, 1), (0, 2), //
    (1, 0), (1, 1), (1, 2),
    (2, 0), (2, 1), (2, 2),
  ],
  [(0, 0), (1, 0), (1, 1)],
  [(0, 0), (0, 1), (1, 0)],
  [(0, 0), (0, 1), (1, 1)],
  [(0, 1), (1, 0), (1, 1)],
  [(0, 0), (1, 0), (2, 0), (2, 1)],
  [(0, 1), (1, 1), (2, 1), (2, 0)],
  [(0, 0), (0, 1), (0, 2), (1, 0)],
  [(0, 0), (0, 1), (0, 2), (1, 2)],
  [(0, 0), (0, 1), (0, 2), (1, 1)],
  [(0, 1), (1, 0), (1, 1), (1, 2)],
  [(0, 1), (0, 2), (1, 0), (1, 1)],
  [(0, 0), (0, 1), (1, 1), (1, 2)],
  [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2)],
];

/// One placement, with what the board needs to animate it.
class BlockBlastMove {
  const BlockBlastMove({
    required this.piece,
    required this.points,
    required this.lines,
    required this.placed,
    required this.cleared,
    required this.combo,
  });

  final int piece;
  final int points;
  final int lines;

  /// Board cells the piece landed on.
  final List<int> placed;

  /// Board cells that were cleared, with the piece id they held.
  final Map<int, int> cleared;
  final int combo;
}

class BlockBlast implements GameEngine {
  BlockBlast({required String seed, BlockBlastConfig? config})
    : config = config ?? const BlockBlastConfig(),
      _rng = DeterministicRng.fromSeed(seed) {
    final n = this.config.boardSize;
    _board = List<int>.filled(n * n, 0);
    _hand = List<int>.filled(this.config.handSize, -1);
    _deal();
  }

  final BlockBlastConfig config;
  final DeterministicRng _rng;

  late final List<int> _board;
  late final List<int> _hand;
  int _score = 0;
  int _lines = 0;
  int _combo = 0;
  int _bestCombo = 0;
  int _placed = 0;
  bool _over = false;
  BlockBlastMove? _lastMove;
  final List<String> _log = <String>[];

  void _deal() {
    for (var i = 0; i < _hand.length; i++) {
      _hand[i] = _rng.nextInt(blockShapes.length);
    }
  }

  int get size => config.boardSize;

  /// 0 for empty, otherwise the id + 1 of the piece that filled the cell.
  List<int> get board => List.unmodifiable(_board);

  /// The hand; -1 marks a slot already placed.
  List<int> get hand => List.unmodifiable(_hand);
  int get lines => _lines;
  int get combo => _combo;
  int get bestCombo => _bestCombo;
  int get placed => _placed;
  BlockBlastMove? get lastMove => _lastMove;

  @override
  int get score => _score;

  @override
  bool get isOver => _over;

  @override
  bool get hasProgress => _placed > 0;

  @override
  List<String> get moves => List<String>.unmodifiable(_log);

  /// Whether a piece fits with its top-left cell at ([row], [col]).
  bool fits(int piece, int row, int col) {
    final n = config.boardSize;
    for (final (dr, dc) in blockShapes[piece]) {
      final r = row + dr;
      final c = col + dc;
      if (r < 0 || c < 0 || r >= n || c >= n || _board[r * n + c] != 0) {
        return false;
      }
    }
    return true;
  }

  /// Whether a piece fits anywhere on the board.
  bool fitsAnywhere(int piece) {
    final n = config.boardSize;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (fits(piece, r, c)) return true;
      }
    }
    return false;
  }

  bool _anyFits() {
    for (final piece in _hand) {
      if (piece >= 0 && fitsAnywhere(piece)) return true;
    }
    return false;
  }

  /// Places the piece in [slot]. Null when it does not fit there.
  BlockBlastMove? place(int slot, int row, int col) {
    if (_over || slot < 0 || slot >= _hand.length || _hand[slot] < 0) {
      return null;
    }
    final piece = _hand[slot];
    if (!fits(piece, row, col)) return null;

    final n = config.boardSize;
    final placedCells = <int>[];
    for (final (dr, dc) in blockShapes[piece]) {
      final i = (row + dr) * n + col + dc;
      _board[i] = piece + 1;
      placedCells.add(i);
    }
    var points = blockShapes[piece].length * config.pointsPerCell;

    // Rows and columns are found first and cleared together.
    final clear = List<bool>.filled(n * n, false);
    var lines = 0;
    for (var r = 0; r < n; r++) {
      var full = true;
      for (var c = 0; c < n && full; c++) {
        full = _board[r * n + c] != 0;
      }
      if (full) {
        lines++;
        for (var c = 0; c < n; c++) {
          clear[r * n + c] = true;
        }
      }
    }
    for (var c = 0; c < n; c++) {
      var full = true;
      for (var r = 0; r < n && full; r++) {
        full = _board[r * n + c] != 0;
      }
      if (full) {
        lines++;
        for (var r = 0; r < n; r++) {
          clear[r * n + c] = true;
        }
      }
    }
    final cleared = <int, int>{};
    for (var i = 0; i < clear.length; i++) {
      if (clear[i]) {
        cleared[i] = _board[i];
        _board[i] = 0;
      }
    }

    if (lines > 0) {
      _combo++;
      points += config.pointsPerLine * lines * (lines + 1) ~/ 2;
      if (_combo > 1) points += config.comboBonus * (_combo - 1);
      if (_combo > _bestCombo) _bestCombo = _combo;
    } else {
      _combo = 0;
    }

    _score += points;
    _lines += lines;
    _placed++;
    _hand[slot] = -1;
    _log.add('$slot:$row:$col');
    if (_hand.every((p) => p < 0)) _deal();
    if (!_anyFits()) _over = true;

    return _lastMove = BlockBlastMove(
      piece: piece,
      points: points,
      lines: lines,
      placed: placedCells,
      cleared: cleared,
      combo: _combo,
    );
  }
}
