import 'package:flutter/material.dart';

/// "Earn 100 pts" on a gift. The API only reports a reward the seller can
/// pay, so this is a promise rather than an advert; nothing shows for zero.
class RewardPointsBadge extends StatelessWidget {
  const RewardPointsBadge({
    super.key,
    required this.points,
    this.large = false,
  });

  final int points;
  final bool large;

  @override
  Widget build(BuildContext context) {
    if (points <= 0) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical: large ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFCD34D),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.stars_rounded,
            size: large ? 16 : 13,
            color: const Color(0xFF6B4410),
          ),
          const SizedBox(width: 4),
          Text(
            'Earn $points pts',
            style: TextStyle(
              fontSize: large ? 13 : 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B4410),
            ),
          ),
        ],
      ),
    );
  }
}
