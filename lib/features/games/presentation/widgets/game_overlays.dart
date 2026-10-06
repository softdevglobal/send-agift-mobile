import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/game.dart';
import '../game_visuals.dart';

/// Dimmed, blurred backdrop that lays a card over the running game.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.45),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  builder: (context, t, child) => Opacity(
                    opacity: t.clamp(0, 1),
                    child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Full-width button in the menu and result cards.
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.gradient,
    this.foreground = AppColors.foreground,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final List<Color>? gradient;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final gradient = this.gradient;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            color: gradient == null
                ? AppColors.muted
                : gradient[gradient.length > 1 ? 1 : 0],
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: gradient == null ? foreground : Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: gradient == null ? foreground : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameBadge extends StatelessWidget {
  const _GameBadge({required this.visual, required this.icon});

  final GameVisual visual;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: visual.colors[1],
        boxShadow: [
          BoxShadow(
            color: visual.accent.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 32),
    );
  }
}

/// Shown while the server issues a seed.
class GameLoading extends StatelessWidget {
  const GameLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Dealing your board…',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Small pill while a finished round is being replayed on the server.
class GameVerifyingBanner extends StatelessWidget {
  const GameVerifyingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 36,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Verifying your score…',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A problem with a primary action and a way out.
class GameMessageCard extends StatelessWidget {
  const GameMessageCard({
    required this.visual,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.onQuit,
    super.key,
  });

  final GameVisual visual;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GameBadge(visual: visual, icon: Icons.wifi_off_rounded),
          const SizedBox(height: 14),
          Text(title, style: AppTypography.display(22)),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          _MenuButton(
            label: actionLabel,
            icon: Icons.refresh_rounded,
            gradient: visual.colors,
            onPressed: onAction,
          ),
          const SizedBox(height: 10),
          _MenuButton(
            label: 'Quit game',
            icon: Icons.logout_rounded,
            onPressed: onQuit,
          ),
        ],
      ),
    );
  }
}

/// [GameMessageCard] laid over a running game.
class GameMessageOverlay extends StatelessWidget {
  const GameMessageOverlay({required this.card, super.key});

  final GameMessageCard card;

  @override
  Widget build(BuildContext context) => _Scrim(child: card);
}

/// The game menu: resume, restart, how to play, quit.
class GamePauseMenu extends StatelessWidget {
  const GamePauseMenu({
    required this.visual,
    required this.onResume,
    required this.onQuit,
    this.onRestart,
    this.onLeaderboard,
    this.quitNote,
    super.key,
  });

  final GameVisual visual;
  final VoidCallback onResume;
  final VoidCallback onQuit;

  /// Hidden when null, e.g. for an official attempt.
  final VoidCallback? onRestart;

  /// Opens the board without leaving the paused round.
  final VoidCallback? onLeaderboard;

  /// What quitting does with the round; defaults to the practice wording.
  final String? quitNote;

  @override
  Widget build(BuildContext context) {
    return _Scrim(
      child: _Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GameBadge(visual: visual, icon: Icons.pause_rounded),
            const SizedBox(height: 12),
            Text('Paused', style: AppTypography.display(26)),
            const SizedBox(height: 4),
            Text(visual.name, style: Theme.of(context).textTheme.bodyMedium),
            if (visual.howToPlay.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HOW TO PLAY', style: AppTypography.eyebrow),
                    const SizedBox(height: 8),
                    for (final line in visual.howToPlay)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: visual.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                line,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            _MenuButton(
              label: 'Resume',
              icon: Icons.play_arrow_rounded,
              gradient: visual.colors,
              onPressed: onResume,
            ),
            if (onRestart != null) ...[
              const SizedBox(height: 10),
              _MenuButton(
                label: 'Restart',
                icon: Icons.refresh_rounded,
                onPressed: onRestart!,
              ),
            ],
            if (onLeaderboard != null) ...[
              const SizedBox(height: 10),
              _MenuButton(
                label: 'Leaderboard',
                icon: Icons.leaderboard_rounded,
                onPressed: onLeaderboard!,
              ),
            ],
            const SizedBox(height: 10),
            _MenuButton(
              label: 'Quit game',
              icon: Icons.logout_rounded,
              foreground: AppColors.destructive,
              onPressed: onQuit,
            ),
            const SizedBox(height: 10),
            Text(
              quitNote ?? 'Quitting banks the score you have so far.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks before leaving a round that is still going, and says what happens
/// to it.
class GameQuitConfirm extends StatelessWidget {
  const GameQuitConfirm({
    required this.visual,
    required this.message,
    required this.onStay,
    required this.onQuit,
    super.key,
  });

  final GameVisual visual;
  final String message;
  final VoidCallback onStay;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return _Scrim(
      child: _Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GameBadge(visual: visual, icon: Icons.logout_rounded),
            const SizedBox(height: 12),
            Text('Leave the game?', style: AppTypography.display(26)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            _MenuButton(
              label: 'Keep playing',
              icon: Icons.play_arrow_rounded,
              gradient: visual.colors,
              onPressed: onStay,
            ),
            const SizedBox(height: 10),
            _MenuButton(
              label: 'Yes, quit',
              icon: Icons.logout_rounded,
              foreground: AppColors.destructive,
              onPressed: onQuit,
            ),
          ],
        ),
      ),
    );
  }
}

/// End-of-round card: the server-verified score, stats, and a celebration
/// when it was a win or a new best.
class GameResultOverlay extends StatelessWidget {
  const GameResultOverlay({
    required this.visual,
    required this.result,
    required this.onQuit,
    this.onPlayAgain,
    this.onLeaderboard,
    super.key,
  });

  final GameVisual visual;
  final GameScoreResult result;
  final VoidCallback onQuit;

  /// Hidden when null, e.g. when no official attempts are left.
  final VoidCallback? onPlayAgain;
  final VoidCallback? onLeaderboard;

  bool get _celebrate =>
      result.accepted &&
      (result.won ||
          result.isPersonalBest ||
          (result.isOfficial && result.rank == 1));

  String get _headline {
    if (result.isOfficial) {
      if (!result.accepted) return 'Attempt under review';
      if (result.rank == 1) return 'Top of the board!';
      if (result.isPersonalBest) return 'New competition best!';
      return 'Attempt submitted';
    }
    if (result.won) return 'You did it!';
    if (result.isPersonalBest) return 'New personal best!';
    return 'Round over';
  }

  @override
  Widget build(BuildContext context) {
    final headline = _headline;
    final rank = result.rank;
    final attemptsLeft = result.attemptsRemaining;

    return Stack(
      children: [
        _Scrim(
          child: _Card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GameBadge(
                  visual: visual,
                  icon: _celebrate
                      ? Icons.emoji_events_rounded
                      : Icons.flag_rounded,
                ),
                const SizedBox(height: 12),
                Text(headline, style: AppTypography.display(26)),
                const SizedBox(height: 14),
                Text('VERIFIED SCORE', style: AppTypography.eyebrow),
                const SizedBox(height: 2),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: result.score.toDouble()),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text(
                    '${value.round()}',
                    style: AppTypography.poster(54, color: visual.colors[1]),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (rank != null)
                      _StatPill(
                        label: 'Rank',
                        value: '#$rank',
                        color: visual.accent,
                      ),
                    for (final entry in result.stats.entries)
                      _StatPill(
                        label: GameVisual.statLabel(entry.key),
                        value: '${entry.value}',
                        color: visual.accent,
                      ),
                    _StatPill(
                      label: result.isOfficial ? 'Your best' : 'Personal best',
                      value: '${result.personalBest}',
                      color: visual.accent,
                    ),
                    if (attemptsLeft != null && attemptsLeft >= 0)
                      _StatPill(
                        label: 'Attempts left',
                        value: '$attemptsLeft',
                        color: visual.accent,
                      ),
                  ],
                ),
                if (!result.accepted) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      result.isOfficial
                          ? 'This attempt is being checked before it counts '
                                'on the competition board. It shows as '
                                '"In review" until then.'
                          : 'This round is being reviewed before it joins the '
                                'leaderboard. Making sure your app is up to '
                                'date usually resolves it.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (onPlayAgain != null) ...[
                  _MenuButton(
                    label: result.isOfficial ? 'Next attempt' : 'Play again',
                    icon: Icons.replay_rounded,
                    gradient: visual.colors,
                    onPressed: onPlayAgain!,
                  ),
                  const SizedBox(height: 10),
                ],
                if (onLeaderboard != null) ...[
                  _MenuButton(
                    label: 'Leaderboard',
                    icon: Icons.leaderboard_rounded,
                    // The main action when there is no next round.
                    gradient: onPlayAgain == null ? visual.colors : null,
                    onPressed: onLeaderboard!,
                  ),
                  const SizedBox(height: 10),
                ],
                _MenuButton(
                  label: 'Quit game',
                  icon: Icons.logout_rounded,
                  onPressed: onQuit,
                ),
              ],
            ),
          ),
        ),
        if (_celebrate)
          Positioned.fill(
            child: IgnorePointer(child: _Confetti(colors: visual.colors)),
          ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label  '),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 13, color: AppColors.foreground),
      ),
    );
  }
}

/// One burst of confetti. Purely decorative, so an ordinary random source is
/// fine here. It has nothing to do with the game's seeded randomness.
class _Confetti extends StatefulWidget {
  const _Confetti({required this.colors});

  final List<Color> colors;

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  late final List<_Piece> _pieces = () {
    final random = math.Random();
    final palette = [...widget.colors, Colors.white, const Color(0xFFFFE066)];
    return List.generate(70, (i) {
      return _Piece(
        x: random.nextDouble(),
        vx: (random.nextDouble() - 0.5) * 0.5,
        vy: -(0.6 + random.nextDouble() * 0.7),
        spin: (random.nextDouble() - 0.5) * 12,
        size: 5 + random.nextDouble() * 6,
        color: palette[random.nextInt(palette.length)],
      );
    });
  }();

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    return CustomPaint(
      painter: _ConfettiPainter(pieces: _pieces, t: _controller),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.size,
    required this.color,
  });

  final double x;
  final double vx;
  final double vy;
  final double spin;
  final double size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.pieces, required this.t}) : super(repaint: t);

  final List<_Piece> pieces;
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final time = t.value;
    if (time >= 1) return;
    final fade = time < 0.75 ? 1.0 : 1 - (time - 0.75) / 0.25;
    for (final p in pieces) {
      final x = (p.x + p.vx * time) * size.width;
      final y = size.height * (0.55 + p.vy * time + 1.3 * time * time);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.spin * time);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = p.color.withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => false;
}
