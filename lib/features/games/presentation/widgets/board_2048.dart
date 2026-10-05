import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../domain/game_2048.dart';
import '../game_controls.dart';
import 'game_hud.dart';
import 'tilt_3d.dart';

/// A flick this fast counts on its own, however short it was.
const double _minSwipeVelocity = 90;

/// Otherwise the finger has to have travelled this far. The original responds
/// to a slow, deliberate drag as readily as a flick, and requiring speed alone
/// made careful play feel like the board was ignoring it.
const double _minSwipeDistance = 16;

/// How long a tile takes to reach its new square.
const _slideDuration = Duration(milliseconds: 110);

/// The 2048 grid.
///
/// Purely a view of the engine: what is drawn is always exactly what the
/// engine. And therefore the server. Thinks the position is. The tiles
/// slide to their new squares rather than appearing there, following the
/// route the engine reports, so the animation can never show a move the
/// engine did not make.
class Board2048 extends StatefulWidget {
  const Board2048({required this.game, required this.controls, super.key});

  final Game2048 game;
  final GameControls controls;

  @override
  State<Board2048> createState() => _Board2048State();
}

class _Board2048State extends State<Board2048>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide;

  /// The journeys the tiles are making. Empty when nothing is in flight.
  List<Tile2048Slide> _slides = const [];

  /// Distance the finger has covered on each axis this drag.
  double _dragX = 0;
  double _dragY = 0;

  Game2048 get _game => widget.game;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(vsync: this, duration: _slideDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          // The slide is over; the settled board takes over from here, and
          // the tiles that merged or appeared pop as it does.
          setState(() => _slides = const []);
        }
      });
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  void _swipe(String dir) {
    if (!widget.controls.active) return;

    if (!_game.move(dir)) return;

    setState(() => _slides = _game.lastSlides);
    _slide.forward(from: 0);
    widget.controls.onChanged();
  }

  /// Turns a finished drag into a swipe. A quick flick counts on velocity; a
  /// slow drag counts on how far it went.
  void _endDrag(
    double velocity,
    double travelled,
    String forward,
    String back,
  ) {
    final byFlick = velocity.abs() >= _minSwipeVelocity;
    final byDistance = travelled.abs() >= _minSwipeDistance;
    if (!byFlick && !byDistance) return;
    final direction = byFlick ? velocity : travelled;
    _swipe(direction > 0 ? forward : back);
  }

  @override
  Widget build(BuildContext context) {
    final size = _game.size;

    // Horizontal and vertical drags are separate recognisers: a single pan
    // recogniser loses the gesture arena to any scrollable ancestor, which
    // turns up/down swipes into scrolling.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _dragX = 0,
      onHorizontalDragUpdate: (d) => _dragX += d.delta.dx,
      onHorizontalDragEnd: (d) => _endDrag(
        d.velocity.pixelsPerSecond.dx,
        _dragX,
        Move.right,
        Move.left,
      ),
      onVerticalDragStart: (_) => _dragY = 0,
      onVerticalDragUpdate: (d) => _dragY += d.delta.dy,
      onVerticalDragEnd: (d) =>
          _endDrag(d.velocity.pixelsPerSecond.dy, _dragY, Move.down, Move.up),
      child: AspectRatio(
        aspectRatio: 1,
        // No perspective tilt: it scales the board down and leans it, so a
        // square is drawn narrower along one edge than the other. A grid of
        // squares has to be square. The depth is in how the tiles are drawn.
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: glassDecoration(radius: 26, alpha: 0.2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 9.0;
              final cell = (constraints.maxWidth - gap * (size - 1)) / size;
              double x(int index) => (index % size) * (cell + gap);
              double y(int index) => (index ~/ size) * (cell + gap);

              return AnimatedBuilder(
                animation: _slide,
                builder: (context, _) => Stack(
                  children: [
                    // The wells, always in place behind whatever moves.
                    for (var i = 0; i < size * size; i++)
                      Positioned(
                        left: x(i),
                        top: y(i),
                        width: cell,
                        height: cell,
                        child: const _Well(),
                      ),

                    ..._tiles(x, y, cell),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _tiles(
    double Function(int) x,
    double Function(int) y,
    double cell,
  ) {
    // Nothing in flight: draw the board as it stands.
    if (_slides.isEmpty) {
      final board = _game.board;
      return [
        for (var i = 0; i < board.length; i++)
          if (board[i] != 0)
            Positioned(
              left: x(i),
              top: y(i),
              width: cell,
              height: cell,
              // Keyed by value so a tile pops when it arrives at a new one,
              // and sits still when it is merely the same tile as before.
              child: _Tile(
                key: ValueKey('$i:${board[i]}'),
                value: board[i],
                extent: cell,
              ),
            ),
      ];
    }

    // Mid-move: every tile is drawn at its old value, part-way along the
    // journey the engine gave it. Merged tiles keep their old value until
    // they land, so the doubling reads as the moment of arrival.
    final t = Curves.easeOut.transform(_slide.value);
    return [
      for (final slide in _slides)
        Positioned(
          left: x(slide.from) + (x(slide.to) - x(slide.from)) * t,
          top: y(slide.from) + (y(slide.to) - y(slide.from)) * t,
          width: cell,
          height: cell,
          child: _Tile(
            key: ValueKey('slide:${slide.from}'),
            value: slide.value,
            extent: cell,
            // A tile arriving on top of another has to be drawn over it.
            elevated: slide.merged,
          ),
        ),
    ];
  }
}

/// An empty cell: a well sunk into the board.
class _Well extends StatelessWidget {
  const _Well();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.value,
    required this.extent,
    this.elevated = false,
    super.key,
  });

  final int value;
  final double extent;

  /// Drawn without the arrival pop, for a tile still in flight. And stacked
  /// above the tile it is about to merge with.
  final bool elevated;

  /// Sunrise ramp: warm creams through orange and gold into violet for the
  /// big numbers.
  static const Map<int, List<Color>> _fills = {
    2: [Color(0xFFFFF8EC), Color(0xFFFFEFD6)],
    4: [Color(0xFFFFE9C7), Color(0xFFFFD9A0)],
    8: [Color(0xFFFFC46B), Color(0xFFFF9F43)],
    16: [Color(0xFFFFA55C), Color(0xFFFF7A2F)],
    32: [Color(0xFFFF8A65), Color(0xFFFF5E3A)],
    64: [Color(0xFFFF6B6B), Color(0xFFEE3B3B)],
    128: [Color(0xFFFFE066), Color(0xFFFFC300)],
    256: [Color(0xFFFFD43B), Color(0xFFFFA600)],
    512: [Color(0xFFFFB800), Color(0xFFFF8C00)],
    1024: [Color(0xFFC77DFF), Color(0xFF9D4EDD)],
    2048: [Color(0xFF9D4EDD), Color(0xFF5A189A)],
  };

  List<Color> get _colors =>
      _fills[value] ?? const [Color(0xFF3C096C), Color(0xFF240046)];

  double get _fontSize {
    final base = extent * 0.4;
    if (value >= 1024) return base * 0.6;
    if (value >= 128) return base * 0.75;
    return base;
  }

  @override
  Widget build(BuildContext context) {
    if (value == 0) {
      // Empty cells read as wells sunk into the board.
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.16),
              Colors.white.withValues(alpha: 0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
      );
    }

    final glow = value >= 128;
    if (elevated) return _face(glow);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.55, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: _face(glow),
    );
  }

  Widget _face(bool glow) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _colors,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          // The tile's side: a solid, darker slab under the face makes
          // each tile a raised 3D block.
          BoxShadow(
            color: extrusionShade(_colors.last),
            offset: Offset(0, extent * 0.07),
          ),
          BoxShadow(
            color: (glow ? _colors.last : Colors.black).withValues(
              alpha: glow ? 0.6 : 0.2,
            ),
            blurRadius: glow ? 18 : 10,
            offset: Offset(0, extent * 0.12),
          ),
        ],
      ),
      // A glossy highlight across the top of the face.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: const Alignment(0, 0.1),
          colors: [
            Colors.white.withValues(alpha: 0.38),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '$value',
            style: AppTypography.display(
              _fontSize,
              color: value >= 8 ? Colors.white : const Color(0xFF8A4B08),
            ),
          ),
        ),
      ),
    );
  }
}
