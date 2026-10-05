import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/memory_match.dart';
import '../game_controls.dart';
import 'tilt_3d.dart';

/// The gift faces a Memory Match grid deals from.
///
/// There must be at least one look per pair on the biggest board the game
/// deals: two cards that look the same but are not a pair would make the
/// round unwinnable by memory. `memory_board_test.dart` holds that line.
const memoryFaces = <(IconData, Color)>[
  (Icons.card_giftcard_rounded, Color(0xFFF25AAA)),
  (Icons.cake_rounded, Color(0xFFBB8803)),
  (Icons.local_florist_rounded, Color(0xFF24A676)),
  (Icons.celebration_rounded, Color(0xFF4294F9)),
  (Icons.coffee_rounded, Color(0xFF9C7CF9)),
  (Icons.diamond_rounded, Color(0xFF0E9FB6)),
  (Icons.music_note_rounded, Color(0xFFFA5870)),
  (Icons.sports_esports_rounded, Color(0xFFB78D03)),
  (Icons.favorite_rounded, Color(0xFFEF4444)),
  (Icons.star_rounded, Color(0xFFCA8208)),
  (Icons.pets_rounded, Color(0xFF0EA674)),
  (Icons.icecream_rounded, Color(0xFF089BDC)),
  (Icons.local_pizza_rounded, Color(0xFFF46806)),
  (Icons.emoji_emotions_rounded, Color(0xFFB98D06)),
  (Icons.beach_access_rounded, Color(0xFF12A191)),
  (Icons.camera_alt_rounded, Color(0xFF7C88F8)),
  (Icons.headphones_rounded, Color(0xFFEC4899)),
  (Icons.watch_rounded, Color(0xFF69A312)),
  (Icons.checkroom_rounded, Color(0xFF05A1BB)),
  (Icons.brush_rounded, Color(0xFFD946EF)),
  (Icons.menu_book_rounded, Color(0xFF0D9BDB)),
  (Icons.rocket_launch_rounded, Color(0xFFF43F5E)),
  (Icons.lightbulb_rounded, Color(0xFFAF8D04)),
  (Icons.spa_rounded, Color(0xFF1FA851)),
  (Icons.wine_bar_rounded, Color(0xFFB670FC)),
  (Icons.shopping_bag_rounded, Color(0xFFEB6C05)),
  (Icons.toys_rounded, Color(0xFF21A392)),
  (Icons.redeem_rounded, Color(0xFFE152F7)),
  (Icons.anchor_rounded, Color(0xFF0C7BAF)),
  (Icons.park_rounded, Color(0xFF1DA74F)),
  (Icons.nightlight_rounded, Color(0xFF748BFA)),
  (Icons.sports_basketball_rounded, Color(0xFFFF5E25)),
];

/// Memory Match: a grid of cards that flip in 3D.
///
/// The flip is a real Y rotation rather than a cross-fade, so the card turns
/// the way a card does. Which is also what makes a pair reading as "the same"
/// obvious at a glance.
class MemoryBoard extends StatefulWidget {
  const MemoryBoard({required this.game, required this.controls, super.key});

  final MemoryMatch game;
  final GameControls controls;

  @override
  State<MemoryBoard> createState() => _MemoryBoardState();
}

class _MemoryBoardState extends State<MemoryBoard> {
  /// The pair being looked at before it turns back. Held briefly so a player
  /// actually sees the second card, rather than it vanishing on contact.
  int? _peekA;
  int? _peekB;

  void _tap(int index) {
    if (!widget.controls.active || widget.game.isOver) return;
    final game = widget.game;
    if (game.isMatched(index) || index == _peekA) return;

    // A tap while two wrong cards are showing clears them first.
    if (_peekA != null && _peekB != null) {
      setState(() {
        _peekA = null;
        _peekB = null;
      });
    }

    final first = game.pending;
    final matched = game.flip(index);
    setState(() {
      if (first < 0) {
        _peekA = index;
        _peekB = null;
      } else if (matched) {
        _peekA = null;
        _peekB = null;
      } else {
        _peekA = first;
        _peekB = index;
      }
    });
    widget.controls.onChanged();

    if (!matched && first >= 0) {
      // Let the mismatch sit long enough to memorise, then turn it back.
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _peekA = null;
          _peekB = null;
        });
      });
    }
  }

  bool _isUp(int index) =>
      widget.game.isMatched(index) || index == _peekA || index == _peekB;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final columns = game.config.columns;
    // A deal that does not divide evenly into the columns leaves the last row
    // short. Rather than a hole at the end of the grid, the spare slot sits in
    // the middle as an emblem. That is what lets a 48-card deal fill a whole
    // 7x7 square, which 49 cards could never do while every card has a pair.
    final slots = columns * game.rows;
    final spare = slots - game.cardCount;
    final emblemAt = spare == 1 ? slots ~/ 2 : -1;
    return Center(
      // No perspective tilt: it scales the grid down and leans it, so the
      // cards come out narrower along one edge and the board sits off
      // centre. A grid of square cards has to be square.
      child: AspectRatio(
        aspectRatio: columns / game.rows,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Everything on a card is sized from the card itself, so a 4x4
            // board and an 8x8 one both read properly instead of the 8x8
            // wearing icons and gaps meant for cards three times the size.
            final gap = (constraints.maxWidth / columns * 0.11).clamp(3.0, 8.0);
            final card = (constraints.maxWidth - gap * (columns - 1)) / columns;
            return GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: gap,
                mainAxisSpacing: gap,
              ),
              itemCount: game.cardCount + (emblemAt >= 0 ? 1 : 0),
              itemBuilder: (context, slot) {
                if (slot == emblemAt) return _Emblem(size: card);
                // Past the emblem every slot is one card further along.
                final index = emblemAt >= 0 && slot > emblemAt
                    ? slot - 1
                    : slot;
                return _Card(
                  face: game.faceOf(index),
                  up: _isUp(index),
                  matched: game.isMatched(index),
                  size: card,
                  onTap: () => _tap(index),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.face,
    required this.up,
    required this.matched,
    required this.size,
    required this.onTap,
  });

  final int face;
  final bool up;
  final bool matched;

  /// The side of this card, which everything drawn on it is scaled from.
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = memoryFaces[face % memoryFaces.length];
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: up ? 1 : 0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          // Past the halfway point the card has turned edge-on, so the front
          // takes over. The same trick a real flip plays on the eye.
          final showFront = t > 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(t * math.pi),
            child: showFront
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _Face(
                      icon: icon,
                      color: color,
                      matched: matched,
                      size: size,
                    ),
                  )
                : _Back(size: size),
          );
        },
      ),
    );
  }
}

/// The odd slot out on a grid whose deal does not fill it.
///
/// Drawn flat and unmistakably unlike a card back, so nobody spends a turn
/// trying to flip it: it holds the grid's shape, nothing more.
class _Emblem extends StatelessWidget {
  const _Emblem({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.2),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Center(
          child: Icon(
            Icons.redeem_rounded,
            color: Colors.white.withValues(alpha: 0.22),
            size: size * 0.42,
          ),
        ),
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.2),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x55000000),
            blurRadius: size * 0.14,
            offset: Offset(0, size * 0.07),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome_rounded,
          color: Colors.white.withValues(alpha: 0.4),
          size: size * 0.38,
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    required this.icon,
    required this.color,
    required this.matched,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final bool matched;
  final double size;

  @override
  Widget build(BuildContext context) {
    // The card wears the colour and the gift is drawn white on top of it.
    // A small tinted glyph on a white card was the other way round, and on a
    // seven-wide board it left the thing you actually have to remember as the
    // smallest mark on the card.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.38)!,
            color,
            extrusionShade(color, 0.14),
          ],
          stops: const [0, 0.55, 1],
        ),
        border: Border.all(
          color: matched ? Colors.white : Colors.white.withValues(alpha: 0.55),
          width: matched ? (size * 0.05).clamp(1.5, 3.0) : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: matched ? 0.6 : 0.3),
            blurRadius: size * (matched ? 0.3 : 0.16),
            spreadRadius: matched ? size * 0.02 : 0,
            offset: Offset(0, size * 0.07),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // A soft disc behind the gift, so the glyph reads against the
          // lighter top-left of the card as clearly as the darker foot.
          Container(
            width: size * 0.76,
            height: size * 0.76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          Icon(
            icon,
            color: Colors.white,
            size: size * 0.62,
            shadows: [
              Shadow(
                color: extrusionShade(color, 0.3).withValues(alpha: 0.7),
                blurRadius: size * 0.06,
                offset: Offset(0, size * 0.03),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
