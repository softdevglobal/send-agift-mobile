import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/customer_order.dart';

final _shippedFormat = DateFormat.yMMMd();

/// The parcel-tracking block on an order line.
///
/// Tracking is per line, not per order: an order can span several shops, each
/// shipping its own parcel with its own courier and number.
class ParcelTrackingCard extends StatelessWidget {
  const ParcelTrackingCard({super.key, required this.tracking});

  final OrderItemTracking tracking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delivered = tracking.isDelivered;
    final accent = delivered ? AppColors.accentForeground : AppColors.purple;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.14),
            ),
            child: Icon(
              delivered
                  ? Icons.inventory_2_rounded
                  : Icons.local_shipping_rounded,
              size: 16,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tracking.label,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (tracking.courierProvider != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '· ${tracking.courierProvider}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  tracking.hint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                    height: 1.35,
                  ),
                ),
                if (tracking.trackingNumber != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'TRACKING NUMBER',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Tap to copy: the number is the thing people paste into a
                  // courier's own app or hand to support.
                  InkWell(
                    onTap: () => _copy(context, tracking.trackingNumber!),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              tracking.trackingNumber!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: AppColors.mutedForeground,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (tracking.trackingUrl != null)
                      FilledButton.tonalIcon(
                        onPressed: () => _open(context, tracking.trackingUrl!),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Track parcel'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (tracking.trackingUrl != null &&
                        tracking.shippedAt != null)
                      const SizedBox(width: 10),
                    if (tracking.shippedAt != null)
                      Flexible(
                        child: Text(
                          'Shipped ${_shippedFormat.format(tracking.shippedAt!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                if (tracking.isSellerManaged &&
                    tracking.trackingUrl == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    tracking.trackingNumber != null
                        ? 'The shop is delivering this one themselves. Use the '
                              'number above with '
                              '${tracking.courierProvider ?? 'their courier'}, '
                              'or message the shop for an update.'
                        : 'The shop is delivering this one in person, so there '
                              'is no courier to track. Message them if you need '
                              'an update.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Tracking number copied.')));
  }

  Future<void> _open(BuildContext context, String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the tracking page.")),
      );
    }
  }
}
