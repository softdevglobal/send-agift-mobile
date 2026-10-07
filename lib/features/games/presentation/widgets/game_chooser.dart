import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';

/// One thing on offer before a round starts.
class GameChoice {
  const GameChoice({
    required this.name,
    required this.colors,
    required this.paint,
  });

  /// Shown under the preview, and what a test taps.
  final String name;

  /// The thing's own colours, for the preview.
  final List<Color> colors;

  /// Draws the preview into the square it is given.
  final void Function(Canvas canvas, Size size) paint;
}

/// The screen a game shows before the first move, for picking what to play
/// with. A picture to rebuild, a vehicle to drive.
///
/// The choice is the player's and is drawn locally. It decides nothing about
/// the round: the board still comes from the server's seed and the moves are
/// still what gets scored, so two players on one seed play the identical game
/// whichever they picked.
class GameChooser extends StatelessWidget {
  const GameChooser({
    required this.title,
    required this.subtitle,
    required this.choices,
    required this.onPick,
    this.previewAspect = 1,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<GameChoice> choices;
  final ValueChanged<GameChoice> onPick;

  /// Width over height of each preview. Square for a picture, wider for
  /// something that is longer than it is tall.
  final double previewAspect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppTypography.display(24, color: Colors.white)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                // Two across, so each preview is big enough to tell what it
                // is before committing to a whole round with it.
                final width =
                    (constraints.maxWidth.clamp(240.0, 460.0) - 14) / 2;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final choice in choices)
                      _ChoiceTile(
                        choice: choice,
                        width: width,
                        height: width / previewAspect,
                        onTap: () => onPick(choice),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.choice,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final GameChoice choice;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: choice.name,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: _ChoicePainter(choice: choice),
                  size: Size(width, height),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              choice.name,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoicePainter extends CustomPainter {
  _ChoicePainter({required this.choice});

  final GameChoice choice;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    choice.paint(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ChoicePainter old) => old.choice != choice;
}
