import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Something to drive over the hills.
///
/// Purely what the player looks at: the physics, the fuel and the scoring all
/// come from the engine and are the same whichever one is picked. A vehicle
/// only decides how the thing on screen is drawn and where its wheels sit.
class HillVehicle {
  const HillVehicle({
    required this.name,
    required this.colors,
    required this.wheelRadius,
    required this.axle,
    required this.wheelY,
    required this.paintBody,
  });

  final String name;

  /// Body colours, light to dark. The chooser takes its glow from the last.
  final List<Color> colors;

  /// In the same units the body is drawn in.
  final double wheelRadius;

  /// How far each wheel sits from the middle.
  final double axle;

  /// How far below the body's baseline the axles run.
  final double wheelY;

  /// Draws the body around the origin, wheels excluded. [s] scales the whole
  /// thing; [squash] is how hard the suspension is loaded, 0 to 1.
  final void Function(Canvas canvas, double s, double squash) paintBody;
}

/// The vehicles on offer before a run.
const hillVehicles = <HillVehicle>[
  HillVehicle(
    name: 'Dune buggy',
    colors: [Color(0xFFFF8A65), Color(0xFFE64A19)],
    wheelRadius: 11,
    axle: 21,
    wheelY: -10,
    paintBody: _paintBuggy,
  ),
  HillVehicle(
    name: 'Monster truck',
    colors: [Color(0xFF81D4FA), Color(0xFF0277BD)],
    wheelRadius: 16,
    axle: 24,
    wheelY: -14,
    paintBody: _paintMonster,
  ),
  HillVehicle(
    name: 'Rally car',
    colors: [Color(0xFFCE93D8), Color(0xFF6A1B9A)],
    wheelRadius: 9,
    axle: 22,
    wheelY: -8,
    paintBody: _paintRally,
  ),
  HillVehicle(
    name: 'Gift van',
    colors: [Color(0xFFA5D6A7), Color(0xFF2E7D32)],
    wheelRadius: 10,
    axle: 20,
    wheelY: -9,
    paintBody: _paintVan,
  ),
];

/// A driver's head and shoulders, which every vehicle carries.
void _driver(Canvas canvas, double s, double x, double y, Color helmet) {
  canvas
    ..drawCircle(Offset(x * s, y * s), 7 * s, Paint()..color = helmet)
    ..drawRect(
      Rect.fromLTWH(x * s, (y - 2) * s, 7 * s, 3 * s),
      Paint()..color = const Color(0xFF263238),
    );
}

void _paintBuggy(Canvas canvas, double s, double squash) {
  // The body settles onto its springs under load.
  final drop = squash * 3 * s;
  final body = RRect.fromRectAndRadius(
    Rect.fromLTWH(-32 * s, -34 * s + drop, 64 * s, 18 * s),
    Radius.circular(7 * s),
  );
  canvas
    ..drawRRect(
      body.shift(Offset(0, 3 * s)),
      Paint()..color = const Color(0xFF8E1B00),
    )
    ..drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF8A65), Color(0xFFE64A19)],
        ).createShader(body.outerRect),
    )
    // Roll cage.
    ..drawPath(
      Path()
        ..moveTo(-12 * s, -34 * s + drop)
        ..lineTo(-6 * s, -52 * s + drop)
        ..lineTo(12 * s, -52 * s + drop)
        ..lineTo(16 * s, -34 * s + drop),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * s
        ..color = const Color(0xFF37474F),
    );
  _driver(canvas, s, 3, -42 + drop / s, const Color(0xFFFFD54F));
}

void _paintMonster(Canvas canvas, double s, double squash) {
  final drop = squash * 5 * s;
  // Sits high on its suspension, with the axles showing beneath.
  canvas.drawRect(
    Rect.fromLTWH(-24 * s, -30 * s + drop, 48 * s, 4 * s),
    Paint()..color = const Color(0xFF37474F),
  );
  final body = RRect.fromRectAndRadius(
    Rect.fromLTWH(-30 * s, -50 * s + drop, 60 * s, 22 * s),
    Radius.circular(6 * s),
  );
  canvas
    ..drawRRect(
      body.shift(Offset(0, 3 * s)),
      Paint()..color = const Color(0xFF01579B),
    )
    ..drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF81D4FA), Color(0xFF0277BD)],
        ).createShader(body.outerRect),
    )
    // A windscreen slanting back over the cab.
    ..drawPath(
      Path()
        ..moveTo(-2 * s, -50 * s + drop)
        ..lineTo(8 * s, -64 * s + drop)
        ..lineTo(24 * s, -64 * s + drop)
        ..lineTo(26 * s, -50 * s + drop)
        ..close(),
      Paint()..color = const Color(0xFF0288D1),
    )
    ..drawPath(
      Path()
        ..moveTo(0, -50 * s + drop)
        ..lineTo(9 * s, -62 * s + drop)
        ..lineTo(22 * s, -62 * s + drop)
        ..lineTo(23 * s, -50 * s + drop)
        ..close(),
      Paint()..color = const Color(0xFFB3E5FC).withValues(alpha: 0.85),
    );
  _driver(canvas, s, 8, -56 + drop / s, const Color(0xFFFF7043));
}

void _paintRally(Canvas canvas, double s, double squash) {
  final drop = squash * 2 * s;
  // Low and long: a wedge rather than a box.
  final shell = Path()
    ..moveTo(-34 * s, -22 * s + drop)
    ..lineTo(-28 * s, -34 * s + drop)
    ..lineTo(-4 * s, -40 * s + drop)
    ..lineTo(18 * s, -38 * s + drop)
    ..lineTo(34 * s, -24 * s + drop)
    ..lineTo(34 * s, -18 * s + drop)
    ..lineTo(-34 * s, -18 * s + drop)
    ..close();
  canvas
    ..drawPath(shell.shift(Offset(0, 3 * s)), Paint()..color = const Color(0xFF4A148C))
    ..drawPath(
      shell,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCE93D8), Color(0xFF6A1B9A)],
        ).createShader(shell.getBounds()),
    )
    // Glass along the top of the wedge.
    ..drawPath(
      Path()
        ..moveTo(-24 * s, -33 * s + drop)
        ..lineTo(-4 * s, -37 * s + drop)
        ..lineTo(14 * s, -36 * s + drop)
        ..lineTo(20 * s, -28 * s + drop)
        ..close(),
      Paint()..color = const Color(0xFFE1BEE7).withValues(alpha: 0.8),
    )
    // A rear wing, which is what makes it read as a rally car.
    ..drawRect(
      Rect.fromLTWH(-40 * s, -38 * s + drop, 14 * s, 3.5 * s),
      Paint()..color = const Color(0xFF4A148C),
    )
    ..drawRect(
      Rect.fromLTWH(-35 * s, -38 * s + drop, 3 * s, 8 * s),
      Paint()..color = const Color(0xFF4A148C),
    );
}

void _paintVan(Canvas canvas, double s, double squash) {
  final drop = squash * 3 * s;
  final body = RRect.fromRectAndRadius(
    Rect.fromLTWH(-32 * s, -52 * s + drop, 58 * s, 36 * s),
    Radius.circular(6 * s),
  );
  canvas
    ..drawRRect(
      body.shift(Offset(0, 3 * s)),
      Paint()..color = const Color(0xFF1B5E20),
    )
    ..drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA5D6A7), Color(0xFF2E7D32)],
        ).createShader(body.outerRect),
    )
    // A ribbon round the parcel it is carrying.
    ..drawRect(
      Rect.fromLTWH(-8 * s, -52 * s + drop, 7 * s, 36 * s),
      Paint()..color = const Color(0xFFFFE066),
    )
    // The cab, snubbed onto the front.
    ..drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(26 * s, -40 * s + drop, 14 * s, 24 * s),
        Radius.circular(4 * s),
      ),
      Paint()..color = const Color(0xFF66BB6A),
    )
    ..drawRect(
      Rect.fromLTWH(28 * s, -37 * s + drop, 10 * s, 9 * s),
      Paint()..color = const Color(0xFFE8F5E9).withValues(alpha: 0.85),
    );
}

/// Draws [vehicle] whole. Wheels and all. For the chooser's preview.
void paintHillVehiclePreview(Canvas canvas, Size size, HillVehicle vehicle) {
  // A strip of sky over a strip of ground, so the preview reads as a vehicle
  // standing somewhere rather than floating.
  final sky = Rect.fromLTWH(0, 0, size.width, size.height * 0.72);
  canvas
    ..drawRect(
      sky,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4FC3F7), Color(0xFFB3E5FC)],
        ).createShader(sky),
    )
    ..drawRect(
      Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.28),
      Paint()..color = const Color(0xFF7CB342),
    );

  // Scaled so the longest vehicle still fits the preview with room round it.
  final s = size.width / 110;
  canvas.save();
  canvas.translate(size.width / 2, size.height * 0.72);

  final wheel = Paint()..color = const Color(0xFF212121);
  final hub = Paint()..color = const Color(0xFFB0BEC5);
  for (final side in [-1.0, 1.0]) {
    final at = Offset(side * vehicle.axle * s, vehicle.wheelY * s);
    canvas
      ..drawCircle(at, vehicle.wheelRadius * s, wheel)
      ..drawCircle(at, vehicle.wheelRadius * 0.55 * s, hub);
  }
  vehicle.paintBody(canvas, s, 0);
  canvas.restore();
}

/// The chooser's swatch for a vehicle.
List<Color> hillVehicleColors(HillVehicle vehicle) => vehicle.colors;

/// A wheel with a spinning hub, shared by every vehicle.
void paintHillWheel(
  Canvas canvas,
  Offset at,
  double radius,
  double turn,
  double s,
) {
  canvas
    ..drawCircle(at, radius * s, Paint()..color = const Color(0xFF212121))
    ..drawCircle(at, radius * 0.55 * s, Paint()..color = const Color(0xFFB0BEC5));
  for (var k = 0; k < 4; k++) {
    final a = turn + k * math.pi / 2;
    canvas.drawLine(
      at,
      at + Offset(math.cos(a), math.sin(a)) * radius * 0.55 * s,
      Paint()
        ..color = const Color(0xFF546E7A)
        ..strokeWidth = 1.5 * s,
    );
  }
  // Tread blocks, so the tyre turns visibly rather than just its spokes.
  for (var k = 0; k < 8; k++) {
    final a = turn * 0.6 + k * math.pi / 4;
    canvas.drawCircle(
      at + Offset(math.cos(a), math.sin(a)) * radius * 0.82 * s,
      radius * 0.1 * s,
      Paint()..color = const Color(0xFF424242),
    );
  }
}
