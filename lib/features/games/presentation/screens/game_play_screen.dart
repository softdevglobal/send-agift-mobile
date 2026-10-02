import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../data/games_providers.dart';
import '../../data/games_repository.dart';
import '../../domain/competition.dart';
import '../../domain/game.dart';
import '../../domain/game_engine.dart';
import '../game_controls.dart';
import '../game_definitions.dart';
import '../competition_format.dart';
import '../game_visuals.dart';
import '../widgets/game_backdrop.dart';
import '../widgets/game_hud.dart';
import '../widgets/game_leaderboard_sheet.dart';
import '../widgets/game_overlays.dart';

/// Runs any game full-screen, like a separate window over the app.
///
/// Owns everything the games share: opening a server session, the game menu,
/// quitting, submitting the move log, and the result card. Each game only
/// brings its engine and board through its [GameDefinition].
///
/// The app is never the authority on the result — when a round ends the move
/// log goes to the server, which replays it from the seed it issued.
class GamePlayScreen extends ConsumerStatefulWidget {
  const GamePlayScreen({
    required this.definition,
    this.competitionId,
    super.key,
  });

  final GameDefinition definition;

  /// Set for an official competition attempt. The session then comes from
  /// the competition (the same board for every entrant), a restart is not
  /// offered because it would use another attempt, and the score goes on
  /// the competition's board.
  final String? competitionId;

  @override
  ConsumerState<GamePlayScreen> createState() => _GamePlayScreenState();
}

/// The room the game itself gets: everything below the panels and above the
/// hint. Named so a test can check a game actually fills it.
const gamePlayAreaKey = ValueKey('game-play-area');

/// Refreshes whichever boards a submitted round changes.
void _invalidateBoards(
  void Function(ProviderOrFamily provider) invalidate,
  String slug,
  String? competitionId,
) {
  if (competitionId == null) {
    invalidate(leaderboardProvider(slug));
    return;
  }
  invalidate(competitionProvider(competitionId));
  invalidate(competitionLeaderboardProvider(competitionId));
  invalidate(competitionsProvider);
}

class _GamePlayScreenState extends ConsumerState<GamePlayScreen> {
  GameSession? _session;
  GameEngine? _engine;

  bool _loading = true;
  String? _loadError;
  bool _paused = false;

  /// The "Leave the game?" pop-up is showing.
  bool _confirmingQuit = false;
  bool _submitting = false;

  /// Set as soon as a round is sent, so it can never be sent twice.
  bool _submitted = false;
  String? _submitError;
  GameScoreResult? _result;

  /// Which official attempt this is, for the badge.
  int? _attemptNumber;

  /// The idempotency key of the official play being started. It is kept
  /// until the server answers, so retrying after a dropped connection
  /// returns the same play instead of charging again (spec §4.2).
  String? _playKey;

  /// What the official play cost and did to the prize.
  AttemptStart? _receipt;

  /// Whether starting failed for a reason worth retrying (a network blip),
  /// rather than a refusal like not having enough points.
  bool _loadRetryable = true;

  /// Where a refusal points the player next, when somewhere helps.
  String? _loadErrorRoute;
  String? _loadErrorAction;

  /// The level a practice round on a [GameDefinition.hasLevels] game is
  /// playing at. Clearing one climbs it; falling short drops it back to 1.
  int _level = 1;

  /// Bumped per round so the board widget (and any clock it owns) is rebuilt
  /// from scratch rather than carried over.
  int _round = 0;

  String get _slug => widget.definition.slug;
  bool get _official => widget.competitionId != null;

  /// Practice can always go again; an official attempt while attempts
  /// remain (-1 from the server means the round has no limit).
  bool get _canPlayAgain =>
      !_official || (_result?.attemptsRemaining ?? 0) != 0;

  @override
  void initState() {
    super.initState();
    // A game takes over the whole screen.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _start();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _paused = false;
      _confirmingQuit = false;
      _submitting = false;
      _submitted = false;
      _submitError = null;
      _result = null;
      _engine = null;
      _session = null;
    });

    try {
      final repo = ref.read(gamesRepositoryProvider);
      final GameSession session;
      int? attemptNumber;
      final competitionId = widget.competitionId;
      if (competitionId != null) {
        final key = _playKey ??= GamesRepository.newPlayKey();
        final attempt = await repo.startAttempt(competitionId, playKey: key);
        _playKey = null;
        _receipt = attempt;
        session = attempt.session;
        attemptNumber = attempt.attemptNumber;
        // The prize and the points balance moved; screens behind this one
        // should show it.
        _invalidateBoards(ref.invalidate, _slug, competitionId);
      } else {
        session = await repo.startSession(
          _slug,
          level: widget.definition.hasLevels ? _level : 1,
        );
        // The play was paid for; balances elsewhere should show it.
        if (session.pointsCharged > 0) ref.invalidate(pointsWalletProvider);
      }
      if (!mounted) return;
      setState(() {
        _session = session;
        _attemptNumber = attemptNumber;
        _engine = widget.definition.createEngine(session);
        _round++;
        _loading = false;
      });
    } on AppException catch (error) {
      if (!mounted) return;
      final refusal = _describeRefusal(error);
      // A refusal never used the key, and a new attempt is a new intention.
      if (!refusal.retryable) _playKey = null;
      setState(() {
        _loadError = refusal.message;
        _loadRetryable = refusal.retryable;
        _loadErrorRoute = refusal.route;
        _loadErrorAction = refusal.action;
        _loading = false;
      });
    }
  }

  /// Turns a refused play into what the player should read and do next.
  /// Nothing was charged for any of these.
  ({String message, bool retryable, String? route, String? action})
  _describeRefusal(AppException error) {
    final d = error.details;
    int? n(String key) => d[key] is num ? (d[key] as num).toInt() : null;
    switch (error.code) {
      case 'INSUFFICIENT_POINTS':
        final need = n('points_required');
        final have = n('points_balance');
        return (
          message: need != null && have != null
              ? 'A play costs $need points and you have $have. '
                    'Nothing was charged.'
              : error.message,
          retryable: false,
          route: AppRoutes.points,
          action: 'See my points',
        );
      case 'SIGN_IN_REQUIRED':
        return (
          message: error.message,
          retryable: false,
          route: AppRoutes.login,
          action: 'Sign in',
        );
      case 'PLAY_LIMIT_REACHED':
        final next = d['next_eligible_at'] is String
            ? DateTime.tryParse(d['next_eligible_at'] as String)
            : null;
        return (
          message: next == null
              ? error.message
              : '${error.message} More plays open ${formatDateTime(next)}.',
          retryable: false,
          route: null,
          action: null,
        );
      case 'GAME_NOT_ACTIVE' ||
          'OUTSIDE_GAME_WINDOW' ||
          'PRIZE_CAP_REACHED' ||
          'NOT_ELIGIBLE' ||
          'IDEMPOTENCY_CONFLICT':
        return (
          message: '${error.message} Nothing was charged.',
          retryable: false,
          route: null,
          action: null,
        );
      default:
        // Network trouble, a busy moment or a server error: safe to retry
        // with the same key, which can never charge twice.
        return (
          message: error.code == 'PLAY_TRANSACTION_FAILED'
              ? 'The play could not be completed and you have not been '
                    'charged. Try again.'
              : error.message,
          retryable: true,
          route: null,
          action: null,
        );
    }
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    final engine = _engine;
    if (engine != null && engine.isOver && !_submitted) _submit();
  }

  Future<void> _submit() async {
    final engine = _engine;
    final session = _session;
    if (engine == null || session == null || _submitting) return;

    setState(() {
      _submitted = true;
      _submitting = true;
      _submitError = null;
    });

    try {
      final result = await ref
          .read(gamesRepositoryProvider)
          .submitScore(
            session.sessionId,
            moves: engine.moves,
            clientScore: engine is UnscoredGame ? null : engine.score,
          );
      if (!mounted) return;
      _invalidateBoards(ref.invalidate, _slug, widget.competitionId);
      if (widget.definition.hasLevels) {
        _level = result.won ? _level + 1 : 1;
      }
      setState(() {
        _result = result;
        _submitting = false;
      });
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = error.message;
      });
    }
  }

  /// Leaving or restarting mid-round still banks the run. A bank can only ever
  /// raise a personal best, never lower it, and it closes the session instead
  /// of leaving it to expire. Fire-and-forget, so leaving is instant.
  void _bankInBackground() {
    final engine = _engine;
    final session = _session;
    if (engine == null ||
        session == null ||
        _submitted ||
        !engine.hasProgress) {
      return;
    }
    _submitted = true;

    final repo = ref.read(gamesRepositoryProvider);
    // The container outlives this screen, so the boards can still refresh.
    final container = ProviderScope.containerOf(context, listen: false);
    final slug = _slug;
    final competitionId = widget.competitionId;
    unawaited(
      repo
          .submitScore(
            session.sessionId,
            moves: engine.moves,
            clientScore: engine is UnscoredGame ? null : engine.score,
          )
          .then(
            (_) => _invalidateBoards(container.invalidate, slug, competitionId),
          )
          .catchError((Object _) {}),
    );
  }

  void _quit() {
    _bankInBackground();
    Navigator.of(context).pop();
  }

  void _restart() {
    _bankInBackground();
    // A deliberate restart gives up the climb rather than continuing it.
    if (widget.definition.hasLevels) _level = 1;
    _start();
  }

  void _openMenu() {
    if (_engine == null || _result != null || _submitting) return;
    setState(() => _paused = true);
  }

  void _resume() => setState(() => _paused = false);

  /// The system back gesture opens the game menu rather than dropping the
  /// player out mid-round; from the menu it resumes.
  /// Quitting mid-round asks first; the round is paused behind the pop-up.
  void _askQuit() => setState(() {
    _paused = true;
    _confirmingQuit = true;
  });

  void _cancelQuit() => setState(() => _confirmingQuit = false);

  /// What leaving now does with the round.
  String get _quitMessage {
    final engine = _engine;
    final played = engine != null && engine.hasProgress;
    if (_official) {
      return played
          ? 'This attempt will be submitted with ${engine.score} points and '
                'counts as one of your attempts.'
          : 'Nothing has been played, but this attempt still counts as used.';
    }
    return played
        ? 'Your score so far (${engine.score}) will be saved.'
        : 'Nothing has been played yet.';
  }

  void _handleBack() {
    if (_confirmingQuit) {
      _cancelQuit();
      return;
    }
    if (_engine == null || _result != null || _loadError != null) {
      _quit();
      return;
    }
    setState(() => _paused = !_paused);
  }

  @override
  Widget build(BuildContext context) {
    final visual = GameVisual.of(_slug);
    final engine = _engine;
    // Only once the game is up: while it is loading, or explaining why it
    // could not start, the message belongs in the middle of the panel
    // layout rather than painted across the whole screen.
    final immersive = widget.definition.immersive && engine != null;
    // Practice shows the player's all-time best; an official attempt has its
    // own board, so the practice best would only mislead.
    final best = _official
        ? null
        : ref.watch(leaderboardProvider(_slug)).valueOrNull?.myBest;
    // The board opens as a sheet over the game, so the round is kept.
    void openBoard() => showGameLeaderboard(
      context,
      slug: _slug,
      competitionId: widget.competitionId,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: visual.colors.first,
        body: Stack(
          children: [
            Positioned.fill(child: GameBackdrop(colors: visual.colors)),

            // A game that paints its own scene takes the whole screen, panels
            // and all, so the court carries on behind the score instead of
            // stopping at a seam and handing over to a different backdrop.
            if (immersive)
              Positioned.fill(
                child: SizedBox.expand(
                  key: gamePlayAreaKey,
                  child: _buildBody(visual, engine),
                ),
              ),

            SafeArea(
              child: Column(
                children: [
                  // The panels sit over the game, and swallow the taps that
                  // land on them: a game reading the whole screen would
                  // otherwise take a tap on the score as a move.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        children: [
                          GameTopBar(
                            title: visual.name,
                            icon: visual.icon,
                            best: best,
                            onMenu: engine == null ? _quit : _openMenu,
                          ),
                          if (_official)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _OfficialBadge(
                                attemptNumber: _attemptNumber,
                                receipt: _receipt,
                                currency: ref
                                    .watch(
                                      competitionProvider(
                                        widget.competitionId!,
                                      ),
                                    )
                                    .valueOrNull
                                    ?.prizeCurrency,
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (engine != null)
                            GameStatsRow(
                              stats: [
                                if (widget.definition.hasLevels)
                                  GameStat('Level', _level),
                                ...widget.definition.stats(engine),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (immersive)
                    const Spacer()
                  else
                    Expanded(
                      // A board of pieces keeps a margin down each side. It
                      // is a fixed shape sitting on the screen rather than a
                      // scene filling it, and run hard against the edges it
                      // looks wedged in.
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: SizedBox.expand(
                          key: gamePlayAreaKey,
                          child: _buildBody(visual, engine),
                        ),
                      ),
                    ),
                  if (engine != null && visual.hint.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        visual.hint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_submitting) const GameVerifyingBanner(),
            if (_paused)
              GamePauseMenu(
                visual: visual,
                onResume: _resume,
                // Restarting an official round would use another attempt.
                onRestart: _official ? null : _restart,
                onLeaderboard: openBoard,
                onQuit: _askQuit,
                quitNote: _official
                    ? 'Quitting submits this attempt with the score you '
                          'have so far.'
                    : null,
              ),
            if (_confirmingQuit)
              GameQuitConfirm(
                visual: visual,
                message: _quitMessage,
                onStay: _cancelQuit,
                onQuit: _quit,
              ),
            if (_result != null)
              GameResultOverlay(
                visual: visual,
                result: _result!,
                onPlayAgain: _canPlayAgain ? _start : null,
                onLeaderboard: openBoard,
                onQuit: _quit,
              ),
            if (_submitError != null)
              GameMessageOverlay(
                card: GameMessageCard(
                  visual: visual,
                  title: 'Score not sent',
                  message: _submitError!,
                  actionLabel: 'Try again',
                  onAction: _submit,
                  onQuit: () => Navigator.of(context).pop(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(GameVisual visual, GameEngine? engine) {
    if (_loading) return const GameLoading();
    if (_loadError != null) {
      return Center(
        child: SingleChildScrollView(
          child: GameMessageCard(
            visual: visual,
            title: _official
                ? 'Could not start your attempt'
                : 'Could not start the game',
            message: _loadError!,
            actionLabel: _loadRetryable
                ? 'Try again'
                : (_loadErrorAction ?? 'Back to the competition'),
            onAction: _loadRetryable
                ? _start
                : () {
                    final route = _loadErrorRoute;
                    if (route == null) {
                      _quit();
                    } else {
                      context.pushReplacement(route);
                    }
                  },
            onQuit: _quit,
          ),
        ),
      );
    }
    if (engine == null) return const SizedBox.shrink();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: KeyedSubtree(
          key: ValueKey(_round),
          child: widget.definition.buildBoard(
            engine,
            GameControls(
              active: !_paused && !_submitted && _result == null,
              onChanged: _onChanged,
            ),
          ),
        ),
      ),
    );
  }
}

/// Marks a round that counts on a competition board, with the play's
/// receipt: the points it cost and what it added to the prize.
class _OfficialBadge extends StatelessWidget {
  const _OfficialBadge({
    required this.attemptNumber,
    this.receipt,
    this.currency,
  });

  final int? attemptNumber;
  final AttemptStart? receipt;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    String? detail;
    if (r != null) {
      final parts = <String>[
        if (r.pointsSpent > 0)
          '−${r.pointsSpent} pts · ${r.walletPointsRemaining} left',
        if (r.prizeIncrementCents > 0 && currency != null)
          'prize +${formatMoneyCents(r.prizeIncrementCents, currency)} → '
              '${formatMoneyCents(r.prizeAfterCents, currency)}'
        else if (r.prizeCapReached)
          'prize at its maximum',
      ];
      if (parts.isNotEmpty) detail = parts.join(' · ');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                attemptNumber == null
                    ? 'OFFICIAL ATTEMPT'
                    : 'OFFICIAL ATTEMPT #$attemptNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          if (detail != null)
            Text(
              detail,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
