import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../checkout/domain/checkout.dart';
import 'account_visuals.dart';

/// One saved address as a card: a little map, its label and the default
/// marker, the address itself, and the actions the screen offers along the
/// bottom.
class AddressTile extends StatelessWidget {
  const AddressTile({
    super.key,
    required this.address,
    required this.isDefault,
    this.onEdit,
    this.onDelete,
    this.onMakeDefault,
    this.needsPoint = true,
  });

  final RecipientAddress address;
  final bool isDefault;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onMakeDefault;

  /// Warn when the address has no map point. Only recipient addresses are
  /// priced for delivery, so the customer's own do not need one.
  final bool needsPoint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missingPoint = needsPoint && !address.hasPoint;
    final streetLines = [
      address.line1,
      address.line2,
    ].where((v) => v != null && v.trim().isNotEmpty).join(', ');
    final area = [
      address.city,
      address.region,
    ].where((v) => v != null && v.trim().isNotEmpty).join(', ');

    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl - 1.5),
        border: isDefault ? null : Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MiniMap(
                  seed: address.id,
                  highlight: isDefault,
                  located: address.hasPoint,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _icon(address),
                            size: 16,
                            color: isDefault
                                ? AppColors.purple
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              address.title,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          if (isDefault) ...[
                            const SizedBox(width: 8),
                            const _Pill(
                              label: 'Default',
                              icon: Icons.star_rounded,
                              color: AppColors.purple,
                              background: AppColors.cream,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (streetLines.isNotEmpty)
                        Text(
                          streetLines,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.foreground,
                            height: 1.35,
                          ),
                        ),
                      if (area.isNotEmpty)
                        Text(area, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if ((address.postalCode ?? '').trim().isNotEmpty)
                            _Pill(
                              label: address.postalCode!,
                              icon: Icons.markunread_mailbox_outlined,
                              color: AppColors.primary,
                              background: AppColors.muted,
                            ),
                          if (missingPoint)
                            const _Pill(
                              label: 'Not on the map',
                              icon: Icons.location_off_outlined,
                              color: AppColors.destructive,
                              background: Color(0xFFFDECEC),
                            )
                          else if (address.hasPoint)
                            const _Pill(
                              label: 'On the map',
                              icon: Icons.near_me_rounded,
                              color: AppColors.accentForeground,
                              background: AppColors.accent,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null || onDelete != null || onMakeDefault != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              // One line when it fits; on a narrow phone or with large text
              // the buttons stack instead of overflowing the card.
              child: OverflowBar(
                alignment: MainAxisAlignment.spaceBetween,
                overflowAlignment: OverflowBarAlignment.start,
                children: [
                  Wrap(
                    children: [
                      if (onEdit != null)
                        _Action(
                          label: 'Edit',
                          icon: Icons.edit_outlined,
                          onTap: onEdit!,
                        ),
                      if (onMakeDefault != null && !isDefault)
                        _Action(
                          label: 'Make default',
                          icon: Icons.star_outline_rounded,
                          onTap: onMakeDefault!,
                        ),
                    ],
                  ),
                  if (onDelete != null)
                    _Action(
                      label: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      onTap: onDelete!,
                      color: AppColors.destructive,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    // The default gets a gradient edge, so it reads first at a glance.
    return Container(
      padding: EdgeInsets.all(isDefault ? 1.5 : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        color: isDefault ? AppColors.purple : null,
        boxShadow: AppTheme.cardShadow,
      ),
      child: card,
    );
  }

  static IconData _icon(RecipientAddress address) {
    final name = '${address.label ?? ''} ${address.addressType}'.toLowerCase();
    if (name.contains('home')) return Icons.home_rounded;
    if (name.contains('work') || name.contains('office')) {
      return Icons.business_center_rounded;
    }
    if (name.contains('return')) return Icons.assignment_return_rounded;
    return Icons.place_rounded;
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        visualDensity: VisualDensity.compact,
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
      icon: Icon(icon, size: 17),
      label: Text(label),
    );
  }
}
