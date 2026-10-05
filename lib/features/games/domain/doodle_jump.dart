import 'deterministic_rng.dart';
import 'game_engine.dart';

/// Doodle Jump rules, read from the config the server issues.
class DoodleConfig {
  const DoodleConfig({
    this.lanes = 5,
    this.platforms = 120,
    this.springEvery = 9,
    this.springLift = 3,
    this.pointsPerHop = 8,
    this.springBonus = 14,
    this.heightBonusEvery = 10,
    this.heightBonus = 25,
  });

  final int lanes;
  final int platforms;
  final int springEvery;

  /// How many ledges a spring carries the climber, counting the spring
  /// itself: 1 is no boost at all, 3 throws them two clear of it.
  final int springLift;
  final int pointsPerHop;
  final int springBonus;
  final int heightBonusEvery;
  final int heightBonus;

  factory DoodleConfig.fromJson(Map<String, dynamic> json) {
    const d = DoodleConfig();
    int pick(String key, int fallback) {
      final value = readConfigInt(json, key);
      return value > 0 ? value : fallback;
    }

    return DoodleConfig(
      lanes: pick('lanes', d.lanes),
      platforms: pick('platforms', d.platforms),
      springEvery: pick('spring_every', d.springEvery),
      springLift: pick('spring_lift', d.springLift),
      pointsPerHop: pick('points_per_hop', d.pointsPerHop),
      springBonus: pick('spring_bonus', d.springBonus),
      heightBonusEvery: pick('height_bonus_every', d.heightBonusEvery),
      heightBonus: pick('height_bonus', d.heightBonus),
    );
  }
}

/// One rung of the tower: the lane always in reach, an optional second ledge
/// off to the side, and whether landing on it springs.
class DoodlePlatform {
  const DoodlePlatform({
    required this.lane,
    required this.alt,
    required this.spring,
  });

  final int lane;

  /// A second ledge on this rung, or -1 when there is only one.
  final int alt;
  final bool spring;

  bool has(int lane) => this.lane == lane || (alt >= 0 && alt == lane);
}

/// Doodle Jump: hop up a tower of ledges, choosing a lane each time. You can
/// only reach the lane you are in or the ones beside it, so a ledge two across
/// is a miss. Springs throw you two rungs up, and every tenth rung pays a
/// height bonus. So the climb rewards reading ahead.
///
/// Mirrors `internal/games/doodlejump.go` exactly, including the generator
/// that keeps every rung within reach so the tower is always climbable.
class DoodleJump implements GameEngine {
  DoodleJump({required String seed, required this.config})
    : platforms = _tower(seed, config) {
    _lane = platforms.first.lane;
  }

  final DoodleConfig config;
  final List<DoodlePlatform> platforms;
  final List<String> _moves = [];

  int _lane = 0;
  int _height = 0;
  int _hops = 0;
  int _springs = 0;
  int _score = 0;
  bool _fell = false;

  static List<DoodlePlatform> _tower(String seed, DoodleConfig config) {
    final rng = DeterministicRng.fromSeed(seed);
    final out = <DoodlePlatform>[];
    var lane = rng.nextInt(config.lanes);
    for (var i = 0; i < config.platforms; i++) {
      if (i > 0) {
        lane += rng.nextInt(3) - 1;
        if (lane < 0) lane = 0;
        if (lane >= config.lanes) lane = config.lanes - 1;
      }
      var alt = -1;
      if (rng.nextInt(3) == 0) {
        final candidate = rng.nextInt(config.lanes);
        if (candidate != lane) alt = candidate;
      }
      out.add(
        DoodlePlatform(
          lane: lane,
          alt: alt,
          spring: i > 0 && i % config.springEvery == 0,
        ),
      );
    }
    return out;
  }

  int get lane => _lane;
  int get height => _height;
  int get hops => _hops;
  int get springs => _springs;
  bool get fell => _fell;
  bool get topped => _height >= platforms.length - 1;

  /// The rung at a height, for the board to draw.
  DoodlePlatform platformAt(int index) {
    if (index < 0 || index >= platforms.length) {
      return const DoodlePlatform(lane: -1, alt: -1, spring: false);
    }
    return platforms[index];
  }

  /// Whether a lane is close enough to hop to from where the player stands.
  bool canReach(int lane) => (lane - _lane).abs() <= 1;

  @override
  int get score => _score;

  @override
  List<String> get moves => List.unmodifiable(_moves);

  @override
  bool get isOver => _fell || topped;

  @override
  bool get hasProgress => _moves.isNotEmpty;

  /// Hops to the next rung, landing in [lane]. Returns true when it stuck.
  bool hop(int lane) {
    if (isOver || lane < 0 || lane >= config.lanes || !canReach(lane)) {
      return false;
    }
    _moves.add('$lane');

    final next = platforms[_height + 1];
    _hops++;
    _lane = lane;
    if (!next.has(lane)) {
      _fell = true;
      return false;
    }

    _height++;
    _score += config.pointsPerHop;
    if (next.spring) {
      _springs++;
      _score += config.springBonus;
      // A spring carries the climber clear over the ledges above it. Each one
      // is skipped outright, so nothing there has to be landed on. It is the
      // reward for reaching the spring in the first place.
      for (var lift = 1; lift < config.springLift && !topped; lift++) {
        _height++;
        _lane = platforms[_height].lane;
      }
    }
    if (_height % config.heightBonusEvery == 0) {
      _score += config.heightBonus;
    }
    return true;
  }
}
