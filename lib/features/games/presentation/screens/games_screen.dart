import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../auth/data/auth_controller.dart';
import '../../data/games_providers.dart';
import '../../domain/game.dart';
import '../game_definitions.dart';
import '../game_visuals.dart';
import '../widgets/game_art.dart';
import '../widgets/competitions_arena.dart';

/// The game zone: every skill game as a colourful tile.
class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(gamesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Game zone')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(competitionsProvider);
          return ref.refresh(gamesListProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppTheme.gutter,
                4,
                AppTheme.gutter,
                0,
              ),
              sliver: SliverToBoxAdapter(child: _Header()),
            ),
            const SliverToBoxAdapter(child: CompetitionsArena()),
            ...games.when<List<Widget>>(
              loading: () => const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (error, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.sports_esports_outlined,
                    title: 'Could not load games',
                    description: '$error',
                    action: FilledButton(
                      onPressed: () => ref.invalidate(gamesListProvider),
                      child: const Text('Try again'),
                    ),
                  ),
                ),
              ],
              data: (items) => items.isEmpty
                  ? const [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.sports_esports_outlined,
                          title: 'No games yet',
                          description:
                              'Skill games will appear here once they open '
                              'in your country.',
                        ),
                      ),
                    ]
                  : [
                      SliverPadding(
                        padding: const EdgeInsets.all(AppTheme.gutter),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.84,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => FadeSlideIn(
                              delay: Duration(milliseconds: 70 * index),
                              child: _GameTile(game: items[index]),
                            ),
                            childCount: items.length,
                          ),
                        ),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PointsBanner(),
        const SizedBox(height: 18),
        Text('Play a round', style: AppTypography.display(28)),
        const SizedBox(height: 4),
        Text(
          'Pure-skill games. Every board comes from a server seed and every '
          'score is replayed on our servers. Chance plays no part.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// The player's available points, at the top of the zone. Just the
/// balance, so it reads at a glance before they pick a game.
class _PointsBanner extends ConsumerWidget {
  const _PointsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authProvider.select((a) => a.isSignedIn));
    final balance = signedIn
        ? ref.watch(pointsWalletProvider).valueOrNull?.balance
        : null;

    return PressableScale(
      onTap: () => context.push(signedIn ? AppRoutes.points : AppRoutes.login),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F1B45), Color(0xFF6D28D9), Color(0xFF0EA5A4)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x406D28D9),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.stars_rounded,
                color: Color(0xFFFCD980),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: signedIn
                  ? Text(
                      balance == null
                          ? 'Your points  …'
                          : 'Your points  $balance',
                      key: const Key('games-points-balance'),
                      style: AppTypography.display(18, color: Colors.white),
                    )
                  : Text(
                      'Sign in to play',
                      style: AppTypography.display(18, color: Colors.white),
                    ),
            ),
            Icon(
              signedIn ? Icons.chevron_right_rounded : Icons.login_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _GameTile extends ConsumerStatefulWidget {
  const _GameTile({required this.game});

  final Game game;

  @override
  ConsumerState<_GameTile> createState() => _GameTileState();
}

class _GameTileState extends ConsumerState<_GameTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final visual = GameVisual.of(game.slug);
    final best = ref.watch(leaderboardProvider(game.slug)).valueOrNull?.myBest;

    return PressableScale(
      onTap: () {
        // The server can offer a game before this build of the app knows
        // how to run it; say so rather than silently doing nothing.
        if (!gameDefinitions.containsKey(game.slug)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  '${game.name} needs the latest version of the app.',
                ),
              ),
            );
          return;
        }
        context.push(AppRoutes.gamePath(game.slug));
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: visual.colors,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: visual.colors[1].withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              // A soft glow behind the artwork, so the hero has something to
              // sit on instead of floating on flat gradient.
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The artwork is the tile's subject rather than a
                    // watermark behind the words. It used to sit bottom-right
                    // at 130px, directly under the tagline, so 2048's numbers
                    // read as part of the sentence.
                    Expanded(
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _float,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(
                              0,
                              -3 + 6 * Curves.easeInOut.transform(_float.value),
                            ),
                            child: child,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) => GameArt(
                              slug: game.slug,
                              // Scales with the tile, so it reads the same on
                              // a small phone as on a tablet.
                              size: constraints.maxWidth.clamp(48.0, 92.0),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(20, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      visual.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Sized to its text, not flexed: shrinking this pill
                        // turned a best score into a bare "Best …", which told
                        // the player less than showing nothing would have.
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                best != null && best > 0 ? 'Best $best' : 'New',
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (game.playCostPoints > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCD980),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${game.playCostPoints} pts',
                              style: const TextStyle(
                                color: Color(0xFF6B4410),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        const Spacer(),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: visual.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: 'Leaderboard',
                  onPressed: () =>
                      context.push(AppRoutes.gameLeaderboardPath(game.slug)),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                  ),
                  icon: const Icon(
                    Icons.leaderboard_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
