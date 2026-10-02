import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/games_providers.dart';
import '../../domain/competition.dart';
import '../game_visuals.dart';
import '../widgets/game_gradient_button.dart';
import '../widgets/leaderboard_list.dart';

/// A competition's full leaderboard: the top 100 on a podium and list, the
/// player's own place pinned below, refreshed every few seconds while the
/// competition is open.
class CompetitionLeaderboardScreen extends ConsumerStatefulWidget {
  const CompetitionLeaderboardScreen({required this.competitionId, super.key});

  final String competitionId;

  @override
  ConsumerState<CompetitionLeaderboardScreen> createState() =>
      _CompetitionLeaderboardScreenState();
}

class _CompetitionLeaderboardScreenState
    extends ConsumerState<CompetitionLeaderboardScreen> {
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Keeps the board live while scores can still come in.
  void _syncPoll(bool open) {
    if (open && _poll == null) {
      _poll = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted) {
          ref.invalidate(
            competitionFullLeaderboardProvider(widget.competitionId),
          );
        }
      });
    } else if (!open) {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(competitionProvider(widget.competitionId));
    final _ = await ref.refresh(
      competitionFullLeaderboardProvider(widget.competitionId).future,
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.competitionId;
    final competition = ref.watch(competitionProvider(id)).valueOrNull;
    final board = ref.watch(competitionFullLeaderboardProvider(id));
    final visual = GameVisual.of(competition?.gameSlug ?? '');
    final open =
        competition != null && (competition.isLive || competition.isPaused);
    _syncPoll(open);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: visual.accent,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 220,
              backgroundColor: visual.colors[1],
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: _Hero(
                  competition: competition,
                  board: board.valueOrNull,
                  visual: visual,
                  open: open,
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
                  error: (error, _) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Could not load the leaderboard. Pull to refresh.',
                    ),
                  ),
                  data: (b) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.isFinal
                            ? 'Verified final standings.'
                            : 'Best score per player. Ties go to the fastest '
                                  'time. Scores stay provisional until the '
                                  'result is verified.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      LeaderboardList(
                        entries: b.entries,
                        me: b.me,
                        colors: visual.colors,
                        emptyMessage: competition?.isUpcoming ?? false
                            ? 'The board opens when the competition starts.'
                            : 'No scores yet. Be the first on the board.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: competition != null && open
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  8,
                  AppTheme.gutter,
                  12,
                ),
                child: GameGradientButton(
                  label: 'Play to climb the board',
                  colors: visual.colors,
                  onPressed: () => context.push(AppRoutes.competitionPath(id)),
                ),
              ),
            )
          : null,
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.competition,
    required this.board,
    required this.visual,
    required this.open,
  });

  final Competition? competition;
  final CompetitionLeaderboard? board;
  final GameVisual visual;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final b = board;
    final label = b?.isFinal ?? false
        ? 'FINAL'
        : open
        ? 'LIVE'
        : 'PROVISIONAL';

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: visual.colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.emoji_events_rounded,
              size: 180,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (open) ...[
                            const Icon(
                              Icons.circle,
                              size: 8,
                              color: Color(0xFF7CFFB2),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            label,
                            style: AppTypography.eyebrow.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'LEADERBOARD',
                      style: AppTypography.eyebrow.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  competition?.title ?? 'Competition',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(28, color: Colors.white),
                ),
                if (b != null)
                  Text(
                    '${b.totalPlayers} '
                    '${b.totalPlayers == 1 ? 'player' : 'players'} ranked'
                    '${b.me != null ? ' · you are #${b.me!.rank}' : ''}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
