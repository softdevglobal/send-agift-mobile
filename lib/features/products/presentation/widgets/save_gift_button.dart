import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../saved/data/saved_controller.dart';

/// Heart toggle. Saving works for guests. The list lives on the device until
/// there is an account to sync it to.
class SaveGiftButton extends ConsumerWidget {
  const SaveGiftButton({super.key, required this.giftId, this.compact = true});

  final String giftId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedGiftsProvider).contains(giftId);
    final size = compact ? 32.0 : 42.0;

    return Semantics(
      button: true,
      label: saved ? 'Remove from saved' : 'Save gift',
      child: GestureDetector(
        onTap: () {
          final nowSaved = ref.read(savedGiftsProvider.notifier).toggle(giftId);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(nowSaved ? 'Saved to your list' : 'Removed from saved'),
                duration: const Duration(milliseconds: 1400),
              ),
            );
        },
        child: Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(saved),
              size: compact ? 17 : 21,
              color: saved ? AppColors.destructive : AppColors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}
