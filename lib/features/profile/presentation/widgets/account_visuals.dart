import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';

/// A stable colour for a name, so a person keeps the same tint everywhere.
Color tintFor(String seed) {
  final hash = seed.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0x7fffffff);
  return AppColors.categoryTints[hash % AppColors.categoryTints.length];
}

/// The brand's navy-to-violet card, with soft glows and a faint icon in the
/// corner. Used at the top of the account pages.
class BrandHero extends StatelessWidget {
  const BrandHero({
    super.key,
    required this.child,
    this.icon = Icons.card_giftcard_rounded,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final IconData icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.26),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.brandGradient,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                top: -50,
                child: _Glow(size: 170, color: AppColors.teal, alpha: 0.32),
              ),
              Positioned(
                left: -30,
                bottom: -70,
                child: _Glow(size: 150, color: Colors.white, alpha: 0.10),
              ),
              Positioned(
                right: 16,
                top: 14,
                child: Icon(
                  icon,
                  size: 70,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color, required this.alpha});

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// Initials in a tinted circle inside a teal-to-violet ring.
class RingAvatar extends StatelessWidget {
  const RingAvatar({
    super.key,
    required this.name,
    this.size = 48,
    this.onDark = false,
  });

  final String name;
  final double size;

  /// On the gradient hero the ring fades to white so it still reads.
  final bool onDark;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size * 0.05),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: onDark
              ? const [AppColors.teal, Colors.white]
              : const [AppColors.teal, AppColors.purple],
        ),
      ),
      child: Container(
        height: size,
        width: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tintFor(name),
          border: Border.all(color: Colors.white, width: size * 0.04),
        ),
        child: Text(
          _initials,
          style: AppTypography.display(size * 0.38, color: AppColors.primary),
        ),
      ),
    );
  }
}

/// A little drawn map. A few streets and a pin. So each address card has
/// a sense of place. The streets are seeded by [seed], so an address always
/// gets the same map.
class MiniMap extends StatelessWidget {
  const MiniMap({
    super.key,
    required this.seed,
    this.size = 76,
    this.highlight = false,
    this.located = true,
  });

  final String seed;
  final double size;
  final bool highlight;

  /// Without a map point the pin is drawn hollow.
  final bool located;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: SizedBox(
        height: size,
        width: size,
        child: CustomPaint(
          painter: _MiniMapPainter(
            seed: seed.hashCode,
            ground: highlight ? AppColors.cream : tintFor(seed),
            road: Colors.white,
            pin: highlight ? AppColors.purple : AppColors.primary,
            located: located,
          ),
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter({
    required this.seed,
    required this.ground,
    required this.road,
    required this.pin,
    required this.located,
  });

  final int seed;
  final Color ground;
  final Color road;
  final Color pin;
  final bool located;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);

    // A park block somewhere on the map.
    final park = Paint()..color = AppColors.teal.withValues(alpha: 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * (0.05 + random.nextDouble() * 0.4),
          size.height * (0.05 + random.nextDouble() * 0.4),
          size.width * 0.32,
          size.height * 0.26,
        ),
        const Radius.circular(4),
      ),
      park,
    );

    final roads = Paint()
      ..color = road
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      roads.strokeWidth = i == 0 ? 5 : 3;
      final y = size.height * (0.2 + random.nextDouble() * 0.6);
      canvas.drawLine(
        Offset(-4, y + random.nextDouble() * 10 - 5),
        Offset(size.width + 4, y + random.nextDouble() * 10 - 5),
        roads,
      );
      final x = size.width * (0.2 + random.nextDouble() * 0.6);
      canvas.drawLine(
        Offset(x + random.nextDouble() * 10 - 5, -4),
        Offset(x + random.nextDouble() * 10 - 5, size.height + 4),
        roads,
      );
    }

    // The pin, with a soft halo.
    final centre = Offset(size.width / 2, size.height / 2 + 4);
    canvas.drawCircle(
      centre + const Offset(0, 9),
      7,
      Paint()..color = pin.withValues(alpha: 0.18),
    );
    final head = centre - const Offset(0, 6);
    final path = Path()
      ..moveTo(centre.dx, centre.dy + 8)
      ..quadraticBezierTo(centre.dx - 9, head.dy + 4, centre.dx - 9, head.dy)
      ..arcToPoint(
        Offset(centre.dx + 9, head.dy),
        radius: const Radius.circular(9),
      )
      ..quadraticBezierTo(centre.dx + 9, head.dy + 4, centre.dx, centre.dy + 8)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = located ? pin : Colors.white
        ..style = PaintingStyle.fill,
    );
    if (!located) {
      canvas.drawPath(
        path,
        Paint()
          ..color = pin
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
    canvas.drawCircle(head, 3.2, Paint()..color = located ? Colors.white : pin);
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) =>
      old.seed != seed ||
      old.ground != ground ||
      old.pin != pin ||
      old.located != located;
}

/// A dashed, tappable "add another" card that sits at the end of a list.
class DashedAddCard extends StatelessWidget {
  const DashedAddCard({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.add_rounded,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 30,
                width: 30,
                decoration: const BoxDecoration(
                  color: AppColors.cream,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: AppColors.purple),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: AppColors.purple),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppTheme.radiusLg),
    );
    final paint = Paint()
      ..color = AppColors.purple.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}

/// A white pill button for use on [BrandHero].
class HeroButton extends StatelessWidget {
  const HeroButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
