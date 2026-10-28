import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../games/data/games_providers.dart';
import '../../data/membership_repository.dart';
import '../../domain/membership.dart';
import '../membership_widgets.dart';

/// The customer's membership: the period in force, its discount and bonus,
/// the next charge, and cancelling renewal. While a payment is still being
/// confirmed it checks again every few seconds; the server asks Stripe each
/// time.
class MyMembershipScreen extends ConsumerStatefulWidget {
  const MyMembershipScreen({super.key, this.testCheckout = false});

  /// Sandbox: back from a test checkout, so offer to confirm the payment.
  final bool testCheckout;

  @override
  ConsumerState<MyMembershipScreen> createState() => _MyMembershipScreenState();
}

class _MyMembershipScreenState extends ConsumerState<MyMembershipScreen> {
  Timer? _poll;
  int _tries = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _pollWhilePending(MembershipStatus? s) {
    final pending =
        s != null && s.paymentPending && s.subscription?.provider == 'stripe';
    if (!pending) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    if (_poll != null) return;
    _tries = 0;
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      _tries++;
      ref.invalidate(membershipStatusProvider);
      if (_tries >= 10) {
        _poll?.cancel();
        _poll = null;
      }
    });
  }

  Future<void> _refreshAfterChange() async {
    ref
      ..invalidate(membershipStatusProvider)
      ..invalidate(memberDiscountBpsProvider)
      ..invalidate(pointsWalletProvider);
  }

  Future<void> _testPay() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(membershipRepositoryProvider).confirmTestPayment();
      await _refreshAfterChange();
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel your renewal?'),
        content: const Text(
          'Your membership will end when the current paid period ends. '
          'Points you already have stay in My points.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel renewal'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(membershipRepositoryProvider).cancel();
      await _refreshAfterChange();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your membership will not renew. Your benefits continue to '
              'the end of the period you paid for.',
            ),
          ),
        );
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(membershipStatusProvider);
    ref.listen(membershipStatusProvider, (_, next) {
      final s = next.valueOrNull;
      _pollWhilePending(s);
      if (s != null && s.isMember) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) maybeShowMembershipWelcome(context, s);
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My membership'),
        actions: [
          TextButton(
            onPressed: () => context.push(AppRoutes.points),
            child: const Text('My points'),
          ),
        ],
      ),
      body: status.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.workspace_premium_outlined,
          title: 'Could not load your membership',
          description: '$error',
          action: FilledButton(
            onPressed: () => ref.invalidate(membershipStatusProvider),
            child: const Text('Try again'),
          ),
        ),
        data: (s) => RefreshIndicator(
          onRefresh: () => ref.refresh(membershipStatusProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              12,
              AppTheme.gutter,
              40,
            ),
            children: [
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.destructive),
                ),
                const SizedBox(height: 12),
              ],
              if (widget.testCheckout &&
                  s?.subscription?.provider == 'test' &&
                  s?.subscription?.status == 'incomplete') ...[
                _SandboxPay(busy: _busy, onPay: _testPay),
                const SizedBox(height: 16),
              ],
              if (s == null || s.state == 'none')
                EmptyState(
                  icon: Icons.workspace_premium_outlined,
                  title: 'You’re not a member',
                  description:
                      'Members get gift discounts, benefits and '
                      'bonus points with each paid period.',
                  action: FilledButton(
                    onPressed: () => context.push(AppRoutes.membership),
                    child: const Text('See memberships'),
                  ),
                )
              else
                ..._details(context, s),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _details(BuildContext context, MembershipStatus s) {
    final offer = s.offer;
    final period = s.currentPeriod;
    final sub = s.subscription;
    final target = nextActionRoute(s.nextAction);
    final slot = period?.bonusSlot;
    final since = s.periods.isEmpty
        ? null
        : s.periods
              .map((p) => p.periodStart)
              .reduce((a, b) => a.isBefore(b) ? a : b);

    return [
      _MemberCard(
        name: offer?.name ?? 'Membership',
        status: s,
        memberSince: since,
      ),
      const SizedBox(height: 14),
      _StatusStrip(
        message: s.message,
        action: target != null && target.route != AppRoutes.myMembership
            ? target.label
            : null,
        onAction: () => followNextAction(context, s.nextAction),
      ),
      if (offer != null &&
          (offer.memberDiscountBps > 0 || offer.memberBonusPoints > 0)) ...[
        const SizedBox(height: 20),
        Text('YOUR PERKS', style: AppTypography.eyebrow),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (offer.memberDiscountBps > 0)
                Expanded(
                  child: _PerkTile(
                    color: AppColors.purple,
                    icon: Icons.percent_rounded,
                    big: formatBps(offer.memberDiscountBps),
                    title: 'off every gift',
                    footer: period != null
                        ? 'Until ${formatMembershipDate(period.periodEnd)}'
                        : 'While a period is paid',
                  ),
                ),
              if (offer.memberDiscountBps > 0 && offer.memberBonusPoints > 0)
                const SizedBox(width: 10),
              if (offer.memberBonusPoints > 0)
                Expanded(
                  child: _PerkTile(
                    color: AppColors.accentForeground,
                    icon: Icons.stars_rounded,
                    big:
                        '+${_points(slot?.bonusPoints ?? offer.memberBonusPoints)}',
                    title: 'bonus points',
                    footer: slot != null
                        ? 'This period · ${slot.statusLabel}'
                        : 'Every paid period',
                  ),
                ),
            ],
          ),
        ),
      ],
      if (offer != null && offer.giftBenefits.isNotEmpty) ...[
        const SizedBox(height: 10),
        for (final b in offer.giftBenefits)
          MembershipPerk(
            icon: Icons.card_giftcard_rounded,
            color: AppColors.primary,
            title: b,
          ),
      ],
      if (offer != null) ...[
        const SizedBox(height: 20),
        Text('RENEWAL', style: AppTypography.eyebrow),
        const SizedBox(height: 10),
        _RenewalCard(
          offer: offer,
          status: s,
          busy: _busy,
          onCancel: sub != null && sub.canCancel ? _cancel : null,
        ),
      ],
      if (s.periods.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text('PAYMENT HISTORY', style: AppTypography.eyebrow),
        const SizedBox(height: 12),
        for (final (i, p) in s.periods.indexed)
          _PeriodRow(period: p, last: i == s.periods.length - 1),
      ],
    ];
  }
}

String _points(int n) => NumberFormat.decimalPattern().format(n);

/// The membership as a member card: the package, its state, how long they
/// have been a member and how far through the paid period they are.
class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.name,
    required this.status,
    required this.memberSince,
  });

  final String name;
  final MembershipStatus status;
  final DateTime? memberSince;

  (String, Color) get _chip {
    final sub = status.subscription;
    if (status.paymentPending) return ('PAYMENT PENDING', AppColors.star);
    if (sub?.status == 'past_due') {
      return ('PAYMENT FAILED', AppColors.destructive);
    }
    if (sub != null && (sub.cancelAtPeriodEnd || sub.status == 'cancelling')) {
      return ('NOT RENEWING', AppColors.star);
    }
    if (status.isMember) return ('ACTIVE', AppColors.teal);
    return ('NOT ACTIVE', AppColors.mutedForeground);
  }

  @override
  Widget build(BuildContext context) {
    final period = status.currentPeriod;
    final (chipLabel, chipColor) = _chip;
    final white60 = Colors.white.withValues(alpha: 0.6);

    double? progress;
    int? daysLeft;
    if (period != null) {
      final total = period.periodEnd.difference(period.periodStart).inSeconds;
      final done = DateTime.now().difference(period.periodStart).inSeconds;
      progress = total > 0 ? (done / total).clamp(0.0, 1.0) : 1.0;
      daysLeft = period.periodEnd.difference(DateTime.now()).inDays + 1;
      if (daysLeft < 0) daysLeft = 0;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius2xl),
      child: Container(
        color: AppColors.foreground,
        child: Stack(
          children: [
            Positioned(
              right: -50,
              top: -60,
              child: _Glow(size: 190, color: AppColors.purple, alpha: 0.55),
            ),
            Positioned(
              left: -40,
              bottom: -70,
              child: _Glow(size: 160, color: AppColors.teal, alpha: 0.30),
            ),
            Positioned(
              right: 18,
              bottom: 64,
              child: Icon(
                Icons.workspace_premium_rounded,
                size: 92,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.purple,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'SENDAGIFT MEMBER',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.tag(color: white60),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: chipColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: chipColor.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          chipLabel,
                          style: AppTypography.tag(
                            size: 9,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    name,
                    style: AppTypography.display(30, color: Colors.white),
                  ),
                  if (memberSince != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Member since ${formatMembershipDate(memberSince!)}',
                      style: TextStyle(color: white60),
                    ),
                  ],
                  const SizedBox(height: 22),
                  if (status.paymentPending)
                    Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Checking with the payment provider…',
                            style: TextStyle(color: white60),
                          ),
                        ),
                      ],
                    )
                  else if (period != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            daysLeft == 1
                                ? '1 day left in this period'
                                : '$daysLeft days left in this period',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            formatMembershipDate(period.periodStart),
                            style: TextStyle(color: white60, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            formatMembershipDate(period.periodEnd),
                            textAlign: TextAlign.end,
                            style: TextStyle(color: white60, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Text(
                      'No paid period right now.',
                      style: TextStyle(color: white60),
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

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color, required this.alpha});

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // A flat translucent disc, as on the account header; no colour fade.
        color: color.withValues(alpha: alpha * 0.5),
      ),
    );
  }
}

/// The server's word on the membership, and the one thing to do next.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.message,
    required this.action,
    required this.onAction,
  });

  final String message;
  final String? action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.purple,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}

/// One perk as a big number on a tinted tile.
class _PerkTile extends StatelessWidget {
  const _PerkTile({
    required this.color,
    required this.icon,
    required this.big,
    required this.title,
    required this.footer,
  });

  final Color color;
  final IconData icon;
  final String big;
  final String title;
  final String footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(big, style: AppTypography.display(28, color: color)),
          ),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            footer,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// What happens at the end of the period: the next charge, or the end.
class _RenewalCard extends StatelessWidget {
  const _RenewalCard({
    required this.offer,
    required this.status,
    required this.busy,
    required this.onCancel,
  });

  final PlanOffer offer;
  final MembershipStatus status;
  final bool busy;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final sub = status.subscription;
    final ending = sub != null && sub.cancelAtPeriodEnd;
    final IconData icon;
    final Color color;
    final String title;
    final String body;
    if (status.nextChargeAt != null) {
      icon = Icons.autorenew_rounded;
      color = AppColors.accentForeground;
      title = 'Renews ${formatMembershipDate(status.nextChargeAt!)}';
      body =
          '${Money.format(status.nextChargeMinor ?? offer.priceMinor, offer.currency)} '
          '${offer.billingLabel} until you cancel.';
    } else if (ending && sub.currentPeriodEnd != null) {
      icon = Icons.event_busy_rounded;
      color = const Color(0xFFB7791F);
      title = 'Ends ${formatMembershipDate(sub.currentPeriodEnd!)}';
      body =
          'You cancelled the renewal. Your benefits continue until then, '
          'and you can join again any time after.';
    } else {
      icon = Icons.receipt_long_rounded;
      color = AppColors.primary;
      title = 'No charge scheduled';
      body = '${offer.name} is ${offer.priceLabel} ${offer.billingLabel}.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.display(17)),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: const TextStyle(
                        color: AppColors.mutedForeground,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onCancel != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.destructive,
                side: BorderSide(
                  color: AppColors.destructive.withValues(alpha: 0.5),
                ),
              ),
              onPressed: busy ? null : onCancel,
              child: const Text('Cancel renewal'),
            ),
          ],
        ],
      ),
    );
  }
}

/// One paid period on a timeline.
class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.period, required this.last});

  final PaidPeriod period;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = period;
    final paid = p.status == 'paid';
    final dot = paid ? AppColors.teal : AppColors.destructive;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: dot.withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(child: Container(width: 2, color: AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatMembershipDate(p.periodStart)} – '
                    '${formatMembershipDate(p.periodEnd)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Pill(p.amountLabel, AppColors.primary),
                      _Pill(paid ? 'Paid' : p.status, dot),
                      if (p.bonusSlot != null)
                        _Pill(
                          '+${_points(p.bonusSlot!.bonusPoints)} pts · '
                          '${p.bonusSlot!.statusLabel.toLowerCase()}',
                          AppColors.purple,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SandboxPay extends StatelessWidget {
  const _SandboxPay({required this.busy, required this.onPay});

  final bool busy;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: Color(0xFF92400E)),
          const SizedBox(width: 10),
          const Expanded(child: Text('Sandbox: no real payment is taken.')),
          FilledButton(
            onPressed: busy ? null : onPay,
            child: const Text('Confirm test payment'),
          ),
        ],
      ),
    );
  }
}
