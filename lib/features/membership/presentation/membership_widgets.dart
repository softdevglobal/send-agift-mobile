import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/membership.dart';

/// Where a server "next action" takes the customer in the app, and what the
/// button says. Null when there is nothing useful to offer.
({String route, String label, bool tab})? nextActionRoute(String? action) {
  return switch (action) {
    'shop' => (route: AppRoutes.explore, label: 'Keep shopping', tab: true),
    'send_gift' => (route: AppRoutes.explore, label: 'Send a gift', tab: true),
    'verify_phone' => (
      route: AppRoutes.editProfile,
      label: 'Verify my number',
      tab: false,
    ),
    'add_date_of_birth' => (
      route: AppRoutes.editProfile,
      label: 'Add my date of birth',
      tab: false,
    ),
    'view_offers' => (
      route: AppRoutes.membership,
      label: 'See memberships',
      tab: false,
    ),
    'view_membership' || 'manage_renewal' => (
      route: AppRoutes.myMembership,
      label: 'My membership',
      tab: false,
    ),
    'track_gift' => (
      route: AppRoutes.orders,
      label: 'Track my gift',
      tab: false,
    ),
    'view_points' || 'view_earning_rules' => (
      route: AppRoutes.points,
      label: 'My points',
      tab: false,
    ),
    'view_competitions' => (
      route: AppRoutes.games,
      label: 'See competitions',
      tab: false,
    ),
    'contact_support' => (
      route: AppRoutes.help,
      label: 'Contact support',
      tab: false,
    ),
    _ => null,
  };
}

void followNextAction(BuildContext context, String? action) {
  final target = nextActionRoute(action);
  if (target == null) return;
  if (target.tab) {
    context.go(target.route);
  } else {
    context.push(target.route);
  }
}

/// Why joining is unavailable, and the one useful thing to do instead. The
/// server decides availability; this only explains its answer.
class AvailabilityNotice extends StatelessWidget {
  const AvailabilityNotice({
    super.key,
    required this.message,
    this.reasonCode,
    this.nextAction,
  });

  final String message;
  final String? reasonCode;
  final String? nextAction;

  IconData get _icon => switch (reasonCode) {
    'LOCATION_UNAVAILABLE' => Icons.location_off_rounded,
    'VERIFICATION_REQUIRED' || 'AGE_RESTRICTED' => Icons.shield_outlined,
    'OPERATION_STOPPED' => Icons.pause_circle_outline_rounded,
    _ => Icons.block_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final target = nextActionRoute(nextAction);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppColors.boxBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(_icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (reasonCode != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Reason: ${reasonCode!.replaceAll('_', ' ').toLowerCase()}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (target != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => followNextAction(context, nextAction),
              child: Text(target.label),
            ),
          ],
        ],
      ),
    );
  }
}

/// A coloured icon tile and its text, for a package's perks.
class MembershipPerk extends StatelessWidget {
  const MembershipPerk({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (body != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    body!,
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a membership checkout in an in-app browser, falling back to the
/// system browser. Returns false when nothing could open it.
Future<bool> openMembershipCheckout(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return true;
  } catch (_) {
    // Fall through to the system browser.
  }
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Closes the checkout browser once the payment is confirmed, where the
/// platform allows it.
Future<void> closeMembershipCheckout() async {
  try {
    if (await supportsCloseForLaunchMode(LaunchMode.inAppBrowserView)) {
      await closeInAppWebView();
    }
  } catch (_) {
    // The customer closes it themselves.
  }
}

// ─── Welcome ──────────────────────────────────────────────────────────────

String _welcomedKey(String periodId) => 'membership-welcomed:$periodId';

/// Shows the welcome the first time a paid period is seen on this device.
/// Returns whether it showed. [onPointsScreen] keeps "See my points" from
/// opening the screen the customer is already on.
Future<bool> maybeShowMembershipWelcome(
  BuildContext context,
  MembershipStatus? status, {
  bool onPointsScreen = false,
}) async {
  final period = status?.currentPeriod;
  if (status == null || period == null || period.id.isEmpty) return false;
  final prefs = await SharedPreferences.getInstance();
  final key = _welcomedKey(period.id);
  if (prefs.getBool(key) ?? false) return false;
  await prefs.setBool(key, true);
  if (!context.mounted) return false;
  await showDialog<void>(
    context: context,
    builder: (_) =>
        _MembershipWelcome(status: status, onPointsScreen: onPointsScreen),
  );
  return true;
}

class _MembershipWelcome extends StatelessWidget {
  const _MembershipWelcome({
    required this.status,
    required this.onPointsScreen,
  });

  final MembershipStatus status;
  final bool onPointsScreen;

  @override
  Widget build(BuildContext context) {
    final offer = status.offer;
    final period = status.currentPeriod!;
    final slot = period.bonusSlot;
    final credited = slot != null && slot.credited ? slot.bonusPoints : 0;
    final bonus = offer?.memberBonusPoints ?? 0;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppColors.foreground,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.purple,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'WELCOME TO',
                    style: AppTypography.tag(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    offer?.name ?? 'your membership',
                    textAlign: TextAlign.center,
                    style: AppTypography.display(26, color: Colors.white),
                  ),
                  if (credited > 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.teal,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '+$credited points added',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.tealForeground,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('YOUR MEMBER BENEFITS', style: AppTypography.eyebrow),
                  const SizedBox(height: 14),
                  if (offer != null && offer.memberDiscountBps > 0)
                    MembershipPerk(
                      icon: Icons.percent_rounded,
                      color: AppColors.purple,
                      title:
                          '${formatBps(offer.memberDiscountBps)} off every gift',
                      body: 'Taken off at checkout.',
                    ),
                  if (bonus > 0)
                    MembershipPerk(
                      icon: Icons.verified_rounded,
                      color: AppColors.accentForeground,
                      title: '$bonus bonus points',
                      body: offer?.bonusTrigger == 'first_gift'
                          ? 'After your first delivered gift each period.'
                          : 'In My points every time your membership renews. '
                                'Unused points carry over.',
                    ),
                  for (final b in offer?.giftBenefits ?? const <String>[])
                    MembershipPerk(
                      icon: Icons.card_giftcard_rounded,
                      color: AppColors.primary,
                      title: b,
                    ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Text(
                      'Paid until ${formatMembershipDate(period.periodEnd)}. '
                      'Manage or cancel any time from My membership.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (!onPointsScreen) context.push(AppRoutes.points);
                    },
                    child: const Text('See my points'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go(AppRoutes.explore);
                    },
                    child: const Text('Send a gift'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 27 Nov 2026.
String formatMembershipDate(DateTime date) =>
    DateFormat('d MMM y').format(date);
