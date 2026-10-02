import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/sheet_header.dart';
import '../../data/games_providers.dart';
import '../../domain/competition.dart';
import '../competition_format.dart';
import '../game_definitions.dart';
import '../game_visuals.dart';
import '../widgets/competition_card.dart';
import '../widgets/countdown.dart';
import '../widgets/game_gradient_button.dart';
import '../widgets/leaderboard_list.dart';

const _prizeDisclosure =
    'Competition prizes are pre-funded by SendAgift or an approved sponsor. '
    'SendAgift Points do not fund prize pools.';

const _growingDisclosure =
    'The prize grows with every eligible play, and the full amount up to its '
    'maximum is pre-funded by SendAgift or an approved sponsor before the '
    'round opens. Every change is recorded on the prize ledger.';

const _skillDisclosure =
    'Chance plays no part. Every entrant plays the identical board, every '
    'score is replayed on our servers, and ties go to the fastest verified '
    'time.';

/// What a chance round's players are told about how it is decided.
String _chanceDisclosure(Competition c) => c.isDraw
    ? 'This is a game of chance. Every play is one entry; when the round '
          'closes, winners are drawn at random from all entries by our '
          'server, and each player can win once. The full draw is recorded.'
    : 'This is a game of chance. Each play wins with a chance of 1 in '
          '${c.winOdds ?? '?'}, decided by our server with a secure random draw '
          'the moment you play. The first winning play takes the prize and '
          'ends the round.';

/// One skill competition: the prize, the rules and disclosures, the player's
/// attempts and eligibility, the live leaderboard, and — for a winner — the
/// prize claim.
class CompetitionScreen extends ConsumerWidget {
  const CompetitionScreen({required this.competitionId, super.key});

  final String competitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(competitionProvider(competitionId))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'Could not load this competition',
              description: '$error',
              action: FilledButton(
                onPressed: () =>
                    ref.invalidate(competitionProvider(competitionId)),
                child: const Text('Try again'),
              ),
            ),
          ),
          data: (competition) => _CompetitionView(competition: competition),
        );
  }
}

void _refreshCompetition(WidgetRef ref, String id) {
  ref.invalidate(competitionProvider(id));
  ref.invalidate(competitionLeaderboardProvider(id));
  ref.invalidate(competitionsProvider);
}

class _CompetitionView extends ConsumerStatefulWidget {
  const _CompetitionView({required this.competition});

  final Competition competition;

  @override
  ConsumerState<_CompetitionView> createState() => _CompetitionViewState();
}

class _CompetitionViewState extends ConsumerState<_CompetitionView> {
  Timer? _reconcile;

  bool get _open => widget.competition.isLive || widget.competition.isPaused;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _CompetitionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  @override
  void dispose() {
    _reconcile?.cancel();
    super.dispose();
  }

  /// The live stream is only a display optimisation, so while the round is
  /// open the screen re-reads it from the server now and then (spec §5.4).
  void _syncTimer() {
    if (_open && _reconcile == null) {
      _reconcile = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) ref.invalidate(competitionProvider(widget.competition.id));
      });
    } else if (!_open) {
      _reconcile?.cancel();
      _reconcile = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    var c = widget.competition;
    if (_open) {
      final live = ref.watch(livePrizeProvider(c.id)).valueOrNull;
      if (live != null) c = c.withLive(live);
    }
    final visual = GameVisual.of(c.gameSlug);
    const gap = SizedBox(height: 14);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: visual.accent,
        onRefresh: () {
          ref.invalidate(competitionLeaderboardProvider(c.id));
          return ref.refresh(competitionProvider(c.id).future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 270,
              backgroundColor: visual.colors[1],
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: _Hero(competition: c, visual: visual),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                16,
                AppTheme.gutter,
                32,
              ),
              sliver: SliverList.list(
                children: [
                  if (c.isCancelled) ...[_CancelledCard(competition: c), gap],
                  if (c.me?.win != null) ...[_WinCard(competition: c), gap],
                  if (!c.isCancelled) ...[_TimeCard(competition: c), gap],
                  _PrizeCard(competition: c),
                  gap,
                  _EntryCard(competition: c),
                  gap,
                  if (c.winners.isNotEmpty) ...[
                    _WinnersCard(competition: c),
                    gap,
                  ],
                  // A chance round has no scores to rank.
                  if (!c.isChance) ...[
                    _BoardSection(competition: c, visual: visual),
                    gap,
                  ],
                  OutlinedButton.icon(
                    onPressed: () => _showRules(context, c),
                    icon: const Icon(Icons.gavel_rounded),
                    label: const Text('Official rules'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _playBar(context, ref, c, visual),
    );
  }

  /// The entry button, or nothing once play is over. Every state says what
  /// happens next (spec §6): sign in, wait, get points, come back tomorrow.
  Widget? _playBar(
    BuildContext context,
    WidgetRef ref,
    Competition c,
    GameVisual visual,
  ) {
    if (!c.isLive && !c.isUpcoming && !c.isPaused) return null;
    final me = c.me;
    final cost = c.pointsPerAttempt;

    String label;
    String? note;
    VoidCallback? onPressed;
    var icon = Icons.play_arrow_rounded;

    if (me == null) {
      // Only signed-in customers get a "me" block back from the server.
      label = 'Sign in to play';
      note = 'Sign in to play this competition.';
      icon = Icons.login_rounded;
      onPressed = () async {
        await context.push(AppRoutes.login);
        if (context.mounted) _refreshCompetition(ref, c.id);
      };
    } else if (c.isUpcoming) {
      label = 'Opens soon';
      note = 'Come back when the competition starts.';
      icon = Icons.schedule_rounded;
    } else if (c.isPaused) {
      label = 'Paused';
      note = 'This round is paused for a moment. Pull down to check again.';
      icon = Icons.pause_circle_outline_rounded;
    } else if (!gameDefinitions.containsKey(c.gameSlug) &&
        !chanceGameSlugs.contains(c.gameSlug)) {
      label = 'Update the app to play';
      icon = Icons.system_update_rounded;
    } else if (!me.eligible) {
      label = 'Not eligible';
      note = me.ineligibleReason;
      icon = Icons.block_rounded;
    } else if (me.attemptsRemaining == 0) {
      label = 'No plays left';
      note = c.isChance
          ? 'You have used every play in this round.'
          : 'Your best verified score stands.';
      icon = Icons.check_circle_outline_rounded;
    } else if (me.playsLeftToday == 0) {
      label = "Today's plays used";
      final reset = me.dailyResetAt;
      note = reset == null
          ? 'You have used your plays for today.'
          : 'More plays open ${formatDateTime(reset)}.';
      icon = Icons.bedtime_outlined;
    } else if (c.stoppedAtCap) {
      label = 'Prize maxed out';
      note =
          'The prize reached its ${c.maxPrizeLabel ?? 'maximum'} and this '
          'round has stopped taking plays.';
      icon = Icons.lock_outline_rounded;
    } else if (me.pointsBalance < cost) {
      label = 'Not enough points';
      note = 'A play costs $cost points and you have ${me.pointsBalance}.';
      icon = Icons.account_balance_wallet_outlined;
      onPressed = () async {
        await context.push(AppRoutes.points);
        if (context.mounted) _refreshCompetition(ref, c.id);
      };
    } else {
      label = cost > 0 ? 'Play now · $cost points' : 'Play now · free';
      final daily = me.playsLeftToday == null
          ? ''
          : ' · ${me.playsLeftToday} today';
      note = c.unlimitedPlays
          ? 'Play as often as you like$daily · ${me.pointsBalance} points'
          : '${me.attemptsRemaining} of ${c.maxAttempts} plays left$daily · '
                '${me.pointsBalance} points';
      if (c.isDraw) label = cost > 0 ? 'Enter · $cost points' : 'Enter · free';
      onPressed = () async {
        await context.push(
          c.isChance
              ? AppRoutes.competitionChancePath(c.id)
              : AppRoutes.competitionPlayPath(c.id, c.gameSlug),
        );
        if (context.mounted) _refreshCompetition(ref, c.id);
      };
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          12,
          AppTheme.gutter,
          12,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameGradientButton(
              label: label,
              icon: icon,
              colors: visual.colors,
              onPressed: onPressed,
            ),
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                note,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void _showRules(BuildContext context, Competition c) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          SheetHeader(
            title: 'Official rules',
            titleStyle: AppTypography.display(24),
            showHandle: false,
          ),
          const SizedBox(height: 12),
          Text(
            c.officialRules ??
                'The official rules are published here before the '
                    'competition opens.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 16),
          _Disclosure(
            icon: Icons.verified_user_outlined,
            text: c.prizeGrowthEnabled ? _growingDisclosure : _prizeDisclosure,
          ),
          const SizedBox(height: 10),
          _Disclosure(
            icon: c.isChance
                ? Icons.casino_outlined
                : Icons.psychology_alt_outlined,
            text: c.isChance ? _chanceDisclosure(c) : _skillDisclosure,
          ),
        ],
      ),
    ),
  );
}

// ─── Sections ────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.competition, required this.visual});

  final Competition competition;
  final GameVisual visual;

  @override
  Widget build(BuildContext context) {
    final c = competition;
    return Container(
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
            right: -30,
            top: 40,
            child: Icon(
              Icons.emoji_events_rounded,
              size: 190,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                56,
                AppTheme.gutter,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CompetitionStatusChip(status: c.status),
                  const SizedBox(height: 10),
                  Text(
                    '${c.isChance ? 'PRIZE GAME' : 'SKILL COMPETITION'} · '
                    '${c.gameName.toUpperCase()} · '
                    '${c.countryName.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.eyebrow.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.display(28, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  if (c.prizeCurrency != null) ...[
                    Text(
                      c.prizeGrowthEnabled && c.finalPrizeCents == null
                          ? 'WIN UP TO'
                          : 'PRIZE',
                      style: AppTypography.eyebrow.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    AnimatedPrize(
                      cents: c.headlinePrizeCents,
                      currency: c.prizeCurrency,
                      style: AppTypography.display(34, color: Colors.white),
                    ),
                  ] else
                    Row(
                      children: [
                        const Icon(
                          Icons.card_giftcard_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            c.prizeDescription,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.title});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!.toUpperCase(), style: AppTypography.eyebrow),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.purple),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.mutedForeground),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeCard extends ConsumerWidget {
  const _TimeCard({required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = competition;
    if (c.isLive || c.isUpcoming || c.isPaused) {
      final target = c.isUpcoming ? c.startsAt : c.endsAt;
      return _Panel(
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.isUpcoming
                        ? 'Opens in'
                        : c.isPaused
                        ? 'Paused · closes in'
                        : 'Closes in',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Countdown(
                    target: target,
                    // The server decides the new state; ask it.
                    onDone: () => _refreshCompetition(ref, c.id),
                    builder: (context, left) => Text(
                      formatCountdown(left),
                      style: AppTypography.display(26),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatDateTime(target),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    return _Panel(
      child: Row(
        children: [
          Icon(
            c.isFinal ? Icons.verified_rounded : Icons.hourglass_top_rounded,
            color: AppColors.purple,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              c.isFinal
                  ? 'Final results are in.'
                  : 'Closed. The leading scores are being replayed and '
                        'verified before winners are declared.',
            ),
          ),
        ],
      ),
    );
  }
}

class _PrizeCard extends StatelessWidget {
  const _PrizeCard({required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    final c = competition;
    final value = c.prizeValueLabel;
    final growing = c.prizeGrowthEnabled;
    final muted = Theme.of(context).textTheme.bodyMedium;
    return _Panel(
      title: 'Prize',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (growing && c.prizeCurrency != null) ...[
            Text(
              c.finalPrizeCents != null ? 'Final prize' : 'Win up to',
              style: muted,
            ),
            AnimatedPrize(
              cents: c.headlinePrizeCents,
              currency: c.prizeCurrency,
              style: AppTypography.display(34),
            ),
            const SizedBox(height: 4),
            if (c.finalPrizeCents == null)
              Text(
                c.prizeCapReached
                    ? 'The prize has reached its maximum of '
                          '${c.maxPrizeLabel}.'
                    : 'Prize grows by ${c.incrementLabel} after every '
                          'eligible play'
                          '${c.maxPrizeLabel == null ? '' : ', up to ${c.maxPrizeLabel}'}.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            Text(
              '${c.eligiblePlayCount} valid '
              '${c.eligiblePlayCount == 1 ? 'play' : 'plays'} so far · '
              'started at ${formatMoneyCents(c.startPrizeCents, c.prizeCurrency)}',
              style: muted,
            ),
            const SizedBox(height: 8),
            Text(c.prizeDescription),
          ] else ...[
            Text(c.prizeDescription, style: AppTypography.display(20)),
            if (value != null) Text('Value $value', style: muted),
          ],
          const SizedBox(height: 6),
          Text(switch (c.winnerMethod) {
            'instant' =>
              'Each play wins 1 in ${c.winOdds ?? '?'}. The first winning '
                  'play takes the prize.',
            'draw' =>
              c.numberOfWinners == 1
                  ? 'One winner is drawn from every entry at close.'
                  : '${c.numberOfWinners} winners are drawn from every '
                        'entry at close and share the prize.',
            _ =>
              c.numberOfWinners == 1
                  ? 'The highest verified score wins.'
                  : 'The top ${c.numberOfWinners} verified scores share '
                        'the prize.',
          }),
          const SizedBox(height: 12),
          _Disclosure(
            icon: Icons.verified_user_outlined,
            text: growing ? _growingDisclosure : _prizeDisclosure,
          ),
        ],
      ),
    );
  }
}

/// A prize figure that counts up to its new value when it changes, so a
/// live increment is visible without a jump.
class AnimatedPrize extends StatelessWidget {
  const AnimatedPrize({
    required this.cents,
    required this.currency,
    required this.style,
    super.key,
  });

  final int cents;
  final String? currency;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: cents.toDouble()),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Text(
        formatMoneyCents(value.round(), currency),
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.competition});

  final Competition competition;

  String get _cost {
    final c = competition;
    if (c.pointsPerAttempt == 0) return 'Free';
    return '${c.pointsPerAttempt} points per play';
  }

  @override
  Widget build(BuildContext context) {
    final c = competition;
    final me = c.me;
    final best = me?.bestScore;
    final rank = me?.rank;
    return _Panel(
      title: 'Entry',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Fact(
            icon: Icons.replay_rounded,
            label: 'Plays',
            value: c.unlimitedPlays
                ? 'No limit · play while your points last'
                : me == null
                ? '${c.maxAttempts} per player'
                : '${me.attemptsRemaining} of ${c.maxAttempts} left',
          ),
          if (c.dailyPlayLimit != null)
            _Fact(
              icon: Icons.today_rounded,
              label: 'Each day',
              value: me?.playsLeftToday == null
                  ? '${c.dailyPlayLimit} plays'
                  : '${me!.playsLeftToday} of ${c.dailyPlayLimit} left today',
            ),
          _Fact(icon: Icons.stars_rounded, label: 'Entry', value: _cost),
          if (me != null)
            InkWell(
              onTap: () => context.push(AppRoutes.points),
              borderRadius: BorderRadius.circular(12),
              child: _Fact(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Your points',
                value: '${me.pointsBalance} · see history ›',
              ),
            ),
          _Fact(
            icon: Icons.badge_outlined,
            label: 'Who can enter',
            value: 'Players in ${c.countryName}',
          ),
          if (best != null)
            _Fact(
              icon: Icons.emoji_events_outlined,
              label: 'Your best',
              value: rank == null ? '$best' : '$best · ${ordinal(rank)} place',
            ),
          if (me != null && !me.eligible)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                me.ineligibleReason ??
                    'You are not eligible for this competition.',
                style: const TextStyle(color: AppColors.destructive),
              ),
            ),
          _Disclosure(
            icon: c.isChance
                ? Icons.casino_outlined
                : Icons.psychology_alt_outlined,
            text: c.isChance ? _chanceDisclosure(c) : _skillDisclosure,
          ),
        ],
      ),
    );
  }
}

class _BoardSection extends ConsumerWidget {
  const _BoardSection({required this.competition, required this.visual});

  final Competition competition;
  final GameVisual visual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = competition;
    final board = ref.watch(competitionLeaderboardProvider(c.id));
    final isFinal = board.valueOrNull?.isFinal ?? c.isFinal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Leaderboard',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.display(22),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: visual.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isFinal ? 'Final' : 'Provisional',
                style: TextStyle(
                  color: visual.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Text(
          isFinal
              ? 'Verified final standings.'
              : 'Scores stay provisional until the result is verified.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        board.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) =>
              const Text('Could not load the leaderboard. Pull to refresh.'),
          data: (b) => Column(
            children: [
              // The top five here; everyone on the full board.
              LeaderboardList(
                entries: b.entries.take(5).toList(growable: false),
                me: b.me,
                colors: visual.colors,
                emptyMessage: c.isUpcoming
                    ? 'The board opens when the competition starts.'
                    : 'No scores yet. Be the first on the board.',
              ),
              if (b.entries.isNotEmpty) ...[
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => context.push(
                      AppRoutes.competitionLeaderboardPath(c.id),
                    ),
                    icon: const Icon(Icons.leaderboard_rounded),
                    label: Text(
                      b.totalPlayers > 5
                          ? 'See all ${b.totalPlayers} players'
                          : 'Open full leaderboard',
                    ),
                    style: TextButton.styleFrom(foregroundColor: visual.accent),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WinnersCard extends StatelessWidget {
  const _WinnersCard({required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Winners',
      child: Column(
        children: [
          for (final w in competition.winners)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFFFC53D),
                    child: Text(
                      ordinal(w.prizePosition),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          w.countryName,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${w.score}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CancelledCard extends StatelessWidget {
  const _CancelledCard({required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    final note = competition.cancelNote;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cancelled', style: AppTypography.display(20)),
          const SizedBox(height: 4),
          Text(
            'This competition was cancelled because of '
            '${cancelReasonText(competition.cancelReason)}. No winner will '
            'be declared.',
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(note, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Shown to a player who finished in a prize place.
class _WinCard extends StatelessWidget {
  const _WinCard({required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    final win = competition.me!.win!;
    String title;
    String message;
    var canClaim = false;

    switch (win.status) {
      case 'pending_validation':
        title = 'You finished in a prize place!';
        message =
            "We're verifying your result. Once it's confirmed you can claim "
            'your prize here.';
      case 'validated':
        switch (win.claimStatus) {
          case 'pending' when win.canClaim:
            title = 'You won!';
            message =
                'Claim your prize by ${formatDateTime(win.claimDeadlineAt!)}.';
            canClaim = true;
          case 'pending' || 'expired':
            title = 'Claim window closed';
            message = 'This prize was not claimed within 14 days.';
          case 'claimed':
            title = 'Prize claimed';
            message = "We're checking your claim.";
          case 'verified':
            title = 'Claim verified';
            message = 'Your prize is being prepared for delivery.';
          case 'fulfilled':
            title = 'Prize delivered';
            message = 'Congratulations, and thanks for playing!';
          default:
            title = 'You won!';
            message = 'Your prize claim is being processed.';
        }
      default:
        title = 'Prize reassigned';
        message =
            'This prize passed to the next eligible player under the '
            'official rules.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB800), Color(0xFFFF7A45)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.display(20, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: Colors.white)),
          if (canClaim) ...[
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFFF7A45),
              ),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => _ClaimSheet(competition: competition),
              ),
              child: const Text('Claim your prize'),
            ),
          ],
        ],
      ),
    );
  }
}

/// The winner accepts the prize terms and picks where it should go.
class _ClaimSheet extends ConsumerStatefulWidget {
  const _ClaimSheet({required this.competition});

  final Competition competition;

  @override
  ConsumerState<_ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends ConsumerState<_ClaimSheet> {
  late final Future<List<DeliveryAddress>> _addresses = ref
      .read(gamesRepositoryProvider)
      .deliveryAddresses();

  String? _selected;
  bool _accepted = false;
  bool _sending = false;
  String? _error;

  Future<void> _claim() async {
    final addressId = _selected;
    if (addressId == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(gamesRepositoryProvider)
          .claimPrize(widget.competition.id, addressId: addressId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      _refreshCompetition(ref, widget.competition.id);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Prize claimed. We'll be in touch about delivery."),
        ),
      );
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            title: 'Claim your prize',
            subtitle: widget.competition.prizeDescription,
            titleStyle: AppTypography.display(24),
            showHandle: false,
          ),
          const SizedBox(height: 12),
          Flexible(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    return FutureBuilder<List<DeliveryAddress>>(
      future: _addresses,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Could not load your addresses. Try again later.'),
          );
        }
        final addresses = snapshot.data;
        if (addresses == null) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_selected == null && addresses.isNotEmpty) {
          final preferred = addresses.where((a) => a.isDefault);
          _selected = (preferred.isEmpty ? addresses : preferred).first.id;
        }

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DELIVER TO', style: AppTypography.eyebrow),
              const SizedBox(height: 8),
              if (addresses.isEmpty)
                const Text(
                  'Add a delivery address in your account, then come back '
                  'to claim.',
                )
              else
                for (final address in addresses)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => setState(() => _selected = address.id),
                    leading: Icon(
                      _selected == address.id
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: AppColors.purple,
                    ),
                    title: Text(address.label ?? address.line1),
                    subtitle: Text(
                      address.label == null
                          ? address.summary
                          : '${address.line1}, ${address.summary}',
                    ),
                  ),
              const SizedBox(height: 4),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _accepted,
                onChanged: (value) =>
                    setState(() => _accepted = value ?? false),
                title: const Text(
                  'I accept the prize terms and the official rules',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.destructive),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected != null && _accepted && !_sending
                      ? _claim
                      : null,
                  child: Text(_sending ? 'Claiming…' : 'Claim prize'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
