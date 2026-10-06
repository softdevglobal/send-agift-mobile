import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../domain/competition.dart';
import '../competition_format.dart';
import '../game_visuals.dart';
import 'countdown.dart';

/// A competition in the game zone strip.
class CompetitionCard extends StatelessWidget {
  const CompetitionCard({
    required this.competition,
    required this.onTap,
    super.key,
  });

  final Competition competition;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = competition;
    final visual = GameVisual.of(c.gameSlug);

    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 290,
        decoration: BoxDecoration(
          color: visual.colors[1],
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: visual.colors[1].withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                bottom: -18,
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: 120,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CompetitionStatusChip(status: c.status),
                        const Spacer(),
                        Icon(visual.icon, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          c.gameName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      c.title,
                      maxLines: c.prizeGrowthEnabled ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(20, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    if (c.prizeGrowthEnabled && c.prizeCurrency != null)
                      _GrowingPrize(competition: c)
                    else
                      Row(
                        children: [
                          const Icon(
                            Icons.card_giftcard_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              c.prizeDescription,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    _TimeLine(competition: c),
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

/// The spec's game card (§6.1): "WIN UP TO $348. +$1 a play · 10 points ·
/// 248 plays", in the space one line of prize text used to take.
class _GrowingPrize extends StatelessWidget {
  const _GrowingPrize({required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    final c = competition;
    final small = TextStyle(
      color: Colors.white.withValues(alpha: 0.9),
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
    );
    final growth = c.finalPrizeCents != null
        ? 'final prize'
        : c.prizeCapReached
        ? 'maximum reached'
        : '+${c.incrementLabel} every play';
    final cost = c.pointsPerAttempt > 0
        ? '${c.pointsPerAttempt} pts to play'
        : 'free to play';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              c.finalPrizeCents != null ? 'PRIZE ' : 'WIN UP TO ',
              style: small.copyWith(letterSpacing: 0.6),
            ),
            Flexible(
              child: Text(
                c.headlinePrize,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.display(22, color: Colors.white),
              ),
            ),
          ],
        ),
        Text(
          '$growth · $cost · ${c.eligiblePlayCount} plays',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: small,
        ),
      ],
    );
  }
}

class _TimeLine extends StatelessWidget {
  const _TimeLine({required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    final c = competition;
    final me = c.me;
    const style = TextStyle(
      color: Colors.white,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    );
    final attempts = me != null && c.isLive && !c.unlimitedPlays
        ? ' · ${me.attemptsRemaining} of ${c.maxAttempts} left'
        : '';

    Widget line(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );

    if (c.isLive || c.isUpcoming || c.isPaused) {
      return Countdown(
        target: c.isUpcoming ? c.startsAt : c.endsAt,
        builder: (context, left) => line(
          '${c.isUpcoming
              ? 'Starts in'
              : c.isPaused
              ? 'Paused · ends in'
              : 'Ends in'} '
          '${formatCountdown(left)}'
          '$attempts',
        ),
      );
    }
    return line(switch (c.status) {
      'finalised' => 'Winners announced',
      'cancelled' => 'Cancelled',
      _ => 'Closed · verifying results',
    });
  }
}

/// LIVE / UPCOMING / VERIFYING / RESULTS / CANCELLED pill. The live one
/// pulses.
class CompetitionStatusChip extends StatelessWidget {
  const CompetitionStatusChip({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'live' => 'LIVE',
      'paused' => 'PAUSED',
      'scheduled' => 'UPCOMING',
      'finalised' => 'RESULTS',
      'cancelled' => 'CANCELLED',
      _ => 'VERIFYING',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: status == 'live'
            ? const Color(0xFFE11D48)
            : Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'live') ...[
            const _PulseDot(),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
