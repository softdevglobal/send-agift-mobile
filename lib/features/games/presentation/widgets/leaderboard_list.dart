import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../domain/game.dart';
import '../competition_format.dart';

const _gold = Color(0xFFFFC53D);
const _silver = Color(0xFFB8C2D6);
const _bronze = Color(0xFFE0955B);

Color _medal(int place) => switch (place) {
  1 => _gold,
  2 => _silver,
  _ => _bronze,
};

String _initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
}

/// A board: the top three on a podium, then everyone else, then the
/// player's own row pinned at the bottom when they rank further down.
class LeaderboardList extends StatelessWidget {
  const LeaderboardList({
    required this.entries,
    required this.colors,
    this.me,
    this.emptyMessage = 'No scores yet. Be the first on the board.',
    super.key,
  });

  final List<LeaderboardEntry> entries;
  final List<Color> colors;
  final LeaderboardEntry? me;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final me = this.me;
    final accent = colors[1];
    if (entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusBox),
          border: Border.all(color: AppColors.boxBorder, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(Icons.leaderboard_rounded, size: 36, color: accent),
            const SizedBox(height: 8),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final rest = entries.skip(3).toList(growable: false);
    final meOutside = me != null && !entries.any((e) => e.isMe);

    return Column(
      children: [
        _Podium(entries: entries.take(3).toList(growable: false)),
        const SizedBox(height: 14),
        for (var i = 0; i < rest.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FadeSlideIn(
              delay: Duration(milliseconds: 40 * i),
              child: LeaderboardRow(entry: rest[i], accent: accent),
            ),
          ),
        if (meOutside) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Icon(
              Icons.more_horiz_rounded,
              color: AppColors.mutedForeground.withValues(alpha: 0.6),
            ),
          ),
          LeaderboardRow(entry: me, accent: accent),
        ],
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    // Second on the left, first in the middle, third on the right.
    final spots = <(LeaderboardEntry, int)>[
      if (entries.length > 1) (entries[1], 2),
      (entries[0], 1),
      if (entries.length > 2) (entries[2], 3),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (entry, place) in spots)
          Expanded(
            child: _PodiumSpot(entry: entry, place: place),
          ),
      ],
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  const _PodiumSpot({required this.entry, required this.place});

  final LeaderboardEntry entry;
  final int place;

  @override
  Widget build(BuildContext context) {
    final medal = _medal(place);
    final height = switch (place) {
      1 => 104.0,
      2 => 78.0,
      _ => 60.0,
    };
    final animate = !MediaQuery.disableAnimationsOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (place == 1)
            const Icon(Icons.emoji_events_rounded, color: _gold, size: 28),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: medal,
              boxShadow: [
                BoxShadow(
                  color: medal.withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: place == 1 ? 28 : 22,
              backgroundColor: AppColors.surface,
              child: Text(
                _initial(entry.displayName),
                style: AppTypography.display(place == 1 ? 22 : 18),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entry.isMe ? '${entry.displayName} (you)' : entry.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          Text('${entry.score}', style: AppTypography.display(18)),
          if (entry.underReview)
            const _Tag(label: 'In review', color: AppColors.star)
          else if (entry.countryName != null)
            Text(
              entry.countryName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: animate ? 0 : height, end: height),
            duration: animate
                ? Duration(milliseconds: 500 + 150 * (3 - place))
                : Duration.zero,
            curve: Curves.easeOutBack,
            builder: (context, h, child) =>
                SizedBox(height: h.clamp(0, height + 12), child: child),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: medal,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${entry.rank}',
                style: AppTypography.display(24, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One ranked player: rank, name, country, time and score.
class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({required this.entry, required this.accent, super.key});

  final LeaderboardEntry entry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (entry.countryName != null) entry.countryName!,
      if (entry.durationMs > 0) formatPlayTime(entry.durationMs),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isMe ? accent.withValues(alpha: 0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusBox),
        border: Border.all(
          color: entry.isMe ? accent : AppColors.boxBorder,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '${entry.rank}',
              textAlign: TextAlign.center,
              style: AppTypography.display(18),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 17,
            backgroundColor: accent.withValues(alpha: 0.15),
            child: Text(
              _initial(entry.displayName),
              style: TextStyle(color: accent, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (entry.isMe) ...[
                      const SizedBox(width: 6),
                      _Tag(label: 'You', color: accent),
                    ],
                  ],
                ),
                if (details.isNotEmpty)
                  Text(details, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.score}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              if (entry.underReview)
                const _Tag(label: 'In review', color: AppColors.star),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusBoxSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
