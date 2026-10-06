import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The living background behind every game: a gradient with soft light blobs
/// drifting across it and a few twinkling sparkles.
///
/// Honours the system "reduce motion" setting by holding still.
class GameBackdrop extends StatefulWidget {
  const GameBackdrop({required this.colors, super.key});

  final List<Color> colors;

  @override
  State<GameBackdrop> createState() => _GameBackdropState();
}

class _GameBackdropState extends State<GameBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BackdropPainter(colors: widget.colors, t: _controller),
        size: Size.infinite,
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.colors, required this.t}) : super(repaint: t);

  final List<Color> colors;
  final Animation<double> t;

  // Fixed sparkle layout. Decoration only, nothing to do with gameplay.
  static final List<Offset> _sparkles = List.generate(18, (i) {
    final a = math.sin(i * 12.9898) * 43758.5453;
    final b = math.sin(i * 78.233) * 12345.6789;
    return Offset(a - a.floorToDouble(), b - b.floorToDouble());
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..color = colors[colors.length > 1 ? 1 : 0],
    );

    final phase = t.value * 2 * math.pi;
    final shortest = size.shortestSide;

    for (var i = 0; i < 3; i++) {
      final offset = i * 2 * math.pi / 3;
      final center = Offset(
        size.width * (0.5 + 0.38 * math.sin(phase + offset)),
        size.height * (0.5 + 0.34 * math.cos(phase * 0.7 + offset)),
      );
      final radius = shortest * (0.55 + 0.12 * i);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.05),
      );
    }

    // A perspective floor grid rolling towards the player gives every game
    // a sense of depth.
    final horizon = size.height * 0.64;
    final vanishing = Offset(size.width / 2, horizon);
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 1;
    for (var i = -9; i <= 9; i++) {
      canvas.drawLine(
        vanishing,
        Offset(size.width / 2 + i * size.width * 0.2, size.height),
        grid,
      );
    }
    final roll = (t.value * 6) % 1;
    for (var k = 0; k < 10; k++) {
      final d = (k + roll) / 10;
      final y = horizon + (size.height - horizon) * d * d;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.1 * d)
          ..strokeWidth = 1,
      );
    }

    for (var i = 0; i < _sparkles.length; i++) {
      final p = _sparkles[i];
      final twinkle = (math.sin(phase * 3 + i * 1.7) + 1) / 2;
      canvas.drawCircle(
        Offset(p.dx * size.width, p.dy * size.height),
        1.2 + 1.8 * twinkle,
        Paint()..color = Colors.white.withValues(alpha: 0.15 + 0.45 * twinkle),
      );
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
