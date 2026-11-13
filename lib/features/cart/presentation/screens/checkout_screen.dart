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
import '../../../checkout/presentation/in_app_payment.dart';
import '../../../checkout/presentation/widgets/delivery_problem_card.dart';
import '../../../checkout/presentation/widgets/delivery_summary.dart';
import '../../../checkout/presentation/widgets/new_recipient_sheet.dart';
import '../../../checkout/presentation/widgets/recipient_picker.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/entries_badge.dart';
import '../../../games/data/games_providers.dart';
import '../../../delivery/data/delivery_providers.dart';
import '../../../delivery/domain/delivery_intent.dart';
import '../../data/cart_controller.dart';

/// The one place the app asks for an account. Everything up to here. Search,
/// product pages, cart, saved gifts. Works as a guest.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String? _recipientId;

  /// One of the recipient's addresses; null means their default.
  String? _addressId;

  /// The Idempotency-Key for the order being placed, and what it was for.
  /// Sending the same order again reuses it; anything changed gets a new one.
  ({String fingerprint, String key})? _orderAttempt;

  /// The note that goes with the gift. Optional.
  final _giftNote = TextEditingController();

  /// A gift note is a line or two, not a letter.
  static const _giftNoteMax = 300;

  @override
  void dispose() {
    _giftNote.dispose();
    super.dispose();
  }

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

  /// Identifies the inputs a quote was made for, so a stale response from a
  /// slower earlier request never overwrites a newer one.
  String _quoteToken = '';

  /// The address searched for before checkout is applied once, when the
  /// customer's recipients have loaded.
  bool _intentHandled = false;

  /// Carries the searched address into checkout: a recipient already saved
  /// at that address is picked, with their details; otherwise the new
  /// recipient form opens with the address filled in, asking only for who
  /// lives there.
  Future<void> _applySearchedAddress(List<Recipient> saved) async {
    final intent = ref.read(deliveryIntentProvider);
    if (intent == null || !intent.hasAddress) return;

    final repository = ref.read(checkoutRepositoryProvider);
    final hits = <(Recipient, RecipientAddress)>[];
    try {
      // The list does not carry addresses, so read each recipient in full.
      final all = await Future.wait(
        saved.map((recipient) => repository.getRecipient(recipient.id)),
      );
      for (final recipient in all) {
        for (final address in recipient.addresses) {
          if (searchedAddressMatches(intent, address)) {
            hits.add((recipient, address));
          }
        }
      }
    } on AppException {
      // Could not compare: fall through to asking for a new recipient.
    }
    if (!mounted || _recipientId != null) return;
    // Exactly one saved address is this one: pick that recipient and that
    // address. Several (neighbours in one building), and the customer picks.
    if (hits.length == 1) {
      setState(() {
        _recipientId = hits.single.$1.id;
        _addressId = hits.single.$2.id;
      });
      return;
    }
    if (hits.length > 1) return;
    final created = await showNewRecipientSheet(context);
    if (created != null && mounted) {
      setState(() {
        _recipientId = created.id;
        _addressId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final recipients = ref.watch(recipientsProvider).valueOrNull;
    if (auth.isSignedIn && !_intentHandled && recipients != null) {
      _intentHandled = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _applySearchedAddress(recipients),
      );
    }
    final summary = ref.watch(cartSummaryProvider);
    final lines = ref.watch(cartLinesProvider).valueOrNull ?? const [];
    // What the order would earn, from the server: each promoted line earns
    // its award once, and only where games are open for this customer.
    final offerKey = auth.isSignedIn
        ? ({for (final l in lines) l.gift.id}.toList()..sort()).join(',')
        : '';
    final offers = ref.watch(entryOffersProvider(offerKey)).valueOrNull;

    // Re-price whenever the recipient, date or cart changes.
    final token = [
      _recipientId ?? '',
      _addressId ?? '',
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
                    if (offers != null && offers.total > 0) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'You earn with this order, once it is paid',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          EntriesBadge(entries: offers.total),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ] else if (offers?.message != null) ...[
                      Text(
                        offers!.message!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                    ],
                    const Divider(),
                    const SizedBox(height: 10),
                    DeliverySummary(
                      subtotal: summary.subtotal,
                      memberDiscount: summary.memberDiscount,
                      memberDiscountBps: summary.memberDiscountBps,
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
                          Expanded(
                            child: Text(
                              'Who is it for?',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      RecipientPicker(
                        selectedId: _recipientId,
                        onChanged: (value) => setState(() {
                          _recipientId = value;
                          _addressId = null;
                        }),
                        selectedAddressId: _addressId,
                        onAddressChanged: (id) =>
                            setState(() => _addressId = id),
                      ),
                      // Each shop that cannot deliver here, and the fixes.
                      for (final shop
                          in _quote?.blocked ?? const <ShopDeliveryCheck>[])
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: DeliveryProblemCard(
                            shop: shop,
                            giftCount: lines
                                .where(
                                  (line) => line.gift.shopId == shop.shopId,
                                )
                                .length,
                            onChangeRecipient: () => setState(() {
                              _recipientId = null;
                              _addressId = null;
                            }),
                            onEditAddress: _recipientId == null
                                ? null
                                : () => context.push(
                                    AppRoutes.recipientPath(_recipientId!),
                                  ),
                            onRemoveShopGifts: () {
                              final cart = ref.read(cartProvider.notifier);
                              for (final line in lines) {
                                if (line.gift.shopId == shop.shopId) {
                                  cart.remove(line.gift.id);
                                }
                              }
                            },
                          ),
                        ),
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
                          Expanded(
                            child: Text(
                              'When should it arrive?',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
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
                        icon: const Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                        ),
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
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 230),
                child: AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.edit_note_rounded,
                            size: 21,
                            color: AppColors.purple,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Add a gift note',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Optional',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.mutedForeground),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Printed on the gift and shown to the recipient.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('gift-note'),
                        controller: _giftNote,
                        enabled: !_placing,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: _giftNoteMax,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'Happy birthday. Thinking of you!',
                        ),
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
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.destructive),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('checkout-submit'),
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
                            : _blocker ?? 'Send a gift',
                      ),
              ),
            ),
            if (auth.isSignedIn && _blocker == null) ...[
              const SizedBox(height: 8),
              const Text(
                'You pay securely on Stripe next. Your gift is only sent '
                'once the payment succeeds.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ],
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

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} '
      '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}';

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
            recipientAddressId: _addressId,
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
    setState(() {
      _placing = true;
      _error = null;
    });

    final repository = ref.read(checkoutRepositoryProvider);
    try {
      // Deliver to the recipient's own country, so the order is not filed
      // under the buyer's country by default.
      final recipient = await repository.getRecipient(recipientId);
      final shipTo = recipient.addressOrDefault(_addressId);
      var countryId = shipTo?.countryId ?? '';
      if (countryId.isEmpty) countryId = await repository.myCountryId();

      // Same order, same key: a retry after a timeout cannot place it twice.
      final fingerprint = [
        recipientId,
        shipTo?.id ?? '',
        countryId,
        _dateKey(_deliveryDate),
        _giftNote.text.trim(),
        for (final line in lines) '${line.gift.id}:${line.quantity}',
      ].join('|');
      final attempt = _orderAttempt?.fingerprint == fingerprint
          ? _orderAttempt!
          : (fingerprint: fingerprint, key: CheckoutRepository.newOrderKey());
      _orderAttempt = attempt;

      // Delivery is not sent: the server prices it from each shop's zones.
      final orderId = await repository.placeOrder(
        countryId: countryId,
        deliveryDate: _deliveryDate,
        lines: lines,
        recipientId: recipientId,
        recipientAddressId: shipTo?.id,
        giftMessage: _giftNote.text,
        idempotencyKey: attempt.key,
      );

      ref.read(cartProvider.notifier).clear();

      // The gift is only sent once it is paid, in Stripe's payment sheet
      // inside the app. Closed, declined or unavailable, the order waits on
      // its page, which offers Pay now.
      String? payProblem;
      try {
        final outcome = await payOrderInApp(ref, orderId);
        if (outcome == InAppPaymentOutcome.unavailable) {
          payProblem = 'Card payments are not available yet.';
        }
      } on AppException catch (error) {
        payProblem = error.message;
      }
      if (payProblem != null && mounted) {
        // Said here, since the order page only shows Pay now.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment not started: $payProblem')),
        );
      }
      if (!mounted) return;
      context.go('${AppRoutes.orders}/$orderId?placed=1');
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
            'Your cart is saved on this device. Sign in. Or create an account '
            'in a minute. To place the order and track delivery.',
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

/// Whether a saved address is the one searched for: the same street line,
/// and the same postcode (or, with no postcode on either side, the same
/// city). Never "close enough" on the map, and never part of a street
/// ("12 Main St" is not "112 Main St"): next door is a different address.
bool searchedAddressMatches(DeliveryIntent intent, RecipientAddress address) {
  String norm(String? v) =>
      (v ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  String street(String? v) => norm((v ?? '').split(',').first);
  final line1 = street(intent.line1).isNotEmpty
      ? street(intent.line1)
      : street(intent.address);
  if (line1.isEmpty || norm(address.line1) != line1) return false;
  final savedPostal = norm(address.postalCode);
  final searchedPostal = norm(intent.postalCode);
  if (savedPostal.isNotEmpty || searchedPostal.isNotEmpty) {
    return savedPostal == searchedPostal;
  }
  final city = norm(address.city);
  return city.isNotEmpty && city == norm(intent.city);
}
