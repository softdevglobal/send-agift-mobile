import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:send_agift_mobile/features/games/data/games_providers.dart';
import 'package:send_agift_mobile/features/games/domain/competition.dart';
import 'package:send_agift_mobile/features/games/presentation/screens/chance_play_screen.dart';
import 'package:send_agift_mobile/features/games/presentation/screens/competition_screen.dart';

import 'support/fake_games_repository.dart';

Future<void> _frames(WidgetTester tester, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Competition _round(String slug, {String method = 'instant', int? odds = 500}) {
  return Competition(
    id: 'c1',
    title: 'Jackpot Wheel',
    status: 'live',
    gameSlug: slug,
    gameName: 'Spin the Wheel',
    countryName: 'New Zealand',
    startsAt: DateTime.now().subtract(const Duration(hours: 1)),
    endsAt: DateTime.now().add(const Duration(hours: 5)),
    entriesPerAttempt: 5,
    entriesDeductionEnabled: true,
    maxAttempts: 10,
    minAge: 18,
    requiresIdentityVerification: true,
    numberOfWinners: 1,
    prizeDescription: 'Cash',
    prizeCurrency: 'NZD',
    startPrizeCents: 10000,
    currentPrizeCents: 10000,
    gameType: 'chance',
    winnerMethod: method,
    winOdds: odds,
    me: const CompetitionMe(
      attemptsUsed: 0,
      attemptsRemaining: 10,
      eligible: true,
      entriesBalance: 100,
    ),
  );
}

Future<FakeGamesRepository> _pump(WidgetTester tester, Competition c, Widget home) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final repo = FakeGamesRepository()..competitions = [c];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gamesRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: home),
    ),
  );
  await _frames(tester);
  return repo;
}

void main() {
  testWidgets('a chance round says it is chance and shows its odds', (tester) async {
    await _pump(tester, _round('spin-wheel'), const CompetitionScreen(competitionId: 'c1'));
    expect(find.textContaining('This is a game of chance'), findsOneWidget);
    expect(find.textContaining('Chance plays no part'), findsNothing);
    expect(find.textContaining('Each play wins 1 in 500'), findsWidgets);
    expect(find.text('Play now · 5 entries'), findsOneWidget);
  });

  testWidgets('a winning spin reveals the win after the wheel stops', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final repo = FakeGamesRepository()
      ..competitions = [_round('spin-wheel')]
      ..chanceResult = const ChanceResult(
        mechanic: 'spin',
        won: true,
        odds: 500,
        draw: 0,
        segment: 0,
        segments: 8,
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gamesRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ChancePlayScreen(competitionId: 'c1')),
      ),
    );
    await _frames(tester);
    expect(repo.playKeys, hasLength(1));
    expect(find.textContaining('You won'), findsNothing, reason: 'nothing shown before the spin');

    await tester.tap(find.text('Spin'));
    await _frames(tester, 4200);
    expect(find.textContaining('You won'), findsOneWidget);
    expect(find.textContaining('draw 0'), findsOneWidget);
  });

  testWidgets('a prize-draw play is an entry ticket', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final repo = FakeGamesRepository()
      ..competitions = [_round('prize-draw', method: 'draw', odds: null)]
      ..chanceResult = const ChanceResult(mechanic: 'draw', won: false, entryNumber: 42);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gamesRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ChancePlayScreen(competitionId: 'c1')),
      ),
    );
    await _frames(tester);
    expect(find.text('#42'), findsOneWidget);
    expect(find.text("You're in the draw!"), findsOneWidget);
  });
}
