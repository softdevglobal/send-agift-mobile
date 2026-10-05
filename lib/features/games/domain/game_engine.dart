/// Directions shared by every game. These exact strings are the wire format
/// the backend replays.
class Move {
  Move._();

  static const String up = 'up';
  static const String down = 'down';
  static const String left = 'left';
  static const String right = 'right';

  /// The order the backend scans directions in. Engines that pick a direction
  /// from the seed depend on it.
  static const List<String> all = [up, down, left, right];

  static bool isDirection(String dir) => all.contains(dir);

  static String opposite(String dir) => switch (dir) {
    Move.up => Move.down,
    Move.down => Move.up,
    Move.left => Move.right,
    Move.right => Move.left,
    _ => '',
  };

  /// Column and row step for a direction.
  static (int, int) delta(String dir) => switch (dir) {
    Move.up => (0, -1),
    Move.down => (0, 1),
    Move.left => (-1, 0),
    Move.right => (1, 0),
    _ => (0, 0),
  };
}

/// A whole-number triangle wave, mirroring `triangle` in
/// `internal/games/engine.go`: -amp at u = 0, +amp at half the period, and
/// back. Everything that moves on its own in a game follows it.
///
/// Integer-only so the app and the server agree on every position exactly;
/// u is never negative and the period is even, so `~/` truncates exactly
/// like Go's `/`.
int triangleWave(int u, int period, int amp) {
  final half = period ~/ 2;
  final m = u % period;
  if (m <= half) return -amp + (2 * amp * m) ~/ half;
  return amp - (2 * amp * (m - half)) ~/ half;
}

/// [v] rounded up to an even number, and no smaller than [min].
int evenAtLeast(int v, int min) {
  var out = v < min ? min : v;
  if (out.isOdd) out++;
  return out;
}

/// Reads an int field from a game config; anything missing reads as 0,
/// exactly as Go's JSON decoding leaves it, so both sides fall back alike.
int readConfigInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is num ? value.toInt() : 0;
}

/// What the shared game screen needs from any engine.
///
/// The engine is never the authority on the result: [moves] is what gets
/// submitted, and the server replays it to compute the real score. [score] is
/// only the provisional number shown while playing.
abstract interface class GameEngine {
  int get score;

  /// The move log exactly as the backend expects it.
  List<String> get moves;

  /// True once no more play is possible. The round submits itself.
  bool get isOver;

  /// Whether anything has been played, i.e. whether quitting would bank a run.
  bool get hasProgress;
}

/// A game whose score the device cannot know. The quiz, whose answers stay
/// on the server. Its [GameEngine.score] is progress only, and no client
/// score is sent with it.
abstract interface class UnscoredGame implements GameEngine {}

/// A game that runs on numbered ticks rather than frames.
///
/// The board's clock calls [advance] once per tick and the player's actions
/// are logged against [tick]. The clock only decides *when* ticks happen,
/// never what they do, so a faster phone gives no advantage and the server
/// replays the same ticks exactly.
abstract interface class TickGame implements GameEngine {
  int get tickMs;
  int get tick;
  void advance();
}
