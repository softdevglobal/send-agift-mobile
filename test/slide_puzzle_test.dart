import 'package:flutter_test/flutter_test.dart';

import 'package:send_agift_mobile/features/games/domain/game_engine.dart';
import 'package:send_agift_mobile/features/games/domain/slide_puzzle.dart';

void main() {
  test('cross-language golden: same scramble and solution as the Go engine', () {
    // Mirrors TestSlideCrossLanguageGolden in internal/games/slide_test.go.
    final puzzle = SlidePuzzle(seed: 'cafebabe');
    expect(puzzle.board, [9, 14, 1, 11, 10, 0, 4, 3, 8, 6, 2, 7, 13, 5, 15, 12]);

    // The optimal solution for this scramble. No shorter one exists. So the
    // score is the most this board can pay.
    const solution =
        'down,left,left,up,right,up,right,up,left,down,right,down,left,up,up,'
        'right,down,right,down,down,left,up,left,up,right,right,down,left,'
        'left,down,left,up,up,right,down,left,up,up';
    for (final move in solution.split(',')) {
      expect(puzzle.move(move), isTrue, reason: 'move $move should be legal');
    }

    expect(puzzle.solved, isTrue);
    expect(puzzle.score, 13240);
    expect(puzzle.moves.join(','), solution);
  });

  test('a scramble is a valid, unsolved permutation', () {
    final puzzle = SlidePuzzle(seed: 'a1b2c3d4');
    expect(puzzle.solved, isFalse);
    expect(puzzle.moves, isEmpty, reason: 'scrambling is not player moves');
    expect(
      [...puzzle.board]..sort(),
      List.generate(16, (i) => i),
    );
    expect(SlidePuzzle(seed: 'a1b2c3d4').board, puzzle.board);
  });

  test('tapping a tile further along the line slides every tile between', () {
    final puzzle = SlidePuzzle(seed: 'cafebabe');
    // Gap at index 5: second row, second column. Index 4 is left of it.
    expect(puzzle.blank, 5);

    expect(puzzle.moveTileAt(4), isTrue);
    expect(puzzle.moves, [Move.right]);
    expect(puzzle.blank, 4);

    // Gap now at the left of that row; tapping the far right tile of the
    // same row pushes all three tiles between them left.
    expect(puzzle.moveTileAt(7), isTrue);
    expect(puzzle.moves, [Move.right, Move.left, Move.left, Move.left]);
    expect(puzzle.blank, 7);
  });

  test('tapping a tile out of line with the gap does nothing', () {
    final puzzle = SlidePuzzle(seed: 'cafebabe');
    expect(puzzle.moveTileAt(0), isFalse);
    expect(puzzle.moves, isEmpty);
  });

  test('an unsolved board scores nothing', () {
    final puzzle = SlidePuzzle(seed: 'cafebabe');
    puzzle.move(Move.left);
    expect(puzzle.score, 0);
  });

  test('config parsing falls back exactly like the backend', () {
    // A size below two is not a puzzle, so both sides fall back to the
    // default board rather than trying to deal it.
    final config = SlideConfig.fromJson(const {'size': 1});
    expect(config.size, const SlideConfig().size);
    // Missing penalty is 0 on the server, so it must be here too.
    expect(config.movePenalty, 0);
  });
}
