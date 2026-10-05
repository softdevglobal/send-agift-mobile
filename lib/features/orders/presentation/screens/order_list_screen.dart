import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/stat_hero.dart';
import '../../../auth/data/auth_controller.dart';
import '../../data/orders_repository.dart';
import '../../domain/customer_order.dart';

/// Order history. This is the second surface (with checkout) that genuinely
/// needs an account, so guests get a sign-in prompt rather than an empty list.
class OrderListScreen extends ConsumerWidget {
  const OrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My orders')),
      body: SafeArea(
        child: FadeSlideIn(
          child: auth.isSignedIn
              ? const _Orders()
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.gutter,
                  ),
                  child: EmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Sign in to see your orders',
                    description:
                        'Order history and delivery tracking are tied to '
                        'your account. Browsing stays open either way.',
                    action: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () => context.push(AppRoutes.login),
                          child: const Text('Sign in'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () => context.push(AppRoutes.register),
                          child: const Text('Register'),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

enum _Filter { all, active, delivered, cancelled }

extension on CustomerOrder {
  bool get isCancelled => status == 'cancelled' || status == 'refunded';
  bool get isDelivered => status == 'delivered';
  bool get isActive => !isClosed;

  bool matches(_Filter filter) => switch (filter) {
    _Filter.all => true,
    _Filter.active => isActive,
    _Filter.delivered => isDelivered,
    _Filter.cancelled => isCancelled,
  };
}

class _Orders extends ConsumerStatefulWidget {
  const _Orders();

  @override
  ConsumerState<_Orders> createState() => _OrdersState();
}

class _OrdersState extends ConsumerState<_Orders> {
  _Filter _filter = _Filter.all;

  /// Tapping the active filter's tile again clears it.
  void _toggle(_Filter filter) =>
      setState(() => _filter = _filter == filter ? _Filter.all : filter);

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(customerOrdersProvider);

    return orders.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (error, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load your orders",
        description: error.toString(),
        action: OutlinedButton(
          onPressed: () => ref.invalidate(customerOrdersProvider),
          child: const Text('Try again'),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No orders yet',
            description:
                'Gifts you send will appear here with live delivery '
                'tracking.',
            action: ElevatedButton(
              onPressed: () => context.go(AppRoutes.explore),
              child: const Text('Find a gift'),
            ),
          );
        }

        final active = list.where((o) => o.isActive).toList();
        final delivered = list.where((o) => o.isDelivered).length;
        final cancelled = list.where((o) => o.isCancelled).length;
        final shown = list.where((o) => o.matches(_filter)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Group under the month each order was placed.
        final groups = <String, List<CustomerOrder>>{};
        for (final order in shown) {
          final key = DateFormat.yMMMM().format(order.createdAt.toLocal());
          groups.putIfAbsent(key, () => []).add(order);
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.refresh(customerOrdersProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              16,
              AppTheme.gutter,
              32,
            ),
            children: [
              _Hero(orders: list, active: active),
              const SizedBox(height: 12),
              StatGrid(
                tiles: [
                  StatTile(
                    label: 'On the way',
                    value: '${active.length}',
                    icon: Icons.local_shipping_rounded,
                    color: AppColors.purple,
                    selected: _filter == _Filter.active,
                    onTap: () => _toggle(_Filter.active),
                  ),
                  StatTile(
                    label: 'Delivered',
                    value: '$delivered',
                    icon: Icons.check_circle_rounded,
                    color: AppColors.accentForeground,
                    selected: _filter == _Filter.delivered,
                    onTap: () => _toggle(_Filter.delivered),
                  ),
                  StatTile(
                    label: 'Cancelled',
                    value: '$cancelled',
                    icon: Icons.cancel_rounded,
                    color: AppColors.destructive,
                    selected: _filter == _Filter.cancelled,
                    onTap: () => _toggle(_Filter.cancelled),
                  ),
                  StatTile(
                    label: 'Total spent',
                    value: _spent(list),
                    icon: Icons.payments_rounded,
                    color: AppColors.star,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text('HISTORY', style: AppTypography.eyebrow),
                  const Spacer(),
                  Text(
                    '${shown.length} of ${list.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilterChipRow<_Filter>(
                options: const [
                  (_Filter.all, 'All'),
                  (_Filter.active, 'On the way'),
                  (_Filter.delivered, 'Delivered'),
                  (_Filter.cancelled, 'Cancelled'),
                ],
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 14),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: Text('No orders here.')),
                ),
              for (final entry in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 6, 0, 10),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: AppTypography.eyebrow,
                  ),
                ),
                for (var i = 0; i < entry.value.length; i++) ...[
                  FadeSlideIn(
                    delay: Duration(milliseconds: 30 * i.clamp(0, 6)),
                    child: _OrderCard(order: entry.value[i]),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  /// Everything paid on orders that went ahead. Mixed currencies can't be
  /// added up, so they show as a count instead.
  static String _spent(List<CustomerOrder> orders) {
    final counted = orders.where((o) => !o.isCancelled).toList();
    if (counted.isEmpty) return '-';
    final currency = counted.first.currency;
    if (counted.any((o) => o.currency != currency)) {
      return '${counted.length} orders';
    }
    final total = counted.fold<int>(0, (sum, o) => sum + o.totalAmount);
    return counted.first.formatAmount(total);
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.orders, required this.active});

  final List<CustomerOrder> orders;
  final List<CustomerOrder> active;

  @override
  Widget build(BuildContext context) {
    final delivered = orders.where((o) => o.isDelivered).length;
    final today = DateUtils.dateOnly(DateTime.now());
    final upcoming =
        active
            .map((o) => o.deliveryDate)
            .whereType<DateTime>()
            .map((d) => DateUtils.dateOnly(d.toLocal()))
            .where((d) => !d.isBefore(today))
            .toList()
          ..sort();

    return StatHero(
      label: 'Gifts sent',
      icon: Icons.card_giftcard_rounded,
      value: Text(
        '${orders.length} ${orders.length == 1 ? 'order' : 'orders'}',
      ),
      caption: '${active.length} on the way · $delivered delivered',
      trailing: upcoming.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Next arrival ${_relativeDay(upcoming.first, today)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

String _relativeDay(DateTime day, DateTime today) {
  final days = day.difference(today).inDays;
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days < 7) return DateFormat.EEEE().format(day);
  return DateFormat.MMMd().format(day);
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final CustomerOrder order;

  /// Which of the four tracker steps the order has reached.
  int get _step => switch (order.status) {
    'accepted' || 'preparing' => 1,
    'dispatched' => 2,
    'delivered' => 3,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final delivery = order.deliveryDate?.toLocal();
    final (Color color, IconData icon) = order.isCancelled
        ? (AppColors.destructive, Icons.cancel_outlined)
        : order.isDelivered
        ? (AppColors.accentForeground, Icons.check_circle_outline_rounded)
        : order.status == 'dispatched'
        ? (AppColors.purple, Icons.local_shipping_outlined)
        : (AppColors.primary, Icons.card_giftcard_rounded);

    final when = order.isDelivered
        ? 'Delivered${delivery == null ? '' : ' ${DateFormat.MMMd().format(delivery)}'}'
        : order.isCancelled || delivery == null
        ? 'Placed ${DateFormat.yMMMd().format(order.createdAt.toLocal())}'
        : 'Arrives ${DateFormat.MMMEd().format(delivery)}';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        onTap: () => context.push(AppRoutes.orderDetailPath(order.id)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(color: AppColors.border),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(when, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(order.totalLabel, style: textTheme.titleSmall),
                      const SizedBox(height: 4),
                      OrderStatusChip(order: order),
                    ],
                  ),
                ],
              ),
              if (!order.isCancelled) ...[
                const SizedBox(height: 14),
                _Tracker(step: _step),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Placed → Preparing → On its way → Delivered, filled up to [step].
class _Tracker extends StatelessWidget {
  const _Tracker({required this.step});

  final int step;

  static const _labels = ['Placed', 'Preparing', 'On its way', 'Delivered'];

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.labelSmall;
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < _labels.length; i++) ...[
              _Dot(done: i <= step, current: i == step),
              if (i != _labels.length - 1)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: i < step
                          ? const LinearGradient(
                              colors: [AppColors.purple, AppColors.teal],
                            )
                          : null,
                      color: i < step ? null : AppColors.mist,
                    ),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < _labels.length; i++)
              Expanded(
                child: Text(
                  _labels[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : i == _labels.length - 1
                      ? TextAlign.right
                      : TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: small?.copyWith(
                    color: i <= step
                        ? AppColors.foreground
                        : AppColors.mutedForeground,
                    fontWeight: i == step ? FontWeight.w700 : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.done, required this.current});

  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: current ? 14 : 10,
      width: current ? 14 : 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? AppColors.purple : AppColors.mist,
        border: current
            ? Border.all(
                color: AppColors.purple.withValues(alpha: 0.25),
                width: 3,
                strokeAlign: BorderSide.strokeAlignOutside,
              )
            : null,
      ),
    );
  }
}

/// Order status as a small pill. Teal while it's moving, muted once done.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final cancelled = order.status == 'cancelled' || order.status == 'refunded';
    final background = cancelled
        ? AppColors.destructive.withValues(alpha: 0.1)
        : order.isClosed
        ? AppColors.muted
        : AppColors.accent;
    final foreground = cancelled
        ? AppColors.destructive
        : order.isClosed
        ? AppColors.mutedForeground
        : AppColors.accentForeground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        order.statusLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
