import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/game_engine.dart';

/// Runs a [TickGame] off the frame clock.
///
/// Each frame adds the real time that passed and advances the engine one
/// tick per whole [TickGame.tickMs]. [fraction] is how far into the next
/// tick we are, so boards can draw smooth motion between ticks while the
/// engine. And the server. Only ever see whole ticks.
///
/// A long stall (the app in the background) is not banked as a burst of
/// ticks: game time simply pauses with the phone.
class TickClock extends ChangeNotifier {
  TickClock({required TickerProvider vsync, required this.game, this.onTicks}) {
    _ticker = vsync.createTicker(_onFrame);
  }

  final TickGame game;

  /// Called after a frame that advanced at least one tick.
  final void Function(int ticks)? onTicks;

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _pendingMs = 0;
  double _wallMs = 0;

  bool get running => _ticker.isActive;

  /// How far into the next tick we are, 0..1.
  double get fraction =>
      game.isOver ? 0 : (_pendingMs / game.tickMs).clamp(0.0, 1.0);

  /// The current tick plus [fraction]. For drawing only.
  double get smoothTick => game.tick + fraction;

  /// Milliseconds the clock has run, for purely decorative animation.
  double get wallMs => _wallMs;

  void run(bool shouldRun) {
    if (shouldRun == _ticker.isActive) return;
    if (shouldRun) {
      _last = Duration.zero;
      _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  void _onFrame(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1000.0;
    _last = elapsed;
    _wallMs += dt;
    _pendingMs += dt;

    var advanced = 0;
    while (_pendingMs >= game.tickMs && advanced < 4 && !game.isOver) {
      _pendingMs -= game.tickMs;
      game.advance();
      advanced++;
    }
    if (_pendingMs > game.tickMs) _pendingMs = game.tickMs.toDouble();

    if (advanced > 0) onTicks?.call(advanced);
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
