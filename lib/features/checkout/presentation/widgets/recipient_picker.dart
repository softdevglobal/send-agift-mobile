import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/checkout_repository.dart';
import 'new_recipient_sheet.dart';

/// Picks who the gift goes to, and shows the address it would ship to.
///
/// Every order needs one: each shop prices its own delivery from the
/// distance to this address. It is also the last chance to notice the gift
/// is pointed at the wrong place.
class RecipientPicker extends ConsumerWidget {
  const RecipientPicker({
    super.key,
    required this.selectedId,
    required this.onChanged,
  });

  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recipients = ref.watch(recipientsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        recipients.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (_, _) => Text(
            'Could not load your recipients.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.destructive,
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Text(
                'Add who the gift is for. Their address is what each shop '
                'prices delivery against.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                  height: 1.35,
                ),
              );
            }
            final known = list.any((recipient) => recipient.id == selectedId);
            return DropdownButtonFormField<String?>(
              // Rebuilt when a new recipient is saved and picked.
              key: ValueKey('recipient-${known ? selectedId : ''}'),
              initialValue: known ? selectedId : null,
              isExpanded: true,
              hint: const Text('Choose a recipient'),
              decoration: const InputDecoration(labelText: 'Send to'),
              items: [
                for (final recipient in list)
                  DropdownMenuItem<String?>(
                    value: recipient.id,
                    child: Text(
                      recipient.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onChanged,
            );
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('recipient-add'),
            onPressed: () async {
              final created = await showNewRecipientSheet(context);
              if (created != null) onChanged(created.id);
            },
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('New recipient'),
          ),
        ),
        if (selectedId != null) _Address(recipientId: selectedId!),
      ],
    );
  }
}

class _Address extends ConsumerWidget {
  const _Address({required this.recipientId});

  final String recipientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final details = ref.watch(recipientDetailsProvider(recipientId));

    return details.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 12),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (recipient) {
        final address = recipient.deliveryAddress;
        return Container(
          width: double.infinity,
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
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cream,
                ),
                child: Text(
                  _initials(recipient.name),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.purple,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipient.name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      address?.formatted ??
                          'No saved address. Add one before sending.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                        height: 1.35,
                      ),
                    ),
                    if (address != null && !address.hasPoint) ...[
                      const SizedBox(height: 4),
                      Text(
                        'This address was saved without a map point, so '
                        'shops cannot price delivery to it. Add them again '
                        'with the address picked from the list.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.destructive,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (recipient.phone != null &&
                        recipient.phone!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        recipient.phone!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}
