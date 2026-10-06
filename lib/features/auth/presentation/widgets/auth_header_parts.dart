import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/storefront_decor.dart';

/// A small ink tag above an auth heading, e.g. "Free forever".
class AuthPill extends StatelessWidget {
  const AuthPill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return TagChip(text, icon: Icons.card_giftcard_rounded);
  }
}

/// Uppercase poster heading whose last word sits on a violet marker block:
/// "WELCOME [BACK]".
class AuthHeadline extends StatelessWidget {
  const AuthHeadline({super.key, required this.lead, required this.accent});

  final String lead;
  final String accent;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.poster(36);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: 4,
      children: [
        Text(lead.toUpperCase(), style: style),
        Marker(accent.toUpperCase(), style: style),
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
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
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
                        color: AppColors.foreground,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
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

/// The solid ink box button used for the main auth action.
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
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          color: AppColors.foreground,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
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
                              label.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.tag(
                                size: 13,
                                color: Colors.white,
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
