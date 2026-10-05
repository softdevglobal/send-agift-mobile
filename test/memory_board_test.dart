import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:send_agift_mobile/features/games/domain/memory_match.dart';
import 'package:send_agift_mobile/features/games/presentation/game_controls.dart';
import 'package:send_agift_mobile/features/games/presentation/widgets/memory_board.dart';

void main() {
  test('every pair on the board gets a look of its own', () {
    // The grid deals one face value per pair, and the board draws a face by
    // indexing this palette. Fewer looks than pairs means two different pairs
    // are drawn identically. You would turn over a matching-looking card and
    // be told it is not a match, which no amount of memory can beat.
    const config = MemoryConfig();
    expect(
      memoryFaces.length,
      greaterThanOrEqualTo(config.pairs),
      reason:
          'a ${config.columns}-wide board deals ${config.pairs} pairs but only '
          '${memoryFaces.length} looks exist, so pairs would share a face',
    );
  });

  test('a white gift reads on every card', () {
    // The card carries the colour and the gift is drawn white on top of it,
    // so a pale card leaves the one thing worth remembering invisible.
    double channel(double c) =>
        c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

    for (final (icon, color) in memoryFaces) {
      final luminance =
          0.2126 * channel(color.r) +
          0.7152 * channel(color.g) +
          0.0722 * channel(color.b);
      final contrast = 1.05 / (luminance + 0.05);
      expect(
        contrast,
        greaterThanOrEqualTo(3.0),
        reason: 'white on ${icon.codePoint} is only '
            '${contrast.toStringAsFixed(2)}:1',
      );
    }
  });

  test('no two faces share a colour', () {
    final colours = memoryFaces.map((f) => f.$2.toARGB32()).toSet();
    expect(colours, hasLength(memoryFaces.length));
  });

  test('no two faces are drawn the same way', () {
    final seen = <String>{};
    for (final (icon, color) in memoryFaces) {
      final key = '${icon.codePoint}:${color.toARGB32()}';
      expect(seen.add(key), isTrue, reason: 'duplicate face look: $key');
    }
  });

  test('the deal fills its grid, give or take one emblem slot', () {
    // 49 cards could never all have pairs, so a 7x7 board is 48 cards plus one
    // emblem. Any bigger shortfall would leave real holes in the grid.
    const config = MemoryConfig();
    final game = MemoryMatch(seed: 'cafebabe', config: config);
    final slots = config.columns * game.rows;
    expect(slots - game.cardCount, lessThanOrEqualTo(1));
    expect(game.cardCount.isEven, isTrue);
  });

  testWidgets('a full board lays out without overflowing a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(750, 1334); // iPhone SE
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final game = MemoryMatch(seed: 'cafebabe', config: const MemoryConfig());
    const config = MemoryConfig();
    expect(game.cardCount, config.pairs * 2);
    // Seven rows of seven: the 48 cards plus the centre emblem.
    expect(game.rows, 7);
    expect(config.columns, 7);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: MemoryBoard(
              game: game,
              controls: GameControls(active: true, onChanged: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Every card is laid out, and none of them has collapsed to nothing.
    final cards = tester.widgetList(find.byType(GestureDetector)).length;
    expect(cards, greaterThanOrEqualTo(game.cardCount));
  });

  testWidgets('the emblem holds a slot without becoming a card', (
    tester,
  ) async {
    final game = MemoryMatch(seed: 'cafebabe', config: const MemoryConfig());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemoryBoard(
            game: game,
            controls: GameControls(active: true, onChanged: () {}),
          ),
        ),
      ),
    );

    // Only the real cards are tappable. The emblem is not one of them.
    expect(find.byType(GestureDetector), findsNWidgets(game.cardCount));

    // The card after the emblem's slot must still be its own card, not the
    // one before it: an off-by-one here would flip the wrong card entirely.
    await tester.tap(
      find.byType(GestureDetector).at(game.cardCount - 1),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(game.pending, game.cardCount - 1);
  });

  testWidgets('tapping two cards of the same face pairs them', (tester) async {
    final game = MemoryMatch(seed: 'cafebabe', config: const MemoryConfig());
    // Find a genuine pair from the deal, so the test asserts the rules rather
    // than a guess about where the cards landed.
    final first = 0;
    final face = game.faceOf(first);
    final second = List.generate(game.cardCount, (i) => i).firstWhere(
      (i) => i != first && game.faceOf(i) == face,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemoryBoard(
            game: game,
            controls: GameControls(active: true, onChanged: () {}),
          ),
        ),
      ),
    );

    final cardFinder = find.byType(GestureDetector);
    await tester.tap(cardFinder.at(first), warnIfMissed: false);
    await tester.pump();
    await tester.tap(cardFinder.at(second), warnIfMissed: false);
    await tester.pump();

    expect(game.matches, 1);
    expect(game.isMatched(first), isTrue);
    expect(game.isMatched(second), isTrue);
  });
}
