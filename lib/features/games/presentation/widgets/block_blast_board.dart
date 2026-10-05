import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../domain/block_blast.dart';
import '../game_controls.dart';
import 'game_hud.dart';

const double _boardPad = 8;

/// How far above the finger a dragged piece floats, so it is never hidden.
const double _lift = 56;

const List<Color> _jewels = [
  Color(0xFFFF5E7E),
  Color(0xFFFFA940),
  Color(0xFFFFD84D),
  Color(0xFF52E08A),
  Color(0xFF3FC7FF),
  Color(0xFF6C7BFF),
  Color(0xFFB36BFF),
  Color(0xFFFF7BD5),
];

Color _jewelColor(int piece) => _jewels[piece % _jewels.length];

(int, int) _extent(int piece) {
  var rows = 0;
  var cols = 0;
  for (final (r, c) in blockShapes[piece]) {
    rows = math.max(rows, r + 1);
    cols = math.max(cols, c + 1);
  }
  return (rows, cols);
}

/// One glossy, raised 3D block.
void _paintJewel(Canvas canvas, Rect rect, Color color, [double alpha = 1]) {
  final radius = Radius.circular(rect.width * 0.2);
  final body = RRect.fromRectAndRadius(rect, radius);
  Color a(Color c) => c.withValues(alpha: alpha * c.a);

  // The block's side, a darker slab underneath the face.
  canvas.drawRRect(
    body.shift(Offset(0, rect.height * 0.09)),
    Paint()..color = a(Color.lerp(color, Colors.black, 0.35)!),
  );
  canvas.drawRRect(
    body,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          a(Color.lerp(color, Colors.white, 0.4)!),
          a(color),
          a(Color.lerp(color, Colors.black, 0.15)!),
        ],
      ).createShader(rect),
  );
  // Bevel and shine.
  canvas
    ..drawRRect(
      body.deflate(rect.width * 0.14),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rect.width * 0.05
        ..color = Colors.white.withValues(alpha: 0.32 * alpha),
    )
    ..drawCircle(
      rect.topLeft + Offset(rect.width * 0.3, rect.height * 0.28),
      rect.width * 0.09,
      Paint()..color = Colors.white.withValues(alpha: 0.7 * alpha),
    );
}

/// Block Blast: drag a piece from the tray onto the board. Or tap a piece,
/// then tap the square for its top-left corner.
class BlockBlastBoard extends StatefulWidget {
  const BlockBlastBoard({
    required this.game,
    required this.controls,
    super.key,
  });

  final BlockBlast game;
  final GameControls controls;

  @override
  State<BlockBlastBoard> createState() => _BlockBlastBoardState();
}

class _BlockBlastBoardState extends State<BlockBlastBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  final _rootKey = GlobalKey();
  final _boardKey = GlobalKey();

  int? _dragSlot;
  Offset? _dragPos;
  (int, int)? _ghost;
  int? _selected;
  Map<int, int> _cleared = const {};
  BlockBlastMove? _lastMove;
  int _moveCount = 0;
  double _cell = 30;

  BlockBlast get _game => widget.game;

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  RenderBox? _box(GlobalKey key) =>
      key.currentContext?.findRenderObject() as RenderBox?;

  (int, int) _cellAt(Offset boardLocal) => (
    ((boardLocal.dy - _boardPad) / _cell).floor(),
    ((boardLocal.dx - _boardPad) / _cell).floor(),
  );

  Offset _floatingTopLeft(int piece) {
    final (rows, cols) = _extent(piece);
    return _dragPos! - Offset(cols * _cell / 2, rows * _cell + _lift);
  }

  void _updateGhost() {
    final slot = _dragSlot;
    final root = _box(_rootKey);
    final board = _box(_boardKey);
    if (slot == null || _dragPos == null || root == null || board == null) {
      return;
    }
    final piece = _game.hand[slot];
    final firstCell = _floatingTopLeft(piece) + Offset(_cell / 2, _cell / 2);
    final (r, c) = _cellAt(board.globalToLocal(root.localToGlobal(firstCell)));
    _ghost = _game.fits(piece, r, c) ? (r, c) : null;
  }

  void _panStart(int slot, DragStartDetails details) {
    final root = _box(_rootKey);
    if (!widget.controls.active || _game.hand[slot] < 0 || root == null) {
      return;
    }
    setState(() {
      _dragSlot = slot;
      _selected = null;
      _dragPos = root.globalToLocal(details.globalPosition);
      _updateGhost();
    });
  }

  void _panUpdate(DragUpdateDetails details) {
    final root = _box(_rootKey);
    if (_dragSlot == null || root == null) return;
    setState(() {
      _dragPos = root.globalToLocal(details.globalPosition);
      _updateGhost();
    });
  }

  void _panEnd(DragEndDetails details) {
    final slot = _dragSlot;
    final ghost = _ghost;
    setState(() {
      _dragSlot = null;
      _dragPos = null;
      _ghost = null;
    });
    if (slot != null && ghost != null) _place(slot, ghost.$1, ghost.$2);
  }

  void _tapSlot(int slot) {
    if (!widget.controls.active || _game.hand[slot] < 0) return;
    setState(() => _selected = _selected == slot ? null : slot);
  }

  void _tapBoard(TapUpDetails details) {
    final slot = _selected;
    if (slot == null) return;
    final (r, c) = _cellAt(details.localPosition);
    if (_place(slot, r, c)) setState(() => _selected = null);
  }

  bool _place(int slot, int row, int col) {
    if (!widget.controls.active) return false;
    final move = _game.place(slot, row, col);
    if (move == null) return false;
    setState(() {
      _lastMove = move;
      _moveCount++;
      _cleared = move.cleared;
    });
    if (move.cleared.isNotEmpty) _burst.forward(from: 0);
    widget.controls.onChanged();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const trayHeight = 110.0;
        final side = math.min(
          constraints.maxWidth,
          constraints.maxHeight - trayHeight - 16,
        );
        _cell = (side - 2 * _boardPad) / _game.size;
        final dragSlot = _dragSlot;
        final dragPiece = dragSlot == null ? null : _game.hand[dragSlot];
        final lastMove = _lastMove;

        return Stack(
          key: _rootKey,
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: GestureDetector(
                    onTapUp: _tapBoard,
                    child: SizedBox(
                      key: _boardKey,
                      width: side,
                      height: side,
                      child: CustomPaint(
                        key: const ValueKey('block-blast-board'),
                        painter: _BoardPainter(
                          game: _game,
                          ghost: _ghost,
                          ghostPiece: dragPiece,
                          burst: _burst,
                          cleared: _cleared,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: trayHeight,
                  child: Row(
                    children: [
                      for (var slot = 0; slot < _game.hand.length; slot++) ...[
                        if (slot > 0) const SizedBox(width: 10),
                        Expanded(child: _slot(slot)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (dragPiece != null && _dragPos != null)
              Positioned(
                left: _floatingTopLeft(dragPiece).dx,
                top: _floatingTopLeft(dragPiece).dy,
                child: IgnorePointer(
                  child: CustomPaint(
                    size: Size(
                      _extent(dragPiece).$2 * _cell,
                      _extent(dragPiece).$1 * _cell,
                    ),
                    painter: _PiecePainter(piece: dragPiece, cell: _cell),
                  ),
                ),
              ),
            if (lastMove != null && lastMove.lines > 0)
              Positioned(
                left: 0,
                right: 0,
                top: side * 0.4,
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_moveCount),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1000),
                    builder: (context, t, _) => Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, -40 * t),
                        child: Column(
                          children: [
                            Text(
                              '+${lastMove.points}',
                              style:
                                  AppTypography.display(
                                    40,
                                    color: const Color(0xFFFFE066),
                                  ).copyWith(
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                            ),
                            if (lastMove.combo > 1)
                              Text(
                                'COMBO ×${lastMove.combo}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _slot(int slot) {
    final piece = _game.hand[slot];
    final selected = _selected == slot;
    final dragging = _dragSlot == slot;
    final playable = piece >= 0 && _game.fitsAnywhere(piece);

    return GestureDetector(
      key: ValueKey('block-blast-slot-$slot'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _tapSlot(slot),
      onPanStart: (d) => _panStart(slot, d),
      onPanUpdate: _panUpdate,
      onPanEnd: _panEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: glassDecoration(radius: 20, alpha: selected ? 0.34 : 0.16)
            .copyWith(
              border: Border.all(
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.28),
                width: selected ? 2.5 : 1,
              ),
            ),
        child: piece < 0 || dragging
            ? const SizedBox.expand()
            : LayoutBuilder(
                builder: (context, c) {
                  final (rows, cols) = _extent(piece);
                  final cell = math.min(
                    22.0,
                    math.min(
                      (c.maxWidth - 16) / cols,
                      (c.maxHeight - 16) / rows,
                    ),
                  );
                  return Center(
                    child: Opacity(
                      opacity: playable ? 1 : 0.35,
                      child: CustomPaint(
                        size: Size(cols * cell, rows * cell),
                        painter: _PiecePainter(piece: piece, cell: cell),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _PiecePainter extends CustomPainter {
  _PiecePainter({required this.piece, required this.cell});

  final int piece;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final color = _jewelColor(piece);
    for (final (r, c) in blockShapes[piece]) {
      _paintJewel(
        canvas,
        Rect.fromLTWH(c * cell + 1.5, r * cell + 1.5, cell - 3, cell - 3),
        color,
      );
    }
  }

  @override
  bool shouldRepaint(_PiecePainter oldDelegate) =>
      oldDelegate.piece != piece || oldDelegate.cell != cell;
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.game,
    required this.ghost,
    required this.ghostPiece,
    required this.burst,
    required this.cleared,
  }) : super(repaint: burst);

  final BlockBlast game;
  final (int, int)? ghost;
  final int? ghostPiece;
  final Animation<double> burst;
  final Map<int, int> cleared;

  @override
  void paint(Canvas canvas, Size size) {
    final n = game.size;
    final cell = (size.width - 2 * _boardPad) / n;
    Rect cellRect(int i) => Rect.fromLTWH(
      _boardPad + (i % n) * cell + 2,
      _boardPad + (i ~/ n) * cell + 2,
      cell - 4,
      cell - 4,
    );

    // A raised tray: its thick side first, then the top.
    final tray = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(22),
    );
    canvas
      ..drawRRect(
        tray.shift(const Offset(0, 9)),
        Paint()..color = const Color(0xFF0B0A2A),
      )
      ..drawRRect(
        tray,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2E2A7A), Color(0xFF17154A)],
          ).createShader(Offset.zero & size),
      );

    final board = game.board;
    // Wells sunk into the tray.
    for (var i = 0; i < n * n; i++) {
      final rect = cellRect(i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.4),
              Colors.white.withValues(alpha: 0.06),
            ],
          ).createShader(rect),
      );
    }

    // The ghost of a dragged piece, and the lines it would clear.
    final g = ghost;
    final gp = ghostPiece;
    if (g != null && gp != null) {
      final cells = {
        for (final (dr, dc) in blockShapes[gp]) (g.$1 + dr) * n + g.$2 + dc,
      };
      final filled = [
        for (var i = 0; i < n * n; i++) board[i] != 0 || cells.contains(i),
      ];
      final glow = <int>{};
      for (var r = 0; r < n; r++) {
        if (List.generate(n, (c) => filled[r * n + c]).every((f) => f)) {
          glow.addAll(List.generate(n, (c) => r * n + c));
        }
      }
      for (var c = 0; c < n; c++) {
        if (List.generate(n, (r) => filled[r * n + c]).every((f) => f)) {
          glow.addAll(List.generate(n, (r) => r * n + c));
        }
      }
      for (final i in glow) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            cellRect(i).inflate(1),
            Radius.circular(cell * 0.2),
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.28),
        );
      }
      for (final i in cells) {
        _paintJewel(canvas, cellRect(i), _jewelColor(gp), 0.45);
      }
    }

    for (var i = 0; i < n * n; i++) {
      if (board[i] != 0) {
        _paintJewel(canvas, cellRect(i), _jewelColor(board[i] - 1));
      }
    }

    // Cleared blocks swell, fade and throw sparks.
    final t = burst.value;
    if (t > 0 && t < 1) {
      for (final entry in cleared.entries) {
        final rect = cellRect(entry.key);
        final grown = Rect.fromCenter(
          center: rect.center,
          width: rect.width * (1 + 0.5 * t),
          height: rect.height * (1 + 0.5 * t),
        );
        final color = _jewelColor(entry.value - 1);
        _paintJewel(canvas, grown, color, 1 - t);
        for (var k = 0; k < 4; k++) {
          final angle = (entry.key * 7 + k * 90) * math.pi / 180;
          canvas.drawCircle(
            rect.center +
                Offset(math.cos(angle), math.sin(angle)) * cell * 1.2 * t,
            cell * 0.08 * (1 - t),
            Paint()..color = color.withValues(alpha: 1 - t),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter oldDelegate) => true;
}
