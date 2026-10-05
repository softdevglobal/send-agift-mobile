import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/bubble_shooter.dart';
import '../game_controls.dart';
import 'tilt_3d.dart';

const _bubbleColors = [
  Color(0xFFF87171),
  Color(0xFF60A5FA),
  Color(0xFFFBBF24),
  Color(0xFF34D399),
  Color(0xFFA78BFA),
  Color(0xFFF472B6),
];

Color _colorOf(int value) => _bubbleColors[value % _bubbleColors.length];

/// The playing surface, which takes the aim. Named so a test can convert a
/// cell into a screen point through the board's own render box. The tilt
/// makes that mapping anything but linear.
const bubbleSurfaceKey = ValueKey('bubble-board-surface');

/// The queue under the board. Tapping anywhere on it swaps the two bubbles.
const bubbleSwapKey = ValueKey('bubble-board-swap');

/// One bubble caught mid-burst, kept on screen after the engine has already
/// taken it off the board so the pop can be seen rather than inferred.
class _Burst {
  const _Burst({required this.row, required this.col, required this.color});

  final int row;
  final int col;
  final Color color;
}

/// Bubble Shooter: drag anywhere to aim, let go to fire.
///
/// The aim line is the engine's own flight. The same integer steps the server
/// replays. So the dotted path, the bounces off the walls and the ghost at the
/// end show exactly where the bubble is going to end up, not an approximation
/// of it.
class BubbleBoard extends StatefulWidget {
  const BubbleBoard({required this.game, required this.controls, super.key});

  final BubbleShooter game;
  final GameControls controls;

  @override
  State<BubbleBoard> createState() => _BubbleBoardState();
}

class _BubbleBoardState extends State<BubbleBoard>
    with SingleTickerProviderStateMixin {
  /// The aim being held, in sideways units per 1000 of rise, or null when the
  /// player is not touching the board. Aiming only previews. Nothing is
  /// fired until the finger lifts.
  int? _aim;

  /// Where the finger went down, and whether it has moved far enough to count
  /// as a drag. A press on the queue that never moves is a swap; one that
  /// does is the player taking hold of the ball to aim with it.
  Offset _down = Offset.zero;
  bool _dragged = false;
  bool _fromQueue = false;

  /// The playing surface and the queue, for turning a touch anywhere in the
  /// widget into board coordinates.
  final GlobalKey _board = GlobalKey();
  final GlobalKey _queue = GlobalKey();

  List<_Burst> _bursts = const [];

  // Built in initState rather than lazily: a round where nothing ever pops
  // would otherwise create the controller for the first time in dispose,
  // which means asking a dead element for a ticker.
  late final AnimationController _burst;

  BubbleShooter get _game => widget.game;

  bool get _live => widget.controls.active && !_game.isOver;

  @override
  void initState() {
    super.initState();
    _burst =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 420),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _bursts = const []);
          }
        });
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  /// Turns a touch anywhere in the widget into an aim.
  ///
  /// Above the launcher the shot points at the finger. Below it. Holding the
  /// ball and pulling down. It works like a catapult and points the opposite
  /// way, so the ball itself can be dragged to aim with.
  void _aimTo(Offset global) {
    if (!_live) return;
    final box = _board.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || box.size.width <= 0) return;

    final columns = _game.config.columns;
    final cell = box.size.width / columns;
    final local = box.globalToLocal(global);
    final dx = local.dx / cell - columns / 2;
    final dy = local.dy / cell - _game.config.rows;

    final double ratio;
    if (dy < -0.2) {
      ratio = dx / -dy;
    } else if (dy > 0.2) {
      ratio = -dx / dy;
    } else {
      // Level with the launcher there is no line to shoot along, so the last
      // aim stands rather than flipping about wildly.
      return;
    }

    final aim = BubbleShooter.clampAim((ratio * 1000).round());
    if (_aim != aim) setState(() => _aim = aim);
  }

  bool _onQueue(Offset global) {
    final box = _queue.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return false;
    return (box.localToGlobal(Offset.zero) & box.size).contains(global);
  }

  void _onDown(PointerDownEvent event) {
    _down = event.position;
    _dragged = false;
    _fromQueue = _onQueue(event.position);
    // A press that begins on the queue might still turn out to be a swap, so
    // it does not aim until the finger actually moves.
    if (!_fromQueue) _aimTo(event.position);
  }

  void _onMove(PointerMoveEvent event) {
    if ((event.position - _down).distance > 8) _dragged = true;
    if (_dragged || !_fromQueue) _aimTo(event.position);
  }

  void _onUp(PointerUpEvent event) {
    if (_fromQueue && !_dragged) {
      setState(() => _aim = null);
      _swap();
      return;
    }
    _fire();
  }

  void _fire() {
    final aim = _aim;
    setState(() => _aim = null);
    if (aim == null || !_live) return;

    // Shooting clears the popped cells and advances the queue, so the colours
    // have to be read off the board before the shot to draw the burst. A pop
    // takes floaters of other colours down with it, so one colour for the lot
    // would not do.
    final fired = _game.next;
    final before = [
      for (var r = 0; r < _game.config.rows; r++)
        [for (var c = 0; c < _game.config.columns; c++) _game.at(r, c)],
    ];

    final popped = _game.shoot(aim);
    if (popped.isNotEmpty) {
      _bursts = [
        for (final cell in popped)
          _Burst(
            row: cell[0],
            col: cell[1],
            // The cell the shot landed in was empty a moment ago, so it wears
            // the colour that was just fired.
            color: _colorOf(
              before[cell[0]][cell[1]] >= 0 ? before[cell[0]][cell[1]] : fired,
            ),
          ),
      ];
      _burst.forward(from: 0);
    }
    widget.controls.onChanged();
  }

  void _swap() {
    if (!_live) return;
    if (_game.swap()) {
      setState(() {});
      widget.controls.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _game.config;
    final aim = _aim;
    final shot = aim == null ? null : _game.trace(aim);
    final endsRound = shot != null && shot.ok && shot.row >= config.rows - 1;

    // Raw pointer events over the whole widget, launcher included, rather
    // than a GestureDetector: a tap recognizer and a drag recognizer would
    // compete in the arena and the tap's down callback is held back until
    // that resolves, so the aim would not appear until the finger moved or
    // lifted. Too late to aim with.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: (_) => setState(() => _aim = null),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Tilt3D(
                angle: 0.14,
                child: AspectRatio(
                  // The board's own geometry: a touch is turned into a cell
                  // through this box, so the perspective tilt is undone by
                  // the same transform that drew it.
                  key: _board,
                  aspectRatio: config.columns / config.rows,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cell = constraints.maxWidth / config.columns;
                      return SizedBox(
                        key: bubbleSurfaceKey,
                        child: Stack(
                          children: [
                            // The flight the shot will take, bounces and all.
                            if (shot != null)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _AimPainter(
                                      path: shot.path,
                                      cell: cell,
                                      color: endsRound
                                          ? const Color(0xFFEF4444)
                                          : _colorOf(_game.next),
                                    ),
                                  ),
                                ),
                              ),

                            // The wall, drawn from the top down.
                            for (var row = 0; row < config.rows; row++)
                              for (var col = 0; col < config.columns; col++)
                                if (_game.at(row, col) >= 0)
                                  Positioned(
                                    left: col * cell,
                                    // Row 0 is the ceiling, so it draws at the top.
                                    top: row * cell,
                                    width: cell,
                                    height: cell,
                                    child: _Bubble(
                                      color: _colorOf(_game.at(row, col)),
                                    ),
                                  ),

                            // A ghost of the shot where it comes to rest.
                            if (shot != null && shot.ok)
                              Positioned(
                                left: shot.col * cell,
                                top: shot.row * cell,
                                width: cell,
                                height: cell,
                                child: IgnorePointer(
                                  child: _Ghost(
                                    color: _colorOf(_game.next),
                                    warn: endsRound,
                                  ),
                                ),
                              ),

                            // Bubbles caught mid-pop.
                            for (final burst in _bursts)
                              Positioned(
                                left: burst.col * cell,
                                top: burst.row * cell,
                                width: cell,
                                height: cell,
                                child: IgnorePointer(
                                  child: _Pop(color: burst.color, t: _burst),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _Launcher(
            queueKey: _queue,
            game: _game,
            aiming: aim != null,
            endsRound: endsRound,
          ),
        ],
      ),
    );
  }
}

/// A bubble bursting: it swells and fades while a ring blows outward from it.
class _Pop extends StatelessWidget {
  const _Pop({required this.color, required this.t});

  final Color color;
  final Animation<double> t;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = Curves.easeOut.transform(t.value);
        return CustomPaint(
          painter: _PopPainter(color: color, t: v),
        );
      },
    );
  }
}

class _PopPainter extends CustomPainter {
  _PopPainter({required this.color, required this.t});

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2;

    // The bubble itself, swelling and thinning out.
    canvas.drawCircle(
      centre,
      radius * (1 + t * 0.35),
      Paint()..color = color.withValues(alpha: (1 - t) * 0.65),
    );

    // A ring blown outward, which is what reads as a burst rather than a fade.
    canvas.drawCircle(
      centre,
      radius * (0.8 + t * 1.1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.22 * (1 - t)
        ..color = color.withValues(alpha: (1 - t) * 0.8),
    );

    // Shards thrown out on the diagonals.
    final shard = Paint()..color = color.withValues(alpha: (1 - t) * 0.9);
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final distance = radius * (0.4 + t * 1.3);
      canvas.drawCircle(
        centre + Offset(math.cos(angle), math.sin(angle)) * distance,
        radius * 0.16 * (1 - t),
        shard,
      );
    }
  }

  @override
  bool shouldRepaint(_PopPainter old) => old.t != t || old.color != color;
}

/// Where the aimed shot comes to rest: the queued colour, outlined rather than
/// filled, so it is never mistaken for a bubble already placed.
class _Ghost extends StatelessWidget {
  const _Ghost({required this.color, required this.warn});

  final Color color;

  /// This landing spot is the floor row, so taking the shot ends the round.
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.28),
          border: Border.all(
            color: warn
                ? const Color(0xFFEF4444)
                : Colors.white.withValues(alpha: 0.85),
            width: 2,
          ),
        ),
      ),
    );
  }
}

/// Draws the shot's flight as a dotted line, following the engine's own path
/// so the bounces drawn are the bounces that will happen.
class _AimPainter extends CustomPainter {
  _AimPainter({required this.path, required this.cell, required this.color});

  /// The flight in cell coordinates, straight from the engine.
  final List<Offset> path;
  final double cell;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;
    final radius = (cell * 0.07).clamp(2.0, 5.0);
    final gap = radius * 3.6;

    var carried = 0.0;
    var drawn = 0;
    for (var i = 0; i < path.length - 1; i++) {
      final a = path[i] * cell;
      final b = path[i + 1] * cell;
      final span = (b - a).distance;
      if (span <= 0) continue;
      final step = (b - a) / span;

      var travelled = carried;
      while (travelled < span) {
        final at = a + step * travelled;
        // The trail thins with distance, so the eye runs along it to the end
        // rather than reading it as a solid bar.
        final fade = (drawn / 34).clamp(0.0, 1.0);
        canvas.drawCircle(
          at,
          radius * (1 - fade * 0.35),
          Paint()..color = color.withValues(alpha: 0.9 - fade * 0.5),
        );
        travelled += gap;
        drawn++;
      }
      carried = travelled - span;
    }
  }

  @override
  bool shouldRepaint(_AimPainter old) =>
      old.path != path || old.cell != cell || old.color != color;
}

/// The shooter: the bubble loaded and ready, the one queued behind it, and a
/// control to trade one for the other.
class _Launcher extends StatelessWidget {
  const _Launcher({
    required this.queueKey,
    required this.game,
    required this.aiming,
    required this.endsRound,
  });

  /// Marks the queue so the board can tell a press on it from one on the
  /// playing surface: a press that stays put here is a swap, one that moves
  /// is the player taking hold of the ball to aim with.
  final GlobalKey queueKey;

  final BubbleShooter game;
  final bool aiming;

  /// The aimed shot lands on the floor row and would end the round.
  final bool endsRound;

  @override
  Widget build(BuildContext context) {
    final tint = endsRound ? const Color(0xFFEF4444) : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The whole queue swaps on a tap, not just the small icon between the
        // two. Reaching for the bubble you want next is the obvious move, and
        // a 34px icon at the bottom edge of a phone is an awkward target.
        Semantics(
          button: true,
          label: 'Swap the loaded bubble with the next one, or drag to aim',
          child: Padding(
            key: queueKey,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              key: bubbleSwapKey,
              mainAxisSize: MainAxisSize.min,
              children: [
                // The loaded bubble, big enough to read its colour at a
                // glance. Knowing what is about to be fired is the game.
                _Loaded(value: game.next, size: 52, tint: tint),
                const SizedBox(width: 8),
                Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.white.withValues(alpha: 0.75),
                  size: 22,
                ),
                const SizedBox(width: 8),
                // What comes after, so a shot can be planned rather than
                // guessed, badged so it reads as the one you can swap to.
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _Loaded(value: game.after, size: 34, tint: Colors.white),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                        child: const Icon(
                          Icons.cached_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          aiming
              ? (endsRound ? 'This shot ends the round' : 'Release to fire')
              : 'Drag to aim · tap the pair to swap',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tint.withValues(alpha: 0.8),
            fontWeight: endsRound ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// A bubble sitting in the queue, in its housing.
class _Loaded extends StatelessWidget {
  const _Loaded({required this.value, required this.size, required this.tint});

  final int value;
  final double size;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final color = _colorOf(value);
    return Container(
      padding: EdgeInsets.all(size * 0.13),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(color: tint.withValues(alpha: 0.45), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: size * 0.35,
            spreadRadius: 1,
          ),
        ],
      ),
      // The switcher lays its children out in a Stack, which hands them loose
      // constraints. And a bubble is a childless DecoratedBox with no size of
      // its own, so it would collapse to its padding and show as an empty
      // ring. The SizedBox inside gives it one.
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: SizedBox(
          key: ValueKey(value),
          width: size,
          height: size,
          child: _Bubble(color: color),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // A light source up and left, so each bubble reads as a sphere
          // rather than a flat dot.
          gradient: RadialGradient(
            center: const Alignment(-0.4, -0.5),
            colors: [
              Color.lerp(color, Colors.white, 0.55)!,
              color,
              extrusionShade(color, 0.16),
            ],
            stops: const [0, 0.55, 1],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
      ),
    );
  }
}
