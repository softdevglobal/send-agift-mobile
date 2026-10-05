import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// A small purple pill above an auth heading, e.g. "Free forever".
class AuthPill extends StatelessWidget {
  const AuthPill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.card_giftcard_rounded,
            size: 14,
            color: AppColors.purple,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.purple,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A heading whose last word is in the brand gradient: "Welcome *back*".
class AuthHeadline extends StatelessWidget {
  const AuthHeadline({super.key, required this.lead, required this.accent});

  final String lead;
  final String accent;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.display(34, height: 1.05);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        Text(lead, style: style),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [AppColors.purple, Color(0xFFDB2777)],
          ).createShader(rect),
          child: Text(accent, style: style.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}

/// What an account unlocks: three outlined pills in one row.
class AuthPerkChips extends StatelessWidget {
  const AuthPerkChips({super.key});

  static const _perks = <({IconData icon, String label})>[
    (icon: Icons.local_shipping_outlined, label: 'Live tracking'),
    (icon: Icons.star_outline_rounded, label: 'Earn points'),
    (icon: Icons.auto_awesome_outlined, label: 'Win prizes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final perk in _perks) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(perk.icon, size: 14, color: AppColors.purple),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      perk.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (perk != _perks.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

/// The solid purple pill button used for the main auth action.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.loading,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null && !loading ? 0.6 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: AppColors.purple,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPressed,
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: Center(
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
