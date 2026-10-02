import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/games_providers.dart';
import '../../data/games_repository.dart';
import '../../domain/competition.dart';
import '../game_visuals.dart';

/// One play of a chance game: spin the wheel, scratch a card, open a chest,
/// unwrap a gift, or enter a prize draw.
///
/// The server decides the outcome when the play is made, with a secure
/// random draw, and sends it back with the receipt. Everything on this
/// screen only reveals that result — no tap, swipe or timing changes it, and
/// the screen says so.
class ChancePlayScreen extends ConsumerStatefulWidget {
  const ChancePlayScreen({required this.competitionId, super.key});

  final String competitionId;

  @override
  ConsumerState<ChancePlayScreen> createState() => _ChancePlayScreenState();
}

class _ChancePlayScreenState extends ConsumerState<ChancePlayScreen> {
  AttemptStart? _play;
  String? _error;
  bool _retryable = true;
  String? _errorRoute;
  bool _loading = true;
  bool _revealed = false;

  /// Kept until the server answers, so a retry after a dropped connection
  /// returns the same play instead of charging again.
  String? _playKey;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
      _play = null;
      _revealed = false;
    });
    try {
      final key = _playKey ??= GamesRepository.newPlayKey();
      final play = await ref
          .read(gamesRepositoryProvider)
          .startAttempt(widget.competitionId, playKey: key);
      _playKey = null;
      if (!mounted) return;
      ref.invalidate(competitionProvider(widget.competitionId));
      ref.invalidate(competitionsProvider);
      setState(() {
        _play = play;
        _loading = false;
        // A draw entry has nothing to reveal.
        _revealed = play.result?.isDrawEntry ?? true;
      });
    } on AppException catch (error) {
      if (!mounted) return;
      final transient = switch (error.code) {
        'INSUFFICIENT_POINTS' ||
        'PLAY_LIMIT_REACHED' ||
        'GAME_NOT_ACTIVE' ||
        'OUTSIDE_GAME_WINDOW' ||
        'PRIZE_CAP_REACHED' ||
        'NOT_ELIGIBLE' ||
        'IDEMPOTENCY_CONFLICT' => false,
        _ => true,
      };
      if (!transient) _playKey = null;
      final d = error.details;
      final need = d['points_required'];
      final have = d['points_balance'];
      setState(() {
        _loading = false;
        _retryable = transient;
        _errorRoute = error.code == 'INSUFFICIENT_POINTS'
            ? AppRoutes.points
            : null;
        _error = error.code == 'INSUFFICIENT_POINTS' && need != null
            ? 'A play costs $need points and you have $have. Nothing was '
                  'charged.'
            : transient
            ? error.message
            : '${error.message} Nothing was charged.';
      });
    }
  }

  void _onRevealed() {
    if (_revealed) return;
    HapticFeedback.mediumImpact();
    setState(() => _revealed = true);
  }

  @override
  Widget build(BuildContext context) {
    final competition = ref
        .watch(competitionProvider(widget.competitionId))
        .valueOrNull;
    final slug = competition?.gameSlug ?? '';
    final visual = GameVisual.of(slug);

    return Scaffold(
      backgroundColor: visual.colors.first,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(visual.name),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: visual.colors,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : _error != null
              ? _ErrorCard(
                  message: _error!,
                  actionLabel: _retryable
                      ? 'Try again'
                      : _errorRoute != null
                      ? 'See my points'
                      : 'Back to the competition',
                  onAction: _retryable
                      ? _start
                      : () {
                          final route = _errorRoute;
                          if (route == null) {
                            context.pop();
                          } else {
                            context.pushReplacement(route);
                          }
                        },
                )
              : _buildPlay(context, competition, visual),
        ),
      ),
    );
  }

  Widget _buildPlay(
    BuildContext context,
    Competition? competition,
    GameVisual visual,
  ) {
    final play = _play!;
    final result = play.result;
    final currency = competition?.prizeCurrency;
    final cost = competition?.pointsPerAttempt ?? play.pointsSpent;
    final canPlayAgain =
        _revealed &&
        !(result?.won ?? false) &&
        play.attemptsRemaining != 0 && // -1: no limit
        play.walletPointsRemaining >= cost &&
        (competition?.isLive ?? true);

    Widget reveal;
    switch (result?.mechanic) {
      case 'spin':
        reveal = _SpinWheel(result: result!, onDone: _onRevealed);
      case 'scratch':
        reveal = _ScratchCard(result: result!, onDone: _onRevealed);
      case 'treasure':
        reveal = _Chests(result: result!, onDone: _onRevealed);
      case 'draw':
        reveal = _DrawTicket(entry: result!.entryNumber ?? play.attemptNumber);
      default:
        reveal = _GiftBox(
          result: result ?? const ChanceResult(mechanic: 'instant', won: false),
          onDone: _onRevealed,
        );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _Receipt(play: play, currency: currency),
        const SizedBox(height: 20),
        reveal,
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: !_revealed
              ? Text(
                  visual.hint,
                  key: const ValueKey('hint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                )
              : _Outcome(
                  key: const ValueKey('outcome'),
                  result: result,
                  prize: currency == null
                      ? null
                      : formatMoneyCents(play.prizeAfterCents, currency),
                ),
        ),
        const SizedBox(height: 24),
        if (canPlayAgain)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: visual.colors[1],
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _start,
            child: Text(cost > 0 ? 'Play again · $cost points' : 'Play again'),
          ),
        if (_revealed) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => context.pop(),
            child: const Text('Back to the competition'),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          result?.odds != null
              ? 'Each play wins 1 in ${result!.odds}. This result was drawn by '
                    'our server when you played (draw ${result.draw}).'
              : 'Winners are drawn at random from every entry when the round '
                    'closes.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({required this.play, required this.currency});

  final AttemptStart play;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (play.pointsSpent > 0)
        '−${play.pointsSpent} pts · ${play.walletPointsRemaining} left',
      if (currency != null && play.prizeIncrementCents > 0)
        'prize +${formatMoneyCents(play.prizeIncrementCents, currency)}',
      if (play.replayed) 'already played — not charged again',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          parts.join(' · '),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({required this.result, required this.prize, super.key});

  final ChanceResult? result;
  final String? prize;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final String title;
    final String body;
    if (r == null || r.isDrawEntry) {
      title = "You're in the draw!";
      body =
          'Winners are drawn from every entry when the round closes. '
          'More plays mean more entries.';
    } else if (r.won) {
      title = prize == null ? 'You won!' : 'You won $prize!';
      body =
          'The round is closed and your win is recorded. We will check it '
          'and open your prize claim on the competition page.';
    } else {
      title = 'Not this time';
      body = 'No win on this play.';
    }
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.display(28, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
              ),
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reveals ─────────────────────────────────────────────────────────────

/// The wheel spins and stops on the segment the server drew. Segment 0 is
/// the jackpot.
class _SpinWheel extends StatefulWidget {
  const _SpinWheel({required this.result, required this.onDone});

  final ChanceResult result;
  final VoidCallback onDone;

  @override
  State<_SpinWheel> createState() => _SpinWheelState();
}

class _SpinWheelState extends State<_SpinWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  late final Animation<double> _turn = CurvedAnimation(
    parent: _spin,
    curve: Curves.easeOutCubic,
  );
  bool _started = false;

  int get _segments => math.max(2, widget.result.segments ?? 8);

  /// How far to turn so the chosen segment ends up under the pointer.
  double get _target {
    final slice = 2 * math.pi / _segments;
    final segment = widget.result.segment ?? 0;
    return 6 * 2 * math.pi - segment * slice;
  }

  @override
  void initState() {
    super.initState();
    _spin.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _go() {
    if (_started) return;
    setState(() => _started = true);
    if (MediaQuery.disableAnimationsOf(context)) {
      _spin.value = 1;
      widget.onDone();
    } else {
      _spin.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.arrow_drop_down_rounded,
          color: Colors.white,
          size: 48,
        ),
        AspectRatio(
          aspectRatio: 1,
          child: AnimatedBuilder(
            animation: _turn,
            builder: (context, _) => Transform.rotate(
              angle: _turn.value * _target,
              child: CustomPaint(painter: _WheelPainter(_segments)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!_started)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              minimumSize: const Size(200, 52),
            ),
            onPressed: _go,
            icon: const Icon(Icons.casino_rounded),
            label: const Text('Spin'),
          ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.segments);

  final int segments;

  static const _colors = [
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFF97316),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final slice = 2 * math.pi / segments;
    for (var i = 0; i < segments; i++) {
      // Segment i is centred straight up once the wheel has turned by
      // -i * slice, which is how the spin lands on the drawn segment.
      final start = -math.pi / 2 + i * slice - slice / 2;
      final paint = Paint()
        ..color = i == 0
            ? const Color(0xFFFACC15)
            : _colors[(i - 1) % _colors.length];
      canvas.drawArc(rect, start, slice, true, paint);
      canvas.drawArc(
        rect,
        start,
        slice,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.7),
      );
      final mid = start + slice / 2;
      final at = center + Offset(math.cos(mid), math.sin(mid)) * radius * 0.68;
      final painter = TextPainter(
        text: TextSpan(
          text: i == 0 ? 'JACKPOT' : '✦',
          style: TextStyle(
            color: i == 0 ? const Color(0xFF713F12) : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: i == 0 ? radius * 0.1 : radius * 0.12,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(mid + math.pi / 2);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }
    canvas.drawCircle(center, radius * 0.12, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.segments != segments;
}

/// Nine panels to scratch. Three jackpots means the card won.
class _ScratchCard extends StatefulWidget {
  const _ScratchCard({required this.result, required this.onDone});

  final ChanceResult result;
  final VoidCallback onDone;

  @override
  State<_ScratchCard> createState() => _ScratchCardState();
}

class _ScratchCardState extends State<_ScratchCard> {
  final Set<int> _scratched = {};

  static const _icons = {
    'jackpot': Icons.emoji_events_rounded,
    'gift': Icons.card_giftcard_rounded,
    'star': Icons.star_rounded,
    'heart': Icons.favorite_rounded,
    'diamond': Icons.diamond_rounded,
    'clover': Icons.spa_rounded,
  };

  void _scratch(int i) {
    if (!_scratched.add(i)) return;
    HapticFeedback.selectionClick();
    setState(() {});
    if (_scratched.length == 9) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final cells = widget.result.cells.length == 9
        ? widget.result.cells
        : List.filled(9, 'star');
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (var i = 0; i < 9; i++)
              GestureDetector(
                onTap: () => _scratch(i),
                onPanDown: (_) => _scratch(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    color: _scratched.contains(i)
                        ? Colors.white
                        : const Color(0xFFB8B8C8),
                    borderRadius: BorderRadius.circular(16),
                    gradient: _scratched.contains(i)
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFFD4D4DC), Color(0xFF9CA3AF)],
                          ),
                  ),
                  child: Center(
                    child: _scratched.contains(i)
                        ? Icon(
                            _icons[cells[i]] ?? Icons.star_rounded,
                            size: 40,
                            color: cells[i] == 'jackpot'
                                ? const Color(0xFFD97706)
                                : const Color(0xFF6B7280),
                          )
                        : const Text(
                            'SCRATCH',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_scratched.length < 9)
          TextButton(
            onPressed: () {
              for (var i = 0; i < 9; i++) {
                _scratched.add(i);
              }
              setState(() {});
              widget.onDone();
            },
            child: const Text(
              'Reveal all',
              style: TextStyle(color: Colors.white),
            ),
          ),
      ],
    );
  }
}

/// Three chests; the one tapped opens to show what the play found.
class _Chests extends StatefulWidget {
  const _Chests({required this.result, required this.onDone});

  final ChanceResult result;
  final VoidCallback onDone;

  @override
  State<_Chests> createState() => _ChestsState();
}

class _ChestsState extends State<_Chests> {
  int? _opened;

  @override
  Widget build(BuildContext context) {
    final won = widget.result.contents == 'jackpot';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < 3; i++)
          GestureDetector(
            onTap: _opened != null
                ? null
                : () {
                    setState(() => _opened = i);
                    widget.onDone();
                  },
            child: AnimatedScale(
              scale: _opened == i ? 1.2 : 1,
              duration: const Duration(milliseconds: 300),
              child: AnimatedOpacity(
                opacity: _opened == null || _opened == i ? 1 : 0.35,
                duration: const Duration(milliseconds: 300),
                child: Column(
                  children: [
                    Icon(
                      _opened == i
                          ? (won
                                ? Icons.emoji_events_rounded
                                : Icons.inventory_2_outlined)
                          : Icons.inventory_2_rounded,
                      size: 76,
                      color: _opened == i && won
                          ? const Color(0xFFFACC15)
                          : Colors.white,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _opened == i ? (won ? 'JACKPOT' : 'Empty') : 'Tap',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A gift to open.
class _GiftBox extends StatefulWidget {
  const _GiftBox({required this.result, required this.onDone});

  final ChanceResult result;
  final VoidCallback onDone;

  @override
  State<_GiftBox> createState() => _GiftBoxState();
}

class _GiftBoxState extends State<_GiftBox> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open
          ? null
          : () {
              setState(() => _open = true);
              widget.onDone();
            },
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              _open
                  ? (widget.result.won
                        ? Icons.emoji_events_rounded
                        : Icons.sentiment_neutral_rounded)
                  : Icons.redeem_rounded,
              key: ValueKey(_open),
              size: 150,
              color: _open && widget.result.won
                  ? const Color(0xFFFACC15)
                  : Colors.white,
            ),
          ),
          if (!_open)
            const Text(
              'Tap to open',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

/// A prize-draw entry ticket.
class _DrawTicket extends StatelessWidget {
  const _DrawTicket({required this.entry});

  final int entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.confirmation_number_rounded,
            size: 56,
            color: Color(0xFF0284C7),
          ),
          const SizedBox(height: 8),
          Text('ENTRY', style: AppTypography.eyebrow),
          Text('#$entry', style: AppTypography.display(40)),
        ],
      ),
    );
  }
}
