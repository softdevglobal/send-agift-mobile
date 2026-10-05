import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/hill_rider.dart';
import '../game_controls.dart';
import 'game_chooser.dart';
import 'hill_vehicles.dart';
import 'tick_clock.dart';

/// Hill Rider, side on with parallax hills. Hold GAS to drive and BRAKE to
/// slow down before a crest.
class HillRiderBoard extends StatefulWidget {
  const HillRiderBoard({required this.game, required this.controls, super.key});

  final HillRider game;
  final GameControls controls;

  @override
  State<HillRiderBoard> createState() => _HillRiderBoardState();
}

class _HillRiderBoardState extends State<HillRiderBoard>
    with SingleTickerProviderStateMixin {
  late final TickClock _clock = TickClock(
    vsync: this,
    game: widget.game,
    onTicks: (_) {
      final g = widget.game;
      final fuel = g.fuel * 100 ~/ g.config.startFuel;
      if (g.distance != _lastDistance || fuel != _lastFuel || g.isOver) {
        _lastDistance = g.distance;
        _lastFuel = fuel;
        widget.controls.onChanged();
      }
    },
  );

  bool _started = false;

  /// Null until one is picked, which is what starts the run. It changes
  /// nothing about the drive. The hills, the fuel and the scoring are the
  /// engine's, and the same seed drives the same course whichever is chosen.
  HillVehicle? _vehicle;

  int _lastDistance = -1;
  int _lastFuel = -1;
  int _gas = 0;
  int _brake = 0;

  /// The camera eases after the car vertically rather than jumping.
  double _camY = 0;
  double? _crashedAt;

  HillRider get _game => widget.game;

  @override
  void initState() {
    super.initState();
    _clock.addListener(_onFrame);
  }

  @override
  void didUpdateWidget(covariant HillRiderBoard oldWidget) {
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
    _camY += (_game.y - _camY) * 0.12;
    if (_game.crashed && _crashedAt == null) _crashedAt = _clock.wallMs;
  }

  void _pedals() {
    final pedal = _gas > 0
        ? HillPedal.gas
        : (_brake > 0 ? HillPedal.brake : HillPedal.neutral);
    _game.setPedal(pedal);
    if (!_started && pedal != HillPedal.neutral && widget.controls.active) {
      _started = true;
      _sync();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _vehicle;
    if (vehicle == null) {
      // The scene runs edge to edge, so the chooser brings its own margin
      // rather than running the previews into the sides of the screen.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: GameChooser(
          title: 'Pick your ride',
          subtitle: 'Hold the gas over the hills. Every one handles the same.',
          previewAspect: 1.5,
          choices: [
            for (final option in hillVehicles)
              GameChoice(
                name: option.name,
                colors: option.colors,
                paint: (canvas, size) =>
                    paintHillVehiclePreview(canvas, size, option),
              ),
          ],
          onPick: (choice) => setState(() {
            _vehicle = hillVehicles.firstWhere((v) => v.name == choice.name);
          }),
        ),
      );
    }

    // The pedals sit over the road rather than on a strip beneath it. Given
    // their own row they took a fifth of the height off the scene, which on a
    // phone is the difference between driving down a hill and watching one
    // through a letterbox.
    return ClipRRect(
      // Square: the scene runs to the corners of the screen now, and a
      // rounded one would leave the backdrop showing through them.
      borderRadius: BorderRadius.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _HillPainter(
              game: _game,
              vehicle: vehicle,
              clock: _clock,
              camY: () => _camY,
              crashedAt: () => _crashedAt,
            ),
          ),
          AnimatedBuilder(
            animation: _clock,
            builder: (context, _) => _Gauges(game: _game),
          ),
          if (!_started)
            Align(
              alignment: const Alignment(0, -0.2),
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
                    'Hold GAS to start',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            left: 16,
            right: 16,
            // Clear of the hint line the play screen prints along the bottom.
            bottom: MediaQuery.paddingOf(context).bottom + 46,
            child: Row(
              children: [
                _Pedal(
                  key: const ValueKey('hill-brake'),
                  label: 'BRAKE',
                  colors: const [Color(0xFFFF8A80), Color(0xFFC62828)],
                  pressed: _brake > 0,
                  onDown: () {
                    _brake++;
                    _pedals();
                  },
                  onUp: () {
                    _brake = math.max(0, _brake - 1);
                    _pedals();
                  },
                ),
                const Spacer(),
                _Pedal(
                  key: const ValueKey('hill-gas'),
                  label: 'GAS',
                  colors: const [Color(0xFFB9F6CA), Color(0xFF2E7D32)],
                  pressed: _gas > 0,
                  wide: true,
                  onDown: () {
                    _gas++;
                    _pedals();
                  },
                  onUp: () {
                    _gas = math.max(0, _gas - 1);
                    _pedals();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A chunky 3D pedal. Press and hold. It tracks the finger, not taps.
class _Pedal extends StatelessWidget {
  const _Pedal({
    required this.label,
    required this.colors,
    required this.pressed,
    required this.onDown,
    required this.onUp,
    this.wide = false,
    super.key,
  });

  final String label;
  final List<Color> colors;
  final bool pressed;
  final bool wide;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    const depth = 7.0;
    return Listener(
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: SizedBox(
        width: wide ? 150 : 120,
        height: 78,
        child: Stack(
          children: [
            // The pedal's side, visible until it is pushed down.
            Positioned(
              left: 0,
              right: 0,
              top: depth,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.lerp(colors.last, Colors.black, 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 70),
              left: 0,
              right: 0,
              top: pressed ? depth : 0,
              bottom: pressed ? 0 : depth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: pressed ? [colors.last, colors.last] : colors,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
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

/// Fuel gauge and air time over the scene. Distance is already in the play
/// screen's stats, so it is not repeated here.
class _Gauges extends StatelessWidget {
  const _Gauges({required this.game});

  final HillRider game;

  @override
  Widget build(BuildContext context) {
    final fuel = game.fuel / game.config.startFuel;
    final fuelColor = Color.lerp(
      const Color(0xFFFF5252),
      const Color(0xFF69F0AE),
      fuel.clamp(0.0, 1.0),
    )!;
    return IgnorePointer(
      child: Stack(
        children: [
          // Just under the play screen's title and stats, which float over the
          // top of the scene; any higher and it sits beneath them.
          Positioned(
            top: MediaQuery.paddingOf(context).top + 146,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_gas_station_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 90,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fuel.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: fuelColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (game.airborne)
            const Align(
              alignment: Alignment(0, -0.6),
              child: Text(
                'AIR!',
                style: TextStyle(
                  color: Color(0xFFFFE066),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                ),
              ),
            ),
          if (game.crashed)
            Align(
              alignment: const Alignment(0, -0.4),
              // Slams in oversized and tilted, then settles with a wobble.
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, t, child) => Transform.rotate(
                  angle: (1 - t) * 0.35 - 0.06,
                  child: Transform.scale(scale: 0.4 + t * 0.6, child: child),
                ),
                child: const Text(
                  'CRASH!',
                  style: TextStyle(
                    color: Color(0xFFFF5252),
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(color: Color(0xFFFFD54F), offset: Offset(3, 3)),
                      Shadow(color: Colors.black87, blurRadius: 12),
                    ],
                  ),
                ),
              ),
            ),
          if (!game.crashed && game.fuel == 0)
            const Align(
              alignment: Alignment(0, -0.4),
              child: Text(
                'OUT OF FUEL',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HillPainter extends CustomPainter {
  _HillPainter({
    required this.game,
    required this.vehicle,
    required this.clock,
    required this.camY,
    required this.crashedAt,
  }) : super(repaint: clock);

  final HillRider game;
  final HillVehicle vehicle;
  final TickClock clock;
  final double Function() camY;
  final double? Function() crashedAt;

  @override
  void paint(Canvas canvas, Size size) {
    final crashed = crashedAt();
    final sinceCrash = crashed == null ? null : clock.wallMs - crashed;

    // The impact shakes the whole scene, dying away over half a second.
    canvas.save();
    if (sinceCrash != null && sinceCrash < 500) {
      final a = 12 * (1 - sinceCrash / 500);
      canvas.translate(
        math.sin(sinceCrash * 0.11) * a,
        math.cos(sinceCrash * 0.17) * a,
      );
    }
    _scene(canvas, size);
    canvas.restore();

    // And a white flash on the moment of impact.
    if (sinceCrash != null && sinceCrash < 160) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.6 * (1 - sinceCrash / 160),
          ),
      );
    }
  }

  void _scene(Canvas canvas, Size size) {
    final s = size.width / 520;
    final camX = game.x - 150;
    final cy = camY();
    final baseY = size.height * 0.6;
    double sx(double xu) => (xu - camX) * s;
    double sy(double yu) => baseY - (yu - cy) * s;

    _sky(canvas, size, camX);

    // Terrain, with a darker band below the grass lip for depth.
    final left = camX - 40;
    final right = camX + size.width / s + 40;
    final top = <Offset>[];
    for (var xu = left; xu <= right; xu += 8) {
      top.add(
        Offset(sx(xu), sy(game.heightAt(math.max(0, xu.round())).toDouble())),
      );
    }
    final ground = Path()
      ..addPolygon([
        ...top,
        Offset(sx(right), size.height),
        Offset(sx(left), size.height),
      ], true);
    canvas.drawPath(
      ground,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8D6E63), Color(0xFF4E342E)],
        ).createShader(Offset.zero & size),
    );
    canvas
      ..drawPath(
        Path()..addPolygon([for (final p in top) p + Offset(0, 10 * s)], false),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8 * s
          ..color = const Color(0xFF33691E),
      )
      ..drawPath(
        Path()..addPolygon(top, false),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9 * s
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF7CB342),
      );

    _markers(canvas, s, left, right, sx, sy);
    _cans(canvas, s, left, right, sx, sy);
    _car(canvas, s, sx, sy);
  }

  void _sky(Canvas canvas, Size size, double camX) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4FC3F7), Color(0xFFE1F5FE)],
        ).createShader(rect),
    );
    final sun = Offset(size.width * 0.8, size.height * 0.14);
    canvas.drawCircle(
      sun,
      size.width * 0.07,
      Paint()..color = const Color(0xFFFFF59D),
    );

    // Three mountain ranges scrolling at different speeds.
    for (final (speed, lift, amp, color) in const [
      (0.1, 0.42, 0.1, Color(0xFF90A4AE)),
      (0.2, 0.34, 0.08, Color(0xFF78909C)),
      (0.35, 0.26, 0.06, Color(0xFF81C784)),
    ]) {
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width + 6; x += 6) {
        final w = (x + camX * speed) / size.width;
        path.lineTo(
          x,
          size.height * (1 - lift) -
              (math.sin(w * math.pi * 2.2) * 0.6 +
                      math.sin(w * math.pi * 5.1 + 1) * 0.4) *
                  size.height *
                  amp,
        );
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  void _markers(
    Canvas canvas,
    double s,
    double left,
    double right,
    double Function(double) sx,
    double Function(double) sy,
  ) {
    for (var m = (left / 1000).ceil(); m * 1000 <= right; m++) {
      if (m <= 0) continue;
      final xu = m * 1000.0;
      final base = Offset(sx(xu), sy(game.heightAt(xu.round()).toDouble()));
      canvas.drawLine(
        base,
        base - Offset(0, 60 * s),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3 * s,
      );
      final sign = Rect.fromCenter(
        center: base - Offset(0, 66 * s),
        width: 64 * s,
        height: 24 * s,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(sign, Radius.circular(4 * s)),
        Paint()..color = const Color(0xFFFF7043),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${m * 100} m',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13 * s,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, sign.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  /// Fuel cans ahead, as little 3D jerry cans.
  void _cans(
    Canvas canvas,
    double s,
    double left,
    double right,
    double Function(double) sx,
    double Function(double) sy,
  ) {
    for (var k = game.nextCan; k < game.nextCan + 3; k++) {
      final xu = game.canX(k).toDouble();
      if (xu < left || xu > right) continue;
      final base = Offset(sx(xu), sy(game.heightAt(xu.round()).toDouble()));
      final body = Rect.fromLTWH(
        base.dx - 12 * s,
        base.dy - 30 * s,
        24 * s,
        30 * s,
      );
      final d = 6 * s;
      canvas
        ..drawPath(
          Path()..addPolygon([
            body.topRight,
            body.topRight + Offset(d, -d),
            body.bottomRight + Offset(d, -d),
            body.bottomRight,
          ], true),
          Paint()..color = const Color(0xFF8E0000),
        )
        ..drawPath(
          Path()..addPolygon([
            body.topLeft,
            body.topLeft + Offset(d, -d),
            body.topRight + Offset(d, -d),
            body.topRight,
          ], true),
          Paint()..color = const Color(0xFFFF8A80),
        )
        ..drawRRect(
          RRect.fromRectAndRadius(body, Radius.circular(3 * s)),
          Paint()..color = const Color(0xFFE53935),
        )
        ..drawRect(
          Rect.fromLTWH(body.left + 4 * s, body.top - 6 * s, 8 * s, 6 * s),
          Paint()..color = const Color(0xFFFFD54F),
        );
    }
  }

  void _car(
    Canvas canvas,
    double s,
    double Function(double) sx,
    double Function(double) sy,
  ) {
    final x = game.x;
    double angle;
    if (game.airborne) {
      angle = math.atan2(
        game.verticalSpeed.toDouble(),
        math.max(game.speed, 1).toDouble(),
      );
    } else {
      final rear = game.heightAt(math.max(0, (x - 22).round())).toDouble();
      final front = game.heightAt((x + 22).round()).toDouble();
      angle = math.atan2(front - rear, 44);
    }
    final crashed = crashedAt();
    if (crashed != null) {
      final ground = game.heightAt(math.max(0, x.round())).toDouble();
      _wreck(
        canvas,
        s,
        Offset(sx(x), sy(ground)),
        angle,
        clock.wallMs - crashed,
      );
      return;
    }

    final pivot = Offset(sx(x), sy(game.y));
    final bob = game.speed.abs() > 10 && !game.airborne
        ? math.sin(clock.wallMs / 70) * 0.8 * s
        : 0.0;
    final wheelTurn = x / 10;

    // Dust behind the rear wheel while driving on the ground.
    if (game.pedal == HillPedal.gas && !game.airborne && game.fuel > 0) {
      for (var k = 0; k < 5; k++) {
        final phase = ((clock.wallMs / 90 + k / 5) % 1);
        canvas.drawCircle(
          pivot + Offset(-32 * s - phase * 30 * s, -4 * s - phase * 14 * s),
          (3 + phase * 5) * s,
          Paint()
            ..color = const Color(
              0xFFD7CCC8,
            ).withValues(alpha: 0.6 * (1 - phase)),
        );
      }
    }

    // Exhaust puffs off the back while the gas is down.
    if (game.pedal == HillPedal.gas && game.fuel > 0) {
      for (var k = 0; k < 3; k++) {
        final phase = ((clock.wallMs / 260 + k / 3) % 1);
        canvas.drawCircle(
          pivot + Offset(-36 * s - phase * 22 * s, -22 * s - phase * 20 * s),
          (2.5 + phase * 6) * s,
          Paint()..color = Colors.white.withValues(alpha: 0.35 * (1 - phase)),
        );
      }
    }

    // How hard the suspension is loaded: it packs down landing from a jump
    // and on the way through a dip, and hangs loose in the air.
    final squash = game.airborne
        ? 0.0
        : (game.verticalSpeed.abs() / 60).clamp(0.0, 1.0);

    canvas
      ..save()
      ..translate(pivot.dx, pivot.dy + bob)
      ..rotate(-angle);

    // Wheels first: the body sits down onto them as the springs compress,
    // so the gap between the two is what shows the load.
    for (final side in [-1.0, 1.0]) {
      paintHillWheel(
        canvas,
        Offset(side * vehicle.axle * s, vehicle.wheelY * s),
        vehicle.wheelRadius,
        wheelTurn,
        s,
      );
    }
    vehicle.paintBody(canvas, s, squash);
    canvas.restore();
  }

  /// The crash, [t] ms after impact at [impact] on the ground: the car hops
  /// and flips onto its roof, the wheels come off, and sparks, bits of
  /// bodywork, dirt and smoke fly from where it hit.
  void _wreck(Canvas canvas, double s, Offset impact, double angle, double t) {
    final sec = t / 1000;
    final g = 1400 * s;

    // Something thrown from [from] at [vx], [vy] (per second), falling
    // under gravity and stopping on the ground line.
    Offset thrown(Offset from, double vx, double vy, double rest) {
      final p = from + Offset(vx * sec, vy * sec + g * sec * sec / 2);
      return Offset(p.dx, math.min(p.dy, impact.dy - rest));
    }

    // Dirt kicked up at the impact.
    for (var k = 0; k < 14; k++) {
      final life = 700 + 300 * _noise(k, 1);
      if (t > life) continue;
      final dir = -math.pi / 2 + (_noise(k, 2) - 0.5) * 2.2;
      final speed = (260 + 260 * _noise(k, 3)) * s;
      final p = thrown(impact, math.cos(dir) * speed, math.sin(dir) * speed, 0);
      canvas.drawCircle(
        p,
        (3 + 4 * _noise(k, 4)) * s,
        Paint()
          ..color = const Color(0xFF6D4C41).withValues(alpha: 1 - t / life),
      );
    }

    // Smoke rising off the wreck, puff after puff.
    for (var k = 0; k < 7; k++) {
      final start = k * 140.0;
      final life = 1500.0;
      final age = t - start;
      if (age < 0 || age > life) continue;
      final f = age / life;
      final p =
          impact +
          Offset(
            (_noise(k, 5) - 0.5) * 50 * s + f * 30 * s,
            -20 * s - f * 110 * s,
          );
      canvas.drawCircle(
        p,
        (10 + 28 * f) * s,
        Paint()
          ..color = const Color(0xFF424242).withValues(alpha: 0.5 * (1 - f)),
      );
    }

    // The car: up in a hop, over onto its roof, a smaller bounce, still.
    final hop = t < 650
        ? math.sin(math.pi * t / 650) * 70 * s
        : (t < 950 ? math.sin(math.pi * (t - 650) / 300) * 16 * s : 0.0);
    final slide = 70 * s * (1 - math.exp(-t / 380));
    final flip = Curves.easeOutBack.transform(math.min(1, t / 650));
    final centre = impact + Offset(slide, -18 * s - hop);
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(-angle * (1 - flip) + math.pi * flip)
      ..translate(0, 6 * s);
    vehicle.paintBody(canvas, s, 1);
    canvas.restore();

    // The wheels come off and bounce away on their own.
    for (final (side, vx, vy) in const [
      (-1.0, -150.0, -380.0),
      (1.0, 210.0, -460.0),
    ]) {
      final from = impact + Offset(side * vehicle.axle * s, -6 * s);
      final p = thrown(from, vx * s, vy * s, vehicle.wheelRadius * s);
      paintHillWheel(
        canvas,
        p,
        vehicle.wheelRadius,
        side * t / 45 * math.min(1, 1600 / (t + 1)),
        s,
      );
    }

    // Bits of bodywork, in the car's own colours, tumbling as they fall.
    for (var k = 0; k < 10; k++) {
      final life = 1400.0;
      if (t > life) continue;
      final dir = -math.pi / 2 + (_noise(k, 6) - 0.5) * 2.6;
      final speed = (300 + 300 * _noise(k, 7)) * s;
      final p = thrown(
        impact + Offset(0, -16 * s),
        math.cos(dir) * speed,
        math.sin(dir) * speed,
        2 * s,
      );
      final size = (5 + 5 * _noise(k, 8)) * s;
      canvas
        ..save()
        ..translate(p.dx, p.dy)
        ..rotate(t / (80 + 60 * _noise(k, 9)))
        ..drawRect(
          Rect.fromCenter(center: Offset.zero, width: size, height: size * 0.6),
          Paint()
            ..color = vehicle.colors[k % vehicle.colors.length].withValues(
              alpha: math.min(1, (life - t) / 300),
            ),
        )
        ..restore();
    }

    // Sparks, fast and short-lived, streaking out from the hit.
    for (var k = 0; k < 18; k++) {
      final life = 380 + 200 * _noise(k, 10);
      if (t > life) continue;
      final dir = -math.pi + _noise(k, 11) * math.pi;
      final speed = (420 + 380 * _noise(k, 12)) * s;
      final v = Offset(math.cos(dir), math.sin(dir)) * speed;
      final p = impact + v * sec + Offset(0, g * 0.4 * sec * sec);
      final f = t / life;
      canvas.drawLine(
        p,
        p - v * 0.035,
        Paint()
          ..strokeWidth = 3 * s
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(
            const Color(0xFFFFF59D),
            const Color(0xFFFF6D00),
            f,
          )!.withValues(alpha: 1 - f),
      );
    }
  }

  /// A fixed scatter in 0..1 for particle [i], property [k]: the same
  /// every frame, so a spark keeps its heading as it flies.
  static double _noise(int i, int k) {
    final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  bool shouldRepaint(_HillPainter oldDelegate) => true;
}
