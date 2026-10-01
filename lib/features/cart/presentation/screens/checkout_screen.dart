import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../auth/data/auth_controller.dart';
import '../../../checkout/data/checkout_repository.dart';
import '../../../checkout/domain/checkout.dart';
import '../../../checkout/presentation/widgets/delivery_summary.dart';
import '../../../checkout/presentation/widgets/recipient_picker.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/reward_points_badge.dart';
import '../../../delivery/data/delivery_providers.dart';
import '../../../games/data/games_providers.dart';
import '../../data/cart_controller.dart';
import '../../domain/cart_item.dart';

/// The one place the app asks for an account. Everything up to here — search,
/// product pages, cart, saved gifts — works as a guest.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String? _recipientId;

  /// The day asked for in the gift search, unless it has since passed.
  late DateTime _deliveryDate = _initialDate(
    ref.read(deliveryIntentProvider)?.date,
  );

  static DateTime _initialDate(DateTime? wanted) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (wanted != null && !wanted.isBefore(today)) return wanted;
    return now.add(const Duration(days: 1));
  }

  DeliveryQuote? _quote;
  bool _quoting = false;
  bool _placing = false;
  String? _error;

  /// Points from the customer's balance to send with the gift.
  final _giftPoints = TextEditingController();

  @override
  void dispose() {
    _giftPoints.dispose();
    super.dispose();
  }

  int get _giftPointsValue => int.tryParse(_giftPoints.text.trim()) ?? 0;

  /// Identifies the inputs a quote was made for, so a stale response from a
  /// slower earlier request never overwrites a newer one.
  String _quoteToken = '';

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final summary = ref.watch(cartSummaryProvider);
    final lines = ref.watch(cartLinesProvider).valueOrNull ?? const [];

    // Re-price whenever the recipient, date or cart changes.
    final token = [
      _recipientId ?? '',
      _dateKey(_deliveryDate),
      for (final line in lines) '${line.gift.id}:${line.quantity}',
    ].join('|');
    if (token != _quoteToken) {
      _quoteToken = token;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshQuote());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter,
            8,
            AppTheme.gutter,
            32,
          ),
          children: [
            FadeSlideIn(
              child: auth.isSignedIn
                  ? _SignedInAs(name: auth.displayName)
                  : const _SignInGate(),
            ),
            const SizedBox(height: 24),
            FadeSlideIn(
              delay: const Duration(milliseconds: 70),
              child: Text('Order summary', style: AppTypography.display(20)),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 110),
              child: AppPanel(
                child: Column(
                  children: [
                    for (final line in lines) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${line.quantity} × ${line.gift.name}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.foreground),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            Money.format(
                              line.lineTotalAmount,
                              line.gift.currency,
                            ),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_rewardPoints(lines) > 0) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'You earn with this order',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          RewardPointsBadge(points: _rewardPoints(lines)),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    const Divider(),
                    const SizedBox(height: 10),
                    DeliverySummary(
                      subtotal: summary.subtotal,
                      currency: summary.currency,
                      quote: _quote,
                      loading: _quoting,
                      hasRecipient: _recipientId != null,
                      deliveryDate: _deliveryDate,
                    ),
                  ],
                ),
              ),
            ),
            if (auth.isSignedIn) ...[
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.card_giftcard_rounded,
                            size: 19,
                            color: AppColors.purple,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Who is it for?',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      RecipientPicker(
                        selectedId: _recipientId,
                        onChanged: (value) =>
                            setState(() => _recipientId = value),
                      ),
                      if (_recipientId != null) _giftPointsField(context),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 190),
                child: AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.event_rounded,
                            size: 19,
                            color: AppColors.purple,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'When should it arrive?',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Each shop delivers itself and says how many days it '
                        'needs, so pick a day it can make.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(_dateLabel(_deliveryDate)),
                      ),
                      const SizedBox(height: 10),
                      // Shortcuts, because the price moves with the date.
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final preset in const [
                            ('Tomorrow', 1),
                            ('In 3 days', 3),
                            ('Next week', 7),
                          ])
                            ChoiceChip(
                              label: Text(preset.$1),
                              selected: _isSameDay(
                                _deliveryDate,
                                DateTime.now().add(Duration(days: preset.$2)),
                              ),
                              onSelected: (_) => setState(
                                () => _deliveryDate = DateTime.now().add(
                                  Duration(days: preset.$2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.destructive,
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          AppTheme.gutter,
          14,
          AppTheme.gutter,
          14 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _placing || (auth.isSignedIn && _blocker != null)
                ? null
                : auth.isSignedIn
                ? _placeOrder
                : () => context.push(AppRoutes.login),
            child: _placing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    !auth.isSignedIn
                        ? 'Sign in to continue'
                        : _blocker ?? 'Place order',
                  ),
          ),
        ),
      ),
    );
  }

  /// Why the order cannot be placed yet, as the button's label, or null when
  /// it can. The server refuses an order without a recipient, or with a shop
  /// whose delivery zones do not reach them.
  String? get _blocker {
    if (_recipientId == null) return 'Choose a recipient';
    if (_quoting) return 'Pricing delivery…';
    final quote = _quote;
    if (quote == null) return 'Delivery not priced';
    if (!quote.complete) return 'Cannot deliver there';
    return null;
  }

  /// What the lines promise on delivery; the server decides the rest.
  static int _rewardPoints(List<CartLine> lines) => lines.fold(
    0,
    (sum, line) => sum + line.gift.rewardPoints * line.quantity,
  );

  /// Sends points with the gift, when the customer has any. They reach the
  /// recipient's account on delivery, matched by email, or come back.
  Widget _giftPointsField(BuildContext context) {
    final balance = ref.watch(pointsWalletProvider).valueOrNull?.balance ?? 0;
    if (balance <= 0) return const SizedBox.shrink();
    final value = _giftPointsValue;
    final tooMany = value > balance;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, size: 18, color: AppColors.star),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add points to this gift',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                'You have $balance',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('checkout-gift-points'),
            controller: _giftPoints,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '0', isDense: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Text(
            tooMany
                ? 'You have $balance points.'
                : 'They reach the recipient\'s SendAGift account (matched by '
                      'email) when the gift is delivered, or come back to you.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tooMany
                  ? AppColors.destructive
                  : AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} '
      '${const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][date.month - 1]} ${date.year}';

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  /// Prices delivery for the current recipient, date and cart. A failure
  /// clears the quote, which holds the order back until it can be priced.
  Future<void> _refreshQuote() async {
    final lines = ref.read(cartLinesProvider).valueOrNull ?? const [];
    final recipientId = _recipientId;
    if (recipientId == null || lines.isEmpty) {
      if (mounted) setState(() => _quote = null);
      return;
    }
    final token = _quoteToken;
    setState(() => _quoting = true);
    try {
      final quote = await ref
          .read(checkoutRepositoryProvider)
          .quoteDelivery(
            recipientId: recipientId,
            deliveryDate: _deliveryDate,
            lines: lines,
          );
      // Another change landed while this was in flight.
      if (!mounted || token != _quoteToken) return;
      setState(() => _quote = quote);
    } on AppException {
      if (mounted && token == _quoteToken) setState(() => _quote = null);
    } finally {
      if (mounted && token == _quoteToken) setState(() => _quoting = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _deliveryDate = picked);
  }

  Future<void> _placeOrder() async {
    final lines = ref.read(cartLinesProvider).valueOrNull ?? const [];
    if (lines.isEmpty) return;
    final recipientId = _recipientId;
    if (recipientId == null || _blocker != null) return;
    final balance = ref.read(pointsWalletProvider).valueOrNull?.balance ?? 0;
    final giftPoints = _giftPointsValue;
    if (giftPoints > balance) {
      setState(() => _error = 'You have $balance points to send.');
      return;
    }
    setState(() {
      _placing = true;
      _error = null;
    });

    final repository = ref.read(checkoutRepositoryProvider);
    try {
      // Deliver to the recipient's own country, so the order is not filed
      // under the buyer's country by default.
      final recipient = await repository.getRecipient(recipientId);
      var countryId = recipient.deliveryAddress?.countryId ?? '';
      if (countryId.isEmpty) countryId = await repository.myCountryId();

      // Delivery is not sent: the server prices it from each shop's zones.
      final orderId = await repository.placeOrder(
        countryId: countryId,
        deliveryDate: _deliveryDate,
        lines: lines,
        recipientId: recipientId,
        giftPoints: giftPoints,
      );

      ref.read(cartProvider.notifier).clear();
      if (giftPoints > 0) ref.invalidate(pointsWalletProvider);
      if (!mounted) return;
      context.go('${AppRoutes.orders}/$orderId');
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }
}

class _SignInGate extends StatelessWidget {
  const _SignInGate();

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 19,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sign in to finish',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Your cart is saved on this device. Sign in — or create an account '
            'in a minute — to place the order and track delivery.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push(AppRoutes.login),
                  child: const Text('Sign in'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push(AppRoutes.register),
                  child: const Text('Register'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignedInAs extends StatelessWidget {
  const _SignedInAs({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Signed in as $name',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}
