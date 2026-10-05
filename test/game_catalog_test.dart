import 'package:flutter_test/flutter_test.dart';

import 'package:send_agift_mobile/features/games/domain/game.dart';
import 'package:send_agift_mobile/features/games/presentation/game_definitions.dart';
import 'package:send_agift_mobile/features/games/presentation/game_visuals.dart';

/// Every slug migration 000032 seeds, plus the ten that came before it.
const _slugs = [
  '2048',
  'snake',
  'slide-puzzle',
  'basketball',
  'stack-tower',
  'archery',
  'cricket',
  'block-blast',
  'sling-shot',
  'hill-rider',
  'memory-match',
  'whack-a-mole',
  'bubble-shooter',
  'tower-blocks',
  'fruit-slice',
  'doodle-jump',
];

void main() {
  test('every game in the catalog can actually be opened', () {
    // A slug the server offers but the app cannot build is a tile that shows
    // up and then refuses to open. The exact failure this guards.
    for (final slug in _slugs) {
      expect(
        gameDefinitions.containsKey(slug),
        isTrue,
        reason: '$slug has no engine or board',
      );
    }
  });

  test('every game has its own look rather than the fallback', () {
    final fallback = GameVisual.of('a-game-added-later');
    for (final slug in _slugs) {
      final visual = GameVisual.of(slug);
      expect(
        visual.name,
        isNot(fallback.name),
        reason: '$slug is falling back to the placeholder visual',
      );
      expect(visual.howToPlay, isNotEmpty, reason: '$slug has no instructions');
      expect(visual.colors.length, 3, reason: '$slug needs a 3-stop gradient');
    }
  });

  test('each engine builds from a session and starts unplayed', () {
    for (final slug in _slugs) {
      final definition = gameDefinitions[slug]!;
      final engine = definition.createEngine(
        GameSession(
          sessionId: 's',
          gameSlug: slug,
          version: '1.0.0',
          mode: 'practice',
          seed: '5f3a91c2',
          config: const {},
          expiresAt: DateTime(2027),
        ),
      );
      // Snake logs a setup move when it is built, so an empty log is not a
      // rule every engine follows. A score on the board before anyone has
      // played, though, would mean points were given away.
      expect(engine.score, 0, reason: '$slug starts with a score');
      expect(
        definition.stats(engine),
        isNotEmpty,
        reason: '$slug reports no stats',
      );
    }
  });
}
