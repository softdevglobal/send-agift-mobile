import 'package:flutter/material.dart';

/// How the rating stage answers a score: a face, a line, and a nudge.
class ReviewMood {
  const ReviewMood(this.icon, this.headline, this.nudge);

  final IconData icon;
  final String headline;
  final String nudge;
}

const _moods = <ReviewMood>[
  ReviewMood(
    Icons.auto_awesome_rounded,
    'Tap a star to begin',
    'Your honest take helps the next person choosing a gift.',
  ),
  ReviewMood(
    Icons.sentiment_dissatisfied_rounded,
    'Not what I hoped',
    'We are sorry it missed. Tell us what went wrong so it can be put right.',
  ),
  ReviewMood(
    Icons.sentiment_neutral_rounded,
    'It was okay',
    'A few things could have been better. What were they?',
  ),
  ReviewMood(
    Icons.sentiment_satisfied_rounded,
    'Good, with niggles',
    'Nearly there. What would have made it great?',
  ),
  ReviewMood(
    Icons.sentiment_very_satisfied_rounded,
    'Really pleased',
    'Lovely. What made it special?',
  ),
  ReviewMood(
    Icons.celebration_rounded,
    'Absolutely love it',
    'Wonderful! Tell people why it was such a hit.',
  ),
];

ReviewMood reviewMood(int score) => _moods[score.clamp(0, 5)];

const _good = [
  'Beautifully wrapped',
  'Arrived on time',
  'Exactly as pictured',
  'Great value',
  'Made them smile',
  'Lovely seller',
];

const _bad = [
  'Arrived late',
  'Not as pictured',
  'Damaged',
  'Poorly packaged',
  'Hard to reach the seller',
];

/// Quick things to say, suited to how the score leans.
List<String> reviewHighlights(int score) {
  if (score >= 4) return _good;
  if (score >= 1 && score <= 2) return _bad;
  if (score == 3) return [..._good.take(3), ..._bad.take(2)];
  return _good;
}
