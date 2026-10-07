import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/games/data/games_providers.dart';
import 'package:send_agift_mobile/features/games/domain/competition.dart';
import 'package:send_agift_mobile/features/games/domain/game.dart';
import 'package:send_agift_mobile/features/games/presentation/screens/games_screen.dart';
import 'package:send_agift_mobile/features/games/presentation/screens/points_screen.dart';
import 'package:send_agift_mobile/features/orders/domain/customer_order.dart';
import 'package:send_agift_mobile/features/products/domain/gift.dart';

import 'support/fake_auth.dart';
import 'support/fake_games_repository.dart';

// The points the server now reports: where a customer's points came from,
// rewards on gifts, and points travelling with an order.

final _wallet = PointsWallet.fromJson({
  'balance': 65,
  'lifetime_earned': 90,
  'lifetime_spent': 25,
  'totals': {
    'from_purchases': 90,
    'from_gifts': 0,
    'from_prizes': 0,
    'spent_on_games': 0,
    'sent_as_gifts': 25,
  },
  'entries': [
    {
      'id': 'a',
      'entry_type': 'product_reward',
      'category': 'PRODUCT_PURCHASE',
      'amount_delta': 30,
      'balance_after': 65,
      'description': 'Purchased Wireless Headphones',
      'created_at': '2026-09-29T09:42:00Z',
    },
    {
      'id': 'b',
      'entry_type': 'gift_points_sent',
      'category': 'GIFT_SENT',
      'amount_delta': -25,
      'balance_after': 35,
      'description': 'Sent with gift SAG-1',
      'created_at': '2026-09-29T09:41:00Z',
    },
  ],
});

void main() {
  test('the wallet reads totals, categories and the server wording', () {
    expect(_wallet.totals.fromPurchases, 90);
    expect(_wallet.totals.sentAsGifts, 25);
    expect(_wallet.entries.first.label, 'Purchased Wireless Headphones');
    expect(_wallet.entries.first.category, 'PRODUCT_PURCHASE');
    expect(_wallet.entries.last.isCredit, isFalse);
  });

  test('an older server without descriptions still gets a readable line', () {
    final e = PointsEntry.fromJson({
      'id': 'x',
      'entry_type': 'gift_points_received',
      'amount_delta': 50,
      'balance_after': 50,
    });
    expect(e.label, 'Gift received');
    expect(PointsWallet.fromJson({'balance': 3}).totals.fromGifts, 0);
  });

  test('a gift carries its reward points', () {
    final gift = Gift.fromJson({
      'id': 'g',
      'name': 'Headphones',
      'reward_points': 100,
    });
    expect(gift.rewardPoints, 100);
    expect(Gift.fromJson({'id': 'g'}).rewardPoints, 0);
  });

  test('order lines and orders describe where their points are', () {
    final order = CustomerOrder.fromJson({
      'id': 'o',
      'gift_points': 25,
      'gift_points_status': 'returned',
      'items': [
        {'id': 'i', 'reward_points': 60, 'reward_status': 'reserved'},
        {'id': 'j', 'reward_points': 0, 'reward_status': 'none'},
      ],
    });
    expect(order.items.first.rewardLabel, 'Earns 60 points when delivered');
    expect(order.rewardPointsTotal, 60);
    expect(order.rewardsEarned, isFalse);
    expect(order.items.last.rewardLabel, isNull);
    expect(order.giftPointsLabel, startsWith('25 points came back to you'));
    expect(CustomerOrder.fromJson({'id': 'p'}).giftPointsLabel, isNull);
  });

  testWidgets('the points screen shows totals and filters its history', (
    tester,
  ) async {
    // Tall enough that the whole history is built.
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pointsWalletProvider.overrideWith((ref) async => _wallet),
          pointsEarningRuleProvider.overrideWith(
            (ref) async => PointsEarningRule.fromJson(const {}),
          ),
        ],
        child: const MaterialApp(home: PointsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('65 points'), findsOneWidget);
    expect(find.text('From purchases'), findsOneWidget);
    expect(find.text('Purchased Wireless Headphones'), findsOneWidget);
    expect(find.text('Sent with gift SAG-1'), findsOneWidget);

    await tester.tap(find.text('SPENT'));
    await tester.pumpAndSettle();
    expect(find.text('Purchased Wireless Headphones'), findsNothing);
    expect(find.text('Sent with gift SAG-1'), findsOneWidget);
  });

  test('games and sessions carry what a play costs', () {
    final game = Game.fromJson({'slug': '2048', 'play_cost_points': 50});
    expect(game.playCostPoints, 50);
    final session = GameSession.fromJson({
      'session_id': 's',
      'points_charged': 50,
      'points_balance': 70,
    });
    expect(session.pointsCharged, 50);
    expect(session.pointsBalance, 70);
  });

  testWidgets('the game zone shows the balance and what a game costs', (
    tester,
  ) async {
    final repo = _PaidGames()..pointsBalance = 120;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakeAuth(customer: {'email': 'p@test.dev'}),
          gamesRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: GamesScreen()),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byKey(const Key('games-points-balance')), findsOneWidget);
    expect(find.text('Your points  120'), findsOneWidget);
    expect(find.text('50 pts'), findsWidgets);
  });

  testWidgets('a guest is asked to sign in before playing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakeAuth(),
          gamesRepositoryProvider.overrideWithValue(_PaidGames()),
        ],
        child: const MaterialApp(home: GamesScreen()),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Sign in to play'), findsOneWidget);
  });
}

/// The standard games, each costing 50 points a play.
class _PaidGames extends FakeGamesRepository {
  @override
  Future<List<Game>> listGames() async => [
    for (final g in FakeGamesRepository.games)
      Game(
        slug: g.slug,
        name: g.name,
        gameType: g.gameType,
        version: g.version,
        config: g.config,
        playCostPoints: 50,
      ),
  ];
}
