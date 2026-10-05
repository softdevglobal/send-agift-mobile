import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../data/cart_controller.dart';
import '../../domain/cart_item.dart';

/// Guest cart. Items are kept on device; the customer only signs in when they
/// move to checkout.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(cartLinesProvider).valueOrNull ?? const <CartLine>[];
    final summary = ref.watch(cartSummaryProvider);
    final itemCount = ref.watch(cartCountProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                10,
                12,
                4,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cart', style: AppTypography.display(28)),
                        const SizedBox(height: 4),
                        Text(
                          lines.isEmpty
                              ? 'Gifts you add stay here until you check out.'
                              : '$itemCount item${itemCount == 1 ? '' : 's'} '
                                  'ready for checkout.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (lines.isNotEmpty)
                    TextButton(
                      onPressed: () => ref.read(cartProvider.notifier).clear(),
                      child: const Text('Clear'),
                    ),
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.foreground,
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Expanded(
              child: lines.isEmpty
                  ? EmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Your cart is empty',
                      description:
                          'Browse the catalog and add a gift to get started. '
                          'no account needed.',
                      action: ElevatedButton(
                        onPressed: () => context.go(AppRoutes.explore),
                        child: const Text('Discover gifts'),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.gutter,
                        14,
                        AppTheme.gutter,
                        24,
                      ),
                      itemCount: lines.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) => FadeSlideIn(
                        delay: Duration(milliseconds: 40 * index),
                        child: _CartLineTile(line: lines[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          lines.isEmpty ? null : _CartSummaryBar(summary: summary),
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gift = line.gift;

    return AppPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push(AppRoutes.giftDetailPath(gift.id)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: SizedBox(
                height: 82,
                width: 82,
                child: AppNetworkImage(url: gift.image),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        gift.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          ref.read(cartProvider.notifier).remove(gift.id),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
                if (gift.shopName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    gift.shopName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    QuantityStepper(
                      quantity: line.quantity,
                      onChanged: (value) => ref
                          .read(cartProvider.notifier)
                          .setQuantity(gift.id, value),
                    ),
                    const SizedBox(width: 8),
                    // On a narrow cart panel (the sheet is 80% of a phone's
                    // width) the stepper and a multi-digit total can outgrow
                    // the row; scaling the price down keeps it on one line
                    // instead of overflowing.
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          Money.format(line.lineTotalAmount, gift.currency),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartSummaryBar extends StatelessWidget {
  const _CartSummaryBar({required this.summary});

  final CartSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppTheme.gutter,
        16,
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
          _SummaryRow(
            label: 'Subtotal',
            value: Money.format(summary.subtotal, summary.currency),
          ),
          const SizedBox(height: 6),
          const _SummaryRow(
            label: 'Delivery',
            value: 'Calculated at dispatch',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(),
          ),
          _SummaryRow(
            label: 'Total',
            value: Money.format(summary.total, summary.currency),
            emphasized: true,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push(AppRoutes.checkout),
              child: const Text('Proceed to checkout'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          )
        : const TextStyle(fontSize: 13.5, color: AppColors.mutedForeground);

    // The value is flexible because it is not always a short amount. The
    // delivery row carries a phrase, which overflowed a narrow phone when both
    // sides were unconstrained.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: style,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
