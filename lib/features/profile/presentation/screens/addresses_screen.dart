import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../checkout/domain/checkout.dart';
import '../../data/account_repository.dart';
import '../widgets/account_visuals.dart';
import '../widgets/address_form_sheet.dart';
import '../widgets/address_tile.dart';

/// The customer's own saved addresses: for deliveries and returns. Recipient
/// addresses live with each recipient.
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(myAddressesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Addresses'),
        actions: [
          IconButton(
            key: const Key('addresses-add'),
            tooltip: 'Add address',
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: () => _add(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: addresses.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Something went wrong',
            description: error is AppException
                ? error.message
                : 'Could not load your addresses.',
            action: OutlinedButton(
              onPressed: () => ref.invalidate(myAddressesProvider),
              child: const Text('Retry'),
            ),
          ),
          data: (items) {
            final defaults = items.where((a) => a.isDefault).toList();
            final others = items.where((a) => !a.isDefault).toList();
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(myAddressesProvider),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  8,
                  AppTheme.gutter,
                  40,
                ),
                children: [
                  FadeSlideIn(
                    child: _Hero(
                      count: items.length,
                      onAdd: () => _add(context, ref),
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (items.isEmpty)
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
                      child: _EmptyHint(onAdd: () => _add(context, ref)),
                    ),
                  if (defaults.isNotEmpty) ...[
                    Text('HOME BASE', style: AppTypography.eyebrow),
                    const SizedBox(height: 10),
                    for (final address in defaults) ...[
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 80),
                        child: _tile(context, ref, address),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 14),
                  ],
                  if (others.isNotEmpty) ...[
                    Text(
                      defaults.isEmpty ? 'SAVED' : 'OTHER ADDRESSES',
                      style: AppTypography.eyebrow,
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < others.length; i++) ...[
                      FadeSlideIn(
                        delay: Duration(milliseconds: 110 + 40 * i),
                        child: _tile(context, ref, others[i]),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                  if (items.isNotEmpty)
                    DashedAddCard(
                      label: 'Add another address',
                      icon: Icons.add_location_alt_outlined,
                      onTap: () => _add(context, ref),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, RecipientAddress address) {
    return AddressTile(
      address: address,
      isDefault: address.isDefault,
      needsPoint: false,
      onDelete: () => _delete(context, ref, address),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final saved = await showAddressFormSheet(
      context,
      title: 'Add an address',
      save: (draft) => ref.read(accountRepositoryProvider).addMyAddress(draft),
    );
    if (saved == true) {
      ref.invalidate(myAddressesProvider);
      if (context.mounted) showToast(context, 'Address added.');
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    RecipientAddress address,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete this address?',
      body: address.formatted,
    );
    if (!confirmed) return;
    try {
      await ref.read(accountRepositoryProvider).deleteMyAddress(address.id);
      ref.invalidate(myAddressesProvider);
      if (context.mounted) showToast(context, 'Address deleted.');
    } catch (error) {
      if (context.mounted) {
        showToast(context, errorMessage(error, 'Could not delete address.'));
      }
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.count, required this.onAdd});

  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return BrandHero(
      icon: Icons.map_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count == 0
                  ? 'No addresses yet'
                  : count == 1
                  ? '1 saved address'
                  : '$count saved addresses',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your places',
            style: AppTypography.display(26, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Where you get deliveries and send returns from. Your default '
            'is used first.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 16),
          HeroButton(
            label: 'Add address',
            icon: Icons.add_location_alt_outlined,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MiniMap(seed: 'home', size: 64),
            SizedBox(width: 10),
            MiniMap(seed: 'office', size: 84, highlight: true),
            SizedBox(width: 10),
            MiniMap(seed: 'parents', size: 64),
          ],
        ),
        const SizedBox(height: 18),
        Text('Add your first address', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Search it once and the street, city and postal code fill in for '
          'you.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        DashedAddCard(
          label: 'Add an address',
          icon: Icons.add_location_alt_outlined,
          onTap: onAdd,
        ),
      ],
    );
  }
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Asks before something is deleted for good.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
