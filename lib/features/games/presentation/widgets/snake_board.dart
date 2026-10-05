import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/game_engine.dart';
import '../../domain/snake_game.dart';
import '../game_controls.dart';
import 'tilt_3d.dart';

/// The Snake board and its controls.
///
/// This widget owns the clock. Each tick it asks the engine to step, and the
/// engine logs which tick every turn landed on. The clock only decides when
/// ticks happen, never what they do, so the server's replay is unaffected by
/// how smooth the phone is.
class SnakeBoard extends StatefulWidget {
  const SnakeBoard({required this.game, required this.controls, super.key});

  final SnakeGame game;
  final GameControls controls;

  @override
  State<SnakeBoard> createState() => _SnakeBoardState();
}

class _SnakeBoardState extends State<SnakeBoard>
    with TickerProviderStateMixin {
  Timer? _timer;
  bool _started = false;
  Offset _drag = Offset.zero;
  bool _dragFired = false;

  /// The body as it stood before the last step, so the snake can be drawn
  /// part-way between one cell and the next instead of jumping a whole cell
  /// every tick.
  List<int> _wasBody = const [];

  /// How far through the current tick the drawing is. It is only ever a view
  /// of the move the engine has already made. The clock decides when a tick
  /// happens, never what it does.
  late final AnimationController _motion;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  SnakeGame get _game => widget.game;

  bool get _running => _started && widget.controls.active && !_game.isOver;

  @override
  void initState() {
    super.initState();
    _wasBody = List.of(_game.body);
    _motion = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _game.tickIntervalMs),
      value: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant SnakeBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _motion.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Starts or stops the clock to match pause / game-over state. The interval
  /// is re-read every tick because the snake speeds up as it eats.
  void _sync() {
    if (_running) {
      _timer ??= Timer(Duration(milliseconds: _game.tickIntervalMs), _tick);
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _tick() {
    _timer = null;
    if (!mounted || !_running) return;

    _wasBody = List.of(_game.body);
    _game.step();
    // The glide runs for exactly one tick, and the tick shortens as the snake
    // speeds up, so the two never drift apart.
    _motion
      ..duration = Duration(milliseconds: _game.tickIntervalMs)
      ..forward(from: 0);
    widget.controls.onChanged();
    _sync();
  }

  void _steer(String dir) {
    if (!widget.controls.active || _game.isOver) return;
    _game.turn(dir);
    if (!_started) setState(() => _started = true);
    _sync();
  }

  void _startIfIdle() {
    if (!widget.controls.active || _game.isOver || _started) return;
    setState(() => _started = true);
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _startIfIdle,
            onPanStart: (_) {
              _drag = Offset.zero;
              _dragFired = false;
            },
            // Fire as soon as the finger has clearly moved, not on release.
            // Snake has to feel instant.
            onPanUpdate: (details) {
              if (_dragFired) return;
              _drag += details.delta;
              if (_drag.distance < 18) return;
              _dragFired = true;
              _steer(
                _drag.dx.abs() > _drag.dy.abs()
                    ? (_drag.dx > 0 ? Move.right : Move.left)
                    : (_drag.dy > 0 ? Move.down : Move.up),
              );
            },
            // No perspective tilt on this one. Snake is played by judging
            // the gap between a head and a wall, and leaning the board turns
            // square cells into trapezoids. The depth here comes from how
            // the snake itself is drawn, not from tipping the grid over.
            child: AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _SnakePainter(
                        body: _game.body,
                        wasBody: _wasBody,
                        motion: _motion,
                        food: _game.food,
                        gridSize: _game.gridSize,
                        heading: _game.heading,
                        dead: _game.dead,
                        pulse: _pulse,
                      ),
                    ),
                    if (!_started && !_game.isOver)
                      // Below centre, so the snake and the way it is facing
                      // stay visible before the first move.
                      Align(
                        alignment: const Alignment(0, 0.62),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text(
                            'Swipe or tap to start',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _DirectionPad(
          heading: _game.heading,
          onSteer: _steer,
          pulse: _pulse,
        ),
      ],
    );
  }
}

/// Where a segment sits part-way through a tick, in cells.
///
/// The snake is drawn between where it was and where it is, so it flows
/// rather than hopping a whole cell each tick. A segment that did not exist a
/// tick ago grows out of the tail end.
@visibleForTesting
Offset snakeSegmentAt({
  required List<int> body,
  required List<int> wasBody,
  required int gridSize,
  required int i,
  required double t,
}) {
  final to = body[i];
  final from = wasBody.isEmpty
      ? to
      : (i < wasBody.length ? wasBody[i] : wasBody.last);
  final a = Offset((from % gridSize).toDouble(), (from ~/ gridSize).toDouble());
  final b = Offset((to % gridSize).toDouble(), (to ~/ gridSize).toDouble());
  return Offset.lerp(a, b, t)!;
}

class _SnakePainter extends CustomPainter {
  _SnakePainter({
    required this.body,
    required this.wasBody,
    required this.motion,
    required this.food,
    required this.gridSize,
    required this.heading,
    required this.dead,
    required this.pulse,
  }) : super(repaint: Listenable.merge([pulse, motion]));

  final List<int> body;

  /// The body one tick ago. Every segment is drawn between where it was and
  /// where it is, so the snake flows instead of hopping a cell at a time.
  final List<int> wasBody;
  final Animation<double> motion;

  final int food;
  final int gridSize;
  final String heading;
  final bool dead;
  final Animation<double> pulse;

  static const _headColor = Color(0xFFB2FF59);
  static const _tailColor = Color(0xFF00E5FF);

  /// Where segment [i] sits right now, in cells, part-way through the tick.
  Offset _at(int i, double t) =>
      snakeSegmentAt(body: body, wasBody: wasBody, gridSize: gridSize, i: i, t: t);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / gridSize;
    final t = dead ? 1.0 : Curves.linear.transform(motion.value);
    final board = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(22),
    );
    canvas
      ..save()
      ..clipRRect(board);

    _paintFloor(canvas, size, cell);
    if (food >= 0) _paintGift(canvas, cell);

    // The path down the middle of the snake, from head to tail.
    final spine = [
      for (var i = 0; i < body.length; i++)
        (_at(i, t) + const Offset(0.5, 0.5)) * cell,
    ];

    _paintBody(canvas, spine, cell);
    _paintHead(canvas, spine.first, cell, t);

    canvas.restore();
  }

  /// The floor: a checker, with a soft glow under where the snake is so the
  /// board reads as lit from the snake rather than flat.
  void _paintFloor(Canvas canvas, Size size, double cell) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22)),
      Paint()..color = const Color(0xFF031B15).withValues(alpha: 0.82),
    );

    final checker = Paint()..color = Colors.white.withValues(alpha: 0.035);
    for (var y = 0; y < gridSize; y++) {
      for (var x = 0; x < gridSize; x++) {
        if ((x + y).isEven) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell, cell),
            checker,
          );
        }
      }
    }

    // Grid lines, faint, receding. Enough to judge a gap by without the
    // board turning into graph paper.
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.6;
    for (var i = 1; i < gridSize; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), line);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), line);
    }
  }

  /// The snake as one rounded ribbon rather than a row of loose beads, with a
  /// darker copy beneath it for the thickness and a lit edge along the top.
  void _paintBody(Canvas canvas, List<Offset> spine, double cell) {
    if (spine.isEmpty) return;

    final path = Path()..moveTo(spine.first.dx, spine.first.dy);
    if (spine.length == 1) {
      path.lineTo(spine.first.dx + 0.01, spine.first.dy);
    } else {
      for (var i = 1; i < spine.length; i++) {
        path.lineTo(spine[i].dx, spine[i].dy);
      }
    }

    final width = cell * 0.82;
    final head = dead ? const Color(0xFFFF5252) : _headColor;

    // The underside, offset down: the snake sits above the floor.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.18),
    );
    canvas.save();
    canvas.translate(0, cell * 0.1);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = extrusionShade(_tailColor, 0.26),
    );
    canvas.restore();

    // The body, shaded head to tail.
    final bounds = path.getBounds().inflate(width);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          colors: [head, _tailColor],
        ).createShader(bounds),
    );

    // A highlight along the upper edge, which is what turns a flat ribbon
    // into something round.
    canvas.save();
    canvas.translate(0, -width * 0.2);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.34
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.26),
    );
    canvas.restore();
  }

  /// The head: a rounded snout with eyes that look the way it is going, and a
  /// tongue that flicks out on the beat.
  void _paintHead(Canvas canvas, Offset at, double cell, double t) {
    final (dx, dy) = switch (heading) {
      Move.up => (0.0, -1.0),
      Move.down => (0.0, 1.0),
      Move.left => (-1.0, 0.0),
      _ => (1.0, 0.0),
    };
    final forward = Offset(dx, dy);
    final side = Offset(-dy, dx);
    final radius = cell * 0.46;
    final head = dead ? const Color(0xFFFF5252) : _headColor;

    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: [
            Color.lerp(head, Colors.white, 0.55)!,
            head,
            extrusionShade(head, 0.2),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: at, radius: radius)),
    );

    if (dead) {
      // Crossed-out eyes, so a crash is unmistakable.
      final cross = Paint()
        ..color = const Color(0xFF3B0A0A)
        ..strokeWidth = cell * 0.07
        ..strokeCap = StrokeCap.round;
      for (final s in [-1.0, 1.0]) {
        final eye = at + side * (radius * 0.42 * s) + forward * (radius * 0.2);
        final r = radius * 0.2;
        canvas.drawLine(eye + Offset(-r, -r), eye + Offset(r, r), cross);
        canvas.drawLine(eye + Offset(r, -r), eye + Offset(-r, r), cross);
      }
      return;
    }

    // A tongue, flicked on the pulse, ahead of the snout.
    final flick = math.sin(pulse.value * math.pi * 2);
    if (flick > 0.3) {
      final root = at + forward * radius * 0.9;
      final tip = root + forward * radius * (0.5 + flick * 0.5);
      canvas.drawLine(
        root,
        tip,
        Paint()
          ..color = const Color(0xFFFF6B9D)
          ..strokeWidth = cell * 0.07
          ..strokeCap = StrokeCap.round,
      );
      for (final s in [-1.0, 1.0]) {
        canvas.drawLine(
          tip,
          tip + forward * radius * 0.22 + side * radius * 0.2 * s,
          Paint()
            ..color = const Color(0xFFFF6B9D)
            ..strokeWidth = cell * 0.055
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    for (final s in [-1.0, 1.0]) {
      final eye = at + side * (radius * 0.42 * s) + forward * (radius * 0.24);
      canvas.drawCircle(eye, radius * 0.24, Paint()..color = Colors.white);
      // The pupil leads the way, which is what makes the head look aimed.
      canvas.drawCircle(
        eye + forward * radius * 0.08,
        radius * 0.13,
        Paint()..color = const Color(0xFF07231A),
      );
    }
  }

  /// The gift, hovering above its square with a shadow under it and a glow
  /// that breathes, so the thing worth chasing is the brightest thing on the
  /// board.
  void _paintGift(Canvas canvas, double cell) {
    final beat = pulse.value;
    final centre = Offset(
      (food % gridSize + 0.5) * cell,
      (food ~/ gridSize + 0.5) * cell,
    );
    final hover = math.sin(beat * math.pi * 2) * cell * 0.08;
    final at = centre + Offset(0, hover);

    // A halo, pulsing, which is what draws the eye across the board.
    canvas.drawCircle(
      at,
      cell * (0.62 + beat * 0.22),
      Paint()
        ..color = const Color(0xFFFF4FA3).withValues(alpha: 0.35 - beat * 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.3),
    );

    // The shadow stays on the floor while the gift floats, which is what
    // sells the height.
    canvas.drawOval(
      Rect.fromCenter(
        center: centre + Offset(0, cell * 0.36),
        width: cell * (0.5 - hover / cell * 0.5),
        height: cell * 0.14,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );

    // The box, turned a little so it reads as a solid thing in the air.
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(math.sin(beat * math.pi * 2) * 0.12);
    final box = Rect.fromCenter(
      center: Offset.zero,
      width: cell * 0.62,
      height: cell * 0.56,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        box.shift(Offset(0, cell * 0.05)),
        Radius.circular(cell * 0.1),
      ),
      Paint()..color = const Color(0xFFB0246A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(cell * 0.1)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Color(0xFFFF8FC4), Color(0xFFFF4FA3)],
        ).createShader(box),
    );

    final ribbon = Paint()..color = const Color(0xFFFFE066);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: cell * 0.12, height: box.height),
      ribbon,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: box.width, height: cell * 0.12),
      ribbon,
    );
    // The bow.
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(side * cell * 0.12, -box.height / 2 - cell * 0.02),
          width: cell * 0.2,
          height: cell * 0.14,
        ),
        ribbon,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SnakePainter old) => true;
}

/// A joystick-style D-pad: four keys around a glowing hub that shows which
/// way the snake is currently heading, in place of four identical circles.
class _DirectionPad extends StatelessWidget {
  const _DirectionPad({
    required this.heading,
    required this.onSteer,
    required this.pulse,
  });

  final String heading;
  final ValueChanged<String> onSteer;
  final Animation<double> pulse;

  static const _hubColor = Color(0xFFB2FF59);

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    const key = 56.0;
    const hub = 52.0;
    return SizedBox(
      width: key * 3 + gap * 2,
      height: key * 3 + gap * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: _DPadKey(
              icon: Icons.keyboard_arrow_up_rounded,
              tooltip: 'Up',
              active: heading == Move.up,
              onTap: () => onSteer(Move.up),
            ),
          ),
          Positioned(
            bottom: 0,
            child: _DPadKey(
              icon: Icons.keyboard_arrow_down_rounded,
              tooltip: 'Down',
              active: heading == Move.down,
              onTap: () => onSteer(Move.down),
            ),
          ),
          Positioned(
            left: 0,
            child: _DPadKey(
              icon: Icons.keyboard_arrow_left_rounded,
              tooltip: 'Left',
              active: heading == Move.left,
              onTap: () => onSteer(Move.left),
            ),
          ),
          Positioned(
            right: 0,
            child: _DPadKey(
              icon: Icons.keyboard_arrow_right_rounded,
              tooltip: 'Right',
              active: heading == Move.right,
              onTap: () => onSteer(Move.right),
            ),
          ),

          // The hub: a small compass needle pointing the way the snake is
          // actually travelling right now, breathing gently with the same
          // pulse as the food glow.
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              final glow = 0.35 + 0.25 * pulse.value;
              return Container(
                width: hub,
                height: hub,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _hubColor.withValues(alpha: 0.9),
                      _hubColor.withValues(alpha: 0.25),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _hubColor.withValues(alpha: glow),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                ),
                child: child,
              );
            },
            child: AnimatedRotation(
              turns: switch (heading) {
                Move.up => 0,
                Move.right => 0.25,
                Move.down => 0.5,
                _ => 0.75,
              },
              duration: const Duration(milliseconds: 150),
              child: const Icon(
                Icons.navigation_rounded,
                color: Color(0xFF04331F),
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One D-pad key: a rounded glass tile that bounces on press and lights up
/// when it's the direction the snake is already travelling.
class _DPadKey extends StatefulWidget {
  const _DPadKey({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_DPadKey> createState() => _DPadKeyState();
}

class _DPadKeyState extends State<_DPadKey> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.active ? 0.85 : (_pressed ? 0.4 : 0.18);
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: widget.active ? 0.32 : 0.16),
                  Colors.white.withValues(alpha: widget.active ? 0.14 : 0.05),
                ],
              ),
              border: Border.all(
                color: widget.active
                    ? const Color(0xFFB2FF59).withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.28),
                width: widget.active ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB2FF59).withValues(alpha: glow * 0.5),
                  blurRadius: widget.active ? 14 : 6,
                  spreadRadius: widget.active ? 1 : 0,
                ),
              ],
            ),
            child: Icon(
              widget.icon,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}
