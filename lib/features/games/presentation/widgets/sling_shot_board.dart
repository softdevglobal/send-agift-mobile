import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/sling_shot.dart';
import '../game_controls.dart';
import 'game_hud.dart';

/// Screen pixels of drag per unit of pull.
const double _pxPerPull = 1.5;
const int _collapseMs = 600;
const int _clearedMs = 1000;

/// World → screen for a board of a given size.
class _Geo {
  _Geo(this.size) : scale = size.width / 1060, groundY = size.height * 0.86;

  final Size size;
  final double scale;
  final double groundY;

  double sx(num x) => (x + 30) * scale;
  double sy(num y) => groundY - y * scale;
  Offset p(num x, num y) => Offset(sx(x), sy(y));
}

/// Sling Shot, side on in 3D. Drag back from anywhere to aim, let go to fire.
class SlingShotBoard extends StatefulWidget {
  const SlingShotBoard({required this.game, required this.controls, super.key});

  final SlingShot game;
  final GameControls controls;

  @override
  State<SlingShotBoard> createState() => _SlingShotBoardState();
}

class _SlingShotBoardState extends State<SlingShotBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this);

  SlingShotResult? _playing;
  int _playMs = 1;
  Offset? _drag;
  (int, int)? _pull;

  SlingShot get _game => widget.game;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  (int, int)? _pullFor(Offset drag) {
    var dx = -drag.dx / _pxPerPull;
    var dy = drag.dy / _pxPerPull;
    final max = _game.config.maxPull.toDouble();
    final len = math.sqrt(dx * dx + dy * dy);
    if (len > max) {
      dx *= max / len;
      dy *= max / len;
    }
    var ix = dx.truncate();
    var iy = dy.truncate();
    while (!_game.validPull(ix, iy) && ix > 1) {
      ix--;
      iy = iy > 0 ? iy - 1 : (iy < 0 ? iy + 1 : 0);
    }
    return _game.validPull(ix, iy) ? (ix, iy) : null;
  }

  bool get _canAim =>
      widget.controls.active && _playing == null && !_game.isOver;

  void _panStart(DragStartDetails details) {
    if (!_canAim) return;
    setState(() {
      _drag = Offset.zero;
      _pull = null;
    });
  }

  void _panUpdate(DragUpdateDetails details) {
    final drag = _drag;
    if (drag == null) return;
    setState(() {
      _drag = drag + details.delta;
      _pull = _pullFor(_drag!);
    });
  }

  void _panEnd(DragEndDetails details) {
    final pull = _pull;
    setState(() {
      _drag = null;
      _pull = null;
    });
    if (pull == null || !_canAim) return;
    final result = _game.shoot(pull.$1, pull.$2);
    if (result == null) return;

    // Replay the shot on screen, then let the game screen know. So the
    // score and the next level only change once the dust has settled.
    _playMs =
        result.path.length * _game.config.tickMs +
        _collapseMs +
        (result.levelCleared ? _clearedMs : 0);
    setState(() => _playing = result);
    _anim
      ..duration = Duration(milliseconds: _playMs)
      ..forward(from: 0).then((_) {
        if (!mounted) return;
        setState(() => _playing = null);
        widget.controls.onChanged();
      });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    // The readouts float over the scene rather than sitting on a strip below
    // it. Given their own row they cost the scene most of a phone's bottom
    // eighth, for two chips that sit comfortably on top of it.
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('sling-area'),
            behavior: HitTestBehavior.opaque,
            onPanStart: _panStart,
            onPanUpdate: _panUpdate,
            onPanEnd: _panEnd,
            child: ClipRRect(
              // Square: the scene runs to the corners of the screen now, and a
              // rounded one would leave the backdrop showing through them.
              borderRadius: BorderRadius.zero,
              child: CustomPaint(
                size: Size.infinite,
                painter: _SlingPainter(
                  game: game,
                  anim: _anim,
                  playing: _playing,
                  playMs: _playMs,
                  drag: _drag,
                  pull: _pull,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              _chip(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < game.config.shotsPerLevel; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          Icons.circle,
                          size: 14,
                          color: i < game.shotsLeft
                              ? const Color(0xFFFF5252)
                              : Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                  ],
                ),
              ),
              _chip(
                Text(
                  'Level ${math.min(game.level + 1, game.config.levels)} of '
                  '${game.config.levels}',
                  style: _chipText,
                ),
              ),
              _chip(Text('Targets ${game.targetsLeft}', style: _chipText)),
            ],
          ),
        ),
      ],
    );
  }

  static const _chipText = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w700,
  );

  Widget _chip(Widget child) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: glassDecoration(radius: 20),
    child: child,
  );
}

class _SlingPainter extends CustomPainter {
  _SlingPainter({
    required this.game,
    required this.anim,
    required this.playing,
    required this.playMs,
    required this.drag,
    required this.pull,
  }) : super(repaint: anim);

  final SlingShot game;
  final Animation<double> anim;
  final SlingShotResult? playing;
  final int playMs;
  final Offset? drag;
  final (int, int)? pull;

  static const _restX = SlingShot.startX;
  static const _restY = SlingShot.startY;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _Geo(size);
    _scenery(canvas, size, g);
    _sling(canvas, g, back: true);

    final res = playing;
    if (res == null) {
      _blocks(canvas, g, game.blocks, const {}, const {}, 1);
      final ball = _restBall(g);
      _bands(canvas, g, ball);
      if (pull != null) _preview(canvas, g, pull!);
      _projectile(canvas, g, ball, 0);
    } else {
      _replay(canvas, size, g, res);
    }
    _sling(canvas, g, back: false);
  }

  Offset _restBall(_Geo g) {
    final rest = g.p(_restX, _restY);
    final d = drag;
    if (d == null) return rest;
    final len = d.distance;
    const max = 100 * _pxPerPull;
    return rest + (len > max ? d / len * max : d);
  }

  void _replay(Canvas canvas, Size size, _Geo g, SlingShotResult res) {
    final ms = anim.value * playMs;
    final tick = ms / game.config.tickMs;
    final flightMs = res.path.length * game.config.tickMs;

    final hitAt = {for (final h in res.hits) h.blockId: h};
    final broken = <int>{
      for (final h in res.hits)
        if (h.broke && h.tick <= tick) h.blockId,
    };
    // The collapse: each block eases from where it stood to where it
    // settles; ones that broke on landing fade out.
    final c = ((ms - flightMs) / _collapseMs).clamp(0.0, 1.0);
    final yOf = <int, double>{};
    final firstFrom = <int, int>{};
    final lastTo = <int, int>{};
    final brokeFalling = <int>{};
    for (final f in res.falls) {
      firstFrom.putIfAbsent(f.blockId, () => f.fromY);
      lastTo[f.blockId] = f.toY;
      if (f.broke) brokeFalling.add(f.blockId);
    }
    for (final id in firstFrom.keys) {
      final eased = c * c;
      yOf[id] = firstFrom[id]! + (lastTo[id]! - firstFrom[id]!) * eased;
    }
    final fade = <int, double>{for (final id in brokeFalling) id: 1 - c};
    _blocks(canvas, g, res.blocksBefore, broken, yOf, 1, fade: fade);

    // Debris where blocks broke in flight.
    for (final h in res.hits) {
      if (!h.broke) continue;
      final age = (tick - h.tick) / 30;
      if (age < 0 || age > 1) continue;
      final b = res.blocksBefore.firstWhere((b) => b.id == h.blockId);
      final centre = g.p(b.x + b.w / 2, b.y + b.h / 2);
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4 + h.blockId;
        canvas.drawRect(
          Rect.fromCenter(
            center:
                centre +
                Offset(math.cos(a), math.sin(a) - 0.5 + age) *
                    40 *
                    g.scale *
                    2 *
                    age,
            width: 8 * g.scale * (1 - age) + 1,
            height: 8 * g.scale * (1 - age) + 1,
          ),
          Paint()..color = _base(b.kind).withValues(alpha: 1 - age),
        );
      }
      _label(
        canvas,
        centre - Offset(0, 30 * age + 10),
        '+${b.kind == 'T' ? game.config.targetPoints : game.config.woodPoints}',
        1 - age,
      );
    }

    if (tick < res.path.length) {
      final i = tick.floor().clamp(0, res.path.length - 1);
      final (px, py) = res.path[i];
      _projectile(canvas, g, g.p(px / 16, py / 16), tick * 0.35);
      // A fading trail.
      for (var k = 1; k < 12; k++) {
        final j = i - k * 2;
        if (j < 0) break;
        final (tx, ty) = res.path[j];
        canvas.drawCircle(
          g.p(tx / 16, ty / 16),
          3 * g.scale * 2,
          Paint()..color = Colors.white.withValues(alpha: 0.4 * (1 - k / 12)),
        );
      }
    } else if (!hitAt.isNotEmpty || res.path.isNotEmpty) {
      final (px, py) = res.path.last;
      _projectile(canvas, g, g.p(px / 16, math.max(py / 16, 14)), 0);
    }

    if (res.levelCleared && ms > flightMs + _collapseMs) {
      final k = ((ms - flightMs - _collapseMs) / _clearedMs).clamp(0.0, 1.0);
      _banner(
        canvas,
        size,
        game.isOver && game.won ? 'All levels cleared!' : 'Level cleared!',
        res.bonus > 0 ? '+${res.bonus} shot bonus' : '',
        k,
      );
    }
  }

  // ─── Drawing ───────────────────────────────────────────────────────────

  void _scenery(Canvas canvas, Size size, _Geo g) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5F6FD8), Color(0xFFB39DDB), Color(0xFFFFCCBC)],
        ).createShader(rect),
    );
    final sun = Offset(size.width * 0.8, size.height * 0.16);
    canvas.drawCircle(
      sun,
      size.width * 0.09,
      Paint()..color = const Color(0xFFFFF3E0).withValues(alpha: 0.9),
    );

    // Two ranges of hills behind the range.
    for (final (lift, amp, color) in const [
      (0.3, 0.07, Color(0xFF9575CD)),
      (0.2, 0.05, Color(0xFF7E57C2)),
    ]) {
      final path = Path()..moveTo(0, g.groundY);
      for (var x = 0.0; x <= size.width; x += size.width / 30) {
        path.lineTo(
          x,
          g.groundY -
              size.height * lift -
              math.sin(x / size.width * math.pi * 2.5 + lift * 9) *
                  size.height *
                  amp,
        );
      }
      path
        ..lineTo(size.width, g.groundY)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    // The ground, with a lit grass lip for depth.
    final ground = Rect.fromLTRB(0, g.groundY, size.width, size.height);
    canvas
      ..drawRect(
        ground,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6D4C41), Color(0xFF3E2723)],
          ).createShader(ground),
      )
      ..drawRect(
        Rect.fromLTRB(0, g.groundY - 6, size.width, g.groundY + 6),
        Paint()..color = const Color(0xFF7CB342),
      )
      ..drawRect(
        Rect.fromLTRB(0, g.groundY - 6, size.width, g.groundY - 3),
        Paint()..color = const Color(0xFFAED581),
      );
  }

  void _sling(Canvas canvas, _Geo g, {required bool back}) {
    final wood = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 12 * g.scale * 1.6
      ..strokeCap = StrokeCap.round;
    final fork = g.p(_restX, 110);
    if (back) {
      canvas
        ..drawLine(g.p(_restX, 0), fork, wood)
        ..drawLine(fork, g.p(_restX + 16, _restY + 4), wood);
    } else {
      canvas.drawLine(fork, g.p(_restX - 16, _restY + 4), wood);
    }
  }

  void _bands(Canvas canvas, _Geo g, Offset ball) {
    final band = Paint()
      ..color = const Color(0xFF3E2723)
      ..strokeWidth = 4 * g.scale * 1.4
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(g.p(_restX + 16, _restY + 4), ball, band)
      ..drawLine(g.p(_restX - 16, _restY + 4), ball, band);
  }

  void _preview(Canvas canvas, _Geo g, (int, int) pull) {
    final path = game.previewPath(pull.$1, pull.$2, 48);
    for (var i = 2; i < path.length; i += 3) {
      final (px, py) = path[i];
      if (py < 0) break;
      canvas.drawCircle(
        g.p(px / 16, py / 16),
        3.2 - i / path.length * 1.8,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9 - i / path.length * 0.6),
      );
    }
  }

  /// A shiny bauble with a gold cap.
  void _projectile(Canvas canvas, _Geo g, Offset c, double spin) {
    final r = SlingShot.radius * g.scale * 1.3;
    canvas
      ..drawCircle(
        c,
        r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.4),
            colors: [Color(0xFFFF8A80), Color(0xFFE53935), Color(0xFF7F0000)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      )
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(spin)
      ..drawRect(
        Rect.fromCenter(
          center: Offset(0, -r),
          width: r * 0.7,
          height: r * 0.35,
        ),
        Paint()..color = const Color(0xFFFFD54F),
      )
      ..restore()
      ..drawCircle(
        c + Offset(-r * 0.35, -r * 0.35),
        r * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
  }

  static Color _base(String kind) => switch (kind) {
    'W' => const Color(0xFFC98B4B),
    'S' => const Color(0xFF8E99A4),
    _ => const Color(0xFF43A047),
  };

  void _blocks(
    Canvas canvas,
    _Geo g,
    List<SlingBlock> blocks,
    Set<int> broken,
    Map<int, double> yOf,
    double alpha, {
    Map<int, double> fade = const {},
  }) {
    final visible = [
      for (final b in blocks)
        if (b.alive && !broken.contains(b.id)) b,
    ]..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
    for (final b in visible) {
      _block(
        canvas,
        g,
        b,
        yOf[b.id] ?? b.y.toDouble(),
        alpha * (fade[b.id] ?? 1),
      );
    }
  }

  /// A block as a cube: front, top and right faces.
  void _block(Canvas canvas, _Geo g, SlingBlock b, double y, double alpha) {
    if (alpha <= 0) return;
    final w = b.w * g.scale;
    final front = Rect.fromLTWH(g.sx(b.x), g.sy(y + b.h), w, w);
    final d = w * 0.24;
    final up = Offset(d, -d);
    final base = _base(b.kind);
    Color a(Color c) => c.withValues(alpha: alpha);

    canvas
      ..drawPath(
        Path()..addPolygon([
          front.topLeft,
          front.topLeft + up,
          front.topRight + up,
          front.topRight,
        ], true),
        Paint()..color = a(Color.lerp(base, Colors.white, 0.3)!),
      )
      ..drawPath(
        Path()..addPolygon([
          front.topRight,
          front.topRight + up,
          front.bottomRight + up,
          front.bottomRight,
        ], true),
        Paint()..color = a(Color.lerp(base, Colors.black, 0.3)!),
      )
      ..drawRect(
        front,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [a(Color.lerp(base, Colors.white, 0.12)!), a(base)],
          ).createShader(front),
      );

    final detail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, w * 0.04)
      ..color = a(Colors.black.withValues(alpha: 0.25));
    switch (b.kind) {
      case 'W': // grain
        for (final k in const [0.3, 0.55, 0.8]) {
          canvas.drawLine(
            front.topLeft + Offset(w * 0.1, w * k),
            front.topLeft + Offset(w * 0.9, w * (k - 0.06)),
            detail,
          );
        }
      case 'S': // speckles
        for (var k = 0; k < 5; k++) {
          canvas.drawCircle(
            front.topLeft +
                Offset(
                  w * (0.2 + (k * 37 % 60) / 100),
                  w * (0.2 + (k * 53 % 60) / 100),
                ),
            w * 0.05,
            Paint()..color = a(Colors.black.withValues(alpha: 0.2)),
          );
        }
      default: // a grumpy gift box
        final ribbon = Paint()..color = a(const Color(0xFFE53935));
        canvas
          ..drawRect(
            Rect.fromCenter(center: front.center, width: w * 0.16, height: w),
            ribbon,
          )
          ..drawRect(
            Rect.fromLTWH(front.left, front.top + w * 0.12, w, w * 0.12),
            ribbon,
          );
        for (final s in const [-1.0, 1.0]) {
          final eye = front.center + Offset(s * w * 0.2, w * 0.1);
          canvas
            ..drawCircle(eye, w * 0.1, Paint()..color = a(Colors.white))
            ..drawCircle(
              eye + Offset(0, w * 0.02),
              w * 0.05,
              Paint()..color = a(Colors.black),
            )
            ..drawLine(
              eye + Offset(-s * w * 0.1, -w * 0.16),
              eye + Offset(s * w * 0.1, -w * 0.1),
              Paint()
                ..color = a(Colors.black)
                ..strokeWidth = math.max(1.2, w * 0.06),
            );
        }
    }
  }

  void _label(Canvas canvas, Offset at, String text, double alpha) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(
            0xFFFFE066,
          ).withValues(alpha: alpha.clamp(0.0, 1.0)),
          fontSize: 16,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  void _banner(Canvas canvas, Size size, String title, String sub, double k) {
    final alpha = k < 0.8 ? 1.0 : (1 - k) / 0.2;
    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$title\n',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          TextSpan(
            text: sub,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
        style: TextStyle(
          color: Colors.white.withValues(alpha: alpha),
          shadows: const [Shadow(color: Colors.black87, blurRadius: 10)],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    tp.paint(
      canvas,
      Offset(size.width / 2 - tp.width / 2, size.height * 0.28 - 20 * k),
    );
  }

  @override
  bool shouldRepaint(_SlingPainter oldDelegate) => true;
}
