import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../data/games_providers.dart';
import '../../domain/competition.dart';
import '../game_visuals.dart';
import 'countdown.dart';

/// The competitions at the top of the game zone: a swipeable stage of big
/// prize cards with live countdowns. Customers are only sent live
/// competitions (and any prize they have yet to claim). Stays out of the way
/// when there are none — the games still work.
class CompetitionsArena extends ConsumerStatefulWidget {
  const CompetitionsArena({super.key});

  @override
  ConsumerState<CompetitionsArena> createState() => _CompetitionsArenaState();
}

class _CompetitionsArenaState extends ConsumerState<CompetitionsArena> {
  final _pages = PageController(viewportFraction: 0.86);
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pages.addListener(() {
      if (_pages.hasClients) setState(() => _page = _pages.page ?? 0);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _open(Competition c) async {
    await context.push(AppRoutes.competitionPath(c.id));
    if (mounted) ref.invalidate(competitionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(competitionsProvider).valueOrNull;
    if (all == null || all.isEmpty) return const SizedBox.shrink();

    final live = all.where((c) => c.isLive).length;

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFD452), Color(0xFFFF8A3D)],
                    ),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Win real prizes',
                    style: AppTypography.display(24),
                  ),
                ),
                if (live > 0) _LiveBadge(count: live),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 14),
          ...[
            SizedBox(
              height: 268,
              child: PageView.builder(
                controller: _pages,
                itemCount: all.length,
                padEnds: all.length == 1,
                itemBuilder: (context, i) {
                  // Cards beside the centre one sit a little smaller and
                  // lower, so the stage reads as a carousel.
                  final t = (i - _page).abs().clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, 14 * t),
                    child: Transform.scale(
                      scale: 1 - 0.06 * t,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: i == 0 && all.length > 1 ? AppTheme.gutter : 6,
                          right: 6,
                        ),
                        child: _PrizeCard(
                          competition: all[i],
                          onTap: () => _open(all[i]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (all.length > 1) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < all.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _page.round() == i ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _page.round() == i
                            ? AppColors.foreground
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// "3 LIVE" with a pulsing dot.
class _LiveBadge extends StatefulWidget {
  const _LiveBadge({required this.count});

  final int count;

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4E6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFE11D48),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${widget.count} LIVE',
            style: const TextStyle(
              color: Color(0xFFBE123C),
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// One competition as a big prize card: the prize front and centre, a live
/// countdown, and the player's own standing.
class _PrizeCard extends StatelessWidget {
  const _PrizeCard({required this.competition, required this.onTap});

  final Competition competition;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = competition;
    final visual = GameVisual.of(c.gameSlug);
    final open = c.isLive || c.isPaused;
    final prize = c.prizeType == 'points'
        ? c.prizeDescription
        : c.prizeValueLabel ?? c.prizeDescription;
    final me = c.me;

    return PressableScale(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: visual.colors,
          ),
          boxShadow: [
            BoxShadow(
              color: visual.colors.last.withValues(alpha: 0.38),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Decorative: the game's own icon, large and faint, and a soft
              // light in the corner.
              Positioned(
                right: -26,
                bottom: -30,
                child: Icon(
                  visual.icon,
                  size: 170,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              Positioned(
                left: -40,
                top: -60,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: _Glass(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  visual.icon,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    c.gameName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusTag(competition: c),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(22, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.isFinal ? 'PRIZE AWARDED' : 'WIN',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                    Text(
                      prize,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(34, color: Colors.white),
                    ),
                    if (c.prizeGrowthEnabled && open)
                      Text(
                        '+${c.incrementLabel} with every play',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const Spacer(),
                    if (open || c.isUpcoming)
                      _Clock(competition: c)
                    else
                      Text(
                        c.winners.isNotEmpty
                            ? 'Won by ${c.winners.first.displayName}'
                            : 'Results are being checked',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      // On a narrow card the player count steps aside and the
                      // button label shortens, so the row never spills.
                      builder: (context, box) {
                        final compact = box.maxWidth < 300;
                        return Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  if (!compact || me?.rank == null)
                                    Flexible(
                                      child: _Glass(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.groups_rounded,
                                              color: Colors.white,
                                              size: 15,
                                            ),
                                            const SizedBox(width: 5),
                                            Flexible(
                                              child: Text(
                                                '${c.uniquePlayerCount} playing',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (me?.rank != null) ...[
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: _Glass(
                                        child: Text(
                                          'You · #${me!.rank}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    open
                                        ? (compact
                                              ? 'Play'
                                              : c.pointsPerAttempt > 0
                                              ? 'Play · ${c.pointsPerAttempt} pts'
                                              : 'Play free')
                                        : c.isUpcoming
                                        ? (compact ? 'Details' : 'See details')
                                        : (compact ? 'Results' : 'See results'),
                                    style: TextStyle(
                                      color: visual.colors.last,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    open
                                        ? Icons.play_arrow_rounded
                                        : Icons.arrow_forward_rounded,
                                    color: visual.colors.last,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    final c = competition;
    final (label, color) = c.isLive
        ? ('LIVE', const Color(0xFF22C55E))
        : c.isPaused
        ? ('PAUSED', const Color(0xFFF59E0B))
        : c.isUpcoming
        ? ('SOON', const Color(0xFF38BDF8))
        : c.isFinal
        ? ('FINAL', const Color(0xFFFACC15))
        : ('ENDED', Colors.white70);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// A ticking countdown in little glass blocks: days, hours, minutes, seconds.
class _Clock extends ConsumerWidget {
  const _Clock({required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = competition;
    final target = c.isUpcoming ? c.startsAt : c.endsAt;
    return Countdown(
      target: target,
      onDone: () => ref.invalidate(competitionsProvider),
      builder: (context, left) {
        final parts = <(String, String)>[
          if (left.inDays > 0) ('${left.inDays}', 'd'),
          (left.inHours.remainder(24).toString().padLeft(2, '0'), 'h'),
          (left.inMinutes.remainder(60).toString().padLeft(2, '0'), 'm'),
          (left.inSeconds.remainder(60).toString().padLeft(2, '0'), 's'),
        ];
        // Scales down on narrow phones rather than spilling off the card.
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Text(
                c.isUpcoming ? 'OPENS IN' : 'ENDS IN',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              for (final (value, unit) in parts) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        TextSpan(
                          text: unit,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A frosted pill on the card.
class _Glass extends StatelessWidget {
  const _Glass({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: child,
    );
  }
}
