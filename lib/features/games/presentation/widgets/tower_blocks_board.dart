import 'package:flutter/material.dart';

import '../../domain/tower_blocks.dart';
import '../game_controls.dart';
import 'tilt_3d.dart';

const _slabColor = Color(0xFF60A5FA);
const _queuedColor = Color(0xFFBFDBFE);

/// Tower Blocks: tap a column to drop the queued slab into the well.
///
/// The slab is drawn hovering over the column it would land in, with a ghost
/// showing where it comes to rest. The stack is the whole read, so showing
/// the landing is what makes a considered drop possible.
class TowerBlocksBoard extends StatefulWidget {
  const TowerBlocksBoard({
    required this.game,
    required this.controls,
    super.key,
  });

  final TowerBlocks game;
  final GameControls controls;

  @override
  State<TowerBlocksBoard> createState() => _TowerBlocksBoardState();
}

class _TowerBlocksBoardState extends State<TowerBlocksBoard> {
  int _aim = 0;

  void _drop(int col) {
    if (!widget.controls.active || widget.game.isOver) return;
    final clamped = col.clamp(0, widget.game.maxColumn);
    widget.game.drop(clamped);
    setState(() => _aim = _aim.clamp(0, widget.game.maxColumn));
    widget.controls.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final config = game.config;
    final aim = _aim.clamp(0, game.maxColumn);
    final rest = game.restRow(aim);

    return Center(
      child: Tilt3D(
        angle: 0.18,
        child: AspectRatio(
          aspectRatio: config.columns / (config.rows + 2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cell = constraints.maxWidth / config.columns;
              // Two rows of headroom above the well for the queued slab.
              final floor = constraints.maxHeight - cell;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final col = (details.localPosition.dx / cell).floor();
                  setState(() => _aim = col.clamp(0, game.maxColumn));
                },
                onTap: () => _drop(aim),
                onHorizontalDragUpdate: (details) {
                  final col = (details.localPosition.dx / cell).floor();
                  setState(() => _aim = col.clamp(0, game.maxColumn));
                },
                child: Stack(
                  children: [
                    // Well floor and walls.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: floor,
                      height: 3,
                      child: const ColoredBox(color: Color(0x66FFFFFF)),
                    ),
                    // Landed slabs, row 0 at the floor.
                    for (var row = 0; row < config.rows; row++)
                      for (var col = 0; col < config.columns; col++)
                        if (game.filled(row, col))
                          Positioned(
                            left: col * cell,
                            top: floor - (row + 1) * cell,
                            width: cell,
                            height: cell,
                            child: const _Cell(color: _slabColor),
                          ),
                    // Ghost of where the queued slab lands.
                    if (!game.isOver && rest < config.rows)
                      Positioned(
                        left: aim * cell,
                        top: floor - (rest + 1) * cell,
                        width: cell * game.width,
                        height: cell,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    // The queued slab, waiting above the well.
                    if (!game.isOver)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOut,
                        left: aim * cell,
                        top: 0,
                        width: cell * game.width,
                        height: cell,
                        child: Row(
                          children: [
                            for (var i = 0; i < game.width; i++)
                              const Expanded(child: _Cell(color: _queuedColor)),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          // A lit top face over a darker base is what gives the slab its
          // thickness without drawing a second shape.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(color, Colors.white, 0.35)!,
              color,
              extrusionShade(color, 0.2),
            ],
            stops: const [0, 0.45, 1],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
      ),
    );
  }
}
