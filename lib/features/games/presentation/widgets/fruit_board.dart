import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../domain/fruit_slice.dart';
import '../game_controls.dart';
import 'tick_clock.dart';

/// How each fruit looks: skin light/base/dark, the flesh and rind of its cut
/// face, and the colour of its juice. Indexed by [FruitThrow.kind].
class _Look {
  const _Look(
    this.light,
    this.base,
    this.dark,
    this.flesh,
    this.rind,
    this.juice,
  );

  final Color light;
  final Color base;
  final Color dark;
  final Color flesh;
  final Color rind;
  final Color juice;
}

const _looks = [
  // watermelon
  _Look(
    Color(0xFF86D67A),
    Color(0xFF2E8B3A),
    Color(0xFF0B3D17),
    Color(0xFFEF3340),
    Color(0xFFF1F5D0),
    Color(0xFFE11D48),
  ),
  // orange
  _Look(
    Color(0xFFFFD592),
    Color(0xFFF7931E),
    Color(0xFFA64B05),
    Color(0xFFFFA93A),
    Color(0xFFFFF1D6),
    Color(0xFFFF9F1C),
  ),
  // apple
  _Look(
    Color(0xFFFF9C8F),
    Color(0xFFE0302C),
    Color(0xFF6E1414),
    Color(0xFFFFF3CF),
    Color(0xFFE0302C),
    Color(0xFFFDE68A),
  ),
  // lemon
  _Look(
    Color(0xFFFFFBC2),
    Color(0xFFFAD932),
    Color(0xFFB88A04),
    Color(0xFFFFF27A),
    Color(0xFFFFFBEB),
    Color(0xFFFDE047),
  ),
  // coconut
  _Look(
    Color(0xFFB88B66),
    Color(0xFF7A4E30),
    Color(0xFF301A0C),
    Color(0xFFFBFAF4),
    Color(0xFF5A3A24),
    Color(0xFFF8FAFC),
  ),
  // plum
  _Look(
    Color(0xFFD5A6FF),
    Color(0xFF7E22CE),
    Color(0xFF2E0655),
    Color(0xFFFFC53D),
    Color(0xFF6B21A8),
    Color(0xFFC026D3),
  ),
];

/// Maps the engine's field (y up from the bottom edge) onto the screen: one
/// uniform scale so a circle stays a circle, centred across and standing on
/// the bottom edge.
class _View {
  factory _View(Size size, FruitConfig c) {
    final s = math.min(size.width / c.width, size.height / c.height);
    return _View._(size.height, s, (size.width - c.width * s) / 2);
  }

  _View._(this.h, this.s, this.ox);

  final double h;
  final double s;
  final double ox;

  Offset toScreen(double x, double y) => Offset(ox + x * s, h - y * s);

  (int, int) toField(Offset p) =>
      (((p.dx - ox) / s).round(), ((h - p.dy) / s).round());
}

/// Fruit Slice: fruit is tossed up across the whole screen and the finger is
/// the blade.
///
/// Every flying thing is drawn from its own flight in the engine, so what is
/// on screen is exactly what the server has in the air. The halves, juice
/// and pop-ups that follow a cut are pure decoration on top.
class FruitBoard extends StatefulWidget {
  const FruitBoard({required this.game, required this.controls, super.key});

  final FruitSlice game;
  final GameControls controls;

  @override
  State<FruitBoard> createState() => _FruitBoardState();
}

class _FruitBoardState extends State<FruitBoard> with TickerProviderStateMixin {
  late final TickClock _clock = TickClock(
    vsync: this,
    game: widget.game,
    onTicks: (_) => _onTicks(),
  );

  /// Drives the effects, which keep playing after the round ends so a bomb
  /// gets to go off before the results come up.
  late final Ticker _fx = createTicker(_onFx);
  Duration _fxLast = Duration.zero;
  double _now = 0; // ms of effect time

  final _rng = math.Random();
  final _effects = _Effects();

  _View? _view;
  int _stroke = 0;
  int? _pointer;
  Offset? _last;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant FruitBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _fx.dispose();
    _clock.dispose();
    super.dispose();
  }

  bool get _playing => widget.controls.active && !widget.game.isOver;

  void _sync() {
    _clock.run(_playing);
    final wantFx = _playing || (widget.game.isOver && _effects.alive);
    if (wantFx && !_fx.isActive) {
      _fxLast = Duration.zero;
      _fx.start();
    } else if (!wantFx && _fx.isActive) {
      _fx.stop();
    }
  }

  void _onFx(Duration elapsed) {
    final dt = _fxLast == Duration.zero
        ? 0.0
        : (elapsed - _fxLast).inMicroseconds / 1e6;
    _fxLast = elapsed;
    _now += dt * 1000;
    _effects.step(dt.clamp(0, 0.05), _now);
    if (!_playing && !_effects.alive) _fx.stop();
    if (mounted) setState(() {});
  }

  void _onTicks() {
    final game = widget.game;
    final view = _view;
    if (view != null) {
      for (final i in game.takeDrops()) {
        final t = game.throws[i];
        _effects.misses.add(_Miss(view.toScreen(t.x1.toDouble(), 0), _now));
      }
    }
    if (game.isOver) _finishSoon();
  }

  /// Tells the screen the round is over once the last effect has had its
  /// moment, rather than cutting straight to the results.
  void _finishSoon() {
    if (_finishing) return;
    _finishing = true;
    _sync();
    Timer(const Duration(milliseconds: 1100), () {
      if (mounted) widget.controls.onChanged();
    });
  }

  // ─── Input ───────────────────────────────────────────────────────────

  void _down(PointerDownEvent e) {
    if (_pointer != null || !_playing) return;
    _pointer = e.pointer;
    _stroke++;
    _last = e.localPosition;
    _effects.trail
      ..clear()
      ..add(_TrailPoint(e.localPosition, _now));
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final from = _last;
    final to = e.localPosition;
    _last = to;
    _effects.trail.add(_TrailPoint(to, _now));
    if (from == null || !_playing) return;
    _cut(from, to);
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _last = null;
  }

  void _cut(Offset from, Offset to) {
    final view = _view;
    if (view == null) return;
    final game = widget.game;
    final (x1, y1) = view.toField(from);
    final (x2, y2) = view.toField(to);
    final cuts = game.slice(_stroke, x1, y1, x2, y2);
    if (cuts.isEmpty) return;

    final dir = to - from;
    final angle = dir.distanceSquared == 0 ? 0.0 : dir.direction;
    for (final cut in cuts) {
      final t = game.throws[cut.index];
      final (cx, cy) = t.smoothPos(game.tick.toDouble());
      final at = view.toScreen(cx, cy);
      final r = t.radius * view.s;
      if (t.bomb) {
        _explode(at, r);
      } else {
        _burst(t, cut, at, r, angle, view);
      }
    }

    if (game.isOver) {
      _finishSoon();
    } else {
      HapticFeedback.lightImpact();
      widget.controls.onChanged();
    }
  }

  void _burst(
    FruitThrow t,
    FruitCut cut,
    Offset at,
    double r,
    double angle,
    _View view,
  ) {
    final look = _looks[t.kind % _looks.length];
    // The fruit's own velocity at the cut, in px/s, so the halves carry on
    // along its arc rather than stopping dead.
    final f = (t.exit - t.enter).toDouble();
    final s = (widget.game.tick - t.enter).toDouble();
    final perSec = 1000 / widget.game.tickMs;
    final vx = (t.x1 - t.x0) / f * perSec * view.s;
    final vy =
        -4 * (t.peak + t.radius) * (f - 2 * s) / (f * f) * perSec * view.s;
    final normal = Offset(-math.sin(angle), math.cos(angle));
    final push = r * 5.5;
    final g = 2300 * view.s;

    for (final side in const [1.0, -1.0]) {
      _effects.halves.add(
        _Half(
          kind: t.kind,
          pos: at + normal * (side * r * 0.1),
          vel: Offset(vx, vy) + normal * (side * push),
          angle: angle + (side > 0 ? 0 : math.pi),
          spin: side * (1.5 + _rng.nextDouble() * 2.5),
          r: r,
          gravity: g,
          born: _now,
        ),
      );
    }

    for (var i = 0; i < 18; i++) {
      final a =
          angle +
          (_rng.nextBool() ? 1 : -1) * math.pi / 2 +
          (_rng.nextDouble() - 0.5) * 2.2;
      final speed = r * (4 + _rng.nextDouble() * 12);
      _effects.drops.add(
        _Drop(
          pos: at,
          vel: Offset(math.cos(a), math.sin(a)) * speed + Offset(vx, vy) * 0.3,
          color: look.juice,
          size: r * (0.06 + _rng.nextDouble() * 0.12),
          gravity: g,
          born: _now,
          life: 500 + _rng.nextDouble() * 500,
        ),
      );
    }

    _effects.splats.add(_Splat.random(_rng, at, r, look.juice, _now));
    _effects.popups.add(
      _Popup('+${cut.points}', at - Offset(0, r * 1.2), _now),
    );

    if (cut.combo >= 3) {
      final bonus =
          widget.game.config.comboBonus * cut.combo * (cut.combo - 1) ~/ 2;
      _effects.combo = _Combo(
        cut.combo,
        bonus,
        _effects.combo?.stroke == _stroke ? _effects.combo!.at : at,
        _now,
        _stroke,
      );
    }
  }

  void _explode(Offset at, double r) {
    HapticFeedback.heavyImpact();
    _effects.blast = _Blast(at, r, _now);
    _effects.shake = 1;
    for (var i = 0; i < 40; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final speed = r * (6 + _rng.nextDouble() * 22);
      _effects.drops.add(
        _Drop(
          pos: at,
          vel: Offset(math.cos(a), math.sin(a)) * speed,
          color: [
            const Color(0xFFFFF7AE),
            const Color(0xFFFFB020),
            const Color(0xFFFF5A1F),
          ][i % 3],
          size: r * (0.09 + _rng.nextDouble() * 0.14),
          gravity: 600,
          born: _now,
          life: 600 + _rng.nextDouble() * 600,
          glow: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final view = _view = _View(size, widget.game.config);
        final shake = _effects.shake * _effects.shake * 14;
        final jolt = shake == 0
            ? Offset.zero
            : Offset(
                math.sin(_now * 0.09) * shake,
                math.cos(_now * 0.11) * shake,
              );

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: ClipRect(
            child: Transform.translate(
              offset: jolt,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  // Overscanned so a shake never shows the edge behind it.
                  const Positioned(
                    left: -24,
                    top: -24,
                    right: -24,
                    bottom: -24,
                    child: RepaintBoundary(
                      child: CustomPaint(painter: _DojoPainter()),
                    ),
                  ),
                  CustomPaint(
                    painter: _ScenePainter(
                      game: widget.game,
                      view: view,
                      tick: _clock.smoothTick,
                      now: _now,
                      fx: _effects,
                    ),
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

// ─── Effects ─────────────────────────────────────────────────────────────

class _Effects {
  final halves = <_Half>[];
  final drops = <_Drop>[];
  final splats = <_Splat>[];
  final popups = <_Popup>[];
  final misses = <_Miss>[];
  final trail = <_TrailPoint>[];
  _Combo? combo;
  _Blast? blast;
  double shake = 0;

  bool get alive =>
      halves.isNotEmpty || drops.isNotEmpty || blast != null || shake > 0;

  void step(double dt, double now) {
    for (final h in halves) {
      h.vel += Offset(0, h.gravity * dt);
      h.pos += h.vel * dt;
      h.angle += h.spin * dt;
    }
    halves.removeWhere((h) => now - h.born > 2500);
    for (final d in drops) {
      d.vel += Offset(0, d.gravity * dt);
      d.pos += d.vel * dt;
    }
    drops.removeWhere((d) => now - d.born > d.life);
    splats.removeWhere((s) => now - s.born > 2600);
    popups.removeWhere((p) => now - p.born > 800);
    misses.removeWhere((m) => now - m.born > 1300);
    trail.removeWhere((p) => now - p.at > 130);
    if (combo != null && now - combo!.born > 1100) combo = null;
    if (blast != null && now - blast!.born > 1200) blast = null;
    shake = math.max(0, shake - dt * 1.8);
  }
}

class _Half {
  _Half({
    required this.kind,
    required this.pos,
    required this.vel,
    required this.angle,
    required this.spin,
    required this.r,
    required this.gravity,
    required this.born,
  });

  final int kind;
  Offset pos;
  Offset vel;
  double angle;
  final double spin;
  final double r;
  final double gravity;
  final double born;
}

class _Drop {
  _Drop({
    required this.pos,
    required this.vel,
    required this.color,
    required this.size,
    required this.gravity,
    required this.born,
    required this.life,
    this.glow = false,
  });

  Offset pos;
  Offset vel;
  final Color color;
  final double size;
  final double gravity;
  final double born;
  final double life;
  final bool glow;
}

class _Splat {
  _Splat(this.at, this.color, this.born, this.blobs);

  factory _Splat.random(
    math.Random rng,
    Offset at,
    double r,
    Color color,
    double born,
  ) {
    final blobs = <(Offset, double)>[(Offset.zero, r * 0.75)];
    for (var i = 0; i < 9; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final d = r * (0.6 + rng.nextDouble() * 1.1);
      blobs.add((
        Offset(math.cos(a), math.sin(a)) * d,
        r * (0.1 + rng.nextDouble() * 0.28),
      ));
    }
    return _Splat(at, color, born, blobs);
  }

  final Offset at;
  final Color color;
  final double born;
  final List<(Offset, double)> blobs;
}

class _Popup {
  _Popup(this.text, this.at, this.born);

  final String text;
  final Offset at;
  final double born;
}

class _Combo {
  _Combo(this.count, this.bonus, this.at, this.born, this.stroke);

  final int count;
  final int bonus;
  final Offset at;
  final double born;
  final int stroke;
}

class _Miss {
  _Miss(this.at, this.born);

  final Offset at;
  final double born;
}

class _Blast {
  _Blast(this.at, this.r, this.born);

  final Offset at;
  final double r;
  final double born;
}

class _TrailPoint {
  _TrailPoint(this.p, this.at);

  final Offset p;
  final double at;
}

// ─── Painting ────────────────────────────────────────────────────────────

/// A dark wooden dojo wall: planks with grain, lit from the middle.
class _DojoPainter extends CustomPainter {
  const _DojoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF3B2414));

    final rng = math.Random(7);
    final plank = size.width / 5;
    for (var i = 0; i < 6; i++) {
      final x = i * plank;
      final tone = [
        const Color(0xFF5A3820),
        const Color(0xFF4E2F1A),
        const Color(0xFF63412A),
      ][i % 3];
      final r = Rect.fromLTWH(x, 0, plank, size.height);
      canvas.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Color.lerp(tone, Colors.black, 0.25)!,
              tone,
              Color.lerp(tone, Colors.black, 0.3)!,
            ],
            stops: const [0, 0.45, 1],
          ).createShader(r),
      );
      // Grain: long wavering lines down the plank.
      final grain = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFF2A160A).withValues(alpha: 0.35);
      for (var g = 0; g < 7; g++) {
        final gx = x + plank * (0.1 + 0.8 * rng.nextDouble());
        final amp = 3 + rng.nextDouble() * 6;
        final freq = 0.004 + rng.nextDouble() * 0.01;
        final phase = rng.nextDouble() * 6;
        final path = Path()..moveTo(gx, 0);
        for (var y = 0.0; y <= size.height; y += 12) {
          path.lineTo(gx + math.sin(y * freq + phase) * amp, y);
        }
        canvas.drawPath(path, grain);
      }
      // A knot here and there.
      if (rng.nextDouble() < 0.7) {
        final c = Offset(
          x + plank * (0.3 + rng.nextDouble() * 0.4),
          size.height * rng.nextDouble(),
        );
        for (var k = 3; k >= 1; k--) {
          canvas.drawOval(
            Rect.fromCenter(center: c, width: 10.0 * k, height: 18.0 * k),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = const Color(0xFF2A160A).withValues(alpha: 0.35),
          );
        }
      }
      // Seam between planks.
      canvas.drawRect(
        Rect.fromLTWH(x - 1.5, 0, 3, size.height),
        Paint()..color = const Color(0xFF1A0D05).withValues(alpha: 0.8),
      );
      canvas.drawRect(
        Rect.fromLTWH(x + 1.5, 0, 1, size.height),
        Paint()..color = const Color(0xFF8A6040).withValues(alpha: 0.25),
      );
    }

    // Warm light in the middle falling off to dark corners.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 1.0,
          colors: [
            const Color(0xFFFFB86B).withValues(alpha: 0.10),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.65),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _DojoPainter oldDelegate) => false;
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.game,
    required this.view,
    required this.tick,
    required this.now,
    required this.fx,
  });

  final FruitSlice game;
  final _View view;
  final double tick;
  final double now;
  final _Effects fx;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSplats(canvas);
    _paintMisses(canvas);

    for (final i in game.airborne) {
      final t = game.throws[i];
      final (x, y) = t.smoothPos(tick);
      final at = view.toScreen(x, y);
      final r = t.radius * view.s;
      final spinRate = (((i * 37) % 7) - 3.2) * 0.02;
      final angle = (tick - t.enter) * spinRate;
      if (t.bomb) {
        _paintBomb(canvas, at, r, angle, now);
      } else {
        _paintFruit(canvas, at, r, angle, t.kind % _looks.length);
      }
    }

    for (final h in fx.halves) {
      _paintHalf(canvas, h);
    }
    _paintDrops(canvas);
    _paintBlast(canvas, size);
    _paintTrail(canvas);
    _paintPopups(canvas);
    _paintCombo(canvas, size);
  }

  // A whole fruit: shadow, skin with its markings (which turn with it),
  // then shading and a highlight that stay put so the light has a direction.
  void _paintFruit(Canvas canvas, Offset at, double r, double angle, int kind) {
    final look = _looks[kind];
    final outline = _outline(kind, r).transform(_rotation(angle, at));

    canvas.drawPath(
      outline.shift(Offset(r * 0.18, r * 0.28)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
    );

    canvas.save();
    canvas.clipPath(outline);
    _paintSkin(canvas, at, r, angle, kind, look);
    canvas.restore();

    _paintExtras(canvas, at, r, angle, kind);
    _paintGloss(canvas, at, r);
  }

  Float64List _rotation(double angle, Offset at) {
    final c = math.cos(angle), s = math.sin(angle);
    return Float64List.fromList([
      c, s, 0, 0, //
      -s, c, 0, 0,
      0, 0, 1, 0,
      at.dx, at.dy, 0, 1,
    ]);
  }

  Path _outline(int kind, double r) {
    switch (kind) {
      case 0: // watermelon: a fat oval
        return Path()..addOval(
          Rect.fromCenter(center: Offset.zero, width: r * 2.2, height: r * 1.8),
        );
      case 3: // lemon: an oval with a point at each end
        return Path()
          ..addOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: r * 2.1,
              height: r * 1.6,
            ),
          )
          ..addOval(
            Rect.fromCenter(
              center: Offset(r * 1.02, 0),
              width: r * 0.4,
              height: r * 0.34,
            ),
          )
          ..addOval(
            Rect.fromCenter(
              center: Offset(-r * 1.02, 0),
              width: r * 0.4,
              height: r * 0.34,
            ),
          );
      case 5: // plum: a touch taller than wide
        return Path()..addOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: r * 1.9,
            height: r * 2.05,
          ),
        );
      default:
        return Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r));
    }
  }

  void _paintSkin(
    Canvas canvas,
    Offset at,
    double r,
    double angle,
    int kind,
    _Look look,
  ) {
    final box = Rect.fromCircle(center: at, radius: r * 1.2);
    canvas.drawRect(
      box,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.9,
          colors: [look.light, look.base, look.dark],
          stops: const [0, 0.5, 1],
        ).createShader(box),
    );

    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    switch (kind) {
      case 0: // dark wavy stripes
        final stripe = Paint()
          ..color = const Color(0xFF0E4A1E).withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.2
          ..strokeCap = StrokeCap.round;
        for (var k = -3; k <= 3; k++) {
          final x = k * r * 0.34;
          final path = Path()..moveTo(x, -r);
          for (var y = -r; y <= r; y += r * 0.2) {
            path.lineTo(
              x +
                  math.sin(y / r * 7 + k) * r * 0.06 +
                  x * 0.25 * (1 - (y / r) * (y / r)),
              y,
            );
          }
          canvas.drawPath(path, stripe);
        }
      case 1: // dimpled peel
        final dimple = Paint()
          ..color = const Color(0xFFB45309).withValues(alpha: 0.35);
        final rng = math.Random(11);
        for (var k = 0; k < 40; k++) {
          final a = rng.nextDouble() * math.pi * 2;
          final d = math.sqrt(rng.nextDouble()) * r * 0.95;
          canvas.drawCircle(
            Offset(math.cos(a) * d, math.sin(a) * d),
            r * 0.035,
            dimple,
          );
        }
      case 2: // a blush of yellow streaks on the apple
        final streak = Paint()
          ..color = const Color(0xFFFFD27A).withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.05;
        for (var k = -2; k <= 2; k++) {
          canvas.drawArc(
            Rect.fromCircle(
              center: Offset(k * r * 0.2, r * 0.9),
              radius: r * 1.3,
            ),
            -math.pi * 0.75,
            math.pi * 0.5,
            false,
            streak,
          );
        }
      case 4: // hairy husk and three eyes
        final hair = Paint()
          ..color = const Color(0xFF2A1608).withValues(alpha: 0.45)
          ..strokeWidth = r * 0.03;
        final rng = math.Random(5);
        for (var k = 0; k < 60; k++) {
          final a = rng.nextDouble() * math.pi * 2;
          final d = rng.nextDouble() * r;
          final p = Offset(math.cos(a) * d, math.sin(a) * d);
          canvas.drawLine(
            p,
            p + Offset(math.cos(a + 1.3), math.sin(a + 1.3)) * r * 0.2,
            hair,
          );
        }
        final eye = Paint()..color = const Color(0xFF1C0E05);
        for (var k = 0; k < 3; k++) {
          final a = -math.pi / 2 + k * math.pi * 2 / 3;
          canvas.drawOval(
            Rect.fromCenter(
              center:
                  Offset(math.cos(a), math.sin(a)) * r * 0.22 +
                  Offset(0, -r * 0.35),
              width: r * 0.16,
              height: r * 0.12,
            ),
            eye,
          );
        }
      case 5: // the plum's crease
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(r * 0.5, 0),
            width: r * 1.2,
            height: r * 2,
          ),
          math.pi * 0.6,
          math.pi * 0.8,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.05
            ..color = look.dark.withValues(alpha: 0.6),
        );
    }
    canvas.restore();

    // Ambient shading: dark round the far rim, a bounced light along the
    // bottom. This is what makes a flat disc read as a ball.
    canvas.drawRect(
      box,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.3),
          radius: 0.72,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
          stops: const [0.55, 1],
        ).createShader(box),
    );
    canvas.drawCircle(
      at + Offset(r * 0.25, r * 0.35),
      r * 0.95,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..color = look.light.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),
    );
  }

  void _paintExtras(
    Canvas canvas,
    Offset at,
    double r,
    double angle,
    int kind,
  ) {
    if (kind != 2 && kind != 1 && kind != 5) return;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final top = Offset(0, -r * (kind == 5 ? 1.0 : 0.92));
    if (kind == 1) {
      canvas.drawCircle(
        top + Offset(0, r * 0.08),
        r * 0.1,
        Paint()..color = const Color(0xFF4D7C0F),
      );
    } else {
      canvas.drawLine(
        top + Offset(0, r * 0.1),
        top + Offset(r * 0.08, -r * 0.32),
        Paint()
          ..color = const Color(0xFF5B3A1E)
          ..strokeWidth = r * 0.09
          ..strokeCap = StrokeCap.round,
      );
      if (kind == 2) {
        final leaf = Path()
          ..moveTo(top.dx + r * 0.08, top.dy - r * 0.18)
          ..quadraticBezierTo(
            top.dx + r * 0.45,
            top.dy - r * 0.55,
            top.dx + r * 0.62,
            top.dy - r * 0.2,
          )
          ..quadraticBezierTo(
            top.dx + r * 0.35,
            top.dy - r * 0.02,
            top.dx + r * 0.08,
            top.dy - r * 0.18,
          );
        canvas.drawPath(
          leaf,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFF86EFAC), Color(0xFF15803D)],
            ).createShader(leaf.getBounds()),
        );
      }
    }
    canvas.restore();
  }

  void _paintGloss(Canvas canvas, Offset at, double r) {
    canvas.drawOval(
      Rect.fromCenter(
        center: at + Offset(-r * 0.38, -r * 0.42),
        width: r * 0.62,
        height: r * 0.38,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.1),
    );
    canvas.drawCircle(
      at + Offset(-r * 0.45, -r * 0.48),
      r * 0.08,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  // Half a fruit: the skin on one side of the cut, and the cut face seen at a
  // tilt as an ellipse along the blade line.
  void _paintHalf(Canvas canvas, _Half h) {
    final look = _looks[h.kind % _looks.length];
    final r = h.r;
    final age = now - h.born;
    final fade = age < 2000 ? 1.0 : 1 - (age - 2000) / 500;
    if (fade <= 0) return;

    canvas.saveLayer(
      Rect.fromCircle(center: h.pos, radius: r * 1.6),
      Paint()..color = Colors.white.withValues(alpha: fade.clamp(0, 1)),
    );
    canvas.translate(h.pos.dx, h.pos.dy);
    canvas.rotate(h.angle);

    // Skin: the whole fruit, clipped to this side of the cut.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-r * 1.4, -r * 1.4, r * 1.4, 0));
    final outline = _outline(h.kind, r);
    canvas.clipPath(outline);
    _paintSkin(canvas, Offset.zero, r, 0, h.kind, look);
    canvas.restore();

    // The cut face.
    final face = Rect.fromCenter(
      center: Offset.zero,
      width:
          r *
          (h.kind == 0
              ? 2.1
              : h.kind == 3
              ? 1.95
              : 1.9),
      height: r * 0.62,
    );
    canvas.drawOval(face, Paint()..color = look.rind);
    final inner = face.deflate(
      r *
          (h.kind == 0
              ? 0.12
              : h.kind == 4
              ? 0.1
              : 0.05),
    );
    canvas.drawOval(
      inner,
      Paint()
        ..shader = RadialGradient(
          colors: [Color.lerp(look.flesh, Colors.white, 0.3)!, look.flesh],
        ).createShader(inner),
    );
    switch (h.kind) {
      case 0: // watermelon seeds
        final seed = Paint()..color = const Color(0xFF1B1B1B);
        for (var k = -3; k <= 3; k++) {
          if (k == 0) continue;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(k * r * 0.24, (k.isEven ? -1 : 1) * r * 0.08),
              width: r * 0.09,
              height: r * 0.06,
            ),
            seed,
          );
        }
      case 1 || 3: // citrus segments
        final line = Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..strokeWidth = r * 0.025;
        for (var k = 0; k < 8; k++) {
          final a = k * math.pi / 4;
          canvas.drawLine(
            Offset.zero,
            Offset(
              math.cos(a) * inner.width / 2,
              math.sin(a) * inner.height / 2,
            ),
            line,
          );
        }
      case 2: // apple core
        final seed = Paint()..color = const Color(0xFF5B3A1E);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: r * 0.5,
            height: r * 0.16,
          ),
          Paint()..color = const Color(0xFFF3E1A6),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(-r * 0.1, 0),
            width: r * 0.1,
            height: r * 0.06,
          ),
          seed,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(r * 0.1, 0),
            width: r * 0.1,
            height: r * 0.06,
          ),
          seed,
        );
      case 5: // plum stone
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: r * 0.55,
            height: r * 0.2,
          ),
          Paint()..color = const Color(0xFF9A3412),
        );
    }
    // Wet shine across the face.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-r * 0.3, -r * 0.08),
        width: r * 0.7,
        height: r * 0.1,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    canvas.restore();
  }

  void _paintBomb(
    Canvas canvas,
    Offset at,
    double r,
    double angle,
    double now,
  ) {
    final pulse = 0.5 + 0.5 * math.sin(now / 90);
    // A red warning glow that throbs.
    canvas.drawCircle(
      at,
      r * (1.35 + 0.1 * pulse),
      Paint()
        ..color = const Color(0xFFFF2D2D).withValues(alpha: 0.25 + 0.2 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35),
    );
    canvas.drawCircle(
      at + Offset(r * 0.18, r * 0.28),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
    );
    final box = Rect.fromCircle(center: at, radius: r);
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 0.9,
          colors: [Color(0xFF6B7280), Color(0xFF1F2937), Color(0xFF030712)],
          stops: [0, 0.45, 1],
        ).createShader(box),
    );

    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle * 0.4);
    // A metal band with rivets.
    canvas.drawArc(
      Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 0.9),
      0,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..color = const Color(0xFF9CA3AF).withValues(alpha: 0.35),
    );
    // Cap and fuse.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -r * 0.98),
          width: r * 0.5,
          height: r * 0.3,
        ),
        Radius.circular(r * 0.06),
      ),
      Paint()..color = const Color(0xFF4B5563),
    );
    final tip = Offset(r * 0.35, -r * 1.55);
    canvas.drawPath(
      Path()
        ..moveTo(0, -r * 1.1)
        ..quadraticBezierTo(r * 0.05, -r * 1.5, tip.dx, tip.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..color = const Color(0xFFC8A165),
    );
    // Sparks fizzing off the end of the fuse.
    final flick = math.sin(now / 35) * 0.5 + 0.5;
    canvas.drawCircle(
      tip,
      r * (0.28 + 0.12 * flick),
      Paint()
        ..color = const Color(0xFFFFB020).withValues(alpha: 0.8)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.15),
    );
    final ray = Paint()
      ..color = const Color(0xFFFFF7AE)
      ..strokeWidth = r * 0.05
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4 + now / 60;
      final len = r * (0.2 + 0.25 * ((k.isEven ? flick : 1 - flick)));
      canvas.drawLine(tip, tip + Offset(math.cos(a), math.sin(a)) * len, ray);
    }
    canvas.drawCircle(tip, r * 0.08, Paint()..color = Colors.white);
    canvas.restore();

    _paintGloss(canvas, at, r);
  }

  void _paintSplats(Canvas canvas) {
    for (final s in fx.splats) {
      final age = now - s.born;
      final a = age < 1400 ? 0.55 : 0.55 * (1 - (age - 1400) / 1200);
      if (a <= 0) continue;
      final paint = Paint()..color = s.color.withValues(alpha: a.clamp(0, 1));
      final grow = Curves.easeOutCubic.transform((age / 180).clamp(0, 1));
      for (final (o, rad) in s.blobs) {
        canvas.drawCircle(s.at + o * grow, rad * grow, paint);
      }
      // Drips running down the wall.
      final drip = (age / 2600).clamp(0.0, 1.0) * s.blobs.first.$2 * 1.6;
      for (final (o, rad) in s.blobs.skip(1).take(3)) {
        final top = s.at + o;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(top.dx - rad * 0.3, top.dy, rad * 0.6, drip),
            Radius.circular(rad * 0.3),
          ),
          paint,
        );
      }
    }
  }

  void _paintMisses(Canvas canvas) {
    for (final m in fx.misses) {
      final age = now - m.born;
      final t = age / 1300;
      final a = (1 - t).clamp(0.0, 1.0);
      final c =
          m.at - Offset(0, 40 + 30 * Curves.easeOut.transform(t.clamp(0, 1)));
      canvas.drawCircle(
        m.at,
        60,
        Paint()
          ..color = const Color(0xFFEF4444).withValues(alpha: 0.35 * a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
      final pop =
          1 + 0.4 * (1 - Curves.elasticOut.transform((age / 500).clamp(0, 1)));
      final s = 14 * pop;
      final cross = Paint()
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round;
      for (final (col, w) in [
        (Colors.black.withValues(alpha: 0.5 * a), 11.0),
        (const Color(0xFFEF4444).withValues(alpha: a), 7.0),
      ]) {
        cross
          ..color = col
          ..strokeWidth = w;
        canvas.drawLine(c + Offset(-s, -s), c + Offset(s, s), cross);
        canvas.drawLine(c + Offset(s, -s), c + Offset(-s, s), cross);
      }
    }
  }

  void _paintDrops(Canvas canvas) {
    for (final d in fx.drops) {
      final t = (now - d.born) / d.life;
      final a = (1 - t).clamp(0.0, 1.0);
      if (d.glow) {
        canvas.drawCircle(
          d.pos,
          d.size * 2.2,
          Paint()
            ..color = d.color.withValues(alpha: 0.5 * a)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, d.size),
        );
      }
      canvas.drawCircle(
        d.pos,
        d.size * (0.6 + 0.4 * a),
        Paint()..color = d.color.withValues(alpha: a),
      );
      canvas.drawCircle(
        d.pos - Offset(d.size * 0.25, d.size * 0.25),
        d.size * 0.3,
        Paint()..color = Colors.white.withValues(alpha: 0.6 * a),
      );
    }
  }

  void _paintBlast(Canvas canvas, Size size) {
    final b = fx.blast;
    if (b == null) return;
    final age = now - b.born;
    final t = (age / 900).clamp(0.0, 1.0);
    // White-out that fades.
    final flash = (1 - age / 380).clamp(0.0, 1.0);
    if (flash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = const Color(0xFFFFF8E1).withValues(alpha: 0.85 * flash),
      );
    }
    final grow = Curves.easeOutCubic.transform(t);
    // The fireball: white-hot in the middle, burning out to red.
    final ball = b.r * (1.2 + 3.2 * grow);
    canvas.drawCircle(
      b.at,
      ball,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFFFF0).withValues(alpha: 1 - t),
            const Color(0xFFFFD23F).withValues(alpha: 0.9 * (1 - t)),
            const Color(0xFFFF4D1A).withValues(alpha: 0.6 * (1 - t)),
            Colors.transparent,
          ],
          stops: const [0, 0.3, 0.65, 1],
        ).createShader(Rect.fromCircle(center: b.at, radius: ball)),
    );
    canvas.drawCircle(
      b.at,
      b.r * (1 + 5 * grow),
      Paint()
        ..color = const Color(0xFFFF7A1A).withValues(alpha: 0.55 * (1 - t))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, b.r * 0.8),
    );
    for (var k = 0; k < 3; k++) {
      final tk = ((age - k * 90) / 800).clamp(0.0, 1.0);
      if (tk <= 0) continue;
      canvas.drawCircle(
        b.at,
        b.r * (1 + 9 * Curves.easeOut.transform(tk)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = b.r * 0.25 * (1 - tk)
          ..color = Colors.white.withValues(alpha: 0.8 * (1 - tk)),
      );
    }
    // Smoke rolling out.
    for (var k = 0; k < 7; k++) {
      final a = k * math.pi * 2 / 7 + 0.4;
      final d = b.r * (0.5 + 2.2 * grow);
      canvas.drawCircle(
        b.at + Offset(math.cos(a), math.sin(a)) * d - Offset(0, 40 * grow),
        b.r * (0.6 + 0.8 * grow),
        Paint()
          ..color = const Color(0xFF1F1F1F).withValues(alpha: 0.5 * (1 - t))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, b.r * 0.4),
      );
    }
  }

  // The blade: a ribbon that is widest at the finger and tapers to nothing
  // along where it has just been, a violet glow under a white-hot core.
  void _paintTrail(Canvas canvas) {
    final pts = fx.trail;
    if (pts.length < 2) return;
    Path ribbon(double maxW) {
      final left = <Offset>[];
      final right = <Offset>[];
      for (var i = 0; i < pts.length; i++) {
        final p = pts[i].p;
        final q = i == 0 ? pts[1].p : pts[i - 1].p;
        var d = i == 0 ? q - p : p - q;
        if (d.distance == 0) d = const Offset(1, 0);
        final n = Offset(-d.dy, d.dx) / d.distance;
        final life = (1 - (now - pts[i].at) / 130).clamp(0.0, 1.0);
        final w = maxW * math.pow(i / (pts.length - 1), 0.7) * life;
        left.add(p + n * w);
        right.add(p - n * w);
      }
      final path = Path()..moveTo(left.first.dx, left.first.dy);
      for (final p in left.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      final tip = pts.last.p;
      path.lineTo(tip.dx, tip.dy);
      for (final p in right.reversed) {
        path.lineTo(p.dx, p.dy);
      }
      return path..close();
    }

    final from = pts.first.p;
    final to = pts.last.p;
    if ((to - from).distance < 1) return;
    canvas.drawPath(
      ribbon(13),
      Paint()
        ..shader = ui.Gradient.linear(
          from,
          to,
          [
            const Color(0x006D28D9),
            const Color(0xCC7C3AED),
            const Color(0xFF38BDF8),
          ],
          [0, 0.55, 1],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      ribbon(5.5),
      Paint()
        ..shader = ui.Gradient.linear(from, to, [
          const Color(0x00FFFFFF),
          const Color(0xFFF5F3FF),
        ]),
    );
    canvas.drawCircle(
      to,
      7,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _paintPopups(Canvas canvas) {
    for (final p in fx.popups) {
      final t = ((now - p.born) / 800).clamp(0.0, 1.0);
      final at = p.at - Offset(0, 50 * Curves.easeOut.transform(t));
      _text(canvas, p.text, at, 22, 1 - t, const [
        Color(0xFFFFFFFF),
        Color(0xFFFFE082),
      ]);
    }
  }

  void _paintCombo(Canvas canvas, Size size) {
    final c = fx.combo;
    if (c == null) return;
    final age = now - c.born;
    final pop = Curves.elasticOut.transform((age / 600).clamp(0, 1));
    final a = age < 800 ? 1.0 : 1 - (age - 800) / 300;
    final at = Offset(
      c.at.dx.clamp(110, size.width - 110),
      c.at.dy.clamp(size.height * 0.25, size.height * 0.8),
    );
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(-0.08);
    canvas.scale(0.4 + 0.6 * pop);
    const gold = [Color(0xFFFFF3B0), Color(0xFFFFB020), Color(0xFFE8590C)];
    _text(canvas, '${c.count} FRUIT', const Offset(0, -34), 30, a, gold);
    _text(canvas, 'COMBO', const Offset(0, 0), 34, a, gold);
    _text(canvas, '+${c.bonus}', const Offset(0, 42), 42, a, gold);
    canvas.restore();
  }

  /// Chunky arcade text: a dark outline under a gradient fill.
  void _text(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    double alpha,
    List<Color> colors,
  ) {
    if (alpha <= 0) return;
    final a = alpha.clamp(0.0, 1.0);
    TextPainter layout(Paint paint) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          foreground: paint,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final outline = layout(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.2
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF3B1705).withValues(alpha: a),
    );
    final origin = center - Offset(outline.width / 2, outline.height / 2);
    outline.paint(canvas, origin + Offset(0, size * 0.08));
    outline.paint(canvas, origin);
    final rect = origin & Size(outline.width, outline.height);
    layout(
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [for (final c in colors) c.withValues(alpha: a)],
        ).createShader(rect),
    ).paint(canvas, origin);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) => true;
}
