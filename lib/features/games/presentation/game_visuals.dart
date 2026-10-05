import 'package:flutter/material.dart';

/// Each game's look: its colours, icon and short copy.
///
/// Kept on the client because it is presentation only. The rules themselves
/// come from the server with every session.
class GameVisual {
  const GameVisual({
    required this.name,
    required this.tagline,
    required this.icon,
    required this.colors,
    required this.accent,
    required this.hint,
    required this.howToPlay,
  });

  final String name;
  final String tagline;
  final IconData icon;

  /// Three-stop background gradient.
  final List<Color> colors;
  final Color accent;

  /// One-line reminder under the board.
  final String hint;
  final List<String> howToPlay;

  static GameVisual of(String slug) => _visuals[slug] ?? _fallback;

  /// Friendly names for the per-game stats the server returns.
  static String statLabel(String key) => switch (key) {
    'highest_tile' => 'Best tile',
    'length' => 'Length',
    'food' => 'Gifts',
    'ticks' => 'Ticks',
    'moves' => 'Moves',
    'tiles_in_place' => 'Tiles home',
    'makes' => 'Baskets',
    'shots' => 'Shots',
    'swishes' => 'Swishes',
    'best_streak' => 'Best streak',
    'floors' => 'Floors',
    'perfects' => 'Perfects',
    'arrows' => 'Arrows',
    'tens' => 'Tens',
    'xs' => 'Bullseyes',
    'fours' => 'Fours',
    'sixes' => 'Sixes',
    'wickets' => 'Wickets',
    'lines' => 'Lines',
    'best_combo' => 'Best combo',
    'placed' => 'Pieces',
    'levels' => 'Levels',
    'targets' => 'Targets',
    'distance' => 'Metres',
    'air_ticks' => 'Air time',
    'fuel_cans' => 'Fuel cans',
    'turns' => 'Turns',
    'hits' => 'Hits',
    'pops' => 'Pops',
    'rows' => 'Rows',
    'fruits' => 'Fruits',
    'height' => 'Height',
    'hops' => 'Hops',
    'springs' => 'Springs',
    _ => key.replaceAll('_', ' '),
  };
}

const Map<String, GameVisual> _visuals = {
  '2048': GameVisual(
    name: '2048',
    tagline: 'Merge the tiles and chase the big number.',
    icon: Icons.grid_view_rounded,
    colors: [Color(0xFFFF5F6D), Color(0xFFFF8E53), Color(0xFFFFC371)],
    accent: Color(0xFFFF5F6D),
    hint: 'Swipe to slide every tile. Equal tiles merge.',
    howToPlay: [
      'Swipe in any direction to slide every tile.',
      'Two equal tiles merge into one. Their sum is your points.',
      'The round ends when the board is full and nothing can merge.',
    ],
  ),
  'snake': GameVisual(
    name: 'Snake',
    tagline: 'Grab the gift boxes, grow long, never crash.',
    icon: Icons.timeline_rounded,
    colors: [Color(0xFF052E26), Color(0xFF0B8F72), Color(0xFF38EF7D)],
    accent: Color(0xFF38EF7D),
    hint: 'Swipe or use the arrows. Every gift speeds you up.',
    howToPlay: [
      'Swipe or tap the arrows to steer.',
      'Each gift box is 10 points and makes you longer. And faster.',
      'Hitting a wall or your own tail ends the round.',
    ],
  ),
  'basketball': GameVisual(
    name: 'Basketball',
    tagline: 'Shoot hoops against the clock. Swish for bonus points.',
    icon: Icons.sports_basketball_rounded,
    colors: [Color(0xFF1A0B3B), Color(0xFFE8590C), Color(0xFFFFB347)],
    accent: Color(0xFFE8590C),
    hint: 'Swipe up from the ball. Lead the hoop once it moves.',
    howToPlay: [
      'Swipe up from the ball. Sideways aims, the length sets the power.',
      'Farther spots need more power; the green band on the meter is the '
          'sweet spot.',
      'Three baskets in a row and you are on fire: every basket counts '
          'double.',
      'Every few baskets the hoop starts moving. Aim where it will be.',
    ],
  ),
  'stack-tower': GameVisual(
    name: 'Stack Tower',
    tagline: 'Drop each floor right on top. Perfect drops grow it back.',
    icon: Icons.layers_rounded,
    colors: [Color(0xFF0F2027), Color(0xFF2C5364), Color(0xFF00C9A7)],
    accent: Color(0xFF00C9A7),
    hint: 'Tap anywhere to drop the sliding floor.',
    howToPlay: [
      'Tap to drop the sliding floor onto the tower.',
      'Anything hanging over the edge is sliced off.',
      'Land it dead centre for a perfect: full width and bonus points.',
      'Miss the tower completely and it is game over.',
    ],
  ),
  'archery': GameVisual(
    name: 'Archery',
    tagline: 'Read the wind, steady your aim, hit the gold.',
    icon: Icons.gps_fixed_rounded,
    colors: [Color(0xFF134E5E), Color(0xFF2E8B57), Color(0xFFA8E063)],
    accent: Color(0xFF2E8B57),
    hint: 'Drag to aim, let go to shoot. Mind the wind.',
    howToPlay: [
      'Drag to move your sight, let go to loose the arrow.',
      'The sight sways. Release when it is steady on the gold.',
      'The windsock and the wind chip show how hard it is blowing; aim '
          'into it.',
      'Ten arrows. The gold scores 10, down to 1 on the outer ring.',
    ],
  ),
  'cricket': GameVisual(
    name: 'Cricket',
    tagline: 'Time your swing, find the gaps, clear the rope.',
    icon: Icons.sports_cricket_rounded,
    colors: [Color(0xFF0B3D1F), Color(0xFF1B7A3A), Color(0xFF8BD450)],
    accent: Color(0xFF1B7A3A),
    hint: 'Tap to swing. Tap left or right of the batter to aim.',
    howToPlay: [
      'Tap as the ball reaches the bat. Perfect timing clears the rope.',
      'Where you tap aims the shot. Red on the ring means a fielder is '
          'there; green is a gap.',
      'Miss a ball on the stumps and you are bowled. Edge it to a fielder '
          'and you are caught.',
      'Twelve balls, three wickets. Every run counts.',
    ],
  ),
  'block-blast': GameVisual(
    name: 'Block Blast',
    tagline: 'Fill rows and columns to blast them. Chain combos.',
    icon: Icons.grid_on_rounded,
    colors: [Color(0xFF1E1B4B), Color(0xFF4338CA), Color(0xFF22D3EE)],
    accent: Color(0xFF4338CA),
    hint: 'Drag a piece onto the board. Or tap it, then tap a square.',
    howToPlay: [
      'Drag a piece from the tray onto the board.',
      'Fill a whole row or column and it blasts away.',
      'Clear lines on back-to-back moves for a combo bonus.',
      'The game ends when none of your pieces fit.',
    ],
  ),
  'sling-shot': GameVisual(
    name: 'Sling Shot',
    tagline: 'Pull, aim, release. Topple the towers.',
    icon: Icons.rocket_launch_rounded,
    colors: [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)],
    accent: Color(0xFFD76D77),
    hint: 'Drag back from anywhere to aim, let go to fire.',
    howToPlay: [
      'Drag back and down to pull the sling; the dots show the flight.',
      'Knock out every grumpy gift box to clear the level.',
      'Wood breaks, stone does not. And anything unsupported falls.',
      'Three shots a level; the ones you save are a bonus.',
    ],
  ),
  'hill-rider': GameVisual(
    name: 'Hill Rider',
    tagline: 'Gas, brake, balance. How far can you drive?',
    icon: Icons.directions_car_filled_rounded,
    colors: [Color(0xFF0F4C75), Color(0xFF3282B8), Color(0xFFF9D56E)],
    accent: Color(0xFF3282B8),
    hint: 'Hold GAS to drive, BRAKE to slow down before a crest.',
    howToPlay: [
      'Hold GAS to drive and BRAKE to slow down.',
      'Hit a crest too fast and you fly. Land nose-first and you crash.',
      'Gas burns fuel. Drive through the red cans to fill up.',
      'Your score is how far you get, plus a bonus for air time.',
    ],
  ),
  'slide-puzzle': GameVisual(
    name: 'Slide Puzzle',
    tagline: 'Put the tiles back in order. Fewer moves, more points.',
    icon: Icons.extension_rounded,
    colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2), Color(0xFFFF6FD8)],
    accent: Color(0xFF8E2DE2),
    hint: 'Tap a tile in line with the gap, or swipe it in.',
    howToPlay: [
      'Tap any tile in line with the gap to slide it across.',
      'Order the tiles 1, 2, 3… with the gap in the bottom corner.',
      'Solving scores 5,000, minus 20 for every move you make.',
    ],
  ),
  'memory-match': GameVisual(
    name: 'Memory Match',
    tagline: 'Pair the gift cards from memory.',
    icon: Icons.psychology_rounded,
    colors: [Color(0xFF2E1065), Color(0xFF7C3AED), Color(0xFFF0ABFC)],
    accent: Color(0xFF7C3AED),
    hint: 'Flip two cards a turn. Matches in a row pay more.',
    howToPlay: [
      'Tap a card to turn it over, then tap a second one.',
      'A matching pair stays up; anything else turns back.',
      'Each match in a row pays a bigger bonus, and every turn costs a point.',
    ],
  ),
  'whack-a-mole': GameVisual(
    name: 'Whack-a-Mole',
    tagline: 'Tap them before they drop back down.',
    icon: Icons.sports_mma_rounded,
    colors: [Color(0xFF451A03), Color(0xFFB45309), Color(0xFFFCD34D)],
    accent: Color(0xFFB45309),
    hint: 'Tap the mole, not the hole. Empty holes cost you.',
    howToPlay: [
      'Tap a mole while it is up to score.',
      'They stay up for less and less time as the round goes on.',
      'Hits in a row pay a growing bonus; tapping an empty hole costs points.',
    ],
  ),
  'bubble-shooter': GameVisual(
    name: 'Bubble Shooter',
    tagline: 'Pop clusters and bring the wall down.',
    icon: Icons.bubble_chart_rounded,
    colors: [Color(0xFF083344), Color(0xFF0891B2), Color(0xFF67E8F9)],
    accent: Color(0xFF0891B2),
    hint: 'Fire the queued colour where it already sits.',
    howToPlay: [
      'Tap a column to fire the colour waiting at the bottom.',
      'Three or more of a colour touching pops the whole cluster.',
      'Anything left hanging falls with it. That is where the big chains are.',
    ],
  ),
  'tower-blocks': GameVisual(
    name: 'Tower Blocks',
    tagline: 'Fill a row across and clear it.',
    icon: Icons.view_week_rounded,
    colors: [Color(0xFF172554), Color(0xFF1D4ED8), Color(0xFF93C5FD)],
    accent: Color(0xFF1D4ED8),
    hint: 'A slab rests on the tallest column it covers.',
    howToPlay: [
      'Tap a column to drop the slab waiting above the well.',
      'Fill a row right across and it clears, pulling the rest down.',
      'Leave a gap underneath a slab and that space is wasted for good.',
    ],
  ),
  'fruit-slice': GameVisual(
    name: 'Fruit Slice',
    tagline: 'Slice the fruit, dodge the bombs.',
    icon: Icons.content_cut_rounded,
    colors: [Color(0xFF4C0519), Color(0xFFBE123C), Color(0xFFFDA4AF)],
    accent: Color(0xFFBE123C),
    hint: 'Swipe through the fruit. Never touch a bomb.',
    howToPlay: [
      'Swipe anywhere to slash. Your finger is the blade.',
      'Cut three or more in one swipe for a fruit combo bonus.',
      'Let three fruit fall and the round is over.',
      'Slice a bomb and it all ends in a bang. Swipe around them.',
    ],
  ),
  'doodle-jump': GameVisual(
    name: 'Doodle Jump',
    tagline: 'Climb the tower one ledge at a time.',
    icon: Icons.stairs_rounded,
    colors: [Color(0xFF022C22), Color(0xFF047857), Color(0xFF6EE7B7)],
    accent: Color(0xFF047857),
    hint: 'You can only reach your lane or the ones beside it.',
    howToPlay: [
      'Tap the lane you want to land in on the next ledge up.',
      'Only your own lane and the two beside it are in reach.',
      'Springs throw you two ledges up, and every tenth ledge pays a bonus.',
    ],
  ),
  'quiz': GameVisual(
    name: 'Quiz',
    tagline: 'Right answers score; fast right answers score more.',
    icon: Icons.quiz_rounded,
    colors: [Color(0xFF1E1B4B), Color(0xFF4338CA), Color(0xFFC7D2FE)],
    accent: Color(0xFF4338CA),
    hint: 'Answer before the timer runs out.',
    howToPlay: [
      'Everyone gets the same questions.',
      'A right answer scores 100, plus up to 50 for answering fast.',
      'Your score is worked out by our server once you finish.',
    ],
  ),
  // Chance games: the server decides each play; the app reveals it.
  'spin-wheel': GameVisual(
    name: 'Spin the Wheel',
    tagline: 'Land on the jackpot to win the prize.',
    icon: Icons.casino_rounded,
    colors: [Color(0xFF3B0764), Color(0xFF7C3AED), Color(0xFFF0ABFC)],
    accent: Color(0xFF7C3AED),
    hint: 'Your result is decided the moment you play.',
    howToPlay: [
      'Each play spins the wheel once.',
      'Land on the jackpot and the prize is yours. The round ends there.',
      'The server decides every spin fairly; the wheel just shows it.',
    ],
  ),
  'scratch-card': GameVisual(
    name: 'Scratch Card',
    tagline: 'Three jackpots wins the prize.',
    icon: Icons.style_rounded,
    colors: [Color(0xFF713F12), Color(0xFFD97706), Color(0xFFFDE68A)],
    accent: Color(0xFFD97706),
    hint: 'Scratch every panel to reveal your card.',
    howToPlay: [
      'Each play is one card.',
      'Scratch the panels. Three jackpot symbols wins the prize.',
      'The card is decided the moment you play.',
    ],
  ),
  'treasure-hunt': GameVisual(
    name: 'Treasure Hunt',
    tagline: 'Open a chest to see what you found.',
    icon: Icons.inventory_2_rounded,
    colors: [Color(0xFF052E16), Color(0xFF15803D), Color(0xFFBBF7D0)],
    accent: Color(0xFF15803D),
    hint: 'Your result is decided the moment you play.',
    howToPlay: [
      'Each play opens one chest.',
      'Find the jackpot and the prize is yours.',
      'Which chest you tap does not change the result. It was decided when '
          'you played.',
    ],
  ),
  'instant-win': GameVisual(
    name: 'Instant Win',
    tagline: 'Open the gift to see if you won.',
    icon: Icons.redeem_rounded,
    colors: [Color(0xFF831843), Color(0xFFDB2777), Color(0xFFFBCFE8)],
    accent: Color(0xFFDB2777),
    hint: 'Your result is decided the moment you play.',
    howToPlay: [
      'Each play is one gift.',
      'Open it to find out straight away whether it won the prize.',
    ],
  ),
  'prize-draw': GameVisual(
    name: 'Prize Draw',
    tagline: 'Every play is an entry in the draw.',
    icon: Icons.confirmation_number_rounded,
    colors: [Color(0xFF0C4A6E), Color(0xFF0284C7), Color(0xFFBAE6FD)],
    accent: Color(0xFF0284C7),
    hint: 'Winners are drawn when the round closes.',
    howToPlay: [
      'Each play adds one entry.',
      'When the round closes, winners are drawn at random from every entry.',
      'Each player can win once.',
    ],
  ),
};

/// The chance games: the server decides each play and the app only reveals
/// it, so they open a reveal screen instead of a game board.
const chanceGameSlugs = {
  'spin-wheel',
  'scratch-card',
  'treasure-hunt',
  'instant-win',
  'prize-draw',
};

const GameVisual _fallback = GameVisual(
  name: 'Game',
  tagline: 'Pure skill, free to play.',
  icon: Icons.sports_esports_rounded,
  colors: [Color(0xFF0F1B45), Color(0xFF6D28D9), Color(0xFF14B8B8)],
  accent: Color(0xFF6D28D9),
  hint: '',
  howToPlay: [],
);
