import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A picture for the slide puzzle to be cut into tiles.
///
/// Painted rather than photographed: a vector picture is sharp at any tile
/// size, weighs nothing in the bundle, and each one is drawn to fill its
/// square edge to edge so no tile comes out blank. A blank tile in a picture
/// puzzle is a tile you cannot place.
class PuzzlePicture {
  const PuzzlePicture({
    required this.name,
    required this.colors,
    required this.paint,
  });

  /// Shown on the chooser.
  final String name;

  /// The two corners of the backdrop, also used for the chooser's swatch.
  final List<Color> colors;

  /// Draws the whole picture into a square of [size].
  final void Function(Canvas canvas, double size) paint;
}

/// The pictures on offer before a round starts.
const puzzlePictures = <PuzzlePicture>[
  PuzzlePicture(
    name: 'Birthday',
    colors: [Color(0xFF7C3AED), Color(0xFFF472B6)],
    paint: _paintBirthday,
  ),
  PuzzlePicture(
    name: 'Seaside',
    colors: [Color(0xFF0EA5E9), Color(0xFFFDE68A)],
    paint: _paintSeaside,
  ),
  PuzzlePicture(
    name: 'Bouquet',
    colors: [Color(0xFF059669), Color(0xFFFCA5A5)],
    paint: _paintBouquet,
  ),
  PuzzlePicture(
    name: 'Night sky',
    colors: [Color(0xFF1E1B4B), Color(0xFF7C3AED)],
    paint: _paintNightSky,
  ),
];

/// Fills the square with a top-to-bottom wash, so every tile has something on
/// it even where the subject does not reach.
void _backdrop(Canvas canvas, double s, List<Color> colors) {
  final rect = Rect.fromLTWH(0, 0, s, s);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(rect),
  );
}

void _paintBirthday(Canvas canvas, double s) {
  _backdrop(canvas, s, const [Color(0xFF4C1D95), Color(0xFFF9A8D4)]);
  final u = s / 100;

  // Bunting across the top, which gives the upper row corners something.
  final string = Paint()
    ..color = Colors.white.withValues(alpha: 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = u * 0.8;
  final line = Path()..moveTo(0, u * 10);
  line.quadraticBezierTo(s / 2, u * 22, s, u * 8);
  canvas.drawPath(line, string);
  const flags = [
    Color(0xFFFDE047),
    Color(0xFF34D399),
    Color(0xFFFB7185),
    Color(0xFF60A5FA),
    Color(0xFFFDE047),
    Color(0xFF34D399),
  ];
  for (var i = 0; i < flags.length; i++) {
    final t = (i + 0.5) / flags.length;
    final x = t * s;
    final y = u * 10 + math.sin(t * math.pi) * u * 11;
    canvas.drawPath(
      Path()
        ..moveTo(x - u * 5, y)
        ..lineTo(x + u * 5, y)
        ..lineTo(x, y + u * 11)
        ..close(),
      Paint()..color = flags[i],
    );
  }

  // The cake: three tiers, so the middle rows differ from one another.
  final tiers = [
    (Rect.fromLTWH(u * 22, u * 62, u * 56, u * 20), const Color(0xFFFFF1F2)),
    (Rect.fromLTWH(u * 28, u * 46, u * 44, u * 18), const Color(0xFFFECDD3)),
    (Rect.fromLTWH(u * 34, u * 32, u * 32, u * 16), const Color(0xFFFFF1F2)),
  ];
  for (final (rect, color) in tiers) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(u * 3)),
      Paint()..color = color,
    );
    // Icing drips along the top edge of each tier.
    final icing = Paint()..color = const Color(0xFFF43F5E);
    for (var x = rect.left + u * 3; x < rect.right - u * 2; x += u * 7) {
      canvas.drawCircle(Offset(x, rect.top + u * 1.5), u * 2.6, icing);
    }
  }

  // Candles, tall enough to cross a tile boundary.
  for (var i = 0; i < 3; i++) {
    final x = s / 2 + (i - 1) * u * 10;
    canvas.drawRect(
      Rect.fromLTWH(x - u * 1.6, u * 20, u * 3.2, u * 12),
      Paint()..color = const Color(0xFF38BDF8),
    );
    canvas.drawCircle(
      Offset(x, u * 18),
      u * 3,
      Paint()..color = const Color(0xFFFDE047),
    );
  }

  // A plate, anchoring the bottom row.
  canvas.drawOval(
    Rect.fromCenter(center: Offset(s / 2, u * 84), width: u * 76, height: u * 9),
    Paint()..color = Colors.white.withValues(alpha: 0.75),
  );
}

void _paintSeaside(Canvas canvas, double s) {
  _backdrop(canvas, s, const [Color(0xFF0369A1), Color(0xFF7DD3FC)]);
  final u = s / 100;

  canvas.drawCircle(
    Offset(u * 74, u * 20),
    u * 11,
    Paint()..color = const Color(0xFFFEF08A),
  );

  // Sea, then sand: two hard bands so rows read differently.
  canvas.drawRect(
    Rect.fromLTWH(0, u * 46, s, u * 22),
    Paint()..color = const Color(0xFF0284C7),
  );
  for (var i = 0; i < 4; i++) {
    final y = u * (50 + i * 5);
    final wave = Path()..moveTo(0, y);
    for (var x = 0.0; x <= s; x += u * 10) {
      wave.quadraticBezierTo(x + u * 2.5, y - u * 2, x + u * 5, y);
      wave.quadraticBezierTo(x + u * 7.5, y + u * 2, x + u * 10, y);
    }
    canvas.drawPath(
      wave,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.9,
    );
  }
  canvas.drawRect(
    Rect.fromLTWH(0, u * 68, s, s - u * 68),
    Paint()..color = const Color(0xFFFDE68A),
  );

  // A parasol, straddling the middle rows.
  canvas.drawRect(
    Rect.fromLTWH(u * 29, u * 44, u * 2.4, u * 34),
    Paint()..color = const Color(0xFF78350F),
  );
  for (var i = 0; i < 4; i++) {
    canvas.drawArc(
      Rect.fromCenter(center: Offset(u * 30, u * 46), width: u * 52, height: u * 34),
      math.pi + i * math.pi / 4,
      math.pi / 4,
      true,
      Paint()
        ..color = i.isEven ? const Color(0xFFEF4444) : const Color(0xFFFFF1F2),
    );
  }

  // Beach ball and shells on the sand.
  canvas.drawCircle(
    Offset(u * 66, u * 80),
    u * 9,
    Paint()..color = const Color(0xFFFFF1F2),
  );
  for (var i = 0; i < 3; i++) {
    canvas.drawArc(
      Rect.fromCircle(center: Offset(u * 66, u * 80), radius: u * 9),
      -math.pi / 2 + i * math.pi * 2 / 3,
      math.pi / 3,
      true,
      Paint()..color = const Color(0xFFF97316),
    );
  }
  for (final x in [12, 40, 88]) {
    canvas.drawCircle(
      Offset(u * x.toDouble(), u * 90),
      u * 3.4,
      Paint()..color = const Color(0xFFFFE4E6),
    );
  }
}

void _paintBouquet(Canvas canvas, double s) {
  _backdrop(canvas, s, const [Color(0xFF065F46), Color(0xFFD9F99D)]);
  final u = s / 100;

  // Stems fanning out from the wrap.
  final stem = Paint()
    ..color = const Color(0xFF166534)
    ..style = PaintingStyle.stroke
    ..strokeWidth = u * 2.2
    ..strokeCap = StrokeCap.round;
  const heads = [
    (Offset(26, 26), Color(0xFFFB7185)),
    (Offset(52, 16), Color(0xFFFDE047)),
    (Offset(76, 28), Color(0xFFF472B6)),
    (Offset(36, 44), Color(0xFFFFF1F2)),
    (Offset(66, 46), Color(0xFFC084FC)),
  ];
  for (final (at, _) in heads) {
    canvas.drawPath(
      Path()
        ..moveTo(s / 2, u * 74)
        ..quadraticBezierTo(s / 2, u * 60, at.dx * u, at.dy * u),
      stem,
    );
  }

  // Leaves, so the empty green has some shape in it.
  for (final side in [-1, 1]) {
    canvas.drawPath(
      Path()
        ..moveTo(s / 2, u * 66)
        ..quadraticBezierTo(
          s / 2 + side * u * 26,
          u * 52,
          s / 2 + side * u * 34,
          u * 62,
        )
        ..quadraticBezierTo(s / 2 + side * u * 20, u * 68, s / 2, u * 66),
      Paint()..color = const Color(0xFF15803D),
    );
  }

  // Blooms: a ring of petals round a centre.
  for (final (at, color) in heads) {
    final centre = Offset(at.dx * u, at.dy * u);
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      canvas.drawCircle(
        centre + Offset(math.cos(angle), math.sin(angle)) * u * 6,
        u * 5,
        Paint()..color = color,
      );
    }
    canvas.drawCircle(
      centre,
      u * 4.5,
      Paint()..color = const Color(0xFFFEF3C7),
    );
  }

  // The wrap, filling the bottom rows.
  canvas.drawPath(
    Path()
      ..moveTo(u * 32, u * 70)
      ..lineTo(u * 68, u * 70)
      ..lineTo(u * 60, s)
      ..lineTo(u * 40, s)
      ..close(),
    Paint()..color = const Color(0xFFFDE68A),
  );
  canvas.drawRect(
    Rect.fromLTWH(u * 30, u * 76, u * 40, u * 6),
    Paint()..color = const Color(0xFFDB2777),
  );
}

void _paintNightSky(Canvas canvas, double s) {
  _backdrop(canvas, s, const [Color(0xFF0F172A), Color(0xFF6D28D9)]);
  final u = s / 100;

  // Stars spread over the whole square, so no tile is a flat block.
  final star = Paint()..color = Colors.white;
  var seed = 7;
  for (var i = 0; i < 46; i++) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    final x = (seed >> 7) % 100 * u;
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    final y = (seed >> 7) % 72 * u;
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    final r = u * (0.6 + (seed >> 9) % 12 / 10);
    canvas.drawCircle(Offset(x, y), r, star);
  }

  // A moon with a bite out of it, up in a corner.
  canvas.drawCircle(
    Offset(u * 72, u * 24),
    u * 15,
    Paint()..color = const Color(0xFFFEF9C3),
  );
  canvas.drawCircle(
    Offset(u * 65, u * 19),
    u * 13,
    Paint()..color = const Color(0xFF231C4B),
  );

  // Hills across the foot.
  for (final (dx, h, color) in [
    (-10.0, 26.0, const Color(0xFF312E81)),
    (40.0, 32.0, const Color(0xFF4C1D95)),
    (85.0, 22.0, const Color(0xFF3730A3)),
  ]) {
    canvas.drawPath(
      Path()
        ..moveTo(u * (dx - 30), s)
        ..quadraticBezierTo(u * dx, s - u * h, u * (dx + 30), s)
        ..close(),
      Paint()..color = color,
    );
  }

  // A gift left on the hillside, the one warm thing in the picture.
  final box = Rect.fromLTWH(u * 14, u * 78, u * 22, u * 18);
  canvas.drawRRect(
    RRect.fromRectAndRadius(box, Radius.circular(u * 2)),
    Paint()..color = const Color(0xFFF43F5E),
  );
  canvas.drawRect(
    Rect.fromLTWH(box.center.dx - u * 2, box.top, u * 4, box.height),
    Paint()..color = const Color(0xFFFDE047),
  );
  canvas.drawRect(
    Rect.fromLTWH(box.left, box.top + u * 6, box.width, u * 4),
    Paint()..color = const Color(0xFFFDE047),
  );
}
