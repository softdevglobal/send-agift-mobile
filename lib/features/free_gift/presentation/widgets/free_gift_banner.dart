import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/data/auth_controller.dart';
import '../../data/free_gift_repository.dart';

/// Whether to point the shopper at the free gift: a guest while anything is
/// on offer, a customer until theirs is sent. Hidden while the program is
/// off, so it only ever shows what the API says is true.
final showFreeGiftProvider = Provider<bool>((ref) {
  final onOffer = ref.watch(freeGiftOnOfferProvider).valueOrNull ?? false;
  if (!onOffer) return false;
  final signedIn = ref.watch(authProvider.select((auth) => auth.isSignedIn));
  if (!signedIn) return true;
  final status = ref.watch(freeGiftStatusProvider).valueOrNull;
  return status != null && !status.used;
});

/// "You have 1 free gift" for a customer, the offer itself for a guest.
class FreeGiftBanner extends ConsumerWidget {
  const FreeGiftBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showFreeGiftProvider)) return const SizedBox.shrink();
    final signedIn = ref.watch(authProvider.select((auth) => auth.isSignedIn));
    final status = ref.watch(freeGiftStatusProvider).valueOrNull;
    final needsVerify = status != null && status.missing.isNotEmpty;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
      child: Material(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: InkWell(
          key: const Key('free-gift-banner'),
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          onTap: () => context.push(AppRoutes.freeGift),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(Icons.redeem_rounded, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        signedIn
                            ? 'You have 1 free gift'
                            : 'Your first gift is free',
                        style: AppTypography.display(
                          19,
                        ).copyWith(color: AppColors.tealForeground),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        !signedIn
                            ? 'Create an account and send one gift on us. '
                                  'You only pay delivery.'
                            : needsVerify
                            ? 'Verify your email and phone, then send it. '
                                  'You only pay delivery.'
                            : 'Send it to someone special. The shop pays for '
                                  'the gift, you pay delivery.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.tealForeground,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.tealForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
