import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:send_agift_mobile/features/games/data/games_providers.dart';
import 'package:send_agift_mobile/features/games/domain/competition.dart';
import 'package:send_agift_mobile/features/games/presentation/widgets/competitions_arena.dart';

import 'support/fake_games_repository.dart';

Competition _competition({
  required String id,
  required String status,
  String title = 'Spring 2048 Cup',
  Duration startsIn = const Duration(hours: -1),
  Duration endsIn = const Duration(days: 28, hours: 21),
  CompetitionMe? me,
  List<PublicWinner> winners = const [],
  bool growing = false,
}) {
  return Competition(
    id: id,
    title: title,
    status: status,
    gameSlug: '2048',
    gameName: 'Bubble Shooter',
    countryName: 'Australia, Sri Lanka, United States',
    startsAt: DateTime.now().add(startsIn),
    endsAt: DateTime.now().add(endsIn),
    pointsPerAttempt: 50,
    pointsDeductionEnabled: true,
    maxAttempts: 0,
    minAge: 18,
    requiresIdentityVerification: false,
    numberOfWinners: 1,
    prizeDescription: r'A$500 bank transfer',
    prizeValueAmount: 50000,
    prizeCurrency: 'AUD',
    me: me,
    winners: winners,
    prizeGrowthEnabled: growing,
    startPrizeCents: 50000,
    currentPrizeCents: 123456,
    incrementPerPlayCents: growing ? 100 : 0,
    maxPrizeCents: growing ? 500000 : null,
    prizeCapReached: false,
    continueAtCap: true,
    eligiblePlayCount: 248,
    uniquePlayerCount: 1204,
  );
}

Future<void> _pump(WidgetTester tester, Size logical) async {
  tester.view.physicalSize = logical * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final repo = FakeGamesRepository()
    ..competitions = [
      _competition(
        id: 'live',
        status: 'live',
        title: 'The Very Long Spring Championship Cup Final',
        growing: true,
        me: const CompetitionMe(
          attemptsUsed: 4,
          attemptsRemaining: -1,
          eligible: true,
          rank: 12,
          pointsBalance: 155,
        ),
      ),
      _competition(
        id: 'soon',
        status: 'scheduled',
        startsIn: const Duration(days: 3, hours: 4),
      ),
      _competition(
        id: 'done',
        status: 'finalised',
        endsIn: const Duration(days: -1),
        winners: const [
          PublicWinner(
            prizePosition: 1,
            displayName: 'Sarah M.',
            countryName: 'Australia',
            score: 900,
          ),
        ],
      ),
    ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gamesRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: CompetitionsArena())),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  for (final size in const [Size(390, 844), Size(320, 640)]) {
    testWidgets('competitions fit a ${size.width.toInt()}pt-wide phone', (
      tester,
    ) async {
      await _pump(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.text('Win real prizes'), findsOneWidget);
      expect(find.text('1 LIVE'), findsOneWidget);
      expect(find.text('ENDS IN'), findsOneWidget);
      expect(find.text('You · #12'), findsOneWidget);
    });
  }
}
