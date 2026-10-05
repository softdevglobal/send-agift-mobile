import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/archery_game.dart';
import '../game_controls.dart';
import 'game_hud.dart';
import 'tick_clock.dart';

/// Target geometry for a range of a given size: centre and the screen size
/// of one target unit (the target is 100 units in radius).
({Offset center, double radius, double unit}) _targetGeometry(Size size) {
  final radius = math.min(size.width * 0.36, size.height * 0.3);
  return (
    center: Offset(size.width / 2, size.height * 0.4),
    radius: radius,
    unit: radius / 100,
  );
}

/// The archery range in 3D perspective. Drag to aim, let go to shoot.
class ArcheryRange extends StatefulWidget {
  const ArcheryRange({required this.game, required this.controls, super.key});

  final ArcheryGame game;
  final GameControls controls;

  @override
  State<ArcheryRange> createState() => _ArcheryRangeState();
}

class _ArcheryRangeState extends State<ArcheryRange>
    with SingleTickerProviderStateMixin {
  late final TickClock _clock = TickClock(
    vsync: this,
    game: widget.game,
    onTicks: (_) {
      if (widget.game.isOver) widget.controls.onChanged();
    },
  );

  /// Where the player is aiming, in target units. Each arrow starts centred.
  Offset _aim = Offset.zero;
  bool _aiming = false;
  double _unit = 1;

  ArcheryGame get _game => widget.game;

  @override
  void initState() {
    super.initState();
    // The sight sways from the moment the bow is raised.
    _sync();
  }

  @override
  void didUpdateWidget(covariant ArcheryRange oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _sync() => _clock.run(widget.controls.active && !_game.isOver);

  void _panStart(DragStartDetails details) {
    if (!widget.controls.active || !_game.canShoot) return;
    setState(() => _aiming = true);
  }

  void _panUpdate(DragUpdateDetails details) {
    if (!_aiming) return;
    const limit = ArcheryGame.aimLimit * 1.0;
    final next = _aim + details.delta / _unit * 0.7;
    setState(() {
      _aim = Offset(next.dx.clamp(-limit, limit), next.dy.clamp(-limit, limit));
    });
  }

  void _panEnd(DragEndDetails details) {
    if (!_aiming) return;
    setState(() => _aiming = false);
    if (!widget.controls.active) return;
    final arrow = _game.shoot(_aim.dx.round(), _aim.dy.round());
    if (arrow == null) return;
    setState(() => _aim = Offset.zero);
    widget.controls.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final wind = _game.wind;
    // The readouts float over the scene rather than sitting on a strip below
    // it. Given their own row they cost the scene most of a phone's bottom
    // eighth, for two chips that sit comfortably on top of it.
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              _unit = _targetGeometry(size).unit;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _panStart,
                onPanUpdate: _panUpdate,
                onPanEnd: _panEnd,
                child: ClipRRect(
                  // Square: the scene runs to the corners of the screen now, and a
                  // rounded one would leave the backdrop showing through them.
                  borderRadius: BorderRadius.zero,
                  child: CustomPaint(
                    size: size,
                    painter: _RangePainter(
                      game: _game,
                      clock: _clock,
                      aim: _aim,
                      aiming: _aiming,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          // Wraps rather than overflowing on narrow phones or large text.
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: glassDecoration(radius: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      wind == 0
                          ? Icons.air_rounded
                          : wind < 0
                          ? Icons.west_rounded
                          : Icons.east_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      wind == 0 ? 'Calm' : 'Wind ${wind.abs()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: glassDecoration(radius: 20),
                child: Text(
                  _game.arrowsLeft > 0
                      ? 'Arrow ${_game.arrowsShot + 1} of ${_game.config.arrows}'
                      : 'Last arrow away',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RangePainter extends CustomPainter {
  _RangePainter({
    required this.game,
    required this.clock,
    required this.aim,
    required this.aiming,
  }) : super(repaint: clock);

  final ArcheryGame game;
  final TickClock clock;
  final Offset aim;
  final bool aiming;

  static const _flightTicks = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.52;
    final g = _targetGeometry(size);
    final t = clock.smoothTick;

    _sky(canvas, size, horizon);
    _field(canvas, size, horizon);
    _windsock(canvas, size, horizon);

    final last = game.lastArrow;
    final flying = last != null && t - last.tick < _flightTicks;
    // How long ago the last arrow landed, in ticks. Everything the target
    // does in reply is timed off this.
    final since = last == null ? 1e9 : t - last.tick - _flightTicks;

    // The target rocks on its stand when it is struck, settling quickly.
    final struck = since >= 0 && since < 14;
    canvas.save();
    if (struck) {
      final fade = 1 - since / 14;
      canvas.translate(
        math.sin(since * 1.5) * g.radius * 0.045 * fade,
        math.sin(since * 2.1) * g.radius * 0.02 * fade,
      );
    }
    _stand(canvas, size, g.center, g.radius, horizon);
    _target(canvas, g.center, g.radius);

    for (final arrow in game.history) {
      if (flying && identical(arrow, last)) continue;
      // The arrow that just landed quivers before it settles.
      final quiver = identical(arrow, last) && since < 16
          ? math.sin(since * 2.4) * (1 - since / 16) * 0.22
          : 0.0;
      _stuck(canvas, _impact(g, arrow), g.radius, quiver);
    }
    if (struck && last != null) _ripple(canvas, _impact(g, last), g.radius, since);
    canvas.restore();
    if (flying) {
      _flying(
        canvas,
        size,
        _impact(g, last),
        g.radius,
        (t - last.tick) / _flightTicks,
      );
    }

    if (game.canShoot && !game.isOver) _reticle(canvas, g, t);
    _bow(canvas, size);
    if (last != null) _popup(canvas, _impact(g, last), last, t);
  }

  Offset _impact(
    ({Offset center, double radius, double unit}) g,
    ArcheryArrow a,
  ) => g.center + Offset(a.impactX * g.unit, a.impactY * g.unit);

  void _sky(Canvas canvas, Size size, double horizon) {
    final sky = Rect.fromLTWH(0, 0, size.width, horizon);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4FB3E8), Color(0xFFBDEBFF)],
        ).createShader(sky),
    );
    final sun = Offset(size.width * 0.82, size.height * 0.1);
    canvas.drawCircle(
      sun,
      size.width * 0.3,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF8E1).withValues(alpha: 0.9),
            const Color(0xFFFFF8E1).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: size.width * 0.3)),
    );

    // Clouds drift slowly. Decoration only.
    for (var i = 0; i < 3; i++) {
      final x =
          (size.width * (0.2 + i * 0.35) + clock.wallMs * 0.006 * (i + 1)) %
              (size.width * 1.3) -
          size.width * 0.15;
      final y = size.height * (0.08 + i * 0.07);
      final cloud = Paint()..color = Colors.white.withValues(alpha: 0.75);
      canvas
        ..drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 70, height: 22),
          cloud,
        )
        ..drawOval(
          Rect.fromCenter(center: Offset(x + 18, y - 8), width: 44, height: 22),
          cloud,
        );
    }

    // Two layers of hills on the horizon.
    for (final (lift, color) in const [
      (0.06, Color(0xFF7CB97C)),
      (0.02, Color(0xFF5E9E5E)),
    ]) {
      final hills = Path()..moveTo(0, horizon);
      for (var x = 0.0; x <= size.width; x += size.width / 24) {
        hills.lineTo(
          x,
          horizon -
              size.height * lift -
              math.sin(x / size.width * math.pi * 3 + lift * 40) *
                  size.height *
                  0.025,
        );
      }
      hills
        ..lineTo(size.width, horizon)
        ..close();
      canvas.drawPath(hills, Paint()..color = color);
    }
  }

  void _field(Canvas canvas, Size size, double horizon) {
    final ground = Rect.fromLTRB(0, horizon, size.width, size.height);
    canvas.drawRect(
      ground,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5DA84F), Color(0xFF2F7A34)],
        ).createShader(ground),
    );
    // Mowing stripes run towards the vanishing point.
    final vp = Offset(size.width / 2, horizon);
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.07);
    for (var i = -8; i <= 8; i += 2) {
      canvas.drawPath(
        Path()..addPolygon([
          vp,
          Offset(size.width / 2 + i * size.width * 0.18, size.height),
          Offset(size.width / 2 + (i + 1) * size.width * 0.18, size.height),
        ], true),
        stripe,
      );
    }
  }

  void _windsock(Canvas canvas, Size size, double horizon) {
    final wind = game.wind;
    final strength = wind.abs() / game.config.maxWind;
    final base = Offset(size.width * 0.12, horizon + size.height * 0.02);
    final top = base.translate(0, -size.height * 0.22);
    canvas.drawLine(
      base,
      top,
      Paint()
        ..color = const Color(0xFF455A64)
        ..strokeWidth = 3,
    );

    // The sock stretches out in the wind and droops when it is calm.
    final dir = wind < 0 ? -1.0 : 1.0;
    final length = size.width * 0.13 * (0.3 + 0.7 * strength);
    final droop = size.height * 0.05 * (1 - strength);
    const bands = 4;
    for (var i = 0; i < bands; i++) {
      final a = i / bands;
      final b = (i + 1) / bands;
      final flutter = math.sin(clock.wallMs / 120 + i) * 2 * strength;
      Offset along(double k, double side) => Offset(
        top.dx + dir * length * k,
        top.dy + droop * k * k + side * (9 - 4 * k) + flutter * k,
      );
      canvas.drawPath(
        Path()..addPolygon([
          along(a, -1),
          along(b, -1),
          along(b, 1),
          along(a, 1),
        ], true),
        Paint()..color = i.isEven ? const Color(0xFFFF5722) : Colors.white,
      );
    }

    // Dust motes blowing across the range.
    if (wind != 0) {
      for (var i = 0; i < 14; i++) {
        final h = math.sin(i * 12.9898) * 43758.5453;
        final frac = h - h.floorToDouble();
        final y = horizon - size.height * 0.15 + frac * size.height * 0.5;
        final x =
            (frac * size.width * 7 + wind * clock.wallMs * 0.012) % size.width;
        canvas.drawCircle(
          Offset(x < 0 ? x + size.width : x, y),
          1.6,
          Paint()..color = Colors.white.withValues(alpha: 0.45),
        );
      }
    }
  }

  void _stand(Canvas canvas, Size size, Offset c, double r, double horizon) {
    final leg = Paint()
      ..color = const Color(0xFF6D4C41)
      ..strokeWidth = r * 0.07
      ..strokeCap = StrokeCap.round;
    final foot = horizon + size.height * 0.1;
    canvas
      ..drawLine(
        c.translate(-r * 0.5, r * 0.6),
        Offset(c.dx - r * 0.85, foot),
        leg,
      )
      ..drawLine(
        c.translate(r * 0.5, r * 0.6),
        Offset(c.dx + r * 0.85, foot),
        leg,
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset(c.dx, foot + 4),
          width: r * 2.2,
          height: r * 0.18,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.18),
      );
  }

  static Color _ringColor(int ring) => switch (ring) {
    1 || 2 => const Color(0xFFFFD43B),
    3 || 4 => const Color(0xFFE53935),
    5 || 6 => const Color(0xFF1E88E5),
    7 || 8 => const Color(0xFF212121),
    _ => const Color(0xFFF5F5F5),
  };

  void _target(Canvas canvas, Offset c, double r) {
    // The straw boss behind the face gives the target its thickness.
    canvas
      ..drawCircle(
        c.translate(r * 0.05, r * 0.07),
        r * 1.03,
        Paint()..color = const Color(0xFFB98A4E),
      )
      ..drawCircle(c, r * 1.02, Paint()..color = const Color(0xFFD9B77E));

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: 0.25);
    for (var ring = 10; ring >= 1; ring--) {
      final radius = r * ring / 10;
      canvas
        ..drawCircle(c, radius, Paint()..color = _ringColor(ring))
        ..drawCircle(c, radius, edge);
    }
    canvas.drawCircle(c, r / 20, edge);

    // Light from the top left.
    final face = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.5, -0.5),
          radius: 1.2,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.15),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(face),
    );
  }

  /// A ring blown outward from where an arrow bit, fading as it widens.
  void _ripple(Canvas canvas, Offset at, double r, double since) {
    final k = (since / 14).clamp(0.0, 1.0);
    canvas.drawCircle(
      at,
      r * (0.05 + k * 0.4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.02 * (1 - k)
        ..color = Colors.white.withValues(alpha: 0.55 * (1 - k)),
    );
  }

  /// An arrow standing in the target. [quiver] leans the shaft, so one that
  /// has only just bitten still shivers before it settles.
  void _stuck(Canvas canvas, Offset p, double r, [double quiver = 0]) {
    final out = Offset(r * 0.1, r * 0.22);
    final shaft = quiver == 0
        ? out
        : Offset(
            out.dx * math.cos(quiver) - out.dy * math.sin(quiver),
            out.dx * math.sin(quiver) + out.dy * math.cos(quiver),
          );
    final tail = p + shaft;
    canvas
      ..drawCircle(
        p,
        r * 0.02,
        Paint()..color = Colors.black.withValues(alpha: 0.7),
      )
      ..drawLine(
        p,
        tail,
        Paint()
          ..color = const Color(0xFF5D4037)
          ..strokeWidth = r * 0.025
          ..strokeCap = StrokeCap.round,
      );
    _fletching(canvas, tail, shaft, r * 0.07);
  }

  void _fletching(Canvas canvas, Offset tail, Offset along, double size) {
    final dir = along / along.distance;
    final side = Offset(-dir.dy, dir.dx);
    final paint = Paint()..color = const Color(0xFFFF4FA3);
    for (final s in const [-1.0, 1.0]) {
      canvas.drawPath(
        Path()..addPolygon([
          tail,
          tail - dir * size * 0.3 + side * size * 0.6 * s,
          tail - dir * size * 1.2 + side * size * 0.4 * s,
          tail - dir * size,
        ], true),
        paint,
      );
    }
  }

  void _flying(Canvas canvas, Size size, Offset impact, double r, double p) {
    final start = Offset(size.width / 2, size.height * 0.8);
    Offset at(double k) =>
        Offset.lerp(start, impact, k)! -
        Offset(0, size.height * 0.08 * math.sin(k * math.pi));
    final pos = at(p);
    final ahead = at(math.min(1, p + 0.05));
    var dir = ahead - pos;
    if (dir.distance < 0.001) dir = impact - start;
    dir = dir / dir.distance;
    final length = r * 0.6 * (1 - 0.7 * p);
    final tail = pos - dir * length;
    canvas.drawLine(
      tail,
      pos,
      Paint()
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = math.max(1.5, r * 0.035 * (1 - 0.6 * p))
        ..strokeCap = StrokeCap.round,
    );
    _fletching(canvas, tail, -dir * length, r * 0.1 * (1 - 0.6 * p));
  }

  void _reticle(
    Canvas canvas,
    ({Offset center, double radius, double unit}) g,
    double t,
  ) {
    final tick = t.floor();
    final (ax, ay) = game.sway(tick);
    final (bx, by) = game.sway(tick + 1);
    final k = t - tick;
    final sway = Offset(ax + (bx - ax) * k, ay + (by - ay) * k);
    final p = g.center + (aim + sway) * g.unit;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = aiming ? const Color(0xFF00E676) : Colors.white;
    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..color = Colors.black.withValues(alpha: 0.35);
    const r = 16.0;
    for (final paint in [shadow, ring]) {
      canvas
        ..drawCircle(p, r, paint)
        ..drawLine(p.translate(-r - 8, 0), p.translate(-r + 6, 0), paint)
        ..drawLine(p.translate(r - 6, 0), p.translate(r + 8, 0), paint)
        ..drawLine(p.translate(0, -r - 8), p.translate(0, -r + 6), paint)
        ..drawLine(p.translate(0, r - 6), p.translate(0, r + 8), paint);
    }
    canvas.drawCircle(p, 2.5, Paint()..color = ring.color);
  }

  void _bow(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final tipY = size.height * 0.97;
    final span = size.width * 0.3;
    final left = Offset(cx - span, tipY);
    final right = Offset(cx + span, tipY);
    // How far the string is hauled back, from how far the aim has been
    // dragged: a bow at full draw should look like one, not like a bow at
    // rest with the string moved a fixed inch.
    final pull = aiming ? (aim.distance / 6).clamp(0.25, 1.0) : 0.0;
    // The limbs bend as it is drawn, so the whole bow loads up.
    final belly = size.height * (0.78 + pull * 0.03);
    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..quadraticBezierTo(cx, belly, right.dx, right.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [Color(0xFF4E342E), Color(0xFFA1887F), Color(0xFF4E342E)],
        ).createShader(Rect.fromPoints(left, right)),
    );

    // The string comes back with the draw, and the nocked arrow with it.
    final nock = Offset(cx, tipY + pull * 26);
    final string = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.5 + pull * 0.8;
    canvas
      ..drawLine(left, nock, string)
      ..drawLine(right, nock, string);
    if (game.canShoot && !game.isOver) {
      canvas.drawLine(
        nock,
        Offset(cx, size.height * 0.8 + pull * 26),
        Paint()
          ..color = const Color(0xFF5D4037)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      // The grip, which gives the bow a front and a back.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, (tipY + belly) / 2),
            width: 13,
            height: 34,
          ),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0xFF3E2723),
      );
    }
  }

  void _popup(Canvas canvas, Offset impact, ArcheryArrow a, double t) {
    final age = t - a.tick - _flightTicks;
    if (age < 0 || age > 22) return;
    final k = age / 22;
    final label = a.points == 0
        ? 'MISS'
        : a.inner
        ? 'X!  +${a.points}'
        : '+${a.points}';
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: (a.points >= 9 ? const Color(0xFFFFE066) : Colors.white)
              .withValues(alpha: 1 - k),
          fontSize: 22,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      impact - Offset(text.width / 2, text.height + 16 + 30 * k),
    );
  }

  @override
  bool shouldRepaint(_RangePainter oldDelegate) => true;
}
