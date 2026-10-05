import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Illustrated art for each game, drawn rather than shipped as images.
///
/// Material icons said "puzzle" and "sports" but never said *which* game, and
/// a flat glyph sits dead on a tile that is otherwise gradient and motion.
/// These are vector illustrations in the style of a sticker decal: a dropped
/// shadow for depth, a bold white body, accent details, and the motion arcs
/// that make a still frame read as movement.
///
/// Drawn instead of bundled so one painter serves the 52px tile badge, the
/// 130px watermark behind it and anything else, with no asset weight, no
/// licensing, and colours that follow the palette rather than fighting it.
class GameArt extends StatelessWidget {
  const GameArt({
    super.key,
    required this.slug,
    this.size = 52,
    this.accent,
    this.opacity = 1,
  });

  final String slug;
  final double size;

  /// Highlight colour for the game's own details. Defaults to a warm amber,
  /// which is what reads on every gradient the tiles use.
  final Color? accent;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GameArtPainter(
          slug: slug,
          accent: accent ?? const Color(0xFFFFC24B),
          opacity: opacity,
        ),
      ),
    );
  }
}

class _GameArtPainter extends CustomPainter {
  _GameArtPainter({
    required this.slug,
    required this.accent,
    required this.opacity,
  });

  final String slug;
  final Color accent;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    // Every illustration is drawn on a 100×100 grid and scaled, so one set of
    // coordinates serves any tile size.
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final ink = const Color(0xFF0C1733).withValues(alpha: 0.45 * opacity);
    final body = Colors.white.withValues(alpha: opacity);
    final tint = accent.withValues(alpha: opacity);

    switch (slug) {
      case '2048':
        _paint2048(canvas, ink, body, tint);
      case 'snake':
        _paintSnake(canvas, ink, body, tint);
      case 'basketball':
        _paintBasketball(canvas, ink, body, tint);
      case 'stack-tower':
        _paintStackTower(canvas, ink, body, tint);
      case 'archery':
        _paintArchery(canvas, ink, body, tint);
      case 'cricket':
        _paintCricket(canvas, ink, body, tint);
      case 'block-blast':
        _paintBlockBlast(canvas, ink, body, tint);
      case 'sling-shot':
        _paintSlingShot(canvas, ink, body, tint);
      case 'hill-rider':
        _paintHillRider(canvas, ink, body, tint);
      case 'slide-puzzle':
        _paintSlidePuzzle(canvas, ink, body, tint);
      case 'memory-match':
        _paintMemory(canvas, ink, body, tint);
      case 'whack-a-mole':
        _paintWhack(canvas, ink, body, tint);
      case 'bubble-shooter':
        _paintBubble(canvas, ink, body, tint);
      case 'tower-blocks':
        _paintTowerBlocks(canvas, ink, body, tint);
      case 'fruit-slice':
        _paintFruit(canvas, ink, body, tint);
      case 'doodle-jump':
        _paintDoodle(canvas, ink, body, tint);
      default:
        _paintFallback(canvas, ink, body, tint);
    }
    canvas.restore();
  }

  // ── shared pieces ───────────────────────────────────────────────────────

  /// The sweeping speed lines behind a moving subject, as in a sports decal.
  /// [from] and [sweep] are radians; each arc sits a little further out.
  void _arcs(
    Canvas canvas, {
    required Offset centre,
    required double radius,
    required double from,
    required double sweep,
    required Color color,
    int count = 3,
    double gap = 7,
    double width = 3,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = color
      ..strokeWidth = width;
    for (var i = 0; i < count; i++) {
      final r = radius + i * gap;
      // Outer arcs are shorter, so the group reads as a fan rather than a ring.
      final shrink = i * 0.12;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: r),
        from + shrink,
        sweep - shrink * 2,
        false,
        paint,
      );
    }
  }

  /// A filled shape with a shadow copy beneath it. The whole 3D trick.
  void _solid(Canvas canvas, Path path, Color ink, Color fill) {
    canvas.save();
    canvas.translate(2.5, 3);
    canvas.drawPath(path, Paint()..color = ink);
    canvas.restore();
    canvas.drawPath(path, Paint()..color = fill);
  }

  void _solidRRect(Canvas canvas, RRect rrect, Color ink, Color fill) {
    canvas.drawRRect(rrect.shift(const Offset(2.5, 3)), Paint()..color = ink);
    canvas.drawRRect(rrect, Paint()..color = fill);
  }

  void _solidCircle(
    Canvas canvas,
    Offset centre,
    double radius,
    Color ink,
    Color fill,
  ) {
    canvas.drawCircle(centre + const Offset(2.5, 3), radius, Paint()..color = ink);
    canvas.drawCircle(centre, radius, Paint()..color = fill);
  }

  // ── per-game illustrations ──────────────────────────────────────────────

  /// Three tiles stacked back into the picture, the top one carrying the
  /// number everyone is chasing.
  void _paint2048(Canvas canvas, Color ink, Color body, Color tint) {
    _solidRRect(
      canvas,
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(16, 40, 40, 40),
        const Radius.circular(9),
      ),
      ink,
      body.withValues(alpha: body.a * 0.55),
    );
    _solidRRect(
      canvas,
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(30, 28, 44, 44),
        const Radius.circular(10),
      ),
      ink,
      tint,
    );
    _solidRRect(
      canvas,
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, 14, 48, 48),
        const Radius.circular(11),
      ),
      ink,
      body,
    );
    _text(canvas, '2048', const Offset(48, 38), 15, const Color(0xFF16233F));
  }

  /// A coiled body with a clear head, so it reads as a snake and not a line.
  void _paintSnake(Canvas canvas, Color ink, Color body, Color tint) {
    final path = Path()
      ..moveTo(18, 74)
      ..cubicTo(18, 50, 46, 56, 46, 40)
      ..cubicTo(46, 26, 26, 28, 26, 42)
      ..cubicTo(26, 54, 52, 50, 62, 34);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(2.5, 3);
    canvas.drawPath(path, stroke..color = ink);
    canvas.restore();
    canvas.drawPath(path, stroke..color = body);

    _solidCircle(canvas, const Offset(68, 28), 11, ink, tint);
    // Eye, pointing the way it is travelling.
    canvas.drawCircle(const Offset(72, 25), 2.6, Paint()..color = const Color(0xFF16233F));
    // The gift it is chasing.
    _solidRRect(
      canvas,
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(74, 62, 16, 16),
        const Radius.circular(4),
      ),
      ink,
      tint,
    );
  }

  /// Ball dropping through the ring, with the arc it came in on.
  void _paintBasketball(Canvas canvas, Color ink, Color body, Color tint) {
    _arcs(
      canvas,
      centre: const Offset(40, 44),
      radius: 30,
      from: math.pi * 1.05,
      sweep: math.pi * 0.62,
      color: tint.withValues(alpha: tint.a * 0.75),
    );
    // Backboard and ring.
    _solidRRect(
      canvas,
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(58, 10, 30, 24),
        const Radius.circular(4),
      ),
      ink,
      body.withValues(alpha: body.a * 0.5),
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = tint;
    canvas.drawLine(const Offset(56, 36), const Offset(84, 36), ring);

    _solidCircle(canvas, const Offset(40, 56), 21, ink, body);
    // Seams.
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..color = const Color(0xFF16233F);
    canvas.drawLine(const Offset(19, 56), const Offset(61, 56), seam);
    canvas.drawArc(
      const Rect.fromLTWH(19, 35, 42, 42),
      math.pi * 0.5,
      math.pi,
      false,
      seam,
    );
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(40, 56), radius: 21),
      -math.pi * 0.5,
      math.pi,
      false,
      seam,
    );
  }

  /// Slabs landing one on another, drawn isometric so the stack has depth.
  void _paintStackTower(Canvas canvas, Color ink, Color body, Color tint) {
    void slab(double cx, double cy, double w, Color fill) {
      final h = w * 0.34;
      final path = Path()
        ..moveTo(cx, cy - h / 2)
        ..lineTo(cx + w / 2, cy)
        ..lineTo(cx, cy + h / 2)
        ..lineTo(cx - w / 2, cy)
        ..close();
      _solid(canvas, path, ink, fill);
    }

    slab(50, 78, 56, body.withValues(alpha: body.a * 0.5));
    slab(50, 64, 50, body.withValues(alpha: body.a * 0.72));
    slab(50, 50, 44, body);
    slab(52, 34, 38, tint);
    // The next slab, still falling.
    slab(46, 15, 30, body.withValues(alpha: body.a * 0.45));
  }

  /// Target rings with an arrow buried dead centre.
  void _paintArchery(Canvas canvas, Color ink, Color body, Color tint) {
    _solidCircle(canvas, const Offset(46, 52), 30, ink, body);
    canvas.drawCircle(const Offset(46, 52), 22, Paint()..color = tint);
    canvas.drawCircle(const Offset(46, 52), 13, Paint()..color = body);
    canvas.drawCircle(
      const Offset(46, 52),
      5.5,
      Paint()..color = const Color(0xFFE23B3B),
    );

    // Shaft coming in from the top right.
    final shaft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      const Offset(50, 48),
      const Offset(92, 16),
      shaft..color = ink,
    );
    canvas.drawLine(
      const Offset(48, 50),
      const Offset(90, 18),
      shaft..color = body,
    );
    // Fletching.
    final feather = Path()
      ..moveTo(90, 18)
      ..lineTo(97, 8)
      ..lineTo(84, 13)
      ..close();
    _solid(canvas, feather, ink, tint);
  }

  /// The reference pose: a batsman mid-drive, wrapped in motion arcs.
  void _paintCricket(Canvas canvas, Color ink, Color body, Color tint) {
    // Arcs first, so the figure sits in front of them.
    _arcs(
      canvas,
      centre: const Offset(50, 52),
      radius: 34,
      from: math.pi * 0.82,
      sweep: math.pi * 0.7,
      color: body.withValues(alpha: body.a * 0.45),
      count: 3,
      gap: 6,
      width: 3.4,
    );
    _arcs(
      canvas,
      centre: const Offset(50, 52),
      radius: 34,
      from: -math.pi * 0.38,
      sweep: math.pi * 0.66,
      color: tint.withValues(alpha: tint.a * 0.9),
      count: 3,
      gap: 6,
      width: 3.4,
    );

    // Bat, swung through the shot.
    final bat = Path()
      ..moveTo(60, 14)
      ..lineTo(78, 24)
      ..lineTo(64, 46)
      ..lineTo(48, 36)
      ..close();
    _solid(canvas, bat, ink, tint);
    final handle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = body;
    canvas.drawLine(const Offset(48, 36), const Offset(38, 50), handle);

    // Helmet, torso and front leg. Simplified to stay legible small.
    _solidCircle(canvas, const Offset(40, 42), 11, ink, body);
    final torso = Path()
      ..moveTo(36, 52)
      ..lineTo(50, 56)
      ..lineTo(46, 76)
      ..lineTo(30, 72)
      ..close();
    _solid(canvas, torso, ink, body);
    final pad = Path()
      ..moveTo(30, 72)
      ..lineTo(46, 76)
      ..lineTo(42, 92)
      ..lineTo(24, 88)
      ..close();
    _solid(canvas, pad, ink, tint);
  }

  /// Interlocking blocks with one line flashing as it clears.
  void _paintBlockBlast(Canvas canvas, Color ink, Color body, Color tint) {
    void cube(double x, double y, Color fill) {
      _solidRRect(
        canvas,
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 20, 20),
          const Radius.circular(5),
        ),
        ink,
        fill,
      );
    }

    cube(14, 16, body.withValues(alpha: body.a * 0.55));
    cube(38, 16, body.withValues(alpha: body.a * 0.55));
    cube(14, 40, body);
    cube(38, 40, tint);
    cube(62, 40, body);
    cube(38, 64, body.withValues(alpha: body.a * 0.72));
    // The clearing line.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 46, 84, 8),
        const Radius.circular(4),
      ),
      Paint()..color = tint.withValues(alpha: tint.a * 0.55),
    );
  }

  /// Drawn-back sling with the shot's trajectory behind it.
  void _paintSlingShot(Canvas canvas, Color ink, Color body, Color tint) {
    // Flight path.
    final flight = Path()
      ..moveTo(34, 52)
      ..quadraticBezierTo(62, 8, 92, 30);
    canvas.drawPath(
      flight,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = tint.withValues(alpha: tint.a * 0.75),
    );

    // Y frame.
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final y = Path()
      ..moveTo(30, 88)
      ..lineTo(30, 58)
      ..moveTo(30, 58)
      ..lineTo(16, 38)
      ..moveTo(30, 58)
      ..lineTo(46, 38);
    canvas.save();
    canvas.translate(2.5, 3);
    canvas.drawPath(y, frame..color = ink);
    canvas.restore();
    canvas.drawPath(y, frame..color = body);

    // Band pulled back to the pouch.
    final band = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = body.withValues(alpha: body.a * 0.8);
    canvas.drawLine(const Offset(16, 38), const Offset(38, 54), band);
    canvas.drawLine(const Offset(46, 38), const Offset(38, 54), band);

    _solidCircle(canvas, const Offset(36, 55), 8, ink, tint);
    _solidCircle(canvas, const Offset(92, 30), 6, ink, body);
  }

  /// Car cresting a hill, wheels off the ground.
  void _paintHillRider(Canvas canvas, Color ink, Color body, Color tint) {
    // Terrain.
    final hill = Path()
      ..moveTo(0, 82)
      ..quadraticBezierTo(24, 52, 50, 66)
      ..quadraticBezierTo(76, 80, 100, 50)
      ..lineTo(100, 100)
      ..lineTo(0, 100)
      ..close();
    canvas.drawPath(hill, Paint()..color = ink);
    canvas.drawPath(
      hill.shift(const Offset(0, -3)),
      Paint()..color = body.withValues(alpha: body.a * 0.35),
    );

    // Body, tilted into the climb.
    canvas.save();
    canvas.translate(50, 44);
    canvas.rotate(-0.28);
    final shell = Path()
      ..moveTo(-24, 6)
      ..lineTo(-16, -8)
      ..lineTo(8, -8)
      ..lineTo(18, 4)
      ..lineTo(24, 6)
      ..lineTo(24, 14)
      ..lineTo(-24, 14)
      ..close();
    _solid(canvas, shell, ink, tint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-12, -5, 16, 10),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF16233F),
    );
    _solidCircle(canvas, const Offset(-14, 16), 9, ink, body);
    _solidCircle(canvas, const Offset(14, 16), 9, ink, body);
    canvas.restore();
  }

  /// A grid mid-slide, with the gap that makes the puzzle work.
  void _paintSlidePuzzle(Canvas canvas, Color ink, Color body, Color tint) {
    const cell = 24.0;
    const origin = 14.0;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        // Bottom-right stays empty: the slot everything slides into.
        if (row == 2 && col == 2) continue;
        final sliding = row == 2 && col == 1;
        _solidRRect(
          canvas,
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              origin + col * cell + (sliding ? 7 : 0),
              origin + row * cell,
              cell - 5,
              cell - 5,
            ),
            const Radius.circular(5),
          ),
          ink,
          sliding ? tint : body.withValues(alpha: body.a * (0.62 + row * 0.12)),
        );
      }
    }
    // Arrow showing which way it moves.
    final arrow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = tint;
    canvas.drawLine(const Offset(72, 74), const Offset(84, 74), arrow);
    canvas.drawLine(const Offset(79, 69), const Offset(84, 74), arrow);
    canvas.drawLine(const Offset(79, 79), const Offset(84, 74), arrow);
  }


  /// Two cards mid-flip: one face down, one turning to reveal its match.
  void _paintMemory(Canvas canvas, Color ink, Color body, Color tint) {
    // Face-down card, tilted back.
    canvas.save();
    canvas.translate(32, 52);
    canvas.rotate(-0.16);
    _solidRRect(
      canvas,
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-19, -26, 38, 52),
        const Radius.circular(7),
      ),
      ink,
      body.withValues(alpha: body.a * 0.55),
    );
    // Back pattern.
    for (var i = -1; i <= 1; i++) {
      canvas.drawCircle(
        Offset(0, i * 13),
        3.4,
        Paint()..color = const Color(0xFF16233F).withValues(alpha: 0.35),
      );
    }
    canvas.restore();

    // Face-up card carrying the gift it matches.
    canvas.save();
    canvas.translate(64, 48);
    canvas.rotate(0.13);
    _solidRRect(
      canvas,
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-20, -28, 40, 56),
        const Radius.circular(7),
      ),
      ink,
      body,
    );
    _solidRRect(
      canvas,
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-11, -11, 22, 22),
        const Radius.circular(4),
      ),
      const Color(0x00000000),
      tint,
    );
    // Ribbon across the gift.
    canvas.drawLine(
      const Offset(0, -11),
      const Offset(0, 11),
      Paint()
        ..color = const Color(0xFF16233F)
        ..strokeWidth = 3,
    );
    canvas.restore();
  }

  /// A mallet coming down on a mole that is still up.
  void _paintWhack(Canvas canvas, Color ink, Color body, Color tint) {
    // Hole the mole is standing in.
    canvas.drawOval(
      const Rect.fromLTWH(20, 62, 56, 22),
      Paint()..color = ink,
    );
    // Mole: head, snout and ears.
    _solidCircle(canvas, const Offset(48, 56), 18, ink, body);
    canvas.drawCircle(const Offset(41, 53), 2.8, Paint()..color = const Color(0xFF16233F));
    canvas.drawCircle(const Offset(55, 53), 2.8, Paint()..color = const Color(0xFF16233F));
    canvas.drawOval(
      const Rect.fromLTWH(41, 58, 14, 9),
      Paint()..color = tint,
    );

    // Mallet, swung in from the top right.
    canvas.save();
    canvas.translate(74, 26);
    canvas.rotate(0.6);
    _solidRRect(
      canvas,
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-13, -12, 26, 20),
        const Radius.circular(5),
      ),
      ink,
      tint,
    );
    final handle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = body;
    canvas.drawLine(const Offset(0, 8), const Offset(0, 34), handle);
    canvas.restore();

    // Impact marks.
    _arcs(
      canvas,
      centre: const Offset(58, 40),
      radius: 14,
      from: -math.pi * 0.9,
      sweep: math.pi * 0.5,
      color: tint.withValues(alpha: tint.a * 0.8),
      count: 2,
      gap: 5,
      width: 2.6,
    );
  }

  /// A bubble fired up into a wall of its own colour.
  void _paintBubble(Canvas canvas, Color ink, Color body, Color tint) {
    // The wall overhead.
    for (var col = 0; col < 4; col++) {
      for (var row = 0; row < 2; row++) {
        final fill = (col + row) % 3 == 0 ? tint : body.withValues(alpha: body.a * 0.6);
        _solidCircle(
          canvas,
          Offset(20 + col * 20 + (row.isOdd ? 10 : 0), 20 + row * 19),
          9.5,
          ink,
          fill,
        );
      }
    }
    // Flight path of the shot.
    canvas.drawPath(
      Path()
        ..moveTo(46, 88)
        ..quadraticBezierTo(46, 70, 50, 58),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = tint.withValues(alpha: tint.a * 0.6),
    );
    // The shot itself, with a highlight so it reads as a sphere.
    _solidCircle(canvas, const Offset(48, 72), 12, ink, tint);
    canvas.drawCircle(
      const Offset(44, 68),
      3.4,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  /// A slab dropping into a well where a row is about to clear.
  void _paintTowerBlocks(Canvas canvas, Color ink, Color body, Color tint) {
    // Well walls.
    final wall = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = body.withValues(alpha: body.a * 0.45);
    canvas.drawLine(const Offset(18, 26), const Offset(18, 88), wall);
    canvas.drawLine(const Offset(82, 26), const Offset(82, 88), wall);

    void cell(double x, double y, Color fill) {
      _solidRRect(
        canvas,
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 15, 15),
          const Radius.circular(3.5),
        ),
        ink,
        fill,
      );
    }

    // The row that is full, and the uneven stack above it.
    for (var i = 0; i < 4; i++) {
      cell(22 + i * 16, 70, tint);
    }
    cell(22, 54, body.withValues(alpha: body.a * 0.7));
    cell(38, 54, body.withValues(alpha: body.a * 0.7));
    cell(70, 54, body.withValues(alpha: body.a * 0.7));

    // The slab still falling.
    cell(38, 20, body);
    cell(54, 20, body);
  }

  /// A blade through a halved gift, with the cut arc behind it.
  void _paintFruit(Canvas canvas, Color ink, Color body, Color tint) {
    _arcs(
      canvas,
      centre: const Offset(50, 56),
      radius: 30,
      from: math.pi * 1.1,
      sweep: math.pi * 0.55,
      color: body.withValues(alpha: body.a * 0.4),
      count: 2,
      gap: 7,
      width: 3,
    );

    // Two halves falling apart from the cut.
    final left = Path()
      ..moveTo(44, 40)
      ..arcToPoint(const Offset(30, 74), radius: const Radius.circular(20), clockwise: false)
      ..lineTo(44, 62)
      ..close();
    _solid(canvas, left, ink, tint);
    final right = Path()
      ..moveTo(54, 42)
      ..arcToPoint(const Offset(70, 76), radius: const Radius.circular(20))
      ..lineTo(56, 64)
      ..close();
    _solid(canvas, right, ink, tint);

    // The blade sweeping through.
    final blade = Path()
      ..moveTo(16, 74)
      ..lineTo(88, 24)
      ..lineTo(92, 32)
      ..lineTo(20, 82)
      ..close();
    _solid(canvas, blade, ink, body);
  }

  /// A figure mid-hop between two ledges.
  void _paintDoodle(Canvas canvas, Color ink, Color body, Color tint) {
    void ledge(double x, double y, double w, Color fill) {
      _solidRRect(
        canvas,
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, 9),
          const Radius.circular(4.5),
        ),
        ink,
        fill,
      );
    }

    ledge(14, 78, 34, body.withValues(alpha: body.a * 0.55));
    ledge(52, 54, 34, tint);
    ledge(20, 28, 30, body.withValues(alpha: body.a * 0.4));

    // Arc of the hop.
    canvas.drawPath(
      Path()
        ..moveTo(32, 74)
        ..quadraticBezierTo(46, 36, 66, 50),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = tint.withValues(alpha: tint.a * 0.7),
    );

    // The jumper, legs tucked.
    _solidCircle(canvas, const Offset(56, 38), 11, ink, body);
    canvas.drawCircle(const Offset(60, 35), 2.6, Paint()..color = const Color(0xFF16233F));
    final legs = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..color = body;
    canvas.drawLine(const Offset(52, 47), const Offset(48, 54), legs);
    canvas.drawLine(const Offset(60, 47), const Offset(62, 55), legs);
  }

  /// Anything the server offers that this build has no drawing for.
  void _paintFallback(Canvas canvas, Color ink, Color body, Color tint) {
    _solidRRect(
      canvas,
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(16, 26, 68, 48),
        const Radius.circular(14),
      ),
      ink,
      body,
    );
    canvas.drawCircle(const Offset(36, 50), 7, Paint()..color = tint);
    canvas.drawCircle(const Offset(64, 44), 5, Paint()..color = const Color(0xFF16233F));
    canvas.drawCircle(const Offset(72, 56), 5, Paint()..color = const Color(0xFF16233F));
  }

  void _text(Canvas canvas, String value, Offset centre, double size, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_GameArtPainter old) =>
      old.slug != slug || old.accent != accent || old.opacity != opacity;
}
