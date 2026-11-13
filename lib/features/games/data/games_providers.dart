import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';
import '../domain/competition.dart';
import '../domain/game_entries.dart';
import '../domain/game.dart';
import 'games_repository.dart';

final gamesRepositoryProvider = Provider<GamesRepository>((ref) {
  return GamesRepository(ref.watch(apiClientProvider));
});

/// The game collection screen.
final gamesListProvider = FutureProvider<List<Game>>((ref) {
  return ref.watch(gamesRepositoryProvider).listGames();
});

/// The board for one game. Invalidated after a score is submitted so a new
/// personal best shows up straight away.
final leaderboardProvider = FutureProvider.family<Leaderboard, String>((
  ref,
  slug,
) {
  return ref.watch(gamesRepositoryProvider).leaderboard(slug);
});

// Competition data changes with the clock and with who is signed in (signing
// in narrows the list to the customer's country and adds their attempts), so
// these are fetched fresh whenever a screen opens them, and screens refresh
// them again after sign-in or an attempt.

/// Published competitions for the game zone.
final competitionsProvider = FutureProvider.autoDispose<List<Competition>>((
  ref,
) {
  return ref.watch(gamesRepositoryProvider).listCompetitions();
});

/// One competition's detail.
final competitionProvider = FutureProvider.autoDispose
    .family<Competition, String>((ref, id) {
      return ref.watch(gamesRepositoryProvider).getCompetition(id);
    });

/// One competition's live board. Invalidated after every official attempt.
final competitionLeaderboardProvider = FutureProvider.autoDispose
    .family<CompetitionLeaderboard, String>((ref, id) {
      return ref.watch(gamesRepositoryProvider).competitionLeaderboard(id);
    });

/// One competition's full board (the top 100), for the leaderboard screen.
final competitionFullLeaderboardProvider = FutureProvider.autoDispose
    .family<CompetitionLeaderboard, String>((ref, id) {
      return ref
          .watch(gamesRepositoryProvider)
          .competitionLeaderboard(id, limit: 100);
    });

/// A round's live prize while it is open. Screens merge it over the round
/// they loaded with [Competition.withLive].
final livePrizeProvider = StreamProvider.autoDispose.family<LivePrize, String>(
  (ref, id) => ref.watch(gamesRepositoryProvider).livePrize(id),
);

/// The signed-in customer's game entries and history.
final gameEntriesProvider = FutureProvider.autoDispose<GameEntriesWallet>((
  ref,
) {
  return ref.watch(gamesRepositoryProvider).gameEntries();
});

/// The state on the signed-in customer's account.
final myStateProvider = FutureProvider.autoDispose<CustomerState>((ref) {
  return ref.watch(gamesRepositoryProvider).myState();
});

/// The active states of a country, for sign-up and the state picker.
final statesProvider = FutureProvider.autoDispose
    .family<List<StateOption>, String>((ref, countryId) {
      if (countryId.isEmpty) return const <StateOption>[];
      return ref.watch(gamesRepositoryProvider).states(countryId);
    });

/// What a cart would earn the signed-in customer, worked out on the server.
/// The key is the cart's product ids, sorted and joined with commas.
final entryOffersProvider = FutureProvider.autoDispose
    .family<EntryOffers, String>((ref, key) {
      if (key.isEmpty) return const EntryOffers(total: 0);
      return ref.watch(gamesRepositoryProvider).entryOffers(key.split(','));
    });
