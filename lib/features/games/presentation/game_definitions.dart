import 'package:flutter/widgets.dart';

import '../domain/archery_game.dart';
import '../domain/basketball_game.dart';
import '../domain/block_blast.dart';
import '../domain/bubble_shooter.dart';
import '../domain/cricket_game.dart';
import '../domain/doodle_jump.dart';
import '../domain/fruit_slice.dart';
import '../domain/game.dart';
import '../domain/hill_rider.dart';
import '../domain/memory_match.dart';
import '../domain/quiz_game.dart';
import '../domain/sling_shot.dart';
import '../domain/game_2048.dart';
import '../domain/slide_puzzle.dart';
import '../domain/snake_game.dart';
import '../domain/stack_tower.dart';
import '../domain/tower_blocks.dart';
import '../domain/whack_a_mole.dart';
import 'game_controls.dart';
import 'widgets/archery_range.dart';
import 'widgets/basketball_court.dart';
import 'widgets/block_blast_board.dart';
import 'widgets/bubble_board.dart';
import 'widgets/board_2048.dart';
import 'widgets/cricket_pitch.dart';
import 'widgets/doodle_board.dart';
import 'widgets/fruit_board.dart';
import 'widgets/hill_rider_board.dart';
import 'widgets/memory_board.dart';
import 'widgets/quiz_board.dart';
import 'widgets/sling_shot_board.dart';
import 'widgets/slide_board.dart';
import 'widgets/snake_board.dart';
import 'widgets/stack_tower_board.dart';
import 'widgets/tower_blocks_board.dart';
import 'widgets/whack_board.dart';

/// Everything the shared game screen needs to run one game.
///
/// Adding a game means adding an engine that mirrors the backend's, a board
/// widget, and an entry here. The screen, menu and results come for free.
class GameDefinition {
  const GameDefinition({
    required this.slug,
    required this.createEngine,
    required this.buildBoard,
    required this.stats,
    this.hasLevels = false,
    this.immersive = false,
  });

  final String slug;
  final GameEngine Function(GameSession session) createEngine;
  final Widget Function(GameEngine engine, GameControls controls) buildBoard;
  final List<GameStat> Function(GameEngine engine) stats;

  /// Whether a practice round on this game climbs through levels: clearing
  /// one (the server's `won` on the submitted score) starts the next, harder
  /// round; falling short drops back to level 1.
  final bool hasLevels;

  /// Whether this game paints a whole scene rather than a board of pieces.
  ///
  /// A scene runs the full screen with the panels floating over it, so the
  /// court or the sky carries on behind the score rather than stopping at a
  /// seam. A board is a fixed shape and stays below them, where it belongs.
  final bool immersive;
}

/// Every game this build can run, by slug.
///
/// A getter rather than a top-level `final`: Flutter keeps globals as state
/// across a hot reload, so a `final` map would keep the games it held when
/// the app started. Newly added games would show in the list but refuse to
/// open until a full restart.
Map<String, GameDefinition> get gameDefinitions => {
  '2048': GameDefinition(
    slug: '2048',
    createEngine: (session) => Game2048(
      seed: session.seed,
      config: GameConfig2048.fromJson(session.config),
    ),
    buildBoard: (engine, controls) =>
        Board2048(game: engine as Game2048, controls: controls),
    stats: (engine) {
      final game = engine as Game2048;
      return [
        GameStat('Score', game.score),
        GameStat('Best tile', game.highestTile),
        GameStat('Moves', game.moves.length),
      ];
    },
  ),
  'snake': GameDefinition(
    slug: 'snake',
    createEngine: (session) => SnakeGame(
      seed: session.seed,
      config: SnakeConfig.fromJson(session.config),
    ),
    buildBoard: (engine, controls) =>
        SnakeBoard(game: engine as SnakeGame, controls: controls),
    stats: (engine) {
      final game = engine as SnakeGame;
      return [
        GameStat('Score', game.score),
        GameStat('Length', game.body.length),
        GameStat('Gifts', game.foods),
      ];
    },
  ),
  'basketball': GameDefinition(
    slug: 'basketball',
    immersive: true,
    createEngine: (session) => BasketballGame(
      seed: session.seed,
      config: BasketballConfig.fromJson(session.config),
    ),
    buildBoard: (engine, controls) =>
        BasketballCourt(game: engine as BasketballGame, controls: controls),
    stats: (engine) {
      final game = engine as BasketballGame;
      return [
        GameStat('Score', game.settledScore),
        GameStat('Time', (game.ticksLeft * game.tickMs / 1000).ceil()),
        GameStat('Baskets', game.makes),
      ];
    },
  ),
  'stack-tower': GameDefinition(
    slug: 'stack-tower',
    immersive: true,
    createEngine: (session) => StackTower(
      seed: session.seed,
      config: StackConfig.fromJson(session.config),
    ),
    buildBoard: (engine, controls) =>
        StackTowerBoard(game: engine as StackTower, controls: controls),
    stats: (engine) {
      final game = engine as StackTower;
      return [
        GameStat('Score', game.score),
        GameStat('Floors', game.floorCount),
        GameStat('Perfects', game.perfects),
      ];
    },
  ),
  'archery': GameDefinition(
    slug: 'archery',
    immersive: true,
    createEngine: (session) => ArcheryGame(
      seed: session.seed,
      config: ArcheryConfig.fromJson(session.config),
    ),
    buildBoard: (engine, controls) =>
        ArcheryRange(game: engine as ArcheryGame, controls: controls),
    stats: (engine) {
      final game = engine as ArcheryGame;
      return [
        GameStat('Score', game.score),
        GameStat('Arrows', game.arrowsLeft),
        GameStat('Tens', game.tens),
      ];
    },
  ),
  'cricket': GameDefinition(
    slug: 'cricket',
    immersive: true,
    createEngine: (session) => CricketGame(
      seed: session.seed,
      config: CricketConfig.fromJson(session.config),
    ),
    buildBoard: (engine, controls) =>
        CricketPitch(game: engine as CricketGame, controls: controls),
    stats: (engine) {
      final game = engine as CricketGame;
      return [
        GameStat('Runs', game.runs),
        GameStat('Wickets', game.wickets),
        GameStat('Balls', game.ballsLeft),
      ];
    },
  ),
  'block-blast': GameDefinition(
    slug: 'block-blast',
    createEngine: (session) => BlockBlast(
      seed: session.seed,
      config: BlockBlastConfig.fromJson(session.config),
    ),
    buildBoard: (engine, controls) =>
        BlockBlastBoard(game: engine as BlockBlast, controls: controls),
    stats: (engine) {
      final game = engine as BlockBlast;
      return [
        GameStat('Score', game.score),
        GameStat('Lines', game.lines),
        GameStat('Best combo', game.bestCombo),
      ];
    },
  ),
  'sling-shot': GameDefinition(
    slug: 'sling-shot',
    immersive: true,
    createEngine: (session) => SlingShot(
      seed: session.seed,
      config: SlingConfig.fromJson(session.config),
    ),
    buildBoard: (engine, controls) =>
        SlingShotBoard(game: engine as SlingShot, controls: controls),
    stats: (engine) {
      final game = engine as SlingShot;
      return [
        GameStat('Score', game.score),
        GameStat('Levels', game.levelsCleared),
        GameStat('Targets', game.targets),
      ];
    },
  ),
  'hill-rider': GameDefinition(
    slug: 'hill-rider',
    immersive: true,
    createEngine: (session) => HillRider(
      seed: session.seed,
      config: HillConfig.fromJson(session.config),
    ),
    buildBoard: (engine, controls) =>
        HillRiderBoard(game: engine as HillRider, controls: controls),
    stats: (engine) {
      final game = engine as HillRider;
      return [
        GameStat('Distance', game.distance),
        GameStat('Fuel %', game.fuel * 100 ~/ game.config.startFuel),
        GameStat('Score', game.score),
      ];
    },
  ),
  'slide-puzzle': GameDefinition(
    slug: 'slide-puzzle',
    createEngine: (session) => SlidePuzzle(
      seed: session.seed,
      config: SlideConfig.fromJson(session.config),
    ),
    buildBoard: (engine, controls) =>
        SlideBoard(game: engine as SlidePuzzle, controls: controls),
    stats: (engine) {
      final game = engine as SlidePuzzle;
      return [
        GameStat('Moves', game.moves.length),
        GameStat('Tiles home', game.tilesInPlace),
        GameStat('Score', game.score),
      ];
    },
  ),
  'memory-match': GameDefinition(
    slug: 'memory-match',
    createEngine: (session) => MemoryMatch(
      seed: session.seed,
      config: MemoryConfig.fromJson(session.config),
    ),
    buildBoard: (engine, controls) =>
        MemoryBoard(game: engine as MemoryMatch, controls: controls),
    stats: (engine) {
      final game = engine as MemoryMatch;
      return [
        GameStat('Matches', game.matches),
        GameStat('Turns', game.turns),
        GameStat('Score', game.score),
      ];
    },
    hasLevels: true,
  ),
  'whack-a-mole': GameDefinition(
    slug: 'whack-a-mole',
    createEngine: (session) => WhackAMole(
      seed: session.seed,
      config: WhackConfig.fromJson(session.config),
    ),
    buildBoard: (engine, controls) =>
        WhackBoard(game: engine as WhackAMole, controls: controls),
    stats: (engine) {
      final game = engine as WhackAMole;
      return [
        GameStat('Hits', game.hits),
        GameStat('Best streak', game.bestStreak),
        GameStat('Score', game.score),
      ];
    },
  ),
  'bubble-shooter': GameDefinition(
    slug: 'bubble-shooter',
    createEngine: (session) => BubbleShooter(
      seed: session.seed,
      config: BubbleConfig.fromJson(session.config),
    ),
    buildBoard: (engine, controls) =>
        BubbleBoard(game: engine as BubbleShooter, controls: controls),
    stats: (engine) {
      final game = engine as BubbleShooter;
      return [
        GameStat('Pops', game.pops),
        GameStat('Best combo', game.bestCombo),
        GameStat('Score', game.score),
      ];
    },
  ),
  'tower-blocks': GameDefinition(
    slug: 'tower-blocks',
    createEngine: (session) => TowerBlocks(
      seed: session.seed,
      config: TowerBlocksConfig.fromJson(session.config),
    ),
    buildBoard: (engine, controls) =>
        TowerBlocksBoard(game: engine as TowerBlocks, controls: controls),
    stats: (engine) {
      final game = engine as TowerBlocks;
      return [
        GameStat('Rows', game.rowsCleared),
        GameStat('Pieces', game.pieces),
        GameStat('Score', game.score),
      ];
    },
  ),
  'fruit-slice': GameDefinition(
    slug: 'fruit-slice',
    immersive: true,
    createEngine: (session) => FruitSlice(
      seed: session.seed,
      config: FruitConfig.fromJson(session.config),
    ),
    buildBoard: (engine, controls) =>
        FruitBoard(game: engine as FruitSlice, controls: controls),
    stats: (engine) {
      final game = engine as FruitSlice;
      return [
        GameStat('Score', game.score),
        GameStat('Lives', game.livesLeft),
        GameStat('Best combo', game.bestCombo),
      ];
    },
  ),
  'doodle-jump': GameDefinition(
    slug: 'doodle-jump',
    immersive: true,
    createEngine: (session) => DoodleJump(
      seed: session.seed,
      config: DoodleConfig.fromJson(session.config),
    ),
    buildBoard: (engine, controls) =>
        DoodleBoard(game: engine as DoodleJump, controls: controls),
    stats: (engine) {
      final game = engine as DoodleJump;
      return [
        GameStat('Height', game.height),
        GameStat('Springs', game.springs),
        GameStat('Score', game.score),
      ];
    },
  ),
  // Competition-only: a quiz round's questions arrive with each play, and
  // its answers stay on the server.
  'quiz': GameDefinition(
    slug: 'quiz',
    createEngine: (session) => QuizGame(config: session.config),
    buildBoard: (engine, controls) =>
        QuizBoard(game: engine as QuizGame, controls: controls),
    stats: (engine) {
      final game = engine as QuizGame;
      return [
        GameStat(
          'Question',
          game.isOver ? game.questions.length : game.index + 1,
        ),
        GameStat('Of', game.questions.length),
        GameStat('Answered', game.answered),
      ];
    },
  ),
};
