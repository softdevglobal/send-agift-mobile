import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/stack_tower.dart';
import '../game_controls.dart';
import 'tick_clock.dart';
import 'game_overlay_area.dart';

/// World height of one floor.
const double _floorH = 20;

/// A sliced-off piece tumbling away.
class _Debris {
  _Debris({
    required this.block,
    required this.floor,
    required this.born,
    required this.alongX,
    required this.sign,
  });

  final StackBlock block;
  final int floor;
  final double born;
  final bool alongX;
  final int sign;
}

/// The glow of a perfect drop.
class _Flash {
  _Flash({
    required this.block,
    required this.floor,
    required this.born,
    required this.streak,
  });

  final StackBlock block;
  final int floor;
  final double born;
  final int streak;
}

/// Stack Tower in isometric 3D. Tap anywhere to drop the sliding floor.
class StackTowerBoard extends StatefulWidget {
  const StackTowerBoard({
    required this.game,
    required this.controls,
    super.key,
  });

  final StackTower game;
  final GameControls controls;

  @override
  State<StackTowerBoard> createState() => _StackTowerBoardState();
}

class _StackTowerBoardState extends State<StackTowerBoard>
    with SingleTickerProviderStateMixin {
  late final TickClock _clock = TickClock(
    vsync: this,
    game: widget.game,
    onTicks: (_) {
      if (widget.game.isOver) widget.controls.onChanged();
    },
  );

  bool _started = false;

  /// The camera follows the top of the tower, easing rather than jumping.
  double _camera = 0;
  double _lastWall = 0;
  final List<_Debris> _debris = [];
  final List<_Flash> _flashes = [];

  StackTower get _game => widget.game;

  @override
  void initState() {
    super.initState();
    _clock.addListener(_onFrame);
  }

  @override
  void didUpdateWidget(covariant StackTowerBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _clock
      ..removeListener(_onFrame)
      ..dispose();
    super.dispose();
  }

  void _sync() =>
      _clock.run(_started && widget.controls.active && !_game.isOver);

  void _onFrame() {
    final now = _clock.wallMs;
    final dt = now - _lastWall;
    _lastWall = now;
    final target = _game.floorCount.toDouble();
    _camera += (target - _camera) * (1 - math.pow(0.02, dt / 1000));
    _debris.removeWhere((d) => now - d.born > 1400);
    _flashes.removeWhere((f) => now - f.born > 700);
  }

  void _tap() {
    if (!widget.controls.active || _game.isOver) return;
    if (!_started) {
      setState(() => _started = true);
      _sync();
      return;
    }
    final drop = _game.drop();
    if (drop == null) return;

    final now = _clock.wallMs;
    final cut = drop.cut;
    if (cut != null) {
      _debris.add(
        _Debris(
          block: cut,
          floor: drop.floor,
          born: now,
          alongX: drop.floor.isOdd,
          sign: drop.fell ? 0 : drop.offset.sign,
        ),
      );
    }
    final placed = drop.placed;
    if (drop.perfect && placed != null) {
      _flashes.add(
        _Flash(
          block: placed,
          floor: drop.floor,
          born: now,
          streak: drop.streak,
        ),
      );
    }
    widget.controls.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Down, not up: in a timing game every millisecond of a tap counts.
      onTapDown: (_) => _tap(),
      child: ClipRRect(
        // Square: the scene runs to the corners of the screen now, and a
        // rounded one would leave the backdrop showing through them.
        borderRadius: BorderRadius.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _StackPainter(
                game: _game,
                clock: _clock,
                camera: () => _camera,
                debris: _debris,
                flashes: _flashes,
              ),
            ),
            if (!_started)
              GameOverlayArea(
                child: Align(
                  alignment: const Alignment(0, 0.55),
                  child: IgnorePointer(
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
                        'Tap to start',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

typedef _Iso = Offset Function(double x, double y, double z);

class _StackPainter extends CustomPainter {
  _StackPainter({
    required this.game,
    required this.clock,
    required this.camera,
    required this.debris,
    required this.flashes,
  }) : super(repaint: clock);

  final StackTower game;
  final TickClock clock;
  final double Function() camera;
  final List<_Debris> debris;
  final List<_Flash> flashes;

  static double _hue(int floor) => (200 + floor * 9) % 360;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height * 0.8) / 250;
    final cx = size.width / 2;
    final baseY = size.height * 0.6 + camera() * _floorH * s;
    Offset iso(double x, double y, double z) =>
        Offset(cx + (x - z) * 0.866 * s, baseY + (x + z) * 0.5 * s - y * s);

    _sky(canvas, size);
    _counter(canvas, size);

    final floors = game.floors;
    final visible = (size.height / (_floorH * s)).ceil() + 6;
    for (var i = math.max(0, floors.length - visible); i < floors.length; i++) {
      final b = floors[i];
      // The base is a tall pedestal reaching off the bottom of the screen.
      final y0 = i == 0 ? -_floorH * 14 : i * _floorH;
      _cuboid(
        canvas,
        iso,
        b.x0.toDouble(),
        b.x1.toDouble(),
        b.z0.toDouble(),
        b.z1.toDouble(),
        y0,
        (i + 1) * _floorH,
        _hue(i),
        1,
      );
    }

    final now = clock.wallMs;
    for (final f in flashes) {
      _flash(canvas, iso, f, (now - f.born) / 700);
    }

    if (!game.fell) _moving(canvas, iso);

    for (final d in debris) {
      _falling(canvas, iso, d, (now - d.born) / 1000);
    }
  }

  void _sky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hue = (220 + game.floorCount * 4) % 360.0;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HSVColor.fromAHSV(1, hue, 0.6, 0.22).toColor(),
            HSVColor.fromAHSV(1, (hue + 40) % 360, 0.5, 0.55).toColor(),
          ],
        ).createShader(rect),
    );
    // Stars come out as the tower climbs.
    final stars = (game.floorCount / 20).clamp(0.0, 1.0);
    if (stars > 0) {
      for (var i = 0; i < 30; i++) {
        final a = math.sin(i * 12.9898) * 43758.5453;
        final b = math.sin(i * 78.233) * 12345.6789;
        canvas.drawCircle(
          Offset(
            (a - a.floorToDouble()) * size.width,
            (b - b.floorToDouble()) * size.height * 0.6,
          ),
          1.4,
          Paint()..color = Colors.white.withValues(alpha: 0.7 * stars),
        );
      }
    }
  }

  void _counter(Canvas canvas, Size size) {
    final text = TextPainter(
      text: TextSpan(
        text: '${game.floorCount}',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: size.width * 0.2,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Colors.black38, blurRadius: 12)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(size.width / 2 - text.width / 2, size.height * 0.06),
    );
  }

  /// A block drawn as three lit faces: top, right (+x) and left (+z).
  void _cuboid(
    Canvas canvas,
    _Iso iso,
    double x0,
    double x1,
    double z0,
    double z1,
    double y0,
    double y1,
    double hue,
    double alpha,
  ) {
    Path quad(List<Offset> pts) => Path()..addPolygon(pts, true);
    Color shade(double sat, double val) =>
        HSVColor.fromAHSV(alpha.clamp(0.0, 1.0), hue, sat, val).toColor();

    final top = quad([
      iso(x0, y1, z0),
      iso(x1, y1, z0),
      iso(x1, y1, z1),
      iso(x0, y1, z1),
    ]);
    canvas
      ..drawPath(
        quad([
          iso(x0, y0, z1),
          iso(x1, y0, z1),
          iso(x1, y1, z1),
          iso(x0, y1, z1),
        ]),
        Paint()..color = shade(0.62, 0.62),
      )
      ..drawPath(
        quad([
          iso(x1, y0, z0),
          iso(x1, y0, z1),
          iso(x1, y1, z1),
          iso(x1, y1, z0),
        ]),
        Paint()..color = shade(0.55, 0.8),
      )
      ..drawPath(top, Paint()..color = shade(0.42, 0.98))
      ..drawPath(
        top,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.4 * alpha),
      );
  }

  void _moving(Canvas canvas, _Iso iso) {
    final t = clock.smoothTick;
    final tick = t.floor();
    final a = game.offsetAt(tick).toDouble();
    final b = game.offsetAt(tick + 1).toDouble();
    final off = a + (b - a) * (t - tick);
    final top = game.top;
    final i = game.floors.length;
    final alongX = game.slidesAlongX;
    _cuboid(
      canvas,
      iso,
      top.x0 + (alongX ? off : 0),
      top.x1 + (alongX ? off : 0),
      top.z0 + (alongX ? 0 : off),
      top.z1 + (alongX ? 0 : off),
      i * _floorH,
      (i + 1) * _floorH,
      _hue(i),
      1,
    );
  }

  void _falling(Canvas canvas, _Iso iso, _Debris d, double age) {
    final drop = 0.5 * 900 * age * age;
    final drift = d.sign * 60 * age;
    final b = d.block;
    _cuboid(
      canvas,
      iso,
      b.x0 + (d.alongX ? drift : 0),
      b.x1 + (d.alongX ? drift : 0),
      b.z0 + (d.alongX ? 0 : drift),
      b.z1 + (d.alongX ? 0 : drift),
      d.floor * _floorH - drop,
      (d.floor + 1) * _floorH - drop,
      _hue(d.floor),
      1 - age / 1.4,
    );
  }

  void _flash(Canvas canvas, _Iso iso, _Flash f, double age) {
    if (age >= 1) return;
    final grow = age * 16;
    final b = f.block;
    final y = (f.floor + 1) * _floorH;
    canvas.drawPath(
      Path()..addPolygon([
        iso(b.x0 - grow, y, b.z0 - grow),
        iso(b.x1 + grow, y, b.z0 - grow),
        iso(b.x1 + grow, y, b.z1 + grow),
        iso(b.x0 - grow, y, b.z1 + grow),
      ], true),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 1 - age),
    );
    final label = f.streak > 1 ? 'PERFECT ×${f.streak}' : 'PERFECT';
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: const Color(0xFFFFF59D).withValues(alpha: 1 - age),
          fontSize: 20,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final anchor = iso((b.x0 + b.x1) / 2, y + 30 + age * 20, (b.z0 + b.z1) / 2);
    text.paint(canvas, anchor - Offset(text.width / 2, text.height));
  }

  @override
  bool shouldRepaint(_StackPainter oldDelegate) => true;
}
