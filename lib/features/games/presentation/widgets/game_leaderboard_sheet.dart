import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/sheet_header.dart';
import '../../data/games_providers.dart';
import '../../domain/game.dart';
import '../game_visuals.dart';
import 'game_art.dart';
import 'leaderboard_list.dart';

/// Opens a game's leaderboard as a sheet over whatever is on screen. From
/// the game menu the round stays paused underneath, so checking the board
/// never costs a run. An official attempt shows its competition's board.
Future<void> showGameLeaderboard(
  BuildContext context, {
  required String slug,
  String? competitionId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    builder: (_) => _LeaderboardSheet(slug: slug, competitionId: competitionId),
  );
}

class _LeaderboardSheet extends ConsumerWidget {
  const _LeaderboardSheet({required this.slug, this.competitionId});

  final String slug;
  final String? competitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = GameVisual.of(slug);
    final id = competitionId;

    // Both boards reduce to the same rows plus the player's own.
    final AsyncValue<(List<LeaderboardEntry>, LeaderboardEntry?, bool)> board =
        id == null
        ? ref
              .watch(leaderboardProvider(slug))
              .whenData((b) => (b.entries, b.me, true))
        : ref
              .watch(competitionLeaderboardProvider(id))
              .whenData((b) => (b.entries, b.me, b.isFinal));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: visual.colors[1],
                ),
                child: Center(child: GameArt(slug: slug, size: 30)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      id == null ? 'Leaderboard' : 'Competition board',
                      style: AppTypography.display(22),
                    ),
                    Text(
                      id == null
                          ? '${visual.name} · best verified score per player'
                          : 'Scores stay provisional until verified',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const SheetCloseButton(),
            ],
          ),
          const SizedBox(height: 16),
          board.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Could not load the leaderboard.\n$error'),
                  TextButton(
                    onPressed: () => id == null
                        ? ref.invalidate(leaderboardProvider(slug))
                        : ref.invalidate(competitionLeaderboardProvider(id)),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
            data: (b) =>
                LeaderboardList(entries: b.$1, me: b.$2, colors: visual.colors),
          ),
        ],
      ),
    );
  }
}
