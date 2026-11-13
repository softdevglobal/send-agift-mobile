import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:send_agift_mobile/features/games/data/games_providers.dart';
import 'package:send_agift_mobile/features/games/domain/competition.dart';
import 'package:send_agift_mobile/features/games/domain/quiz_game.dart';
import 'package:send_agift_mobile/features/games/presentation/game_definitions.dart';
import 'package:send_agift_mobile/features/games/presentation/screens/game_play_screen.dart';

import 'support/fake_games_repository.dart';

const _config = {
  'questions': [
    {
      'prompt': '2 + 2?',
      'options': ['3', '4'],
      'time_limit_ms': 10000,
    },
    {
      'prompt': 'Largest ocean?',
      'options': ['Atlantic', 'Pacific', 'Indian'],
      'time_limit_ms': 2000,
    },
  ],
};

Future<void> _frames(WidgetTester tester, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  test('the quiz engine records answers and time-outs, never scores', () {
    final game = QuizGame(config: _config);
    expect(game.questions, hasLength(2));
    game.answer(1, 1234);
    game.answer(-1, 99999);
    expect(game.moves, ['0:1:1234', '1:-1:2000']);
    expect(game.isOver, isTrue);
    expect(game.answered, 1);
  });

  testWidgets('an official quiz submits its answers with no client score', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final repo = FakeGamesRepository()
      ..officialConfig = _config
      ..quizScore = 140
      ..competitions = [
        Competition(
          id: 'c1',
          title: 'Friday Quiz',
          status: 'live',
          gameSlug: 'quiz',
          gameName: 'Quiz',
          countryName: 'New Zealand',
          startsAt: DateTime.now().subtract(const Duration(hours: 1)),
          endsAt: DateTime.now().add(const Duration(hours: 1)),
          entriesPerAttempt: 0,
          entriesDeductionEnabled: true,
          maxAttempts: 3,
          minAge: 18,
          requiresIdentityVerification: false,
          numberOfWinners: 1,
          prizeDescription: 'Voucher',
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gamesRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: GamePlayScreen(
            definition: gameDefinitions['quiz']!,
            competitionId: 'c1',
          ),
        ),
      ),
    );
    await _frames(tester);
    expect(find.text('2 + 2?'), findsOneWidget);

    await tester.tap(find.text('4'));
    await _frames(tester);
    expect(find.text('Largest ocean?'), findsOneWidget);

    // Let the second question's two seconds run out.
    await _frames(tester, 3000);

    expect(repo.lastMoves, hasLength(2));
    expect(repo.lastMoves!.first, startsWith('0:1:'));
    expect(repo.lastMoves!.last, startsWith('1:-1:'));
    expect(repo.clientScores.single, isNull);
  });
}
