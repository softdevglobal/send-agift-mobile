import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../domain/checkout.dart';

/// Subtotal, delivery and the final total.
///
/// Delivery is each shop's own, priced from the delivery zone that covers
/// the recipient's address. A zone can be priced in a currency other than the
/// cart's. When they differ the two are shown side by side rather than added,
/// because there is no exchange rate here to combine them honestly.
class DeliverySummary extends StatelessWidget {
  const DeliverySummary({
    super.key,
    required this.subtotal,
    required this.currency,
    required this.quote,
    required this.loading,
    required this.hasRecipient,
    required this.deliveryDate,
  });

  final int subtotal;
  final String currency;
  final DeliveryQuote? quote;
  final bool loading;
  final bool hasRecipient;
  final DateTime deliveryDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priced = quote != null && quote!.complete;
    final combinable = priced && quote!.matchesCurrency(currency);

    return Column(
      children: [
        _row(context, 'Subtotal', Money.format(subtotal, currency)),
        const SizedBox(height: 8),
        _row(
          context,
          'Delivery',
          loading
              ? 'Pricing…'
              : priced
              ? Money.format(quote!.amount, quote!.currency)
              : quote != null
              ? 'Not available there'
              : hasRecipient
              ? 'Not priced yet'
              : 'Pick a recipient',
          muted: !priced,
        ),
        if (priced) ...[
          for (final shipment in quote!.shipments) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_shipping_rounded,
                    size: 13,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      shipment.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Money.format(shipment.amount, shipment.currency),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total', style: theme.textTheme.titleMedium),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    combinable
                        ? Money.format(subtotal + quote!.amount, currency)
                        : Money.format(subtotal, currency),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                  if (priced && !combinable)
                    Text(
                      '+ ${Money.format(quote!.amount, quote!.currency)} delivery',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (priced && !combinable) ...[
          const SizedBox(height: 8),
          _note(
            context,
            'The shop prices delivery in ${quote!.currency.toUpperCase()} '
            'while this cart is priced in ${currency.toUpperCase()}, so they '
            'are shown separately rather than converted.',
          ),
        ],
        if (priced && quote!.arrivesAfter(deliveryDate)) ...[
          const SizedBox(height: 8),
          _note(
            context,
            'A shop needs more days than are left before the date you picked, '
            'so it may arrive later. Pick a later day to be sure.',
            warn: true,
          ),
        ],
        if (quote != null && !quote!.complete) ...[
          const SizedBox(height: 8),
          _note(
            context,
            quote!.unquoted.isEmpty
                ? 'A shop in your cart cannot deliver to this address.'
                : 'Cannot deliver there: ${quote!.unquoted.join('; ')}. '
                      'Choose another recipient or remove that shop\'s gifts.',
            warn: true,
          ),
        ],
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool muted = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: muted ? AppColors.mutedForeground : AppColors.foreground,
              fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _note(BuildContext context, String text, {bool warn = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: warn ? AppColors.cream : AppColors.muted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.mutedForeground,
          height: 1.35,
        ),
      ),
    );
  }
}
