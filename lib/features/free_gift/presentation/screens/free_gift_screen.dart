import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../auth/data/auth_controller.dart';
import '../../../auth/domain/code_signup.dart';
import '../../../checkout/data/checkout_repository.dart';
import '../../../checkout/domain/checkout.dart';
import '../../../checkout/presentation/in_app_payment.dart';
import '../../../checkout/presentation/widgets/delivery_problem_card.dart';
import '../../../checkout/presentation/widgets/recipient_picker.dart';
import '../../../delivery/data/delivery_providers.dart';
import '../../../delivery/domain/delivery_intent.dart';
import '../../../orders/data/orders_repository.dart';
import '../../../profile/presentation/widgets/verify_phone_card.dart';
import '../../data/free_gift_repository.dart';
import '../../domain/free_gift.dart';

/// The free gift: who it is for, the day, and the gift, then send it. The
/// seller pays for the gift; the customer pays only its delivery, in the
/// same payment sheet as any order. Everything about eligibility comes from
/// the API and is checked again when it is sent.
class FreeGiftScreen extends ConsumerStatefulWidget {
  const FreeGiftScreen({super.key, this.initialProductId});

  /// A gift to start with selected, e.g. from a banner on a product.
  final String? initialProductId;

  @override
  ConsumerState<FreeGiftScreen> createState() => _FreeGiftScreenState();
}

class _FreeGiftScreenState extends ConsumerState<FreeGiftScreen> {
  // Offers: the list follows the delivery address and the day, so a gift
  // that cannot get there is never offered.
  List<FreeGiftOffer> _offers = const [];
  bool _offersLoading = true;
  bool _disabled = false;
  String? _loadError;
  String _offersToken = '';

  String? _productId;
  String? _recipientId;
  Recipient? _recipient;
  FreeGiftRecipientCheck? _recipientCheck;
  bool _checkingRecipient = false;
  late DateTime _deliveryDate = _initialDate(
    ref.read(deliveryIntentProvider)?.date,
  );

  // What the customer pays: the delivery to this recipient.
  DeliveryQuote? _quote;
  bool _quoting = false;
  String _quoteToken = '';

  final _message = TextEditingController();
  bool _sending = false;
  String? _error;

  /// One key for this screen, so a retry or a double tap is one order.
  final String _idempotencyKey = FreeGiftRepository.newIdempotencyKey();

  @override
  void initState() {
    super.initState();
    _productId = widget.initialProductId;
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  static DateTime _initialDate(DateTime? wanted) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (wanted != null && !wanted.isBefore(today)) return wanted;
    return today.add(const Duration(days: 1));
  }

  RecipientAddress? get _address => _recipient?.deliveryAddress;

  /// The map point the gifts are filtered by: the recipient's address once
  /// one is picked, else the address searched on home or explore.
  (double, double)? get _point {
    final address = _address;
    if (address != null && address.hasPoint) {
      return (address.latitude!, address.longitude!);
    }
    final intent = ref.read(deliveryIntentProvider);
    if (intent != null && intent.hasPoint) {
      return (intent.latitude!, intent.longitude!);
    }
    return null;
  }

  FreeGiftOffer? get _product {
    for (final offer in _offers) {
      if (offer.productId == _productId) return offer;
    }
    return null;
  }

  Future<void> _loadOffers() async {
    final point = _point;
    final token = '${point?.$1},${point?.$2},${_dateKey(_deliveryDate)}';
    _offersToken = token;
    setState(() => _offersLoading = true);
    try {
      final offers = await ref
          .read(freeGiftRepositoryProvider)
          .listOffers(
            latitude: point?.$1,
            longitude: point?.$2,
            deliveryDate: _deliveryDate,
          );
      if (!mounted || token != _offersToken) return;
      setState(() {
        _offers = offers;
        _disabled = false;
        _loadError = null;
        // A gift that dropped out of the list can no longer be picked.
        if (_productId != null &&
            !offers.any((offer) => offer.productId == _productId)) {
          _productId = null;
        }
      });
    } on AppException catch (error) {
      if (!mounted || token != _offersToken) return;
      setState(() {
        if (FreeGiftRepository.isDisabled(error)) {
          _disabled = true;
        } else {
          _loadError = error.message;
        }
      });
    } finally {
      if (mounted && token == _offersToken) {
        setState(() => _offersLoading = false);
      }
    }
  }

  Future<void> _pickRecipient(String? id) async {
    setState(() {
      _recipientId = id;
      _recipient = null;
      _recipientCheck = null;
      _checkingRecipient = id != null;
    });
    // The gift list follows their address; build reloads it when it changes.
    if (id == null) return;
    try {
      final results = await Future.wait([
        ref.read(freeGiftRepositoryProvider).status(recipientId: id),
        ref.read(checkoutRepositoryProvider).getRecipient(id),
      ]);
      if (!mounted || _recipientId != id) return;
      setState(() {
        _recipientCheck = (results[0] as FreeGiftStatus).recipient;
        _recipient = results[1] as Recipient;
      });
    } on AppException catch (error) {
      if (mounted && _recipientId == id) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && _recipientId == id) {
        setState(() => _checkingRecipient = false);
      }
    }
  }

  /// The day is the shared one from the gift search, as on the web, so
  /// home, explore and checkout keep the same day.
  void _setDate(DateTime date) {
    setState(() => _deliveryDate = date);
    final intent = ref.read(deliveryIntentProvider);
    ref
        .read(deliveryIntentProvider.notifier)
        .set((intent ?? const DeliveryIntent()).withDate(date));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) _setDate(picked);
  }

  /// Prices the delivery the customer will pay, whenever the gift, the
  /// recipient or the day changes. A stale answer never replaces a newer one.
  Future<void> _refreshQuote() async {
    final recipientId = _recipientId;
    final productId = _productId;
    if (recipientId == null || productId == null) {
      if (_quote != null) setState(() => _quote = null);
      return;
    }
    final token = _quoteToken;
    setState(() => _quoting = true);
    try {
      final quote = await ref
          .read(checkoutRepositoryProvider)
          .quoteItems(
            recipientId: recipientId,
            deliveryDate: _deliveryDate,
            items: [(productId, 1)],
          );
      if (!mounted || token != _quoteToken) return;
      setState(() => _quote = quote);
    } on AppException {
      if (mounted && token == _quoteToken) setState(() => _quote = null);
    } finally {
      if (mounted && token == _quoteToken) setState(() => _quoting = false);
    }
  }

  /// Why the gift cannot be sent yet, in the order it would be fixed, or
  /// null when it can.
  String? _blocker(FreeGiftStatus? status) {
    if (status != null && !status.available) {
      if (status.used) return 'Free gift already sent';
      if (status.locked) return 'On hold after an email change';
      if (status.missing.isNotEmpty) {
        return 'Verify your ${status.missing.join(' and ')}';
      }
      return 'Not available right now';
    }
    if (_recipientId == null) return 'Choose who it is for';
    if (_checkingRecipient) return 'Checking the recipient…';
    final check = _recipientCheck;
    if (check != null && !check.canReceive) return 'Choose another recipient';
    if (_recipient != null && _address == null) return 'Add their address';
    if (_product == null) return 'Pick a gift';
    if (_quoting) return 'Pricing delivery…';
    final quote = _quote;
    if (quote == null) return 'Delivery not priced';
    if (!quote.complete) return 'Cannot deliver there';
    return null;
  }

  Future<void> _send() async {
    final product = _product;
    final recipient = _recipient;
    final address = _address;
    if (product == null || recipient == null || address == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      var countryId = address.countryId;
      if (countryId.isEmpty) {
        countryId = await ref.read(checkoutRepositoryProvider).myCountryId();
      }
      final sent = await ref
          .read(freeGiftRepositoryProvider)
          .send(
            productId: product.productId,
            recipientId: recipient.id,
            countryId: countryId,
            deliveryDate: _deliveryDate,
            idempotencyKey: _idempotencyKey,
            giftMessage: _message.text,
          );
      ref.invalidate(freeGiftStatusProvider);
      ref.invalidate(customerOrdersProvider);

      // The gift is free; its delivery is paid in the same sheet as any
      // order. Closed or declined, the order waits on its page with Pay now.
      if (sent.needsPayment) {
        String? payProblem;
        try {
          final outcome = await payOrderInApp(ref, sent.orderId);
          if (outcome == InAppPaymentOutcome.unavailable) {
            payProblem = 'Card payments are not available yet.';
          }
        } on AppException catch (error) {
          payProblem = error.message;
        }
        if (payProblem != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delivery not paid yet: $payProblem')),
          );
        }
      }
      if (!mounted) return;
      context.go('${AppRoutes.orders}/${sent.orderId}');
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      // Whatever refused it, the screen should now say the same thing.
      ref.invalidate(freeGiftStatusProvider);
      final id = _recipientId;
      if (id != null) await _pickRecipient(id);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final statusAsync = ref.watch(freeGiftStatusProvider);
    final status = statusAsync.valueOrNull;

    // The first load, and a reload whenever the address or day changes.
    final offersToken =
        '${_point?.$1},${_point?.$2},${_dateKey(_deliveryDate)}';
    if (offersToken != _offersToken) {
      _offersToken = offersToken;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadOffers());
    }
    final quoteToken = [
      _recipientId ?? '',
      _productId ?? '',
      _dateKey(_deliveryDate),
    ].join('|');
    if (quoteToken != _quoteToken) {
      _quoteToken = quoteToken;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshQuote());
    }

    final statusDisabled =
        statusAsync.hasError &&
        FreeGiftRepository.isDisabled(statusAsync.error!);
    if (_disabled || statusDisabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Free gift')),
        body: EmptyState(
          icon: Icons.redeem_rounded,
          title: 'Not available right now',
          description:
              'The free gift is not open at the moment. Browse the gifts our '
              'shops have ready today.',
          action: ElevatedButton(
            onPressed: () => context.go(AppRoutes.explore),
            child: const Text('Browse gifts'),
          ),
        ),
      );
    }

    final canChoose = auth.isSignedIn && status != null && status.available;
    final blocker = auth.isSignedIn ? _blocker(status) : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Free gift')),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(freeGiftStatusProvider);
            await _loadOffers();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              8,
              AppTheme.gutter,
              32,
            ),
            children: [
              const FadeSlideIn(child: _Hero()),
              const SizedBox(height: 18),
              if (_loadError != null) ...[
                _Notice(text: _loadError!, error: true),
                const SizedBox(height: 14),
              ],
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: _AccountPanel(
                  signedIn: auth.isSignedIn,
                  status: status,
                  loading: statusAsync.isLoading,
                  error: statusAsync.hasError && !statusDisabled
                      ? 'Could not load your free gift. Pull down to try again.'
                      : null,
                ),
              ),
              if (canChoose) ...[
                const SizedBox(height: 16),
                _Step(
                  number: 1,
                  title: 'Who is it for?',
                  hint:
                      'They need an email and a phone number. Each person can '
                      'receive one free gift.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RecipientPicker(
                        selectedId: _recipientId,
                        onChanged: _pickRecipient,
                        requireContact: true,
                      ),
                      if (_checkingRecipient)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: LinearProgressIndicator(minHeight: 2),
                        )
                      else if (_recipientCheck != null &&
                          !_recipientCheck!.canReceive) ...[
                        const SizedBox(height: 10),
                        _Notice(text: _recipientCheck!.problem, error: true),
                      ] else if (_recipientCheck?.canReceive ?? false) ...[
                        const SizedBox(height: 10),
                        const _Notice(
                          text: 'They can receive your free gift.',
                          good: true,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Step(
                  number: 2,
                  title: 'When should it arrive?',
                  hint: 'Only gifts a shop can deliver by then are listed.',
                  child: _DatePicker(
                    date: _deliveryDate,
                    onPick: _pickDate,
                    onPreset: _setDate,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _Step(
                number: canChoose ? 3 : null,
                title: canChoose ? 'Pick your gift' : 'Gifts you can send free',
                hint: _point == null
                    ? 'Choose a recipient to see what can reach them.'
                    : 'Gifts that can reach that address by '
                          '${DeliveryIntent.shortDate(_deliveryDate)}.',
                child: _OfferList(
                  offers: _offers,
                  loading: _offersLoading,
                  selectedId: _productId,
                  filtered: _point != null,
                  onSelect: canChoose
                      ? (id) => setState(() => _productId = id)
                      : null,
                ),
              ),
              if (canChoose) ...[
                const SizedBox(height: 14),
                AppPanel(
                  child: TextField(
                    key: const Key('free-gift-message'),
                    controller: _message,
                    maxLines: 3,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Gift message (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Summary(
                  product: _product,
                  quote: _quote,
                  quoting: _quoting,
                  onChangeRecipient: () => _pickRecipient(null),
                  onEditAddress: _recipientId == null
                      ? null
                      : () => context.push(
                          AppRoutes.recipientPath(_recipientId!),
                        ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                _Notice(text: _error!, error: true),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: !auth.isSignedIn || canChoose
          ? Container(
              padding: EdgeInsets.fromLTRB(
                AppTheme.gutter,
                12,
                AppTheme.gutter,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  key: const Key('free-gift-send'),
                  onPressed: !auth.isSignedIn
                      ? () => context.push(AppRoutes.login)
                      : _sending || blocker != null
                      ? null
                      : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.redeem_rounded, size: 19),
                  label: Text(
                    !auth.isSignedIn
                        ? 'Sign in to send yours'
                        : blocker ?? _sendLabel(),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  String _sendLabel() {
    final quote = _quote;
    if (quote == null || quote.amount <= 0) return 'Send my free gift';
    return 'Send free gift · ${Money.format(quote.amount, quote.currency)} '
        'delivery';
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14B8B8), Color(0xFF5EEAD4)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FREE GIFT',
                  style: AppTypography.eyebrow.copyWith(
                    color: AppColors.tealForeground,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Send one gift, free',
                  style: AppTypography.display(
                    26,
                  ).copyWith(color: AppColors.tealForeground),
                ),
                const SizedBox(height: 6),
                Text(
                  'Every SendAGift customer has one free gift to send to '
                  'someone special. The shop pays for the gift. You only pay '
                  'its delivery.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.tealForeground,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Icon(
              Icons.redeem_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

/// Where this customer stands, before anything they can pick.
class _AccountPanel extends ConsumerWidget {
  const _AccountPanel({
    required this.signedIn,
    required this.status,
    required this.loading,
    this.error,
  });

  final bool signedIn;
  final FreeGiftStatus? status;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (!signedIn) {
      return AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create an account to send yours',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'It takes a minute. Verify your email and phone, then pick a '
              'gift below.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.push(AppRoutes.register),
                    child: const Text('Create account'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push(AppRoutes.login),
                    child: const Text('Sign in'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (loading && status == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) return _Notice(text: error!, error: true);
    final current = status;
    if (current == null) return const SizedBox.shrink();

    if (current.used) {
      return AppPanel(
        color: AppColors.cream,
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.purple,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You have sent your free gift',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Each customer has one. Follow it from your orders.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.orders),
              child: const Text('Orders'),
            ),
          ],
        ),
      );
    }
    if (current.locked) {
      return const _Notice(
        text:
            'Your free gift is on hold for a few days because your email '
            'address was changed. It will be here when the hold ends.',
        error: true,
      );
    }
    if (current.missing.isNotEmpty) {
      return AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'First, verify your account',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'A free gift needs a verified email address and a verified '
              'phone number.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Text('Email address', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            if (current.needsEmail)
              const _VerifyEmail()
            else
              const _Verified('Email verified'),
            const SizedBox(height: 14),
            Text('Phone number', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            if (current.needsPhone)
              const _VerifyPhone()
            else
              const _Verified('Phone verified'),
          ],
        ),
      );
    }
    return const _Notice(
      text: 'You have 1 free gift. Pick who it is for, the day and the gift.',
      good: true,
    );
  }
}

class _Verified extends StatelessWidget {
  const _Verified(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF059669)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF047857),
          ),
        ),
      ],
    );
  }
}

/// Proves the customer reads their own inbox with the same emailed code
/// they would sign in with. Entering it marks the email verified.
class _VerifyEmail extends ConsumerStatefulWidget {
  const _VerifyEmail();

  @override
  ConsumerState<_VerifyEmail> createState() => _VerifyEmailState();
}

class _VerifyEmailState extends ConsumerState<_VerifyEmail> {
  final _code = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send(String email) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .requestLoginCode(channel: CodeChannel.email, destination: email);
      if (mounted) setState(() => _sent = true);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(String email) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pending = await ref
          .read(authProvider.notifier)
          .verifyLoginCode(
            channel: CodeChannel.email,
            destination: email,
            code: _code.text.trim(),
          );
      if (pending != null) {
        if (mounted) setState(() => _error = 'That code did not work.');
        return;
      }
      ref.invalidate(freeGiftStatusProvider);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authProvider.select((auth) => auth.email)) ?? '';
    final theme = Theme.of(context);

    return Container(
      key: const Key('verify-email'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'We will email a 6-digit code to $email.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (_sent)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('verify-email-code'),
                    controller: _code,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(hintText: '6-digit code'),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _busy || _code.text.length != 6
                      ? null
                      : () => _confirm(email),
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
              ],
            )
          else
            OutlinedButton(
              key: const Key('verify-email-send'),
              onPressed: _busy || email.isEmpty ? null : () => _send(email),
              child: const Text('Email me a code'),
            ),
          if (_sent)
            TextButton(
              onPressed: _busy ? null : () => _send(email),
              child: const Text('Send a new code'),
            ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.destructive,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The phone card from the profile, or a way to add a phone first.
class _VerifyPhone extends ConsumerWidget {
  const _VerifyPhone();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    // Verifying refreshes the profile; the free gift status follows it.
    ref.listen(authProvider.select((a) => a.phoneVerified), (_, verified) {
      if (verified) ref.invalidate(freeGiftStatusProvider);
    });
    if (auth.phone != null) return const VerifyPhoneCard();
    return OutlinedButton.icon(
      key: const Key('free-gift-add-phone'),
      onPressed: () => context.push(AppRoutes.editProfile),
      icon: const Icon(Icons.phone_iphone_rounded, size: 18),
      label: const Text('Add a phone number'),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.title,
    required this.child,
    this.number,
    this.hint,
  });

  final int? number;
  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (number != null) ...[
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DatePicker extends StatelessWidget {
  const _DatePicker({
    required this.date,
    required this.onPick,
    required this.onPreset,
  });

  final DateTime date;
  final VoidCallback onPick;
  final ValueChanged<DateTime> onPreset;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool same(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          key: const Key('free-gift-date'),
          onPressed: onPick,
          icon: const Icon(Icons.calendar_today_rounded, size: 16),
          label: Text(DeliveryIntent.shortDate(date)),
        ),
        const SizedBox(height: 8),
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
                selected: same(date, today.add(Duration(days: preset.$2))),
                onSelected: (_) =>
                    onPreset(today.add(Duration(days: preset.$2))),
              ),
          ],
        ),
      ],
    );
  }
}

class _OfferList extends StatelessWidget {
  const _OfferList({
    required this.offers,
    required this.filtered,
    required this.loading,
    required this.selectedId,
    required this.onSelect,
  });

  final List<FreeGiftOffer> offers;

  /// Narrowed to an address, so an empty list means nothing can get there.
  final bool filtered;
  final bool loading;
  final String? selectedId;

  /// Null when nothing can be picked yet (a guest, or not verified).
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    if (loading && offers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (offers.isEmpty) {
      final theme = Theme.of(context);
      return Column(
        key: const Key('free-gift-empty'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            filtered ? 'No free gifts can get there' : 'No free gifts right now',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            filtered
                ? 'No shop can deliver a free gift to that address by that '
                      'day. Try another day or another recipient.'
                : 'Shops add and remove free gifts as their budgets allow. '
                      'Check back soon. Your free gift stays yours until you '
                      'send it.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.explore),
            child: const Text('Browse all gifts'),
          ),
        ],
      );
    }
    return Column(
      children: [
        if (loading) const LinearProgressIndicator(minHeight: 2),
        for (final offer in offers)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _OfferTile(
              offer: offer,
              selected: offer.productId == selectedId,
              onTap: onSelect == null ? null : () => onSelect!(offer.productId),
            ),
          ),
      ],
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({
    required this.offer,
    required this.selected,
    required this.onTap,
  });

  final FreeGiftOffer offer;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: Key('free-gift-offer-${offer.productId}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: selected ? AppColors.teal : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: SizedBox(
                width: 64,
                height: 64,
                child: offer.imageUrl == null
                    ? Container(
                        color: AppColors.cream,
                        child: const Icon(
                          Icons.card_giftcard_rounded,
                          color: AppColors.purple,
                        ),
                      )
                    : AppNetworkImage(url: offer.imageUrl!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    offer.shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        offer.valueLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'FREE',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppColors.tealForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.teal : AppColors.mutedForeground,
              ),
          ],
        ),
      ),
    );
  }
}

/// The gift is free; the delivery is what is paid.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.product,
    required this.quote,
    required this.quoting,
    this.onChangeRecipient,
    this.onEditAddress,
  });

  final VoidCallback? onChangeRecipient;
  final VoidCallback? onEditAddress;

  final FreeGiftOffer? product;
  final DeliveryQuote? quote;
  final bool quoting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gift = product;
    final priced = quote != null && quote!.complete;

    Widget row(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: strong
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
            ),
          ),
          Text(
            value,
            style: strong
                ? const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  )
                : theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
          ),
        ],
      ),
    );

    return AppPanel(
      key: const Key('free-gift-summary'),
      color: AppColors.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What you pay', style: AppTypography.display(18)),
          const SizedBox(height: 10),
          row(
            gift == null ? 'Gift' : 'Gift (${gift.valueLabel} value)',
            'Free',
          ),
          row(
            'Delivery',
            quoting
                ? 'Pricing…'
                : priced
                ? (quote!.amount > 0
                      ? Money.format(quote!.amount, quote!.currency)
                      : 'Free')
                : quote != null
                ? 'Not available there'
                : '—',
          ),
          const Divider(height: 18),
          row(
            'You pay',
            priced ? Money.format(quote!.amount, quote!.currency) : '—',
            strong: true,
          ),
          const SizedBox(height: 6),
          Text(
            'The shop pays for the gift from its marketing budget. Delivery is '
            'priced from the shop\'s own delivery zones to the recipient.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.mutedForeground,
              height: 1.35,
            ),
          ),
          if (quote != null && !quote!.complete) ...[
            const SizedBox(height: 10),
            // What is wrong and how to fix it, as in checkout.
            for (final shop in quote!.blocked)
              DeliveryProblemCard(
                shop: shop,
                onChangeRecipient: onChangeRecipient,
                onEditAddress: onEditAddress,
              ),
            if (quote!.blocked.isEmpty)
              const _Notice(
                text: 'This shop cannot deliver to that address.',
                error: true,
              ),
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.error = false, this.good = false});

  final String text;
  final bool error;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = error
        ? (const Color(0xFFFEF2F2), AppColors.destructive)
        : good
        ? (AppColors.accent, AppColors.accentForeground)
        : (AppColors.muted, AppColors.mutedForeground);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}
