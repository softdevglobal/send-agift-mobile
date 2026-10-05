import 'package:flutter_test/flutter_test.dart';

import 'package:send_agift_mobile/features/games/domain/game_2048.dart';

/// The app's 2048 engine has to agree with the backend's exactly. The server
/// replays every submitted round from the same seed, so any drift between the
/// two implementations would flag honest players as cheats.
///
/// The golden numbers below are copied from the Go test
/// `internal/games/game2048_test.go`. If one side changes, both fail.
void main() {
  group('DeterministicRng', () {
    test('matches the backend PRNG sequence', () {
      final rng = DeterministicRng(1);
      final got = List<int>.generate(8, (_) => rng.next());

      expect(got, <int>[
        1015568748,
        1586005467,
        2165703038,
        3027450565,
        217083232,
        1587069247,
        3327581586,
        2388811721,
      ]);
    });

    test('stays inside 32 bits', () {
      final rng = DeterministicRng(0xFFFFFFFF);
      for (var i = 0; i < 1000; i++) {
        final v = rng.next();
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThanOrEqualTo(0xFFFFFFFF));
      }
    });

    test('reads a hex seed', () {
      expect(DeterministicRng.fromSeed('0000000f').next(),
          DeterministicRng(15).next());
    });
  });

  group('Game2048', () {
    test('the same seed always deals the same opening board', () {
      final a = Game2048(seed: 'a1b2c3d4');
      final b = Game2048(seed: 'a1b2c3d4');

      expect(a.board, b.board);
      expect(Game2048(seed: 'ffffffff').board, isNot(a.board));
    });

    test('opens with exactly two tiles, each a 2 or a 4', () {
      final game = Game2048(seed: '12345678');
      final tiles = game.board.where((v) => v != 0).toList();

      expect(tiles, hasLength(2));
      for (final tile in tiles) {
        expect(tile, anyOf(2, 4));
      }
    });

    test('merging scores the merged value', () {
      // Drive a real game and check the score only ever grows by a merge.
      final game = Game2048(seed: 'deadbeef');
      var previous = game.score;

      for (var i = 0; i < 60 && !game.isGameOver; i++) {
        final dir = [
          Move.left,
          Move.up,
          Move.right,
          Move.down,
        ][i % 4];
        game.move(dir);

        final gained = game.score - previous;
        expect(gained, greaterThanOrEqualTo(0));
        if (gained > 0) {
          // Every merge produces a power of two of at least 4.
          expect(gained % 4, 0);
        }
        previous = game.score;
      }
      expect(game.score, greaterThan(0));
    });

    test('records only the moves that changed the board', () {
      // Swiping into a wall changes nothing, and those no-op swipes must not
      // reach the move log. The server would just replay them as no-ops.
      final game = Game2048(seed: 'cafebabe');

      var accepted = 0;
      var attempted = 0;
      for (var i = 0; i < 60; i++) {
        attempted++;
        if (game.move(Move.left)) accepted++;
      }

      expect(game.moves.length, accepted);
      expect(accepted, lessThan(attempted), reason: 'expected some no-ops');
      expect(game.moves.every((m) => m == Move.left), isTrue);
    });

    test('a replayed move list rebuilds the identical game', () {
      // This is what the server does. Playing a list of moves into a fresh
      // engine must land on the same board and score.
      final original = Game2048(seed: 'cafebabe');
      for (var i = 0; i < 80 && !original.isGameOver; i++) {
        original.move([
          Move.up,
          Move.left,
          Move.down,
          Move.right,
        ][i % 4]);
      }

      final replay = Game2048(seed: 'cafebabe');
      for (final move in original.moves) {
        replay.move(move);
      }

      expect(replay.score, original.score);
      expect(replay.board, original.board);
      expect(replay.highestTile, original.highestTile);
    });

    test('stops accepting moves once the board is dead', () {
      final game = Game2048(seed: '0badf00d');
      for (var i = 0; i < 5000 && !game.isGameOver; i++) {
        game.move([
          Move.left,
          Move.up,
          Move.right,
          Move.down,
        ][i % 4]);
      }

      if (!game.isGameOver) return; // board never filled; nothing to assert
      final movesAtEnd = game.moves.length;
      expect(game.move(Move.left), isFalse);
      expect(game.moves.length, movesAtEnd);
    });

    test('cross-language golden: matches the Go engine exactly', () {
      // The backend runs this same seed and direction cycle in
      // internal/games/game2048_test.go (TestCrossLanguageGolden) and asserts
      // the same numbers. If these two ever disagree, the server will start
      // flagging honest scores. Fix the drift rather than the constants.
      final game = Game2048(seed: 'cafebabe');
      const dirs = [
        Move.up,
        Move.left,
        Move.down,
        Move.right,
      ];
      for (var i = 0; i < 400 && !game.isGameOver; i++) {
        game.move(dirs[i % 4]);
      }

      expect(game.score, 2348);
      expect(game.highestTile, 256);
      expect(game.isGameOver, isTrue);
      expect(game.board, <int>[
        2, 16, 8, 2, //
        32, 4, 2, 8, //
        2, 64, 256, 16, //
        8, 16, 4, 2, //
      ]);
    });

    test('honours the config handed down by the server', () {
      final game = Game2048(
        seed: '00000001',
        config: const GameConfig2048(boardSize: 5, startTiles: 3),
      );

      expect(game.size, 5);
      expect(game.board, hasLength(25));
      expect(game.board.where((v) => v != 0), hasLength(3));
    });
  });

  group('tile travel', () {
    // The board slides tiles rather than redrawing them in their new homes,
    // and it takes the route from the engine. If these ever disagree with the
    // board itself, tiles would glide to the wrong squares.
    const dirs = [Move.left, Move.up, Move.right, Move.down];

    test('every tile is accounted for, and the slides rebuild the board', () {
      final game = Game2048(seed: 'deadbeef');

      for (var i = 0; i < 120 && !game.isGameOver; i++) {
        final before = game.board;
        if (!game.move(dirs[i % 4])) continue;
        final after = game.board;
        final slides = game.lastSlides;
        final spawn = game.lastSpawn;

        // One slide per tile that was on the board, no more and no fewer.
        final sources = slides.map((s) => s.from).toList()..sort();
        final occupied = [
          for (var j = 0; j < before.length; j++)
            if (before[j] != 0) j,
        ];
        expect(sources, occupied, reason: 'move $i lost or invented a tile');

        for (final slide in slides) {
          expect(slide.value, before[slide.from]);
        }

        // Laying every tile down at the end of its journey has to reproduce
        // the new board exactly. A merged pair summing to its double.
        // except at the square the new tile appeared on.
        final rebuilt = List<int>.filled(before.length, 0);
        for (final slide in slides) {
          rebuilt[slide.to] += slide.value;
        }
        for (var j = 0; j < after.length; j++) {
          if (j == spawn) {
            expect(rebuilt[j], 0, reason: 'a tile spawned on an occupied cell');
            expect(after[j], anyOf(2, 4));
          } else {
            expect(rebuilt[j], after[j], reason: 'move $i square $j');
          }
        }
      }
    });

    test('a tile never leaves its row or column', () {
      final game = Game2048(seed: 'a1b2c3d4');
      final size = game.size;

      for (var i = 0; i < 120 && !game.isGameOver; i++) {
        final dir = dirs[i % 4];
        if (!game.move(dir)) continue;

        for (final slide in game.lastSlides) {
          if (dir == Move.left || dir == Move.right) {
            expect(slide.from ~/ size, slide.to ~/ size, reason: 'changed row');
          } else {
            expect(slide.from % size, slide.to % size, reason: 'changed column');
          }
        }
      }
    });

    test('merges are reported in pairs landing on one square', () {
      final game = Game2048(seed: '12345678');

      for (var i = 0; i < 120 && !game.isGameOver; i++) {
        if (!game.move(dirs[i % 4])) continue;

        final merging = game.lastSlides.where((s) => s.merged).toList();
        final byTarget = <int, List<Tile2048Slide>>{};
        for (final slide in merging) {
          byTarget.putIfAbsent(slide.to, () => []).add(slide);
        }
        for (final entry in byTarget.entries) {
          // Exactly two tiles, of equal value: a tile that already merged
          // this move cannot merge again.
          expect(entry.value, hasLength(2));
          expect(entry.value[0].value, entry.value[1].value);
        }
      }
    });
  });
}
