import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:send_agift_mobile/core/errors/app_exception.dart';
import 'package:send_agift_mobile/features/games/data/games_providers.dart';
import 'package:send_agift_mobile/features/games/domain/competition.dart';
import 'package:send_agift_mobile/features/games/domain/game.dart';
import 'package:send_agift_mobile/features/games/presentation/game_definitions.dart';
import 'package:send_agift_mobile/features/games/presentation/screens/competition_screen.dart';
import 'package:send_agift_mobile/features/games/presentation/screens/game_play_screen.dart';

import 'support/fake_games_repository.dart';

/// Countdowns and the live pulse run forever, so frames are pumped for a
/// fixed time instead of pumpAndSettle.
Future<void> _frames(WidgetTester tester, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void _usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Competition _competition({
  String status = 'live',
  CompetitionMe? me,
  List<PublicWinner> winners = const [],
  bool growing = false,
  bool continueAtCap = true,
  int currentPrizeCents = 5000,
}) {
  return Competition(
    id: 'c1',
    title: 'Spring 2048 Cup',
    status: status,
    gameSlug: '2048',
    gameName: '2048',
    countryName: 'New Zealand',
    startsAt: DateTime.now().subtract(const Duration(hours: 1)),
    endsAt: DateTime.now().add(const Duration(hours: 5)),
    entriesPerAttempt: 50,
    entriesDeductionEnabled: false,
    maxAttempts: 3,
    minAge: 18,
    requiresIdentityVerification: true,
    numberOfWinners: 1,
    prizeDescription: r'NZ$50 gift card',
    prizeValueAmount: 5000,
    prizeCurrency: 'NZD',
    officialRules: 'Highest verified score wins.',
    me: me,
    winners: winners,
    prizeGrowthEnabled: growing,
    startPrizeCents: 5000,
    currentPrizeCents: currentPrizeCents,
    incrementPerPlayCents: growing ? 100 : 0,
    maxPrizeCents: growing ? 50000 : null,
    prizeCapReached: growing && currentPrizeCents >= 50000,
    continueAtCap: continueAtCap,
    eligiblePlayCount: growing ? 248 : 0,
  );
}

const _eligible = CompetitionMe(
  attemptsUsed: 1,
  attemptsRemaining: 2,
  eligible: true,
  entriesBalance: 120,
);

Future<FakeGamesRepository> _openCompetition(
  WidgetTester tester,
  Competition competition, {
  CompetitionLeaderboard? board,
  List<DeliveryAddress> addresses = const [],
}) async {
  _usePhoneScreen(tester);
  final repo = FakeGamesRepository()
    ..competitions = [competition]
    ..addresses = addresses;
  if (board != null) repo.board = board;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gamesRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: CompetitionScreen(competitionId: 'c1')),
    ),
  );
  await _frames(tester);
  return repo;
}

void main() {
  group('Competition screen', () {
    testWidgets('shows the prize, the required disclosures and the board', (
      tester,
    ) async {
      await _openCompetition(
        tester,
        _competition(me: _eligible),
        board: const CompetitionLeaderboard(
          status: 'live',
          isFinal: false,
          totalPlayers: 2,
          entries: [
            LeaderboardEntry(
              rank: 1,
              displayName: 'Sarah M.',
              score: 900,
              countryName: 'New Zealand',
              durationMs: 61000,
              status: 'provisional',
            ),
            LeaderboardEntry(
              rank: 2,
              displayName: 'Ben C.',
              score: 400,
              status: 'provisional',
              isMe: true,
            ),
          ],
        ),
      );

      expect(find.text('Play now · 50 entries'), findsOneWidget);
      expect(find.textContaining('pre-funded by SendAgift'), findsOneWidget);
      expect(find.textContaining('Chance plays no part'), findsOneWidget);
      expect(find.text('2 of 3 left'), findsOneWidget);
      expect(find.text('50 entries per play'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Sarah M.'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Sarah M.'), findsOneWidget);
      expect(find.text('Ben C. (you)'), findsOneWidget);
      expect(find.text('Provisional'), findsOneWidget);
    });

    testWidgets('guests are asked to sign in before playing', (tester) async {
      await _openCompetition(tester, _competition());
      expect(find.text('Sign in to play'), findsOneWidget);
      expect(find.textContaining('Play now'), findsNothing);
    });

    testWidgets('no attempts left means no play button', (tester) async {
      await _openCompetition(
        tester,
        _competition(
          me: const CompetitionMe(
            attemptsUsed: 3,
            attemptsRemaining: 0,
            eligible: true,
            bestScore: 1200,
            rank: 4,
          ),
        ),
      );
      expect(find.text('No plays left'), findsOneWidget);
      expect(find.text('1200 · 4th place'), findsOneWidget);
    });

    testWidgets('a growing prize shows what it is now and how it grows', (
      tester,
    ) async {
      await _openCompetition(
        tester,
        _competition(me: _eligible, growing: true, currentPrizeCents: 34800),
      );
      expect(find.text('WIN UP TO'), findsOneWidget);
      expect(find.text(r'NZ$348'), findsWidgets);
      expect(
        find.text(
          r'Prize grows by NZ$1 after every eligible play, up to NZ$500.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('248 valid plays so far'), findsOneWidget);
      expect(
        find.textContaining('grows with every eligible play'),
        findsOneWidget,
      );
    });

    testWidgets('a round stopped at its cap takes no more plays', (
      tester,
    ) async {
      await _openCompetition(
        tester,
        _competition(
          me: _eligible,
          growing: true,
          continueAtCap: false,
          currentPrizeCents: 50000,
        ),
      );
      expect(find.text('Prize maxed out'), findsOneWidget);
      expect(find.textContaining('reached its maximum'), findsWidgets);
    });

    testWidgets('without enough entries the player is shown their balance', (
      tester,
    ) async {
      await _openCompetition(
        tester,
        _competition(
          me: const CompetitionMe(
            attemptsUsed: 0,
            attemptsRemaining: 3,
            eligible: true,
            entriesBalance: 10,
          ),
        ),
      );
      expect(find.text('Not enough game entries'), findsOneWidget);
      expect(
        find.textContaining('A play costs 50 entries and you have 10.'),
        findsOneWidget,
      );
    });

    testWidgets('a paused round says so and takes no plays', (tester) async {
      await _openCompetition(
        tester,
        _competition(status: 'paused', me: _eligible),
      );
      expect(find.text('Paused'), findsOneWidget);
      expect(find.textContaining('Play now'), findsNothing);
      expect(find.text('Paused · closes in'), findsOneWidget);
    });

    testWidgets('a used-up daily limit says when plays reopen', (tester) async {
      await _openCompetition(
        tester,
        _competition(
          me: CompetitionMe(
            attemptsUsed: 1,
            attemptsRemaining: 2,
            eligible: true,
            entriesBalance: 120,
            playsLeftToday: 0,
            dailyResetAt: DateTime.now().add(const Duration(hours: 3)),
          ),
        ),
      );
      expect(find.text("Today's plays used"), findsOneWidget);
      expect(find.textContaining('More plays open'), findsOneWidget);
    });

    testWidgets('an ineligible player is told why', (tester) async {
      await _openCompetition(
        tester,
        _competition(
          me: const CompetitionMe(
            attemptsUsed: 0,
            attemptsRemaining: 3,
            eligible: false,
            ineligibleReason: 'Verify your age to enter.',
          ),
        ),
      );
      expect(find.text('Not eligible'), findsOneWidget);
      expect(find.text('Verify your age to enter.'), findsWidgets);
    });

    testWidgets('a winner claims the prize to a saved address', (tester) async {
      final repo = await _openCompetition(
        tester,
        _competition(
          status: 'finalised',
          me: CompetitionMe(
            attemptsUsed: 2,
            attemptsRemaining: 1,
            eligible: true,
            win: MyWin(
              winnerId: 'w1',
              prizePosition: 1,
              status: 'validated',
              claimId: 'claim-1',
              claimStatus: 'pending',
              claimDeadlineAt: DateTime.now().add(const Duration(days: 10)),
            ),
          ),
          winners: const [
            PublicWinner(
              prizePosition: 1,
              displayName: 'Ben C.',
              countryName: 'New Zealand',
              score: 1400,
            ),
          ],
        ),
        addresses: const [
          DeliveryAddress(
            id: 'a1',
            line1: '1 Queen St',
            city: 'Auckland',
            isDefault: true,
          ),
        ],
      );

      expect(find.text('You won!'), findsOneWidget);
      await tester.tap(find.text('Claim your prize'));
      await _frames(tester);

      expect(find.text('1 Queen St'), findsOneWidget);
      // Claiming stays off until the terms are accepted.
      await tester.tap(find.text('Claim prize'));
      await _frames(tester, 200);
      expect(repo.claims, isEmpty);

      await tester.tap(
        find.text('I accept the prize terms and the official rules'),
      );
      await _frames(tester, 200);
      await tester.tap(find.text('Claim prize'));
      await _frames(tester);

      expect(repo.claims, ['a1']);
    });
  });

  group('Official attempt', () {
    Future<void> launch(WidgetTester tester, FakeGamesRepository repo) async {
      _usePhoneScreen(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [gamesRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
        ),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => GamePlayScreen(
            definition: gameDefinitions['2048']!,
            competitionId: 'c1',
          ),
        ),
      );
      await _frames(tester);
    }

    testWidgets(
      'a refused play says why, charges nothing and offers no retry',
      (tester) async {
        final repo = FakeGamesRepository()
          ..competitions = [_competition(me: _eligible)]
          ..playFailures.add(
            const AppException(
              'You do not have enough game entries to play.',
              statusCode: 422,
              code: 'INSUFFICIENT_ENTRIES',
              details: {'entries_required': 50, 'entries_balance': 10},
            ),
          );
        await launch(tester, repo);
        expect(
          find.text(
            'A play costs 50 game entries and you have 10. Nothing was charged.',
          ),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsNothing);
        expect(find.text('See my game entries'), findsOneWidget);
        expect(repo.attemptCount, 0);
      },
    );

    testWidgets('retrying after a dropped connection reuses the play key', (
      tester,
    ) async {
      final repo = FakeGamesRepository()
        ..competitions = [_competition(me: _eligible)]
        ..playFailures.add(const NetworkException());
      await launch(tester, repo);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await _frames(tester);

      expect(repo.playKeys, hasLength(2));
      expect(
        repo.playKeys[1],
        repo.playKeys[0],
        reason: 'the same intended play must not be charged twice',
      );
      expect(repo.attemptCount, 1);
      expect(find.text('OFFICIAL ATTEMPT #1'), findsOneWidget);
    });

    testWidgets('uses an attempt, offers no restart, and submits on quit', (
      tester,
    ) async {
      _usePhoneScreen(tester);
      final repo = FakeGamesRepository()
        ..competitions = [_competition(me: _eligible)];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [gamesRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GamePlayScreen(
                          definition: gameDefinitions['2048']!,
                          competitionId: 'c1',
                        ),
                      ),
                    ),
                    child: const Text('launcher'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('launcher'));
      await _frames(tester);

      expect(repo.attemptCount, 1);
      expect(repo.startCount, 0, reason: 'no practice session is opened');
      expect(find.text('OFFICIAL ATTEMPT #1'), findsOneWidget);

      // Seed 'cafebabe' opens with both tiles off the left wall.
      await tester.fling(
        find.byType(AspectRatio).first,
        const Offset(-300, 0),
        1200,
      );
      await _frames(tester, 400);

      await tester.tap(find.byTooltip('Game menu'));
      await _frames(tester, 400);
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Restart'), findsNothing);
      expect(find.textContaining('submits this attempt'), findsOneWidget);

      await tester.tap(find.text('Quit game'));
      await _frames(tester, 400);
      expect(
        find.textContaining('counts as one of your attempts'),
        findsOneWidget,
      );
      await tester.tap(find.text('Yes, quit'));
      await _frames(tester);

      expect(find.byType(GamePlayScreen), findsNothing);
      expect(repo.lastMoves, ['left']);
    });
  });
}
