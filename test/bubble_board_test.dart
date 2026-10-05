import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:send_agift_mobile/features/games/domain/bubble_shooter.dart';
import 'package:send_agift_mobile/features/games/presentation/game_controls.dart';
import 'package:send_agift_mobile/features/games/presentation/widgets/bubble_board.dart';

const _config = BubbleConfig();

Future<void> _pumpBoard(WidgetTester tester, BubbleShooter game) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BubbleBoard(
          game: game,
          controls: GameControls(active: true, onChanged: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The screen point for a spot on the board, given in cells from its
/// top-left.
///
/// The board is drawn through a perspective tilt, so screen coordinates do
/// not map linearly onto the cells. Going through the board's own render box
/// applies the same transform the hit test will undo.
Offset _at(WidgetTester tester, double col, double row) {
  final box = tester.renderObject<RenderBox>(
    find.descendant(
      of: find.byType(BubbleBoard),
      matching: find.byType(AspectRatio),
    ),
  );
  final cell = box.size.width / _config.columns;
  return box.localToGlobal(Offset(col * cell, row * cell));
}

/// The middle of the queue under the board. The ball itself.
Offset _queueCentre(WidgetTester tester) =>
    tester.getRect(find.byKey(bubbleSwapKey)).center;

/// The point to drag to so the board reads off a particular aim. The board
/// takes the line from the launcher. Bottom centre. Out to the finger, so
/// this inverts that at a height chosen to keep the point on the board even
/// for the flattest aims.
Offset _dragFor(WidgetTester tester, int aim) {
  final reach = (_config.columns / 2 - 0.05) * 1000;
  final rise = aim == 0 ? 4.0 : math.min(4.0, reach / aim.abs());
  final col = _config.columns / 2 + aim * rise / 1000;
  return _at(tester, col, _config.rows - rise);
}

/// Replays a line of play onto a fresh game.
BubbleShooter _replay(List<int> aims) {
  final game = BubbleShooter(seed: 'cafebabe', config: _config);
  for (final aim in aims) {
    game.shoot(aim);
  }
  return game;
}

/// The middle of the widest run of aims that all pop from this position.
///
/// A single aim will not do: the board is drawn through a perspective tilt,
/// and Flutter resolves a touch back through it assuming z=0, so a point and
/// its round trip differ by a little. Aiming at the middle of a band leaves
/// room for that.
int? _widestPoppingAim(List<int> played) {
  var bestStart = 0;
  var bestRun = 0;
  var runStart = 0;
  var run = 0;
  for (var dx = -bubbleMaxAim; dx <= bubbleMaxAim; dx += 20) {
    if (_replay(played).shoot(dx).isNotEmpty) {
      if (run == 0) runStart = dx;
      run++;
      if (run > bestRun) {
        bestRun = run;
        bestStart = runStart;
      }
    } else {
      run = 0;
    }
  }
  if (bestRun == 0) return null;
  return bestStart + (bestRun - 1) * 20 ~/ 2;
}

/// Plays the engine forward until a shot pops something, and returns the aims
/// that got there. A pop needs real play, so a single repeated aim will not
/// find one.
List<int> _aimsUntilAPop() {
  final game = BubbleShooter(seed: 'cafebabe', config: _config);
  final aims = <int>[];
  for (var turn = 0; turn < 40 && !game.isOver; turn++) {
    var chosen = 0;
    for (var dx = -bubbleMaxAim; dx <= bubbleMaxAim; dx += 100) {
      final probe = BubbleShooter(seed: 'cafebabe', config: _config);
      for (final aim in aims) {
        probe.shoot(aim);
      }
      if (probe.shoot(dx).isNotEmpty) {
        chosen = dx;
        break;
      }
    }
    aims.add(chosen);
    if (game.shoot(chosen).isNotEmpty) return aims;
  }
  return const [];
}

void main() {
  group('the engine', () {
    test('an aim steers where the bubble lands', () {
      final game = BubbleShooter(seed: 'cafebabe', config: _config);
      final landed = <int>{};
      for (var dx = -bubbleMaxAim; dx <= bubbleMaxAim; dx += 100) {
        final shot = game.trace(dx);
        expect(shot.ok, isTrue, reason: 'aim $dx found nowhere to land');
        expect(
          game.at(shot.row, shot.col),
          -1,
          reason: 'aim $dx landed on an occupied cell',
        );
        landed.add(shot.col);
      }
      // If every aim came to rest in one column the game would be a tap in
      // disguise, which is what angled shooting was meant to fix.
      expect(landed.length, greaterThanOrEqualTo(3));
    });

    test('the traced path is the flight, bounces included', () {
      final game = BubbleShooter(seed: 'cafebabe', config: _config);
      final flat = game.trace(bubbleMaxAim);
      // A bank off the wall turns the path, so a flat shot has more corners
      // in it than a straight one, which flies in a single line.
      expect(flat.path.length, greaterThan(game.trace(0).path.length));
      for (final point in flat.path) {
        expect(point.dx, inInclusiveRange(0, _config.columns.toDouble()));
      }
    });

    test('swapping exchanges the queue without drawing a new colour', () {
      final game = BubbleShooter(seed: 'cafebabe', config: _config);
      final first = game.next;
      final second = game.after;
      expect(game.swap(), isTrue);
      expect(game.next, second);
      expect(game.after, first);
      expect(game.moves, [bubbleSwapMove]);
    });

    test('a pop reports the cells that burst', () {
      // Played with full knowledge, so the log is one that actually pops
      // rather than a guess that might not.
      final game = BubbleShooter(seed: 'cafebabe', config: _config);
      List<List<int>> burst = const [];
      for (var i = 0; i < 40 && !game.isOver; i++) {
        for (var dx = -bubbleMaxAim; dx <= bubbleMaxAim; dx += 200) {
          final probe = BubbleShooter(seed: 'cafebabe', config: _config);
          for (final m in game.moves) {
            if (m == bubbleSwapMove) {
              probe.swap();
            } else {
              probe.shoot(int.parse(m));
            }
          }
          if (probe.shoot(dx).isNotEmpty) {
            burst = game.shoot(dx);
            break;
          }
        }
        if (burst.isNotEmpty) break;
        game.shoot(0);
      }
      expect(burst, isNotEmpty, reason: 'no shot ever popped anything');
      expect(game.pops, greaterThanOrEqualTo(burst.length));
    });
  });

  group('the board', () {
    testWidgets('shows what is loaded, what is next, and how to fire', (
      tester,
    ) async {
      final game = BubbleShooter(seed: 'cafebabe', config: _config);
      await _pumpBoard(tester, game);

      expect(find.text('Drag to aim · tap the pair to swap'), findsOneWidget);
      // Two bubbles in the queue: the loaded one and the one behind it.
      expect(find.byType(AnimatedSwitcher), findsNWidgets(2));
    });

    testWidgets('the loaded bubble is drawn at a readable size', (
      tester,
    ) async {
      final game = BubbleShooter(seed: 'cafebabe', config: _config);
      await _pumpBoard(tester, game);

      // It was a 34px swatch that collapsed to 3px under the switcher's loose
      // constraints and read as an empty ring on a phone.
      final loaded = tester.getSize(
        find
            .descendant(
              of: find.byType(AnimatedSwitcher),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(loaded.width, greaterThanOrEqualTo(48));
    });

    testWidgets('dragging aims without firing, and lifting fires', (
      tester,
    ) async {
      final game = BubbleShooter(seed: 'cafebabe', config: _config);
      await _pumpBoard(tester, game);

      final gesture = await tester.startGesture(_at(tester, 5.5, 6));
      await tester.pump();

      // Holding an aim must not spend a shot. Firing on touch-down would
      // make aiming impossible.
      expect(game.shots, 0);
      expect(find.text('Release to fire'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(game.shots, 1);
      expect(game.moves.single, isNot(bubbleSwapMove));
    });

    testWidgets('aiming left and right sends the shot different ways', (
      tester,
    ) async {
      final left = BubbleShooter(seed: 'cafebabe', config: _config);
      await _pumpBoard(tester, left);
      var gesture = await tester.startGesture(_at(tester, 0.5, 6));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final right = BubbleShooter(seed: 'cafebabe', config: _config);
      await _pumpBoard(tester, right);
      gesture = await tester.startGesture(_at(tester, 6.5, 6));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        int.parse(left.moves.single),
        lessThan(int.parse(right.moves.single)),
        reason: 'dragging left must aim left of dragging right',
      );
    });

    testWidgets('pulling down from the ball aims the opposite way', (
      tester,
    ) async {
      // Holding the ball and dragging down is how a catapult is aimed, and
      // it used to do nothing at all: touches at or below the launcher were
      // ignored, so the aim never appeared.
      final left = BubbleShooter(seed: 'cafebabe', config: _config);
      await _pumpBoard(tester, left);
      var gesture = await tester.startGesture(_queueCentre(tester));
      await tester.pump();
      // Pull down and to the left, which should send the shot up and right.
      await gesture.moveTo(_at(tester, 1.0, _config.rows + 2.0));
      await tester.pump();
      expect(find.text('Release to fire'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();

      final right = BubbleShooter(seed: 'cafebabe', config: _config);
      await _pumpBoard(tester, right);
      gesture = await tester.startGesture(_queueCentre(tester));
      await tester.pump();
      await gesture.moveTo(_at(tester, 6.0, _config.rows + 2.0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(left.shots, 1);
      expect(right.shots, 1);
      expect(
        int.parse(left.moves.single),
        greaterThan(int.parse(right.moves.single)),
        reason: 'pulling left must send the shot right, and the other way',
      );
    });

    testWidgets('tapping the queue exchanges the two bubbles', (tester) async {
      final game = BubbleShooter(seed: 'cafebabe', config: _config);
      final first = game.next;
      final second = game.after;
      await _pumpBoard(tester, game);

      await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
      await tester.pumpAndSettle();

      expect(game.next, second);
      expect(game.after, first);
    });

    testWidgets('tapping the next bubble itself swaps it in', (tester) async {
      // Reaching for the bubble you want is the obvious move. It used to do
      // nothing, because only the small icon between the two was live.
      final game = BubbleShooter(seed: 'cafebabe', config: _config);
      final first = game.next;
      final second = game.after;
      await _pumpBoard(tester, game);

      final queue = tester.getRect(find.byKey(bubbleSwapKey));
      await tester.tapAt(Offset(queue.right - 8, queue.center.dy));
      await tester.pumpAndSettle();

      expect(game.next, second);
      expect(game.after, first);
    });

    testWidgets('the swap target is big enough to hit on a phone', (
      tester,
    ) async {
      final game = BubbleShooter(seed: 'cafebabe', config: _config);
      await _pumpBoard(tester, game);

      // It was a 34px icon at the bottom edge of the screen, under the
      // 44px a touch target needs. The padded queue is the region the board
      // treats as a swap, so that is what has to be big enough.
      final target = tester
          .getSize(
            find
                .ancestor(
                  of: find.byKey(bubbleSwapKey),
                  matching: find.byType(Padding),
                )
                .first,
          );
      expect(target.height, greaterThanOrEqualTo(44));
      expect(target.width, greaterThanOrEqualTo(44));
    });

    testWidgets('swapping is logged so the server replays it', (tester) async {
      final game = BubbleShooter(seed: 'cafebabe', config: _config);
      await _pumpBoard(tester, game);

      await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
      await tester.pumpAndSettle();

      expect(game.moves, [bubbleSwapMove]);
    });

    testWidgets('a pop is shown bursting instead of vanishing', (tester) async {
      final aims = _aimsUntilAPop();
      expect(aims, isNotEmpty, reason: 'no line of play on this board pops');

      // Play everything up to the popping shot straight on the engine, so the
      // test is about how the board draws a burst, not about steering.
      final played = aims.sublist(0, aims.length - 1);
      final game = _replay(played);
      final aim = _widestPoppingAim(played);
      expect(aim, isNotNull, reason: 'nothing pops from this position');

      await _pumpBoard(tester, game);
      final quiet = tester.widgetList(find.byType(CustomPaint)).length;

      final gesture = await tester.startGesture(_dragFor(tester, aim!));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(game.pops, greaterThan(0), reason: 'the drag did not pop');

      // While the burst runs there is more being painted than at rest, and it
      // is cleared up once the animation finishes.
      expect(
        tester.widgetList(find.byType(CustomPaint)).length,
        greaterThan(quiet),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widgetList(find.byType(CustomPaint)).length,
        lessThanOrEqualTo(quiet),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
