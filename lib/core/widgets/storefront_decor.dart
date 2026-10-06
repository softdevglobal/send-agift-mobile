import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// A word set on a solid block of brand colour, like a highlighter swipe.
/// The poster headlines stack these line by line.
class Marker extends StatelessWidget {
  const Marker(
    this.text, {
    super.key,
    required this.style,
    this.color = AppColors.purple,
    this.textColor = Colors.white,
  });

  final String text;
  final TextStyle style;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 24;
    return Container(
      color: color,
      padding: EdgeInsets.fromLTRB(size * 0.16, size * 0.04, size * 0.16, 0),
      child: Text(text, style: style.copyWith(color: textColor)),
    );
  }
}

/// A heading with a thick solid bar behind the lower half of the words.
class UnderlineMarker extends StatelessWidget {
  const UnderlineMarker(
    this.text, {
    super.key,
    required this.style,
    this.color = const Color(0xFF8EDFDF),
    this.maxLines,
  });

  final String text;
  final TextStyle style;
  final Color color;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 24;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -size * 0.1,
          right: -size * 0.1,
          bottom: size * 0.04,
          height: size * 0.42,
          child: ColoredBox(color: color),
        ),
        Text(
          text,
          style: style,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Small heavy uppercase label on a solid chip.
class TagChip extends StatelessWidget {
  const TagChip(
    this.label, {
    super.key,
    this.color = AppColors.foreground,
    this.textColor = Colors.white,
    this.icon,
  });

  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 5),
          ],
          Text(label.toUpperCase(), style: AppTypography.tag(color: textColor)),
        ],
      ),
    );
  }
}

/// Four-point sparkle scattered over banners as flat confetti.
class Sparkle extends StatelessWidget {
  const Sparkle({super.key, this.size = 18, this.color = AppColors.purple});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.square(size),
        painter: _SparklePainter(color),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w / 2, h / 2);
    final path = Path()
      ..moveTo(c.dx, 0)
      ..quadraticBezierTo(c.dx + w * 0.06, c.dy - h * 0.06, w, c.dy)
      ..quadraticBezierTo(c.dx + w * 0.06, c.dy + h * 0.06, c.dx, h)
      ..quadraticBezierTo(c.dx - w * 0.06, c.dy + h * 0.06, 0, c.dy)
      ..quadraticBezierTo(c.dx - w * 0.06, c.dy - h * 0.06, c.dx, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => oldDelegate.color != color;
}

/// Solid dot, the other half of the banner confetti.
class Dot extends StatelessWidget {
  const Dot({super.key, this.size = 8, this.color = AppColors.teal});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
