import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/cricket_game.dart';
import '../game_controls.dart';
import 'tick_clock.dart';

// World units: x sideways, y up, z away from the camera behind the batter.
const double _stumpZ = 240;
const double _batZ = 268;
const double _bowlerStumpZ = 1240;
const double _fieldRadius = 520;

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// The stadium in perspective, seen from behind the batter. Tap to swing;
/// where you tap aims the shot. Left of the batter goes left.
class CricketPitch extends StatefulWidget {
  const CricketPitch({required this.game, required this.controls, super.key});

  final CricketGame game;
  final GameControls controls;

  @override
  State<CricketPitch> createState() => _CricketPitchState();
}

class _CricketPitchState extends State<CricketPitch>
    with SingleTickerProviderStateMixin {
  late final TickClock _clock = TickClock(
    vsync: this,
    game: widget.game,
    onTicks: (_) {
      final seen = widget.game.outcomes.length;
      if (seen != _seen || widget.game.isOver) {
        _seen = seen;
        widget.controls.onChanged();
      }
    },
  );

  bool _started = false;
  int _seen = 0;
  int? _swingTick;

  CricketGame get _game => widget.game;

  @override
  void didUpdateWidget(covariant CricketPitch oldWidget) {
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

  void _tap(TapDownDetails details, double width) {
    if (!widget.controls.active || _game.isOver) return;
    if (!_started) {
      setState(() => _started = true);
      _sync();
      return;
    }
    final maxAngle = _game.config.maxAngle;
    final angle = ((details.localPosition.dx / width - 0.5) * 2 * maxAngle)
        .round();
    setState(() => _swingTick = _game.tick);
    if (_game.swing(angle) != null) {
      _seen = _game.outcomes.length;
      widget.controls.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _tap(d, width),
          child: ClipRRect(
            // Square: the scene runs to the corners of the screen now, and a
            // rounded one would leave the backdrop showing through them.
            borderRadius: BorderRadius.zero,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _CricketPainter(
                    game: _game,
                    clock: _clock,
                    swingTick: _swingTick,
                  ),
                ),
                AnimatedBuilder(
                  animation: _clock,
                  builder: (context, _) => _Hud(game: _game),
                ),
                if (!_started)
                  const Align(
                    alignment: Alignment(0, 0.35),
                    child: _Prompt('Tap to start'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt(this.text);

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
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// The ball counter and what just happened.
class _Hud extends StatelessWidget {
  const _Hud({required this.game});

  final CricketGame game;

  static (String, String) _describe(CricketGame game, CricketOutcome o) {
    final title = switch (o) {
      CricketOutcome(wicket: true, swung: true, timing: 1) => 'CAUGHT!',
      CricketOutcome(wicket: true) => 'BOWLED!',
      CricketOutcome(runs: 6) => 'SIX!',
      CricketOutcome(runs: 4) => 'FOUR!',
      CricketOutcome(runs: 1, timing: 1) => 'Edged for 1',
      CricketOutcome(runs: 1, blocked: true) => 'Stopped · 1 run',
      CricketOutcome(runs: 1) => '1 run',
      CricketOutcome(swung: false) => 'Dot ball',
      _ => 'Missed',
    };
    final delta = o.tick - game.arrival(o.ball);
    final timing = !o.swung
        ? ''
        : switch (o.timing) {
            3 => 'Perfect timing',
            2 => 'Good timing',
            1 => 'Off the edge',
            _ => delta < 0 ? 'Too early' : 'Too late',
          };
    return (title, timing);
  }

  @override
  Widget build(BuildContext context) {
    final last = game.lastOutcome;
    final showLast = last != null && game.tick - last.tick < 70;
    final ball = math.min(game.nextBall + 1, game.config.balls);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 12,
            left: 12,
            child: _pill('Ball $ball of ${game.config.balls}'),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: _pill('${game.runs}/${game.wickets}'),
          ),
          if (showLast)
            Align(
              alignment: const Alignment(0, -0.45),
              child: Builder(
                builder: (context) {
                  final (title, timing) = _describe(game, last);
                  final big = last.runs >= 4 || last.wicket;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: last.wicket
                              ? const Color(0xFFFF5252)
                              : const Color(0xFFFFE066),
                          fontSize: big ? 40 : 26,
                          fontWeight: FontWeight.w900,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 10),
                          ],
                        ),
                      ),
                      if (timing.isNotEmpty)
                        Text(
                          timing,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 6),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
    ),
  );
}

class _Vec {
  const _Vec(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

class _Camera {
  _Camera(this.size)
    : f = math.min(size.width * 1.5, size.height * 1.0),
      horizon = size.height * 0.34;

  final Size size;
  final double f;
  final double horizon;

  static const double eyeY = 150;

  Offset p(double x, double y, double z) =>
      Offset(size.width / 2 + x * f / z, horizon + (eyeY - y) * f / z);

  double scale(double z) => f / z;
}

class _CricketPainter extends CustomPainter {
  _CricketPainter({
    required this.game,
    required this.clock,
    required this.swingTick,
  }) : super(repaint: clock);

  final CricketGame game;
  final TickClock clock;
  final int? swingTick;

  @override
  void paint(Canvas canvas, Size size) {
    final cam = _Camera(size);
    final t = clock.smoothTick;
    final cfg = game.config;
    final ball = math.min(t ~/ cfg.ballCycleTicks, cfg.balls - 1);

    _stands(canvas, size, cam);
    _field(canvas, cam);
    _gapRing(canvas, cam, ball);
    _pitch(canvas, cam);
    _stumps(canvas, cam, _bowlerStumpZ, 0);

    final field = game.fieldFor(ball);
    final order = [...field]..sort((a, b) => b.abs().compareTo(a.abs()));
    for (final angle in order) {
      final rad = angle * math.pi / 180;
      _figure(
        canvas,
        cam,
        _fieldRadius * math.sin(rad),
        _stumpZ + _fieldRadius * math.cos(rad),
        const Color(0xFF1565C0),
      );
    }

    _bowler(canvas, cam, t, ball);
    final pos = _ballPosition(t, ball);
    if (pos != null && pos.z > _batZ + 10) _ball(canvas, cam, pos);
    _stumps(canvas, cam, _stumpZ, _bowledAge(t, ball));
    _batter(canvas, cam, t);
    if (pos != null && pos.z <= _batZ + 10) _ball(canvas, cam, pos);
  }

  // ─── Ball ──────────────────────────────────────────────────────────────

  CricketOutcome? _outcome(int ball) {
    final outcomes = game.outcomes;
    return ball < outcomes.length ? outcomes[ball] : null;
  }

  double? _bowledAge(double t, int ball) {
    final o = _outcome(ball);
    if (o == null || !o.wicket || (o.swung && o.timing == 1)) return null;
    final at = game.arrival(ball).toDouble();
    return t < at ? null : (t - at) / 30;
  }

  _Vec? _ballPosition(double t, int ball) {
    final outcome = _outcome(ball);
    if (game.inningsOver && outcome == null) return null;
    final release = game.release(ball).toDouble();
    final arrival = game.arrival(ball).toDouble();
    final line = game.balls[ball].line * 28.0;

    if (t < release) {
      // In the bowler's hand during the run-up.
      final k =
          (t - ball * game.config.ballCycleTicks) / game.config.runupTicks;
      return _Vec(18, 150, _lerp(1480, 1250, k.clamp(0.0, 1.0)));
    }

    final hit = outcome != null && outcome.swung && outcome.timing > 0;
    if (!hit && (outcome == null || t <= arrival)) {
      // The delivery: down, a bounce, and up to the bat.
      final p = (t - release) / (arrival - release);
      if (p < 0.7) {
        final q = p / 0.7;
        return _Vec(
          _lerp(line * 0.4, line * 0.8, q),
          200 * (1 - q * q),
          _lerp(_bowlerStumpZ, 560, q),
        );
      }
      final q = math.min((p - 0.7) / 0.3, 1.8);
      return _Vec(
        _lerp(line * 0.8, line, q),
        42 * math.sin(q * math.pi / 2),
        _lerp(560, 280, q),
      );
    }

    if (!hit) {
      // Past the bat: into the stumps, or through to the keeper.
      final u = ((t - arrival) / 25).clamp(0.0, 1.0);
      final bowled = outcome.wicket;
      return _Vec(
        _lerp(line, bowled ? 0 : line * 1.3, u),
        _lerp(42, bowled ? 40 : 20, u),
        _lerp(280, bowled ? _stumpZ : 160, u),
      );
    }

    // Struck: away towards where the shot was aimed.
    final start = math.max(outcome.tick.toDouble(), arrival - 2);
    final u = ((t - start) / 55).clamp(0.0, 1.0);
    final rad = outcome.angle * math.pi / 180;
    final dist = outcome.wicket || outcome.blocked
        ? _fieldRadius
        : switch (outcome.runs) {
            6 => 820.0,
            4 => 720.0,
            _ => 260.0,
          };
    final arc = switch (outcome.runs) {
      6 => 300.0,
      4 => 18.0,
      _ => outcome.wicket ? 120.0 : 30.0,
    };
    final eased = 1 - (1 - u) * (1 - u);
    return _Vec(
      dist * math.sin(rad) * eased,
      50 + arc * 4 * u * (1 - u),
      _batZ + 20 + dist * math.cos(rad) * eased,
    );
  }

  void _ball(Canvas canvas, _Camera cam, _Vec b) {
    final s = cam.scale(b.z);
    final c = cam.p(b.x, b.y, b.z);
    final r = math.max(2.0, 5 * s);
    canvas
      ..drawOval(
        Rect.fromCenter(
          center: cam.p(b.x, 0, b.z),
          width: r * 2.4,
          height: r * 0.7,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.3),
      )
      ..drawCircle(
        c,
        r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.4),
            colors: [Color(0xFFFF8A80), Color(0xFFC62828), Color(0xFF5D0000)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
  }

  // ─── Scenery ───────────────────────────────────────────────────────────

  void _stands(Canvas canvas, Size size, _Camera cam) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D1B3E), Color(0xFF2B4C7E), Color(0xFF14532D)],
          stops: [0, 0.3, 0.45],
        ).createShader(rect),
    );

    // Tiers of the crowd behind the far boundary.
    final top = cam.horizon - size.height * 0.2;
    for (var row = 0; row < 8; row++) {
      final y = top + row * size.height * 0.024;
      for (var i = 0; i < 30; i++) {
        final h = math.sin((row * 37 + i) * 12.9898) * 43758.5453;
        final hue = (h - h.floorToDouble()) * 360;
        canvas.drawCircle(
          Offset((i + (row.isOdd ? 0.5 : 0)) / 30 * size.width, y),
          size.width * 0.011,
          Paint()
            ..color = HSVColor.fromAHSV(
              0.6,
              hue,
              0.45,
              0.5 + row * 0.05,
            ).toColor(),
        );
      }
    }

    // Floodlight towers.
    for (final side in const [0.06, 0.94]) {
      final x = size.width * side;
      canvas.drawLine(
        Offset(x, cam.horizon),
        Offset(x, size.height * 0.02),
        Paint()
          ..color = const Color(0xFF90A4AE)
          ..strokeWidth = 3,
      );
      final lamp = Offset(x, size.height * 0.03);
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: lamp, width: 26, height: 12),
            const Radius.circular(3),
          ),
          Paint()..color = const Color(0xFFFFF9C4),
        )
        ..drawCircle(
          lamp,
          60,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFFFF9C4).withValues(alpha: 0.35),
                const Color(0xFFFFF9C4).withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: lamp, radius: 60)),
        );
    }
  }

  List<Offset> _ellipse(_Camera cam, double rx, double rz, double cz) {
    final pts = <Offset>[];
    for (var i = 0; i <= 72; i++) {
      final th = i / 72 * 2 * math.pi;
      final z = cz + rz * math.sin(th);
      if (z < 150) continue;
      pts.add(cam.p(rx * math.cos(th), 0, z));
    }
    return pts;
  }

  void _field(Canvas canvas, _Camera cam) {
    final size = cam.size;
    // Grass from the far boundary down to the camera.
    final far = _ellipse(cam, 760, 700, 820);
    final field = Path()..addPolygon(far, true);
    field
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height);
    canvas.drawPath(
      Path()..addPolygon([
        ...far,
        Offset(size.width, size.height),
        Offset(0, size.height),
      ], true),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
        ).createShader(Offset.zero & size),
    );

    // Mowing stripes across the outfield.
    for (var k = 0; k < 12; k++) {
      final z0 = 200.0 + k * 110;
      if (k.isOdd) continue;
      canvas.drawPath(
        Path()..addPolygon([
          cam.p(-900, 0, z0),
          cam.p(900, 0, z0),
          cam.p(900, 0, z0 + 110),
          cam.p(-900, 0, z0 + 110),
        ], true),
        Paint()..color = Colors.white.withValues(alpha: 0.05),
      );
    }

    // The boundary rope.
    canvas.drawPath(
      Path()..addPolygon(_ellipse(cam, 700, 640, 820), false),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  /// A ring on the grass: green where the gaps are, red where a fielder
  /// can reach.
  void _gapRing(Canvas canvas, _Camera cam, int ball) {
    final reach = game.config.fielderReach;
    final field = game.fieldFor(ball);
    const radius = 560.0;
    for (var a = -game.config.maxAngle; a < game.config.maxAngle; a += 2) {
      final blocked = field.any((f) => (a + 1 - f).abs() <= reach);
      final r0 = a * math.pi / 180;
      final r1 = (a + 2) * math.pi / 180;
      canvas.drawLine(
        cam.p(radius * math.sin(r0), 0, _stumpZ + radius * math.cos(r0)),
        cam.p(radius * math.sin(r1), 0, _stumpZ + radius * math.cos(r1)),
        Paint()
          ..strokeWidth = 5
          ..color =
              (blocked ? const Color(0xFFFF5252) : const Color(0xFFB9F6CA))
                  .withValues(alpha: 0.55),
      );
    }
  }

  void _pitch(Canvas canvas, _Camera cam) {
    canvas.drawPath(
      Path()..addPolygon([
        cam.p(-42, 0, 200),
        cam.p(42, 0, 200),
        cam.p(42, 0, 1300),
        cam.p(-42, 0, 1300),
      ], true),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC8B27A), Color(0xFFE6D3A3)],
        ).createShader(Offset.zero & cam.size),
    );
    final crease = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    for (final z in const [300.0, _bowlerStumpZ - 60]) {
      canvas.drawLine(cam.p(-60, 0, z), cam.p(60, 0, z), crease);
    }
  }

  // ─── People and stumps ────────────────────────────────────────────────

  void _figure(Canvas canvas, _Camera cam, double x, double z, Color kit) {
    if (z < 180) return;
    final s = cam.scale(z);
    final foot = cam.p(x, 0, z);
    canvas
      ..drawOval(
        Rect.fromCenter(center: foot, width: 26 * s, height: 7 * s),
        Paint()..color = Colors.black.withValues(alpha: 0.28),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: foot - Offset(0, 36 * s),
            width: 16 * s,
            height: 52 * s,
          ),
          Radius.circular(8 * s),
        ),
        Paint()
          ..shader =
              LinearGradient(
                colors: [Colors.white, Colors.white, kit],
                stops: const [0, 0.55, 1],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(
                Rect.fromCenter(
                  center: foot - Offset(0, 36 * s),
                  width: 16 * s,
                  height: 52 * s,
                ),
              ),
      )
      ..drawCircle(
        foot - Offset(0, 70 * s),
        8 * s,
        Paint()..color = const Color(0xFF8D5524),
      )
      ..drawArc(
        Rect.fromCircle(center: foot - Offset(0, 71 * s), radius: 8.5 * s),
        math.pi,
        math.pi,
        true,
        Paint()..color = kit,
      );
  }

  void _bowler(Canvas canvas, _Camera cam, double t, int ball) {
    final start = (ball * game.config.ballCycleTicks).toDouble();
    final k = ((t - start) / game.config.runupTicks).clamp(0.0, 1.0);
    final z = _lerp(1480, 1255, k);
    _figure(canvas, cam, 16, z, const Color(0xFF2E7D32));
  }

  void _stumps(Canvas canvas, _Camera cam, double z, double? bowledAge) {
    final s = cam.scale(z);
    final age = (bowledAge ?? 0).clamp(0.0, 1.0);
    final wood = Paint()
      ..color = const Color(0xFFF5DEB3)
      ..strokeWidth = math.max(1.5, 2.5 * s)
      ..strokeCap = StrokeCap.round;
    for (final x in const [-9.0, 0.0, 9.0]) {
      final base = cam.p(x, 0, z);
      final lean = age * (x == 0 ? 0.2 : x.sign * 0.9);
      final top = base + Offset(math.sin(lean), -math.cos(lean)) * 72 * s;
      canvas.drawLine(base, top, wood);
    }
    if (age == 0) {
      canvas.drawLine(
        cam.p(-10, 73, z),
        cam.p(10, 73, z),
        Paint()
          ..color = const Color(0xFFD7B98E)
          ..strokeWidth = math.max(1, 2 * s),
      );
    }
  }

  void _batter(Canvas canvas, _Camera cam, double t) {
    const x = -24.0;
    _figure(canvas, cam, x, _batZ, const Color(0xFF283593));

    // The bat: resting in the stance, swinging through on a tap.
    final s = cam.scale(_batZ);
    final hands = cam.p(x + 12, 56, _batZ);
    var angle = 0.5;
    final st = swingTick;
    if (st != null && t - st < 16) {
      angle = _lerp(-1.9, 1.6, ((t - st) / 12).clamp(0.0, 1.0));
    }
    canvas
      ..save()
      ..translate(hands.dx, hands.dy)
      ..rotate(angle)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-4 * s, 0, 8 * s, 18 * s),
          Radius.circular(3 * s),
        ),
        Paint()..color = const Color(0xFF263238),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-6 * s, 16 * s, 12 * s, 44 * s),
          Radius.circular(4 * s),
        ),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFF3D9A4), Color(0xFFD4A95E)],
          ).createShader(Rect.fromLTWH(-6 * s, 16 * s, 12 * s, 44 * s)),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_CricketPainter oldDelegate) => true;
}
