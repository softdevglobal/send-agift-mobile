import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../checkout/data/checkout_repository.dart';
import '../../../checkout/presentation/in_app_payment.dart';
import '../../../messages/data/messages_providers.dart';
import '../../../products/data/catalog_providers.dart';
import '../../../reviews/data/reviews_repository.dart';
import '../../../reviews/domain/product_review.dart';
import '../../../reviews/presentation/screens/write_review_screen.dart';
import '../../../reviews/presentation/widgets/star_rating.dart';
import '../../data/orders_repository.dart';
import '../widgets/parcel_tracking_card.dart';
import '../../domain/customer_order.dart';
import 'order_list_screen.dart';

/// One order and its gifts. Each gift comes from one shop, so this is where a
/// customer messages that shop about their item. A delivery question, a
/// change, or photos of a gift that arrived damaged.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(customerOrderProvider(orderId));

    return Scaffold(
      // The hero carries the order number; the bar just says where you are.
      appBar: AppBar(title: const Text('Order details')),
      body: SafeArea(
        child: order.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (error, _) => EmptyState(
            icon: Icons.receipt_long_outlined,
            title: "Couldn't load this order",
            description: error.toString(),
            action: OutlinedButton(
              onPressed: () => ref.invalidate(customerOrderProvider(orderId)),
              child: const Text('Try again'),
            ),
          ),
          data: (order) => FadeSlideIn(child: _OrderBody(order: order)),
        ),
      ),
    );
  }
}

class _OrderBody extends StatelessWidget {
  const _OrderBody({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final delivery = order.deliveryDate;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        8,
        AppTheme.gutter,
        32,
      ),
      children: [
        _OrderHero(order: order, delivery: delivery),
        if (order.status == 'pending_payment') ...[
          const SizedBox(height: 14),
          _PayNowCard(order: order),
        ],
        if (order.rewardPointsTotal > 0 || order.giftPointsLabel != null) ...[
          const SizedBox(height: 14),
          _PointsCard(order: order),
        ],
        const SizedBox(height: 14),
        _TrackingCard(order: order, delivery: delivery),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('GIFTS IN THIS ORDER', style: AppTypography.eyebrow),
        ),
        for (final item in order.items) ...[
          _OrderItemCard(order: order, item: item),
          const SizedBox(height: 10),
        ],
        if (order.giftMessage != null) ...[
          const SizedBox(height: 6),
          _GiftMessageCard(message: order.giftMessage!),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        AppPanel(
          color: AppColors.cream,
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.photo_camera_outlined,
                size: 19,
                color: AppColors.purple,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Something wrong with a gift? Message its shop and attach '
                  'photos. They reply in Messages.',
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// An order still waiting for payment. Paying happens on Stripe's page in the
/// browser; the order only becomes paid when Stripe tells the server, so this
/// re-reads the order as the app comes back into view.
class _PayNowCard extends ConsumerStatefulWidget {
  const _PayNowCard({required this.order});

  final CustomerOrder order;

  String get orderId => order.id;
  String get totalLabel => order.totalLabel;

  @override
  ConsumerState<_PayNowCard> createState() => _PayNowCardState();
}

class _PayNowCardState extends ConsumerState<_PayNowCard>
    with WidgetsBindingObserver {
  bool _starting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Already paid on Stripe but the webhook was late? Settle it now.
    _recheck();
  }

  /// Asks the server to re-check this order's payment with Stripe. It is a
  /// best-effort nudge in the background, so it never surfaces an error.
  Future<void> _recheck() async {
    try {
      final paid = await ref
          .read(checkoutRepositoryProvider)
          .syncPayment(widget.orderId);
      if (paid && mounted) {
        ref.invalidate(customerOrderProvider(widget.orderId));
      }
    } catch (_) {
      // Offline, or not signed in: the order simply stays as it is.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // The payment is confirmed by Stripe's webhook, a moment after the
    // customer is back, so look again a few times.
    for (final seconds in const [0, 2, 5]) {
      Future<void>.delayed(Duration(seconds: seconds), () {
        if (mounted) _recheck();
      });
    }
  }

  Future<void> _pay() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      // Stripe's own payment sheet, inside the app.
      final outcome = await payOrderInApp(ref, widget.orderId);
      if (!mounted) return;
      switch (outcome) {
        case InAppPaymentOutcome.paid:
          ref.invalidate(customerOrderProvider(widget.orderId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment received. Your gift is on its way.'),
            ),
          );
        case InAppPaymentOutcome.unavailable:
          setState(() => _error = 'Card payments are not available yet.');
        case InAppPaymentOutcome.cancelled:
          break;
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AppException
              ? error.message
              : 'Could not open the payment.',
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      key: const Key('pay-now'),
      color: AppColors.cream,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Complete your payment', style: AppTypography.display(18)),
          const SizedBox(height: 4),
          const Text(
            'Your gift is sent as soon as the payment goes through.',
            style: TextStyle(color: AppColors.mutedForeground, height: 1.4),
          ),
          const SizedBox(height: 12),
          // What the total is made of, before it is asked for.
          _BreakdownRow('Gifts', widget.order.subtotalLabel),
          _BreakdownRow('Delivery', widget.order.deliveryLabel),
          const Divider(height: 18),
          _BreakdownRow('Total', widget.totalLabel, strong: true),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.destructive)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('pay-now-button'),
              onPressed: _starting ? null : _pay,
              child: _starting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Pay ${widget.totalLabel}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
      color: strong ? AppColors.foreground : AppColors.mutedForeground,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style.copyWith(color: AppColors.foreground)),
        ],
      ),
    );
  }
}

/// The sender's note, set as a quote rather than a plain line.
class _GiftMessageCard extends StatelessWidget {
  const _GiftMessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('gift-message'),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border(
          left: const BorderSide(color: AppColors.purple, width: 4),
          top: BorderSide(color: AppColors.boxBorder),
          right: BorderSide(color: AppColors.boxBorder),
          bottom: BorderSide(color: AppColors.boxBorder),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.format_quote_rounded,
                size: 18,
                color: AppColors.purple,
              ),
              const SizedBox(width: 6),
              Text('GIFT MESSAGE', style: AppTypography.eyebrow),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: AppTypography.display(20)),
        ],
      ),
    );
  }
}

/// The order at a glance: number, status, how far along it is, and the three
/// facts people open an order for.
class _OrderHero extends StatelessWidget {
  const _OrderHero({required this.order, required this.delivery});

  final CustomerOrder order;
  final DateTime? delivery;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(
      color: Colors.white.withValues(alpha: 0.7),
      fontSize: 12,
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.foreground,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: AppTypography.display(21, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Placed ${DateFormat.yMMMd().format(order.createdAt.toLocal())}',
                      style: muted,
                    ),
                  ],
                ),
              ),
              OrderStatusChip(order: order),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroFact(
                  icon: Icons.event_rounded,
                  label: 'Delivery',
                  value: delivery == null
                      ? 'To be set'
                      : DateFormat.MMMd().format(delivery!.toLocal()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroFact(
                  icon: Icons.receipt_long_rounded,
                  label: 'Total',
                  value: order.totalLabel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroFact(
                  icon: Icons.stars_rounded,
                  label: 'Points',
                  value: order.rewardPointsTotal > 0
                      ? '${order.rewardsEarned ? '+' : ''}${order.rewardPointsTotal}'
                      : '-',
                  highlight: order.rewardPointsTotal > 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFFFCD980).withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? const Color(0xFFFCD980).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: highlight ? const Color(0xFFFCD980) : Colors.white70,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// What this order means for the customer's points: the reward it carries
/// and any points sent with the gift.
class _PointsCard extends StatelessWidget {
  const _PointsCard({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final points = order.rewardPointsTotal;
    final headline = points <= 0
        ? null
        : order.rewardsEarned
        ? '+$points points added to your balance'
        : order.items.firstWhere((i) => i.rewardLabel != null).rewardLabel ??
              '$points points';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'POINTS FROM THIS ORDER',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A5A12),
                  ),
                ),
                if (headline != null)
                  Text(
                    headline,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF4A2E08),
                    ),
                  ),
                if (order.giftPointsLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      order.giftPointsLabel!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B4410),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'My points',
            onPressed: () => context.push(AppRoutes.points),
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF6B4410),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemCard extends ConsumerWidget {
  const _OrderItemCard({required this.order, required this.item});

  final CustomerOrder order;
  final CustomerOrderItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gift = ref.watch(giftByIdProvider(item.productId)).valueOrNull;
    final textTheme = Theme.of(context).textTheme;
    // Unread replies from this item's shop, if there's already a thread.
    final thread = (ref.watch(inboxProvider).valueOrNull ?? const [])
        .where(
          (conversation) =>
              conversation.type == 'order' &&
              conversation.orderItemId == item.id,
        )
        .firstOrNull;
    final unread = thread?.unreadCount ?? 0;

    return AppPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: SizedBox(
                  height: 60,
                  width: 60,
                  child: gift == null
                      ? Container(
                          color: AppColors.muted,
                          child: const Icon(
                            Icons.card_giftcard_rounded,
                            color: AppColors.mutedForeground,
                          ),
                        )
                      : AppNetworkImage(url: gift.image),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gift?.name ?? 'Gift',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall,
                    ),
                    if (gift?.shopName != null)
                      Text(
                        gift!.shopName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Qty ${item.quantity} · ${order.formatAmount(item.unitAmount)} · '
                      '${item.fulfilmentLabel}',
                      style: textTheme.bodySmall,
                    ),
                    if (item.rewardLabel != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            size: 14,
                            color: AppColors.star,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.rewardLabel!,
                              style: textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF8A5A12),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push(
              thread != null
                  ? AppRoutes.chatPath(thread.id)
                  : AppRoutes.askAboutOrderItemPath(
                      item.id,
                      productId: item.productId,
                    ),
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
            label: Text(
              unread > 0
                  ? '$unread new ${unread == 1 ? 'reply' : 'replies'} from the shop'
                  : thread != null
                  ? 'Open chat with the shop'
                  : 'Message the shop',
            ),
          ),
          if (item.tracking != null)
            ParcelTrackingCard(tracking: item.tracking!),
          _ReviewAction(item: item, giftName: gift?.name),
        ],
      ),
    );
  }
}

/// Writes or reopens this line's review. Hidden until the line is delivered,
/// because the API refuses a review before then.
class _ReviewAction extends ConsumerWidget {
  const _ReviewAction({required this.item, this.giftName});

  final CustomerOrderItem item;
  final String? giftName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.fulfilmentStatus != 'delivered') return const SizedBox.shrink();

    // One request for the whole screen rather than one per line.
    final mine = ref.watch(myReviewsByOrderItemProvider(null)).valueOrNull;
    final existing = mine?[item.id];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: existing == null
          ? FilledButton.tonalIcon(
              onPressed: () => _open(context, ref, null),
              icon: const Icon(Icons.star_rounded, size: 18),
              label: const Text('Write a review'),
            )
          : OutlinedButton.icon(
              onPressed: () => _open(context, ref, existing),
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StarMeter(value: existing.rating.toDouble(), size: 13),
                  const SizedBox(width: 8),
                  const Text('Edit your review'),
                ],
              ),
            ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ProductReview? existing,
  ) async {
    await Navigator.of(context).push<ProductReview>(
      MaterialPageRoute(
        builder: (_) => WriteReviewScreen(
          orderItemId: item.id,
          existing: existing,
          productName: giftName,
        ),
      ),
    );
    ref.invalidate(myReviewsProvider);
  }
}

/// One step of the order's journey.
enum _StepState { complete, current, upcoming, stopped }

class _TrackStep {
  const _TrackStep(this.label, this.description, this.statuses);

  final String label;
  final String description;
  final List<String> statuses;
}

/// "Track this gift": the order's journey step by step, as on the website.
class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.order, required this.delivery});

  final CustomerOrder order;
  final DateTime? delivery;

  static const _steps = [
    _TrackStep('Order placed', 'We received your gift order.', [
      'draft',
      'pending_payment',
    ]),
    _TrackStep(
      'Payment received',
      'Payment is confirmed. The seller can start on your gift.',
      ['paid'],
    ),
    _TrackStep('Seller accepted', 'The seller has accepted this order.', [
      'accepted',
    ]),
    _TrackStep('Preparing gift', 'Your gift is being prepared for delivery.', [
      'preparing',
    ]),
    _TrackStep('On the way', 'The gift is on its way to the recipient.', [
      'dispatched',
    ]),
    _TrackStep('Delivered', 'The gift has been delivered.', ['delivered']),
  ];

  static const _descriptions = {
    'draft': 'This order is still being prepared on our side.',
    'pending_payment': 'Waiting for your payment.',
    'paid': 'Payment is confirmed. Waiting for the seller to accept.',
    'accepted': 'The seller has accepted this gift order.',
    'preparing': 'The seller is preparing your gift.',
    'dispatched': 'The gift is on its way to the recipient.',
    'delivered': 'The gift has been delivered.',
    'cancelled': 'This order was cancelled.',
    'refunded': 'This order was refunded.',
  };

  @override
  Widget build(BuildContext context) {
    final stopped = order.status == 'cancelled' || order.status == 'refunded';
    final current = _steps.indexWhere((s) => s.statuses.contains(order.status));
    final format = DateFormat('MMM d, y, h:mm a');
    final placed = format.format(order.createdAt.toLocal());
    final updated = order.updatedAt == null
        ? null
        : format.format(order.updatedAt!.toLocal());

    // The steps reached so far, then (for a cancelled order) where it stopped.
    final shown = <({String label, String description, _StepState state})>[
      for (var i = 0; i < _steps.length; i++)
        if (!stopped || i == 0)
          (
            label: _steps[i].label,
            description: _steps[i].description,
            state: stopped
                ? _StepState.complete
                : i < current
                ? _StepState.complete
                : i == current
                ? _StepState.current
                : _StepState.upcoming,
          ),
      if (stopped)
        (
          label: order.statusLabel,
          description: _descriptions[order.status] ?? '',
          state: _StepState.stopped,
        ),
    ];

    return AppPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Track this gift', style: AppTypography.display(19)),
                    const SizedBox(height: 2),
                    Text(
                      delivery == null
                          ? 'Delivery date to be set'
                          : 'Delivery ${DateFormat.yMMMd().format(delivery!.toLocal())}',
                      style: const TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusTag(status: order.status, label: order.statusLabel),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _descriptions[order.status] ??
                'You can follow this gift as it moves toward delivery.',
            style: const TextStyle(
              color: AppColors.mutedForeground,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < shown.length; i++)
            _TrackRow(
              label: shown[i].label,
              description: shown[i].description,
              state: shown[i].state,
              isLast: i == shown.length - 1,
              time: i == 0 && shown[i].state != _StepState.stopped
                  ? placed
                  : shown[i].state == _StepState.current ||
                        shown[i].state == _StepState.stopped
                  ? updated
                  : null,
            ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'pending_payment' => (const Color(0xFFFDE68A), const Color(0xFF451A03)),
      'paid' || 'accepted' || 'preparing' => (AppColors.purple, Colors.white),
      'dispatched' => (AppColors.foreground, Colors.white),
      'delivered' => (AppColors.teal, AppColors.tealForeground),
      'cancelled' || 'refunded' => (AppColors.destructive, Colors.white),
      _ => (AppColors.accent, AppColors.foreground),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.label,
    required this.description,
    required this.state,
    required this.isLast,
    this.time,
  });

  final String label;
  final String description;
  final _StepState state;
  final bool isLast;
  final String? time;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      _StepState.complete => (AppColors.purple, Colors.white),
      _StepState.current => (AppColors.foreground, Colors.white),
      _StepState.upcoming => (AppColors.accent, AppColors.mutedForeground),
      _StepState.stopped => (AppColors.destructive, Colors.white),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    switch (state) {
                      _StepState.complete => Icons.check_rounded,
                      _StepState.stopped => Icons.close_rounded,
                      _ => Icons.circle,
                    },
                    size:
                        state == _StepState.current ||
                            state == _StepState.upcoming
                        ? 8
                        : 18,
                    color: fg,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: state == _StepState.complete
                          ? AppColors.purple
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: state == _StepState.upcoming
                          ? AppColors.mutedForeground
                          : AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  if (time != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      time!,
                      style: const TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
