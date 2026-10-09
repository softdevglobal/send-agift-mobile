import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';

/// Asks before signing out, as a box-template sheet: a waving gift, the
/// customer's name, and what is waiting on their account — so leaving feels
/// safe rather than final. Signing out happens inside the sheet, which shows
/// its progress and any failure; it returns true once the customer is
/// signed out.
Future<bool> showSignOutSheet(
  BuildContext context, {
  required String? name,
  required int? points,
  required int savedCount,
  required int? orderCount,
  required Future<void> Function() onSignOut,
}) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radius2xl),
      ),
    ),
    builder: (_) => _SignOutSheet(
      name: name,
      points: points,
      savedCount: savedCount,
      orderCount: orderCount,
      onSignOut: onSignOut,
    ),
  );
  return done ?? false;
}

class _SignOutSheet extends StatefulWidget {
  const _SignOutSheet({
    required this.name,
    required this.points,
    required this.savedCount,
    required this.orderCount,
    required this.onSignOut,
  });

  final String? name;
  final int? points;
  final int savedCount;
  final int? orderCount;
  final Future<void> Function() onSignOut;

  @override
  State<_SignOutSheet> createState() => _SignOutSheetState();
}

class _SignOutSheetState extends State<_SignOutSheet> {
  bool _busy = false;
  String? _error;

  String get _firstName {
    final parts = (widget.name ?? '').trim().split(RegExp(r'\s+'));
    return parts.first;
  }

  Future<void> _signOut() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSignOut();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not sign out. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = _firstName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        12,
        AppTheme.gutter,
        20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.boxBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Center(child: _WavingGift()),
          const SizedBox(height: 18),
          Text(
            first.isEmpty ? 'Leaving so soon?' : 'Leaving so soon, $first?',
            textAlign: TextAlign.center,
            style: AppTypography.display(24),
          ),
          const SizedBox(height: 6),
          Text(
            'Everything stays safe on your account. It will all be here '
            'when you sign back in.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _KeptTile(
                  icon: Icons.stars_rounded,
                  color: AppColors.purple,
                  tint: AppColors.categoryTints[5],
                  value: widget.points,
                  label: 'Points',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KeptTile(
                  icon: Icons.favorite_rounded,
                  color: AppColors.destructive,
                  tint: AppColors.categoryTints[0],
                  value: widget.savedCount,
                  label: 'Saved',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KeptTile(
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.accentForeground,
                  tint: AppColors.categoryTints[4],
                  value: widget.orderCount,
                  label: 'Orders',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: AppTheme.box(color: AppColors.background),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'To check out, track orders or message shops, you will '
                    'need to sign in again.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.destructive),
            ),
          ],
          const SizedBox(height: 18),
          _BoxButton(
            label: 'Stay signed in',
            icon: Icons.favorite_border_rounded,
            solid: true,
            onTap: _busy ? null : () => Navigator.of(context).pop(false),
          ),
          const SizedBox(height: 10),
          _BoxButton(
            label: _busy ? 'Signing out…' : 'Sign out',
            icon: Icons.logout_rounded,
            foreground: AppColors.destructive,
            busy: _busy,
            onTap: _busy ? null : _signOut,
          ),
        ],
      ),
    );
  }
}

/// A gift box that pops in, with a hand waving goodbye from its corner.
class _WavingGift extends StatefulWidget {
  const _WavingGift();

  @override
  State<_WavingGift> createState() => _WavingGiftState();
}

class _WavingGiftState extends State<_WavingGift>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _anim.value = 1;
    } else if (!_anim.isAnimating && _anim.value == 0) {
      _anim.forward();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = _anim.value;
        // The box pops in over the first third…
        final pop = Curves.elasticOut.transform((t / 0.45).clamp(0.0, 1.0));
        // …then the hand waves three times and settles.
        final waveT = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
        final wave = math.sin(waveT * math.pi * 6) * 0.45 * (1 - waveT);
        return SizedBox(
          width: 100,
          height: 92,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 0.6 + 0.4 * pop,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: AppColors.foreground,
                    borderRadius: BorderRadius.circular(AppTheme.radiusBox + 6),
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Opacity(
                  opacity: pop.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: wave,
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.teal,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusBoxSm + 3,
                        ),
                        border: Border.all(color: AppColors.surface, width: 3),
                      ),
                      child: const Icon(
                        Icons.waving_hand_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One thing the account keeps, as a small tinted box.
class _KeptTile extends StatelessWidget {
  const _KeptTile({
    required this.icon,
    required this.color,
    required this.tint,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final Color tint;
  final int? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: AppTheme.box(color: tint),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(value?.toString() ?? '—', style: AppTypography.display(20)),
          Text(
            label.toUpperCase(),
            style: AppTheme.boxLabel.copyWith(
              fontSize: 10.5,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// A box-template button: a solid ink block for the main choice, white with
/// an ash outline for the other.
class _BoxButton extends StatelessWidget {
  const _BoxButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.solid = false,
    this.busy = false,
    this.foreground = AppColors.foreground,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool solid;
  final bool busy;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusBox);
    final ink = solid ? Colors.white : foreground;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              color: solid ? AppColors.foreground : AppColors.surface,
              borderRadius: radius,
              border: solid
                  ? null
                  : Border.all(color: AppColors.boxBorder, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ink,
                    ),
                  )
                else
                  Icon(icon, size: 19, color: ink),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTypography.sansFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
