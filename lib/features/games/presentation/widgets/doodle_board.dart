import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/doodle_jump.dart';
import '../game_controls.dart';
import 'tilt_3d.dart';

/// How many rungs of the tower are on screen at once.
const _visibleRungs = 7;

/// The playing surface, so a test can reach a lane through the board's own
/// coordinates rather than guessing past the perspective.
const doodleSurfaceKey = ValueKey('doodle-board-surface');

const _hopDuration = Duration(milliseconds: 260);

/// A sprung hop covers several ledges, so it is given time per ledge rather
/// than a flat figure. Being flung three should not finish as quickly as
/// being flung two.
const _springRungDuration = Duration(milliseconds: 220);

/// When the climber meets the spring, as a fraction of a sprung hop: the
/// first part is the step up onto it, the rest is being thrown off it.
const _springContact = 0.32;

/// Doodle Jump: a tower of ledges seen from the side, climbed a rung at a time.
///
/// The tower is drawn in perspective and scrolls under the jumper as it
/// climbs, rather than snapping a rung at a time, so a hop reads as a jump
/// rather than a redraw. Lanes out of reach stay visible but fall back into
/// the haze, so the rule. Your lane and the two beside it. Can be seen
/// instead of learned by falling.
class DoodleBoard extends StatefulWidget {
  const DoodleBoard({required this.game, required this.controls, super.key});

  final DoodleJump game;
  final GameControls controls;

  @override
  State<DoodleBoard> createState() => _DoodleBoardState();
}

class _DoodleBoardState extends State<DoodleBoard>
    with TickerProviderStateMixin {
  /// Runs 0 to 1 across a single hop; everything that moves is read from it,
  /// so the climb, the arc and the squash cannot drift apart.
  late final AnimationController _hop;

  /// A slow loop for the things that never stop: the idle bob, the shimmer on
  /// a spring, the drifting motes.
  late final AnimationController _idle;

  /// Where the hop started, so the tower and the jumper can be drawn part-way
  /// between one rung and the next.
  int _fromLane = 0;
  int _fromHeight = 0;

  /// How many rungs this hop covers. A spring is the only thing that carries
  /// the climber two at once, which is also how one is recognised: after the
  /// hop the engine's height has already moved past the spring to the rung
  /// above it, so the spring cannot be read off the landing rung.
  int _rungs = 1;

  bool get _sprung => _rungs > 1;

  DoodleJump get _game => widget.game;

  @override
  void initState() {
    super.initState();
    _fromLane = _game.lane;
    _fromHeight = _game.height;
    _hop = AnimationController(
      vsync: this,
      duration: _hopDuration,
      value: 1,
    );
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _idle.stop();
    } else if (!_idle.isAnimating) {
      _idle.repeat();
    }
  }

  @override
  void dispose() {
    _hop.dispose();
    _idle.dispose();
    super.dispose();
  }

  void _jump(int lane) {
    if (!widget.controls.active || _game.isOver) return;
    if (!_game.canReach(lane)) return;

    final fromLane = _game.lane;
    final fromHeight = _game.height;
    // A hop that misses reports false, but the round still has to move on.
    // that is the fall that ends it, and the screen only hears about it
    // through onChanged below.
    _game.hop(lane);

    setState(() {
      _fromLane = fromLane;
      _fromHeight = fromHeight;
      _rungs = _game.height - fromHeight;
    });
    // Being flung two rungs takes longer than stepping up one.
    _hop
      ..duration = _sprung
          ? _springRungDuration * _rungs
          : _hopDuration
      ..forward(from: 0);
    widget.controls.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final lanes = _game.config.lanes;

    return LayoutBuilder(
      builder: (context, constraints) {
        final laneWidth = constraints.maxWidth / lanes;
        final rungHeight = constraints.maxHeight / _visibleRungs;

        return Stack(
          key: doodleSurfaceKey,
          children: [
            // The shaft the tower climbs, drawn behind everything.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _idle,
                  builder: (context, _) => CustomPaint(
                    painter: _ShaftPainter(
                      phase: _idle.value,
                      lanes: lanes,
                      climb: _climb,
                    ),
                  ),
                ),
              ),
            ),

            // Clipped to the board: a rung entering at the top, or the one
            // being left behind at the bottom, would otherwise be drawn over
            // the score panels and the hint beneath them.
            Positioned.fill(
              child: ClipRect(
                child: IgnorePointer(
                  child: Tilt3D(
                    angle: 0.1,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_hop, _idle]),
                      builder: (context, _) => _tower(laneWidth, rungHeight),
                    ),
                  ),
                ),
              ),
            ),

            // Tap targets, one per lane. A lane out of reach is left visible
            // but pushed back into the haze rather than blacked out.
            Row(
              children: [
                for (var lane = 0; lane < lanes; lane++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _jump(lane),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          gradient: _game.canReach(lane)
                              ? null
                              : LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    const Color(
                                      0xFF03251B,
                                    ).withValues(alpha: 0.42),
                                    const Color(
                                      0xFF03251B,
                                    ).withValues(alpha: 0.24),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// How many rungs the world has climbed so far this hop.
  ///
  /// A sprung hop is in two parts, so the tower does not glide smoothly past
  /// two rungs while the climber is standing on the spring in the middle: it
  /// rises one rung onto the spring, pauses on the compression, then rises
  /// the second as the spring lets go.
  double get _climb {
    final t = _hop.value;
    if (!_sprung) return Curves.easeOutCubic.transform(t) * _rungs;
    if (t <= _springContact) {
      return Curves.easeOutCubic.transform(t / _springContact);
    }
    final after = (t - _springContact) / (1 - _springContact);
    return 1 + Curves.easeOutCubic.transform(after) * (_rungs - 1);
  }

  /// How high off the ledges the climber is right now, 0 to 1.
  ///
  /// A plain hop is one arc. A sprung one is a short arc onto the spring and
  /// then a much bigger one off it, which is what makes a spring feel like a
  /// launch rather than a longer step.
  double get _arc {
    final t = _hop.value;
    if (!_sprung) return math.sin(t * math.pi);
    if (t <= _springContact) {
      return math.sin(t / _springContact * math.pi) * 0.3;
    }
    final after = (t - _springContact) / (1 - _springContact);
    return math.sin(after * math.pi);
  }

  /// How far the spring is squashed, 0 to 1. It takes the climber's weight as
  /// they arrive and is fully released a moment later.
  double get _springSquash {
    if (!_sprung) return 0;
    final t = _hop.value;
    if (t < _springContact) {
      return Curves.easeIn.transform((t / _springContact).clamp(0.0, 1.0));
    }
    final release = ((t - _springContact) / 0.18).clamp(0.0, 1.0);
    return 1 - Curves.easeOutCubic.transform(release);
  }

  Widget _tower(double laneWidth, double rungHeight) {
    // The rung the world is drawn around, part-way between two whole rungs
    // while a hop is in flight.
    final climbed = _climb;
    final viewHeight = _fromHeight + climbed;
    final t = _rungs == 0 ? _hop.value : (climbed / _rungs).clamp(0.0, 1.0);

    final ledges = <Widget>[];
    for (var offset = -2; offset <= _visibleRungs + _rungs; offset++) {
      final index = _fromHeight + offset;
      if (index < 0 || index >= _game.platforms.length) continue;

      final platform = _game.platformAt(index);
      // Distance up the screen, in rungs, once the climb is accounted for.
      final up = index - viewHeight;
      final bottom = rungHeight * (up + 1.15);
      if (bottom < -rungHeight || bottom > rungHeight * (_visibleRungs + 1)) {
        continue;
      }

      // Further up the tower is further away: smaller, dimmer, tucked toward
      // the middle. That is what gives the shaft its depth.
      final depth = (up / _visibleRungs).clamp(0.0, 1.0);
      final scale = 1 - depth * 0.22;
      final fade = 1 - depth * 0.55;

      void add(int lane) {
        if (lane < 0) return;
        final centre = (lane + 0.5) * laneWidth;
        final width = laneWidth * 0.76 * scale;
        ledges.add(
          Positioned(
            left: centre - width / 2,
            bottom: bottom,
            width: width,
            height: rungHeight * 0.2 * scale,
            child: Opacity(
              opacity: fade.clamp(0.25, 1.0),
              child: _Ledge(
                spring: platform.spring,
                underfoot: index == _game.height,
                shimmer: _idle.value,
                // Only the spring actually being used is squashed.
                squash: _sprung && index == _fromHeight + 1 ? _springSquash : 0,
              ),
            ),
          ),
        );
      }

      add(platform.lane);
      add(platform.alt);
    }

    // The jumper rides at a fixed place on screen; the tower is what moves.
    final lane = _fromLane + (_game.lane - _fromLane) * t;
    final arc = _arc;
    final bob = math.sin(_idle.value * math.pi * 2) * 0.012;
    final height = rungHeight * 0.66;
    final width = laneWidth * 0.52;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ...ledges,
        Positioned(
          left: (lane + 0.5) * laneWidth - width / 2,
          // The arc lifts it off the ledge and sets it down again. A spring
          // throws it as far as it actually carries the climber, so three
          // ledges look like three ledges rather than a slightly bigger hop.
          bottom:
              rungHeight * (1.35 + bob) +
              arc * rungHeight * (_sprung ? 0.85 * _rungs : 0.7),
          width: width,
          height: height,
          child: _Jumper(
            arc: arc,
            lean: (_game.lane - _fromLane) * arc * 0.22,
            sprung: _sprung,
          ),
        ),
      ],
    );
  }
}

/// A ledge, built as a slab: a lit top face with a darker front edge beneath
/// it, which is what makes it read as something you could land on.
///
/// A spring ledge carries a coil that takes the climber's weight and throws
/// them off it, rather than being a plain ledge in another colour.
class _Ledge extends StatelessWidget {
  const _Ledge({
    required this.spring,
    required this.underfoot,
    required this.shimmer,
    this.squash = 0,
  });

  final bool spring;
  final bool underfoot;
  final double shimmer;

  /// How far this spring is compressed, 0 to 1. Always 0 on a plain ledge.
  final double squash;

  @override
  Widget build(BuildContext context) {
    final color = spring ? const Color(0xFFFCD34D) : const Color(0xFF34D399);
    // A spring breathes so it can be picked out from a plain ledge at a
    // glance, which is the whole reason to aim for one.
    final pulse = spring ? 0.5 + 0.5 * math.sin(shimmer * math.pi * 4) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (spring)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                // The coil stands above the ledge, and loses height as it is
                // squashed.
                top: -h * 1.5 * (1 - squash),
                child: CustomPaint(
                  painter: _CoilPainter(squash: squash, glow: pulse),
                ),
              ),
            // The front face, dropped below the top so the slab has a side.
            Positioned(
              left: h * 0.12,
              right: h * 0.12,
              top: h * 0.42,
              height: h * 0.72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(h * 0.42),
                  color: extrusionShade(color, 0.26),
                ),
              ),
            ),
            // The top face.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(h * 0.5),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(color, Colors.white, 0.55)!,
                      color,
                      extrusionShade(color, 0.14),
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(
                        alpha: underfoot ? 0.75 : 0.2 + pulse * 0.35,
                      ),
                      blurRadius: underfoot ? h * 1.2 : h * (0.4 + pulse * 0.6),
                      spreadRadius: underfoot ? 1 : 0,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The coil on a spring ledge: a zigzag that closes up as it takes weight and
/// snaps back open as it lets go, with a cap on top for the climber to meet.
class _CoilPainter extends CustomPainter {
  _CoilPainter({required this.squash, required this.glow});

  final double squash;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0 || size.width <= 0) return;

    const gold = Color(0xFFFCD34D);
    final w = size.width;
    final h = size.height;
    final centre = w / 2;
    final coilWidth = w * (0.3 + squash * 0.12);
    final capHeight = (h * 0.28).clamp(1.0, h);
    final coilTop = capHeight;
    final coilHeight = (h - capHeight).clamp(0.0, h);

    // The zigzag, drawn tighter the more it is squashed. Winding closer
    // together as it compresses is what makes it read as a spring rather
    // than a shrinking shape.
    const turns = 4;
    final path = Path()..moveTo(centre - coilWidth / 2, h);
    for (var i = 0; i < turns; i++) {
      final from = h - coilHeight * (i / turns);
      final to = h - coilHeight * ((i + 1) / turns);
      final side = i.isEven ? 1 : -1;
      path.lineTo(centre + side * coilWidth / 2, (from + to) / 2);
      path.lineTo(centre - side * coilWidth / 2, to);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (w * 0.07).clamp(1.0, 6.0)
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = extrusionShade(gold, 0.1),
    );

    // The cap the climber actually lands on.
    final cap = RRect.fromLTRBR(
      centre - w * 0.3,
      coilTop - capHeight * 0.5,
      centre + w * 0.3,
      coilTop + capHeight * 0.5,
      Radius.circular(capHeight),
    );
    canvas.drawRRect(
      cap,
      Paint()
        ..color = gold.withValues(alpha: 0.35 + glow * 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, capHeight * 0.8),
    );
    canvas.drawRRect(cap, Paint()..color = gold);
  }

  @override
  bool shouldRepaint(_CoilPainter old) =>
      old.squash != squash || old.glow != glow;
}

/// The climber: a figure that tucks its legs on the way up, reaches overhead
/// at the top of the arc and lands on bent knees. Drawn rather than assembled
/// from boxes, so the limbs can actually move with the jump.
class _Jumper extends StatelessWidget {
  const _Jumper({required this.arc, required this.lean, required this.sprung});

  /// 0 on a ledge, 1 at the top of the jump.
  final double arc;
  final double lean;
  final bool sprung;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: lean,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // A shadow left on the ledge, shrinking away as the figure climbs.
          Positioned(
            left: 0,
            right: 0,
            bottom: -arc * 6,
            height: 6,
            child: Opacity(
              opacity: (1 - arc) * 0.4,
              child: Transform.scale(
                scaleX: 1 - arc * 0.5,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF022C22),
                    borderRadius: BorderRadius.all(Radius.elliptical(20, 6)),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _JumperPainter(arc: arc, sprung: sprung)),
          ),
        ],
      ),
    );
  }
}

class _JumperPainter extends CustomPainter {
  _JumperPainter({required this.arc, required this.sprung});

  final double arc;
  final bool sprung;

  static const _skin = Color(0xFFFDE8C8);
  static const _suit = Color(0xFF34D399);
  static const _suitDark = Color(0xFF047857);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final unit = h / 100; // the figure is laid out in hundredths of its height

    // Airborne the body stretches and the legs tuck; on a ledge it settles
    // and the knees bend to take the landing.
    final lift = arc;
    final crouch = (1 - arc) * (1 - arc);

    final centre = w / 2;
    final headR = unit * 13;
    final headY = unit * (16 + crouch * 5);
    final hipY = unit * (60 - lift * 4 + crouch * 4);

    final limb = Paint()
      ..color = _suitDark
      ..strokeWidth = unit * 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Legs: tucked up under the body in flight, planted and bent on landing.
    final kneeOut = unit * (9 + lift * 5);
    final kneeY = hipY + unit * (18 - lift * 8);
    final footY = hipY + unit * (36 - lift * 20 - crouch * 4);
    for (final side in [-1, 1]) {
      final path = Path()
        ..moveTo(centre + side * unit * 4, hipY)
        ..lineTo(centre + side * kneeOut, kneeY)
        ..lineTo(centre + side * unit * (5 + crouch * 4), footY);
      canvas.drawPath(path, limb);
    }

    // Arms: swung down by the sides on a ledge, thrown overhead in the air.
    // which is what makes the jump read as effort rather than a float.
    final shoulderY = unit * 36;
    final handY = shoulderY - lift * unit * 26 + (1 - lift) * unit * 26;
    final handOut = unit * (16 + lift * 6);
    for (final side in [-1, 1]) {
      final path = Path()
        ..moveTo(centre + side * unit * 6, shoulderY)
        ..lineTo(centre + side * handOut, (shoulderY + handY) / 2)
        ..lineTo(centre + side * handOut * 0.86, handY);
      canvas.drawPath(path, limb);
    }

    // Body.
    final bodyRect = RRect.fromLTRBR(
      centre - unit * 13,
      unit * 28,
      centre + unit * 13,
      hipY + unit * 4,
      Radius.circular(unit * 11),
    );
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6EE7B7), _suit, _suitDark],
        ).createShader(bodyRect.outerRect),
    );

    // Head, with a scarf trailing behind when there is speed to trail with.
    if (lift > 0.1) {
      final scarf = Paint()
        ..color = (sprung ? const Color(0xFFFCD34D) : const Color(0xFFA7F3D0))
            .withValues(alpha: 0.9)
        ..strokeWidth = unit * 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(
        Path()
          ..moveTo(centre - unit * 9, headY + unit * 6)
          ..quadraticBezierTo(
            centre - unit * (20 + lift * 10),
            headY + unit * (10 + lift * 8),
            centre - unit * (26 + lift * 16),
            headY + unit * 4,
          ),
        scarf,
      );
    }

    canvas.drawCircle(
      Offset(centre, headY),
      headR,
      Paint()..color = _skin,
    );

    // A face that looks where it is going: eyes up in flight, level on a
    // ledge, and a wider smile the higher it gets.
    final eye = Paint()..color = const Color(0xFF064E3B);
    final eyeY = headY - unit * (1 + lift * 3);
    for (final side in [-1, 1]) {
      canvas.drawCircle(
        Offset(centre + side * unit * 5, eyeY),
        unit * 2.2,
        eye,
      );
    }
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(centre, headY + unit * 4),
        radius: unit * (4 + lift * 2),
      ),
      0.35,
      2.44,
      false,
      Paint()
        ..color = const Color(0xFF064E3B)
        ..strokeWidth = unit * 1.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_JumperPainter old) =>
      old.arc != arc || old.sprung != sprung;
}

/// The shaft behind the tower: rails running away into the distance and motes
/// drifting down past them, so the climb has something to be measured against.
class _ShaftPainter extends CustomPainter {
  _ShaftPainter({
    required this.phase,
    required this.lanes,
    required this.climb,
  });

  final double phase;
  final int lanes;
  final double climb;

  @override
  void paint(Canvas canvas, Size size) {
    final vanish = Offset(size.width / 2, size.height * 0.24);

    // Rails from the foot of each lane to a point up the shaft, which is what
    // makes the tower read as receding rather than flat.
    final rail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.07);
    for (var lane = 0; lane <= lanes; lane++) {
      final x = size.width * lane / lanes;
      canvas.drawLine(Offset(x, size.height), vanish, rail);
    }

    // Motes falling past, which give the climb a sense of speed.
    final mote = Paint()..color = Colors.white.withValues(alpha: 0.16);
    for (var i = 0; i < 14; i++) {
      final seed = i * 0.137;
      final x = size.width * ((seed * 7) % 1);
      final drift = (phase + seed + climb * 0.1) % 1;
      final y = size.height * drift;
      canvas.drawCircle(Offset(x, y), 1.4 + (i % 3) * 0.6, mote);
    }
  }

  @override
  bool shouldRepaint(_ShaftPainter old) =>
      old.phase != phase || old.climb != climb || old.lanes != lanes;
}
