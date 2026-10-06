import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/games_providers.dart';
import '../game_definitions.dart';
import '../game_visuals.dart';
import '../widgets/game_action_button.dart';
import '../widgets/leaderboard_list.dart';

/// The practice board for one game: who holds the highest verified score.
class GameLeaderboardScreen extends ConsumerWidget {
  const GameLeaderboardScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = GameVisual.of(slug);
    final board = ref.watch(leaderboardProvider(slug));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: visual.accent,
        onRefresh: () => ref.refresh(leaderboardProvider(slug).future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 200,
              backgroundColor: visual.colors[1],
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: DecoratedBox(
                  decoration: BoxDecoration(
                    color: visual.colors[1],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        bottom: -20,
                        child: Icon(
                          Icons.leaderboard_rounded,
                          size: 170,
                          color: Colors.white.withValues(alpha: 0.13),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.gutter,
                          0,
                          AppTheme.gutter,
                          20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'LEADERBOARD',
                              style: AppTypography.eyebrow.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            Text(
                              visual.name,
                              style: AppTypography.display(
                                30,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Best verified score per player. Ties go to '
                              'the fastest time.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.gutter),
              sliver: SliverToBoxAdapter(
                child: board.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Text(
                    'Could not load the leaderboard. Pull to refresh.\n$error',
                  ),
                  data: (b) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (b.totalPlayers > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '${b.totalPlayers} '
                            '${b.totalPlayers == 1 ? 'player' : 'players'} '
                            'ranked',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      LeaderboardList(
                        entries: b.entries,
                        me: b.me,
                        colors: visual.colors,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: gameDefinitions.containsKey(slug)
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  8,
                  AppTheme.gutter,
                  12,
                ),
                child: GameActionButton(
                  label: 'Play ${visual.name}',
                  colors: visual.colors,
                  onPressed: () => context.push(AppRoutes.gamePath(slug)),
                ),
              ),
            )
          : null,
    );
  }
}
