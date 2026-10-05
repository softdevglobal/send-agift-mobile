import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:send_agift_mobile/features/games/domain/game_2048.dart';
import 'package:send_agift_mobile/features/games/presentation/game_controls.dart';
import 'package:send_agift_mobile/features/games/presentation/widgets/board_2048.dart';

Future<void> _pumpBoard(WidgetTester tester, Game2048 game) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: Board2048(
              game: game,
              controls: GameControls(active: true, onChanged: () {}),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Drags across the board at [speed] pixels per second, which is what decides
/// whether Flutter reports it as a flick or a slow haul.
Future<void> _drag(
  WidgetTester tester,
  Offset by, {
  double speed = 1000,
}) async {
  await tester.timedDragFrom(
    tester.getCenter(find.byType(Board2048)),
    by,
    Duration(milliseconds: (by.distance / speed * 1000).round().clamp(16, 4000)),
  );
  await tester.pump();
}

void main() {
  testWidgets('a flick moves the board', (tester) async {
    final game = Game2048(seed: 'deadbeef');
    await _pumpBoard(tester, game);

    await _drag(tester, const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(game.moves, isNotEmpty);
  });

  testWidgets('a slow, deliberate drag moves the board too', (tester) async {
    // The board used to demand a flick: below 90px/s nothing happened at all,
    // so careful play felt like the game was ignoring the swipe.
    final game = Game2048(seed: 'deadbeef');
    await _pumpBoard(tester, game);

    await _drag(tester, const Offset(-120, 0), speed: 40);
    await tester.pumpAndSettle();

    expect(
      game.moves,
      isNotEmpty,
      reason: 'a slow drag across the board did nothing',
    );
  });

  testWidgets('a stray touch that barely moves is not a swipe', (tester) async {
    final game = Game2048(seed: 'deadbeef');
    await _pumpBoard(tester, game);

    await _drag(tester, const Offset(-4, 0), speed: 20);
    await tester.pumpAndSettle();

    expect(game.moves, isEmpty);
  });

  testWidgets('tiles slide to their new squares instead of jumping', (
    tester,
  ) async {
    final game = Game2048(seed: 'deadbeef');
    await _pumpBoard(tester, game);

    // Where every tile sits before the move.
    Set<Offset> tilePositions() => tester
        .widgetList<Positioned>(find.byType(Positioned))
        .map((p) => Offset(p.left ?? 0, p.top ?? 0))
        .toSet();
    final settled = tilePositions();

    await _drag(tester, const Offset(-120, 0));
    // Part-way through the slide the tiles must be between squares. If they
    // teleported, every position would already be one of the settled ones.
    await tester.pump(const Duration(milliseconds: 45));

    final midFlight = tilePositions().difference(settled);
    expect(
      midFlight,
      isNotEmpty,
      reason: 'no tile was caught between two squares',
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the board settles on exactly what the engine holds', (
    tester,
  ) async {
    final game = Game2048(seed: 'a1b2c3d4');
    await _pumpBoard(tester, game);

    for (final by in const [
      Offset(-120, 0),
      Offset(0, -120),
      Offset(120, 0),
      Offset(0, 120),
    ]) {
      await _drag(tester, by);
      await tester.pumpAndSettle();
    }

    // Once the dust settles the drawn tiles are the engine's board, no more
    // and no fewer. A slide left behind would be a tile that does not exist.
    final drawn = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => int.parse(t.data!))
        .toList()
      ..sort();
    final expected = game.board.where((v) => v != 0).toList()..sort();

    expect(drawn, expected);
    expect(tester.takeException(), isNull);
  });
}
