import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/basketball_game.dart';
import '../game_controls.dart';
import 'tick_clock.dart';

// World units. x is sideways (the same units as a shot's aim), y is height
// above the floor and z is depth away from the camera.
const double _zHoop = 700;
const double _boardZ = 730;
const double _rimY = 300;
const double _rimR = 22;
const double _ballR = 12;
const double _heldY = 36;

double _spotZ(int distance) => _zHoop - (190 + 85 * distance);

double _lerp(double a, double b, double t) => a + (b - a) * t;

int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

/// Turns a swipe into the whole numbers the engine logs: sideways travel
/// sets the aim, upward travel the power.
(int, int) basketballShotFromSwipe(Offset drag, Size size) {
  final aim = _clampInt(
    (drag.dx / (size.width * 0.42) * 100).round(),
    -BasketballGame.aimLimit,
    BasketballGame.aimLimit,
  );
  final power = _clampInt(
    (-drag.dy / (size.height * 0.5) * 100).round(),
    0,
    BasketballGame.maxPower,
  );
  return (aim, power);
}

/// The 3D court: swipe up from the ball to shoot.
///
/// Everything is drawn from the engine's whole-number state through a
/// perspective camera, so the arc you see is the shot the server scores.
class BasketballCourt extends StatefulWidget {
  const BasketballCourt({
    required this.game,
    required this.controls,
    super.key,
  });

  final BasketballGame game;
  final GameControls controls;

  @override
  State<BasketballCourt> createState() => _BasketballCourtState();
}

class _BasketballCourtState extends State<BasketballCourt>
    with SingleTickerProviderStateMixin {
  late final TickClock _clock = TickClock(
    vsync: this,
    game: widget.game,
    // The shot clock and scoreboard change as ticks pass.
    onTicks: (_) => widget.controls.onChanged(),
  );

  bool _started = false;
  Offset? _drag;
  Size _size = Size.zero;

  BasketballGame get _game => widget.game;

  @override
  void didUpdateWidget(covariant BasketballCourt oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _sync() =>
      _clock.run(_started && widget.controls.active && !_game.isOver);

  void _panStart(DragStartDetails details) {
    if (!widget.controls.active || _game.isOver) return;
    // The shot clock starts with the first touch, not when the screen opens.
    if (!_started) _started = true;
    _sync();
    setState(() => _drag = Offset.zero);
  }

  void _panUpdate(DragUpdateDetails details) {
    final drag = _drag;
    if (drag == null) return;
    setState(() => _drag = drag + details.delta);
  }

  void _panEnd(DragEndDetails details) {
    final drag = _drag;
    setState(() => _drag = null);
    if (drag == null || !widget.controls.active) return;
    // A tap or a sideways brush is not a shot.
    if (drag.dy > -12) return;
    final (aim, power) = basketballShotFromSwipe(drag, _size);
    if (_game.shoot(aim, power) != null) widget.controls.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : width * 1.45;
        _size = Size(width, height);

        return SizedBox(
          width: width,
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: _panStart,
            onPanUpdate: _panUpdate,
            onPanEnd: _panEnd,
            child: ClipRRect(
              // Square: the scene runs to the corners of the screen now, and a
              // rounded one would leave the backdrop showing through them.
              borderRadius: BorderRadius.zero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _CourtPainter(
                      game: _game,
                      clock: _clock,
                      drag: _drag,
                    ),
                  ),
                  if (_game.onFire)
                    const Positioned(
                      top: 12,
                      left: 12,
                      child: _CourtBadge(
                        icon: Icons.local_fire_department_rounded,
                        label: 'ON FIRE ×2',
                        color: Color(0xFFFF6D00),
                      ),
                    ),
                  if (_game.level > 0)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _CourtBadge(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Level ${_game.level + 1}',
                        color: const Color(0xFF7C4DFF),
                      ),
                    ),
                  if (!_started)
                    const Align(
                      alignment: Alignment(0, 0.3),
                      child: _CourtPrompt('Swipe up from the ball to shoot'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CourtBadge extends StatelessWidget {
  const _CourtBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourtPrompt extends StatelessWidget {
  const _CourtPrompt(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _Vec {
  const _Vec(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

/// A pinhole camera behind the shooter, looking down the court.
class _Camera {
  _Camera(this.size)
    : f = math.min(size.width * 1.35, size.height * 0.85),
      horizon = size.height * 0.33;

  final Size size;
  final double f;
  final double horizon;

  static const double eyeY = 160;

  Offset p(double x, double y, double z) =>
      Offset(size.width / 2 + x * f / z, horizon + (eyeY - y) * f / z);

  double scale(double z) => f / z;
}

class _CourtPainter extends CustomPainter {
  _CourtPainter({required this.game, required this.clock, required this.drag})
    : super(repaint: clock);

  final BasketballGame game;
  final TickClock clock;
  final Offset? drag;

  @override
  void paint(Canvas canvas, Size size) {
    final cam = _Camera(size);
    final t = clock.smoothTick;
    final cfg = game.config;

    _arena(canvas, size, cam);
    _floor(canvas, cam);

    final shot = game.lastShot;
    final inPlay = shot != null && t < shot.tick + cfg.shotCooldownTicks;
    // While a ball is in the air the hoop keeps the rhythm it was thrown at.
    final hoopLevel = inPlay ? shot.level : game.level;
    final hx = _hoopAt(t, hoopLevel);

    _backboard(canvas, cam, hx);

    final ball = _ballPosition(t, shot, inPlay);
    final stretch = _netStretch(t, shot, inPlay);
    final spin = inPlay ? (t - shot.tick) * 0.6 : 0.0;

    // Draw the ball between the back and the front of the rim when it is
    // dropping through, so it really goes *through* the hoop.
    final behind =
        ball != null &&
        ball.z >= _zHoop - _rimR &&
        ball.y <= _rimY + _ballR * 0.5;
    _rim(canvas, cam, hx, back: true, stretch: stretch);
    if (ball != null && behind) _ball(canvas, cam, ball, spin);
    _rim(canvas, cam, hx, back: false, stretch: stretch);
    if (ball != null && !behind) _ball(canvas, cam, ball, spin);

    if (drag != null && ball != null && !inPlay) {
      _preview(canvas, size, cam, ball);
    }
    if (shot != null) _popup(canvas, cam, shot, t);
  }

  double _hoopAt(double t, int level) {
    final tick = t.floor();
    final a = game.hoopXFor(tick, level).toDouble();
    final b = game.hoopXFor(tick + 1, level).toDouble();
    return _lerp(a, b, t - tick);
  }

  // ─── Scenery ───────────────────────────────────────────────────────────

  void _arena(Canvas canvas, Size size, _Camera cam) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0620), Color(0xFF2A1250), Color(0xFF3B1A4A)],
        ).createShader(rect),
    );

    // Spotlights from the rafters.
    for (final x in const [0.18, 0.82]) {
      final center = Offset(size.width * x, -size.height * 0.05);
      final radius = size.height * 0.75;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.16),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // The crowd: rows of heads above the far baseline. A fixed pattern.
    // decoration only.
    final crowdTop = cam.horizon - size.height * 0.17;
    const perRow = 26;
    for (var row = 0; row < 7; row++) {
      final y = crowdTop + row * size.height * 0.022;
      for (var i = 0; i < perRow; i++) {
        final h = math.sin((row * 31 + i) * 12.9898) * 43758.5453;
        final hue = (h - h.floorToDouble()) * 360;
        final x = (i + (row.isOdd ? 0.5 : 0)) / perRow * size.width;
        canvas.drawCircle(
          Offset(x, y),
          size.width * 0.012,
          Paint()
            ..color = HSVColor.fromAHSV(
              0.55,
              hue,
              0.5,
              0.5 + row * 0.05,
            ).toColor(),
        );
      }
    }
  }

  void _floor(Canvas canvas, _Camera cam) {
    const near = 205.0;
    const far = 790.0;
    const halfW = 175.0;
    Offset p(double x, double z) => cam.p(x, 0, z);

    final court = Path()
      ..addPolygon([
        p(-halfW, near),
        p(halfW, near),
        p(halfW, far),
        p(-halfW, far),
      ], true);
    canvas.drawPath(
      court,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB86B32), Color(0xFFE8B071)],
        ).createShader(court.getBounds()),
    );

    // Floorboards converge on the vanishing point.
    final plank = Paint()
      ..color = Colors.black.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (var x = -halfW; x <= halfW; x += 22) {
      canvas.drawLine(p(x, near), p(x, far), plank);
    }

    // The painted key.
    canvas.drawPath(
      Path()
        ..addPolygon([p(-55, 560), p(55, 560), p(55, 720), p(-55, 720)], true),
      Paint()..color = const Color(0xFF6D28D9).withValues(alpha: 0.55),
    );

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    Path poly(List<Offset> pts) => Path()..addPolygon(pts, false);

    canvas
      ..drawPath(poly([p(-55, 720), p(-55, 560), p(55, 560), p(55, 720)]), line)
      ..drawLine(p(-halfW, 720), p(halfW, 720), line)
      ..drawLine(p(-halfW, near), p(-halfW, 720), line)
      ..drawLine(p(halfW, near), p(halfW, 720), line);

    // Free-throw circle and the three-point arc.
    canvas.drawPath(
      poly([
        for (var i = 0; i <= 32; i++)
          p(
            45 * math.cos(i / 32 * 2 * math.pi),
            560 + 45 * math.sin(i / 32 * 2 * math.pi),
          ),
      ]),
      line,
    );
    final arc = <Offset>[];
    for (var i = 0; i <= 48; i++) {
      final th = math.pi + math.pi * i / 48;
      final x = 300 * math.cos(th);
      if (x.abs() <= halfW) arc.add(p(x, 720 + 300 * math.sin(th)));
    }
    canvas.drawPath(poly(arc), line);
  }

  void _backboard(Canvas canvas, _Camera cam, double hx) {
    // Stanchion and arm.
    final poleWidth = 7 * cam.scale(800);
    final pole = Paint()
      ..color = const Color(0xFF263238)
      ..strokeWidth = poleWidth * 2
      ..strokeCap = StrokeCap.round;
    final top = cam.p(hx, 335, 800);
    canvas
      ..drawLine(cam.p(hx, 0, 800), top, pole)
      ..drawLine(top, cam.p(hx, 335, _boardZ), pole..strokeWidth = poleWidth);

    // Glass backboard.
    final board = Path()
      ..addPolygon([
        cam.p(hx - 72, 388, _boardZ),
        cam.p(hx + 72, 388, _boardZ),
        cam.p(hx + 72, 282, _boardZ),
        cam.p(hx - 72, 282, _boardZ),
      ], true);
    canvas
      ..drawPath(board, Paint()..color = Colors.white.withValues(alpha: 0.88))
      ..drawPath(
        board,
        Paint()
          ..color = const Color(0xFFE53935)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      )
      ..drawPath(
        Path()..addPolygon([
          cam.p(hx - 24, 342, _boardZ),
          cam.p(hx + 24, 342, _boardZ),
          cam.p(hx + 24, 302, _boardZ),
          cam.p(hx - 24, 302, _boardZ),
        ], true),
        Paint()
          ..color = const Color(0xFFE53935)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );

    // The shot clock sits on top of the board.
    final clockRect = Rect.fromPoints(
      cam.p(hx - 32, 422, _boardZ),
      cam.p(hx + 32, 394, _boardZ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(clockRect, const Radius.circular(4)),
      Paint()..color = const Color(0xFF111111),
    );
    final seconds = (game.ticksLeft * game.tickMs / 1000).ceil();
    final text = TextPainter(
      text: TextSpan(
        text: '$seconds',
        style: TextStyle(
          color: seconds <= 5
              ? const Color(0xFFFF1744)
              : const Color(0xFFFF6E40),
          fontSize: clockRect.height * 0.8,
          fontWeight: FontWeight.w900,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      clockRect.center - Offset(text.width / 2, text.height / 2),
    );
  }

  /// Half the rim and net: the back half is drawn before the ball, the
  /// front half after it.
  void _rim(
    Canvas canvas,
    _Camera cam,
    double hx, {
    required bool back,
    required double stretch,
  }) {
    final s = cam.scale(_zHoop);
    final from = back ? 0.0 : math.pi;
    Offset rimPoint(double th, double r, double y) =>
        cam.p(hx + r * math.cos(th), y, _zHoop + r * math.sin(th));

    if (back) {
      // The bracket holding the rim to the board.
      canvas.drawLine(
        rimPoint(math.pi / 2, _rimR, _rimY),
        cam.p(hx, _rimY, _boardZ),
        Paint()
          ..color = const Color(0xFFBF360C)
          ..strokeWidth = math.max(2, 2.4 * s),
      );
    }

    final net = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = math.max(1, 0.7 * s);
    final netBottom = _rimY - 42 - stretch;
    const strings = 6;
    for (var k = 0; k <= strings; k++) {
      final th = from + math.pi * k / strings;
      canvas.drawLine(
        rimPoint(th, _rimR, _rimY),
        rimPoint(th + 0.35, 12, netBottom),
        net,
      );
    }
    final ring = Path();
    for (var i = 0; i <= 16; i++) {
      final pt = rimPoint(
        from + math.pi * i / 16,
        16,
        _rimY - 22 - stretch / 2,
      );
      i == 0 ? ring.moveTo(pt.dx, pt.dy) : ring.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(ring, net..style = PaintingStyle.stroke);

    final rim = Path();
    for (var i = 0; i <= 28; i++) {
      final pt = rimPoint(from + math.pi * i / 28, _rimR, _rimY);
      i == 0 ? rim.moveTo(pt.dx, pt.dy) : rim.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(
      rim,
      Paint()
        ..color = const Color(0xFFFF5722)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.5, 2.6 * s)
        ..strokeCap = StrokeCap.round,
    );
  }

  // ─── The ball ──────────────────────────────────────────────────────────

  _Vec _missEnd(BasketballShot s) {
    final pe = s.powerError.toDouble();
    return _Vec(
      s.aim.toDouble(),
      math.max(_ballR, _rimY + 4 + pe * 3),
      (_zHoop + pe * 5).clamp(_zHoop - 200, _boardZ - 14),
    );
  }

  _Vec? _ballPosition(double t, BasketballShot? shot, bool inPlay) {
    final cfg = game.config;
    if (!inPlay) {
      if (game.ticksLeft <= 0) return null;
      return _Vec(0, _heldY, _spotZ(game.distance));
    }
    final s = shot!;
    final start = _Vec(0, _heldY, _spotZ(s.distance));
    final end = s.made
        ? _Vec(s.hoopX.toDouble(), _rimY + 6, _zHoop)
        : _missEnd(s);
    final elapsed = t - s.tick;
    final flight = cfg.flightTicks.toDouble();

    if (elapsed <= flight) {
      final p = (elapsed / flight).clamp(0.0, 1.0);
      final arc = 150 + 40.0 * s.distance;
      return _Vec(
        _lerp(start.x, end.x, p),
        _lerp(start.y, end.y, p) + arc * 4 * p * (1 - p),
        _lerp(start.z, end.z, p),
      );
    }

    final q = ((elapsed - flight) / math.max(1, cfg.shotCooldownTicks - flight))
        .clamp(0.0, 1.0);
    if (s.made) {
      // Through the net, then a little bounce under the hoop.
      final y = q < 0.55
          ? end.y - (end.y - _ballR) * math.pow(q / 0.55, 2)
          : _ballR + 36 * math.sin((q - 0.55) / 0.45 * math.pi);
      return _Vec(end.x, y.toDouble(), end.z);
    }
    // A near miss rattles out off the rim; a bad one just drops.
    final dir = s.aimError == 0 ? 1.0 : s.aimError.sign.toDouble();
    final rimOut = s.aimError.abs() <= 28 && s.powerError.abs() <= 14;
    final y = math.max(
      _ballR,
      end.y * (1 - q) * (1 - q) +
          (rimOut ? 80 : 26) * math.sin(q * math.pi) * (1 - q * 0.5),
    );
    return _Vec(
      end.x + dir * (rimOut ? 90 : 35) * q,
      y,
      end.z + (rimOut ? -70 : 25) * q,
    );
  }

  double _netStretch(double t, BasketballShot? shot, bool inPlay) {
    if (!inPlay || !shot!.made) return 0;
    final cfg = game.config;
    final after = t - shot.tick - cfg.flightTicks;
    final window = (cfg.shotCooldownTicks - cfg.flightTicks) * 0.55;
    if (after < 0 || after > window) return 0;
    return 16 * math.sin(after / window * math.pi);
  }

  void _ball(Canvas canvas, _Camera cam, _Vec b, double spin) {
    final center = cam.p(b.x, b.y, b.z);
    final r = _ballR * cam.scale(b.z);

    // A shadow on the floor that shrinks and fades as the ball rises.
    final lift = (b.y / 420).clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: cam.p(b.x, 0, b.z),
        width: r * 2.2 * (1 - lift * 0.5),
        height: r * 0.6 * (1 - lift * 0.5),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.35 * (1 - lift)),
    );

    if (game.onFire) {
      final glow = r * 2.3;
      canvas.drawCircle(
        center,
        glow,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFD54F).withValues(alpha: 0.7),
              const Color(0xFFFF6D00).withValues(alpha: 0.35),
              const Color(0xFFFF6D00).withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: glow)),
      );
    }

    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          colors: [Color(0xFFFFC38A), Color(0xFFF26B1D), Color(0xFF7A2E05)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );

    // Seams, turning as the ball spins.
    final seam = Paint()
      ..color = const Color(0xFF3A1602)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * 0.08);
    canvas
      ..save()
      ..clipPath(Path()..addOval(rect))
      ..translate(center.dx, center.dy)
      ..rotate(spin)
      ..drawLine(Offset(-r, 0), Offset(r, 0), seam)
      ..drawLine(Offset(0, -r), Offset(0, r), seam)
      ..drawArc(
        Rect.fromCircle(center: Offset(-r * 1.25, 0), radius: r * 0.95),
        -0.9,
        1.8,
        false,
        seam,
      )
      ..drawArc(
        Rect.fromCircle(center: Offset(r * 1.25, 0), radius: r * 0.95),
        math.pi - 0.9,
        1.8,
        false,
        seam,
      )
      ..restore();

    canvas.drawCircle(
      center + Offset(-r * 0.35, -r * 0.4),
      r * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  // ─── Aiming and feedback ───────────────────────────────────────────────

  void _preview(Canvas canvas, Size size, _Camera cam, _Vec ball) {
    final (aim, power) = basketballShotFromSwipe(drag!, size);
    final required = BasketballGame.requiredPower(game.distance);
    final tolerance = game.config.powerTolerance;
    final good = (power - required).abs() <= tolerance;
    final color = good ? const Color(0xFF69F0AE) : const Color(0xFFFFD54F);

    // The arc this swipe would throw.
    final pe = (power - required).toDouble();
    final endY = math.max(_ballR, _rimY + 6 + pe * 3);
    final endZ = (_zHoop + pe * 5).clamp(_zHoop - 200, _boardZ - 14);
    final arc = 150 + 40.0 * game.distance;
    for (var i = 1; i <= 14; i++) {
      final p = i / 15;
      final pt = cam.p(
        _lerp(ball.x, aim.toDouble(), p),
        _lerp(ball.y, endY, p) + arc * 4 * p * (1 - p),
        _lerp(ball.z, endZ, p),
      );
      canvas.drawCircle(
        pt,
        3.4 - p * 1.8,
        Paint()..color = color.withValues(alpha: 0.95 - p * 0.45),
      );
    }

    // Power meter with the sweet spot for this spot on the floor.
    final top = size.height * 0.36;
    final bottom = size.height * 0.86;
    final x = size.width - 24;
    double yFor(int v) => bottom - (bottom - top) * v / BasketballGame.maxPower;
    canvas
      ..drawRRect(
        RRect.fromLTRBR(x - 7, top, x + 7, bottom, const Radius.circular(7)),
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      )
      ..drawRect(
        Rect.fromLTRB(
          x - 7,
          yFor(required + tolerance),
          x + 7,
          yFor(required - tolerance),
        ),
        Paint()..color = const Color(0xFF69F0AE).withValues(alpha: 0.55),
      )
      ..drawRRect(
        RRect.fromLTRBR(
          x - 4,
          yFor(power),
          x + 4,
          bottom,
          const Radius.circular(4),
        ),
        Paint()..color = color,
      );
  }

  void _popup(Canvas canvas, _Camera cam, BasketballShot s, double t) {
    final age = t - s.tick - game.config.flightTicks;
    if (age < 0 || age > 24) return;
    final k = age / 24;
    final label = !s.made
        ? 'MISS'
        : s.onFire
        ? '+${s.points}  ON FIRE!'
        : s.swish
        ? '+${s.points}  SWISH!'
        : '+${s.points}';
    final anchor = cam.p(
      (s.made ? s.hoopX : s.aim).toDouble(),
      _rimY + 70 + 50 * k,
      _zHoop,
    );
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: (s.made ? const Color(0xFFFFE066) : Colors.white).withValues(
            alpha: 1 - k,
          ),
          fontSize: 22,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, anchor - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(_CourtPainter oldDelegate) => true;
}
