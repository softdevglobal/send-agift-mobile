import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/data/auth_controller.dart';
import '../../../games/data/games_providers.dart';
import '../../data/membership_repository.dart';
import '../../domain/membership.dart';
import '../membership_widgets.dart';

/// The membership packages on sale where the customer lives, with every term
/// they agree to shown before payment: the price, the true renewal interval,
/// the discount and the bonus. Renewal consent is never pre-ticked.
///
/// Paying happens on Stripe's page in an in-app browser. The app then checks
/// with the server until the payment is confirmed, closes the browser and
/// welcomes the new member.
class MembershipScreen extends ConsumerStatefulWidget {
  const MembershipScreen({super.key});

  @override
  ConsumerState<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends ConsumerState<MembershipScreen>
    with WidgetsBindingObserver {
  Timer? _poll;
  int _tries = 0;
  bool _waiting = false;

  static const _maxTries = 100; // about seven minutes at four seconds

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  // Back from the browser: check straight away instead of waiting a tick.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waiting) unawaited(_check());
  }

  Future<void> _onJoined(MembershipCheckout checkout) async {
    if (checkout.provider == 'test') {
      // Sandbox: no payment page; My membership confirms the test payment.
      context.pushReplacement('${AppRoutes.myMembership}?test=1');
      return;
    }
    final opened = await openMembershipCheckout(checkout.checkoutUrl);
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We couldn’t open the payment page.')),
      );
      return;
    }
    setState(() => _waiting = true);
    _tries = 0;
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check());
  }

  Future<void> _check() async {
    if (!_waiting) return;
    _tries++;
    try {
      final status = await ref.read(membershipRepositoryProvider).status();
      if (!mounted) return;
      if (status.isMember) {
        _poll?.cancel();
        setState(() => _waiting = false);
        await closeMembershipCheckout();
        ref
          ..invalidate(membershipStatusProvider)
          ..invalidate(memberDiscountBpsProvider)
          ..invalidate(pointsWalletProvider);
        if (!mounted) return;
        await maybeShowMembershipWelcome(context, status);
        if (mounted) context.pushReplacement(AppRoutes.myMembership);
        return;
      }
    } catch (_) {
      // The payment may still be settling; try again on the next tick.
    }
    if (_tries >= _maxTries) {
      _poll?.cancel();
      if (mounted) setState(() => _waiting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authProvider.select((a) => a.isSignedIn));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Membership')),
      body: !signedIn
          ? const _SignInPrompt()
          : RefreshIndicator(
              onRefresh: () => ref.refresh(membershipOffersProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  8,
                  AppTheme.gutter,
                  40,
                ),
                children: [
                  Text('SENDAGIFT MEMBERSHIP', style: AppTypography.eyebrow),
                  const SizedBox(height: 6),
                  Text(
                    'Gift discounts, benefits and bonus points with every '
                    'paid membership period.',
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_waiting) ...[
                    const _WaitingForPayment(),
                    const SizedBox(height: 16),
                  ],
                  _Offers(onJoined: _onJoined, busy: _waiting),
                ],
              ),
            ),
    );
  }
}

class _Offers extends ConsumerWidget {
  const _Offers({required this.onJoined, required this.busy});

  final Future<void> Function(MembershipCheckout) onJoined;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(membershipOffersProvider);
    return offers.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => EmptyState(
        icon: Icons.workspace_premium_outlined,
        title: 'Could not load memberships',
        description: '$error',
        action: FilledButton(
          onPressed: () => ref.invalidate(membershipOffersProvider),
          child: const Text('Try again'),
        ),
      ),
      data: (data) {
        final d = data.decision;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!d.allowed) ...[
              AvailabilityNotice(
                message: d.message,
                reasonCode: d.reasonCode,
                nextAction: d.nextAction,
              ),
              const SizedBox(height: 16),
            ],
            if (d.allowed && data.offers.isEmpty)
              const AvailabilityNotice(
                message:
                    'There are no memberships on sale where you live '
                    'right now.',
                nextAction: 'shop',
              ),
            for (final offer in data.offers) ...[
              _OfferCard(
                offer: offer,
                canBuy: d.allowed && !busy,
                onJoined: onJoined,
              ),
              const SizedBox(height: 16),
            ],
            if (data.offers.isNotEmpty) ...[
              const _HowItWorks(),
              const SizedBox(height: 16),
            ],
            Text(
              'Bonus points are added to My points, the same points you earn '
              'from gifts and prizes. Points cannot be transferred or '
              'withdrawn as cash. Competition availability and point '
              'conditions apply, and vary by location.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

class _OfferCard extends ConsumerStatefulWidget {
  const _OfferCard({
    required this.offer,
    required this.canBuy,
    required this.onJoined,
  });

  final PlanOffer offer;
  final bool canBuy;
  final Future<void> Function(MembershipCheckout) onJoined;

  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  bool _consent = false;
  bool _busy = false;
  String? _error;

  // One key per attempt to join, so a double tap is one checkout.
  final String _key = MembershipRepository.newRequestKey();

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final checkout = await ref
          .read(membershipRepositoryProvider)
          .join(
            offerId: widget.offer.id,
            renewalConsent: _consent,
            idempotencyKey: _key,
          );
      await widget.onJoined(checkout);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not start the checkout.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    final white70 = Colors.white.withValues(alpha: 0.7);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        border: Border.all(color: AppColors.boxBorder, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.foreground,
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
                    const SizedBox(width: 12),
                    if (o.countryName != null)
                      Text(
                        o.countryName!.toUpperCase(),
                        style: AppTypography.tag(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  o.name,
                  style: AppTypography.display(24, color: Colors.white),
                ),
                if (o.description != null) ...[
                  const SizedBox(height: 4),
                  Text(o.description!, style: TextStyle(color: white70)),
                ],
                const SizedBox(height: 16),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  children: [
                    Text(
                      o.priceLabel,
                      style: AppTypography.display(32, color: Colors.white),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        o.billingLabel,
                        style: TextStyle(
                          color: white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('WHAT YOU GET', style: AppTypography.eyebrow),
                const SizedBox(height: 14),
                if (o.memberDiscountBps > 0)
                  MembershipPerk(
                    icon: Icons.percent_rounded,
                    color: AppColors.purple,
                    title: '${formatBps(o.memberDiscountBps)} off every gift',
                    body:
                        'On the gift price of every order while you are a '
                        'member.',
                  ),
                if (o.memberBonusPoints > 0)
                  MembershipPerk(
                    icon: Icons.verified_rounded,
                    color: AppColors.accentForeground,
                    title: '+${o.memberBonusPoints} bonus points',
                    body: o.bonusWhen,
                  ),
                for (final b in o.giftBenefits)
                  MembershipPerk(
                    icon: Icons.card_giftcard_rounded,
                    color: AppColors.primary,
                    title: b,
                  ),
                const SizedBox(height: 4),
                Text(
                  'Renews at ${o.priceLabel} ${o.billingLabel} until you '
                  'cancel. Your benefits continue to the end of the period '
                  'you paid for. Free gifts don’t qualify. Terms '
                  '${o.termsVersion}.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Opacity(
                  opacity: widget.canBuy ? 1 : 0.6,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    onTap: widget.canBuy && !_busy
                        ? () => setState(() => _consent = !_consent)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: _consent ? AppColors.purple : AppColors.border,
                          width: 1.5,
                        ),
                        color: _consent
                            ? AppColors.purple.withValues(alpha: 0.05)
                            : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _consent,
                            onChanged: widget.canBuy && !_busy
                                ? (v) => setState(() => _consent = v ?? false)
                                : null,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'I agree that this membership renews at '
                                '${o.priceLabel} ${o.billingLabel} until I '
                                'cancel, and to the terms.',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.destructive),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: widget.canBuy && _consent && !_busy ? _join : null,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.workspace_premium_rounded),
                  label: Text('Join for ${o.priceLabel}'),
                ),
                if (widget.canBuy && !_consent) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Tick the box above to continue.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
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

/// Shown while the payment page is open and the payment is being confirmed.
class _WaitingForPayment extends StatelessWidget {
  const _WaitingForPayment();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.25)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Finish paying on the payment page. We’ll welcome you here as '
              'soon as your payment is confirmed.',
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        Icons.workspace_premium_rounded,
        'Join',
        'Pick a membership and pay securely. You’re a member once the payment '
            'goes through.',
      ),
      (
        Icons.card_giftcard_rounded,
        'Send a gift',
        'Your member discount comes off the gift price at checkout.',
      ),
      (
        Icons.verified_rounded,
        'Get your bonus',
        'Bonus points land in My points with each paid period and carry over.',
      ),
    ];
    return Column(
      children: [
        for (final (i, step) in steps.indexed)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.foreground,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(step.$1, size: 16, color: AppColors.purple),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              step.$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.$3,
                        style: const TextStyle(
                          color: AppColors.mutedForeground,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.workspace_premium_outlined,
      title: 'Sign in to see memberships',
      description:
          'What is offered depends on where you live. We check that '
          'before showing any price.',
      action: FilledButton(
        onPressed: () => context.push(AppRoutes.login),
        child: const Text('Sign in'),
      ),
    );
  }
}
