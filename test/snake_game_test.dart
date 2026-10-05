import 'package:flutter_test/flutter_test.dart';

import 'package:send_agift_mobile/features/games/domain/game_engine.dart';
import 'package:send_agift_mobile/features/games/domain/snake_game.dart';

/// Produced by a bot on the backend (`internal/games/snake_test.go`,
/// TestSnakeCrossLanguageGolden). Both engines must replay it identically.
const _goldenLog =
    '0:down,1:left,6:down,12:right,14:up,16:left,19:up,21:right,31:up,35:left,'
    '46:up,51:right,54:down,66:right,77:up,87:left,93:down,100:right,104:up,'
    '106:left,110:down,115:left,121:up,122:right,131:up,139:left,144:down,'
    '154:right,162:up,163:left,177:up,185:right,197:down,202:right,204:up,'
    '206:left,207:up,211:left,221:up,223:right,226:down,227:left,230:end';

void main() {
  test('cross-language golden: replays exactly like the Go engine', () {
    final entries = _goldenLog.split(',');
    final end = int.parse(entries.last.split(':').first);
    final turns = <int, String>{
      for (final e in entries.take(entries.length - 1))
        int.parse(e.split(':')[0]): e.split(':')[1],
    };

    final game = SnakeGame(seed: 'cafebabe');
    for (var t = 0; t < end && !game.isOver; t++) {
      final dir = turns[t];
      if (dir != null) game.turn(dir);
      game.step();
    }

    expect(game.score, 190);
    expect(game.foods, 19);
    expect(game.ticks, 230);
    expect(game.dead, isTrue);
    expect(game.body, [
      49, 50, 51, 36, 35, 34, 33, 48, 63, 64, 65, //
      66, 67, 68, 69, 70, 71, 72, 73, 88, 103, 118,
    ]);
    expect(game.food, 215);

    // And the app would submit exactly the log the server replayed.
    expect(game.moves.join(','), _goldenLog);
  });

  test('starts centred, facing right, with food off the snake', () {
    final game = SnakeGame(seed: '00000001');
    expect(game.body, [7 * 15 + 7, 7 * 15 + 6, 7 * 15 + 5]);
    expect(game.heading, Move.right);
    expect(game.body, isNot(contains(game.food)));
  });

  test('driving straight hits the wall on the eighth tick', () {
    final game = SnakeGame(seed: '00000001');
    while (!game.isOver) {
      game.step();
    }
    expect(game.dead, isTrue);
    expect(game.ticks, 8);
  });

  test('reversing into itself is ignored and never logged', () {
    final game = SnakeGame(seed: '00000001');
    expect(game.turn(Move.left), isFalse);
    expect(game.turn(Move.right), isFalse, reason: 'already heading right');
    game.step();
    expect(game.heading, Move.right);
    expect(game.moves, ['1:end']);
  });

  test('a turn is logged against the tick it takes effect on', () {
    final game = SnakeGame(seed: '00000001');
    game
      ..step()
      ..step();
    expect(game.turn(Move.up), isTrue);
    // Queued, but not played yet. So not in the log.
    expect(game.moves, ['2:end']);

    game.step();
    expect(game.moves, ['2:up', '3:end']);
    expect(game.heading, Move.up);
  });

  test('only the last turn before a tick counts', () {
    final game = SnakeGame(seed: '00000001');
    game
      ..turn(Move.up)
      ..turn(Move.down)
      ..step();
    expect(game.moves, ['0:down', '1:end']);
  });

  test('opens at a walk, and quickens as it eats and as time passes', () {
    const config = SnakeConfig();
    final game = SnakeGame(seed: '00000001');
    expect(game.tickIntervalMs, config.tickMs);

    // A gift takes milliseconds off the tick, and so does the passing of
    // time on its own, both down to the same floor.
    expect(config.speedupMsPerFood, greaterThan(0));
    expect(config.speedupEveryTicks, greaterThan(0));
    expect(config.minTickMs, lessThan(config.tickMs));
  });

  test('the pace matches the server tick for tick', () {
    // The server works out the same pace and derives from it the least time a
    // round could have taken. Drift between the two and the faster one has
    // its scores thrown out for arriving too quickly. These are the same
    // numbers TestSnakePaceIsPinnedForTheClient pins in the Go engine.
    const config = SnakeConfig();
    for (final (foods, ticks, want) in const [
      (0, 0, 300),
      (2, 45, 275),
      (5, 90, 238),
      (10, 90, 178), // five more gifts is worth far more than the drift
      (50, 3000, 70), // the floor
    ]) {
      expect(
        snakeTickIntervalMs(config, foods: foods, ticks: ticks),
        want,
        reason: '$foods gifts and $ticks ticks',
      );
    }
  });

  test('config parsing falls back exactly like the backend', () {
    final config = SnakeConfig.fromJson(const {'grid_size': 3});
    expect(config.gridSize, 15, reason: 'grids under 5 fall back');
    // A missing speed-up is 0 on the server, so it must be here too.
    expect(config.speedupMsPerFood, 0);
    expect(
      SnakeConfig.fromJson(const {'grid_size': 9, 'start_length': 20})
          .startLength,
      5,
      reason: 'the start length is clamped to fit left of centre',
    );
  });
}
