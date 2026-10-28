import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

    final facts = <(IconData, String, String)>[
      if (offer != null && offer.memberDiscountBps > 0)
        (
          Icons.percent_rounded,
          'Gift discount',
          period != null
              ? '${formatBps(offer.memberDiscountBps)} off every order until '
                    '${formatMembershipDate(period.periodEnd)}'
              : '${formatBps(offer.memberDiscountBps)} off, while a period is '
                    'paid',
        ),
      (
        Icons.event_rounded,
        'This period',
        period != null
            ? '${formatMembershipDate(period.periodStart)} – '
                  '${formatMembershipDate(period.periodEnd)}'
            : 'No paid period now',
      ),
      (
        Icons.verified_rounded,
        'Member bonus',
        slot != null
            ? '${slot.bonusPoints} points · ${slot.statusLabel}'
            : period != null
            ? 'No bonus on this plan'
            : '-',
      ),
      (
        Icons.receipt_long_rounded,
        'Next charge',
        s.nextChargeAt != null && offer != null
            ? '${Money.format(s.nextChargeMinor ?? 0, offer.currency)} on '
                  '${formatMembershipDate(s.nextChargeAt!)}'
            : sub != null &&
                  sub.cancelAtPeriodEnd &&
                  sub.currentPeriodEnd != null
            ? 'Ends ${formatMembershipDate(sub.currentPeriodEnd!)}, no renewal'
            : 'None scheduled',
      ),
    ];

    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.foreground,
          borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (offer?.name ?? 'Membership').toUpperCase(),
                    style: AppTypography.tag(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.purple,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              s.message,
              style: AppTypography.display(22, color: Colors.white),
            ),
            if (s.paymentPending) ...[
              const SizedBox(height: 12),
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
                  Text(
                    'Checking with the payment provider…',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ],
            if (target != null && target.route != AppRoutes.myMembership) ...[
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.tealForeground,
                ),
                onPressed: () => followNextAction(context, s.nextAction),
                child: Text(target.label),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      for (final (icon, label, value) in facts)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label.toUpperCase(), style: AppTypography.eyebrow),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      if (offer != null) ...[
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: offer.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text:
                          ' renews at ${offer.priceLabel} '
                          '${offer.billingLabel}'
                          '${sub != null && sub.cancelAtPeriodEnd ? ', but you have cancelled it.' : '.'}',
                    ),
                  ],
                ),
              ),
              if (sub != null && sub.canCancel) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.destructive,
                    side: const BorderSide(color: AppColors.destructive),
                  ),
                  onPressed: _busy ? null : _cancel,
                  child: const Text('Cancel renewal'),
                ),
              ],
            ],
          ),
        ),
      ],
      if (s.periods.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('PAID PERIODS', style: AppTypography.eyebrow),
        const SizedBox(height: 8),
        for (final p in s.periods)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatMembershipDate(p.periodStart)} – '
                    '${formatMembershipDate(p.periodEnd)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  [
                    p.amountLabel,
                    p.status,
                    if (p.bonusSlot != null)
                      'bonus ${p.bonusSlot!.statusLabel.toLowerCase()}',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    ];
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
