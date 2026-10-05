import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/quantity_stepper.dart';
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
        if (order.rewardPointsTotal > 0 || order.giftPointsLabel != null) ...[
          const SizedBox(height: 14),
          _PointsCard(order: order),
        ],
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('GIFTS IN THIS ORDER', style: AppTypography.eyebrow),
        ),
        for (final item in order.items) ...[
          _OrderItemCard(order: order, item: item),
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

/// The order at a glance: number, status, how far along it is, and the three
/// facts people open an order for.
class _OrderHero extends StatelessWidget {
  const _OrderHero({required this.order, required this.delivery});

  final CustomerOrder order;
  final DateTime? delivery;

  static const _stages = [
    'pending_payment',
    'paid',
    'accepted',
    'preparing',
    'dispatched',
    'delivered',
  ];

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(
      color: Colors.white.withValues(alpha: 0.7),
      fontSize: 12,
    );
    final stage = _stages.indexOf(order.status);
    final stopped = order.status == 'cancelled' || order.status == 'refunded';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1B45), Color(0xFF3B1D8F), Color(0xFF6D28D9)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x406D28D9),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
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
          // How far along the order is: one segment per stage.
          Row(
            children: [
              for (var i = 0; i < _stages.length; i++) ...[
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: stopped
                          ? Colors.white.withValues(alpha: 0.15)
                          : i <= stage
                          ? const Color(0xFF5EEAD4)
                          : Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                if (i < _stages.length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(order.statusLabel, style: muted),
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
        : order.items
                  .firstWhere((i) => i.rewardLabel != null)
                  .rewardLabel ??
              '$points points';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7E0), Color(0xFFFDE3A7)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF4C872)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFCD980), Color(0xFFF4B545)],
              ),
              borderRadius: BorderRadius.circular(15),
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
          if (item.tracking != null) ParcelTrackingCard(tracking: item.tracking!),
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
