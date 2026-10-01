import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/sheet_header.dart';
import '../../../auth/data/countries_provider.dart';
import '../../../checkout/data/checkout_repository.dart';
import '../../../checkout/domain/checkout.dart';
import '../../../delivery/data/delivery_providers.dart';
import '../../../delivery/domain/delivery_intent.dart';
import '../../data/account_repository.dart';
import '../widgets/account_visuals.dart';
import '../widgets/address_form_sheet.dart';
import '../widgets/address_tile.dart';
import 'addresses_screen.dart' show confirmDelete, showToast;

/// One recipient: who they are, how to reach them, every address they have,
/// and a shortcut to gifts that can reach them.
class RecipientDetailScreen extends ConsumerWidget {
  const RecipientDetailScreen({super.key, required this.recipientId});

  final String recipientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(recipientDetailsProvider(recipientId));

    return Scaffold(
      appBar: AppBar(title: const Text('Recipient')),
      body: SafeArea(
        child: details.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Something went wrong',
            description: error is AppException
                ? error.message
                : 'Could not load this recipient.',
            action: OutlinedButton(
              onPressed: () =>
                  ref.invalidate(recipientDetailsProvider(recipientId)),
              child: const Text('Retry'),
            ),
          ),
          data: (recipient) {
            final delivery = recipient.deliveryAddress;
            final firstName = _firstName(recipient.name);
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(recipientDetailsProvider(recipientId)),
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
                      recipient: recipient,
                      onEdit: () => _editDetails(context, ref, recipient),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 60),
                    child: _GiftShortcut(
                      firstName: firstName,
                      address: delivery,
                      onTap: delivery == null
                          ? () => _addAddress(context, ref, recipient)
                          : () => _findGifts(context, ref, delivery),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipient.addresses.length > 1
                              ? 'ADDRESSES · ${recipient.addresses.length}'
                              : 'ADDRESS',
                          style: AppTypography.eyebrow,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < recipient.addresses.length; i++) ...[
                    FadeSlideIn(
                      delay: Duration(milliseconds: 100 + 40 * i),
                      child: AddressTile(
                        address: recipient.addresses[i],
                        isDefault: delivery?.id == recipient.addresses[i].id,
                        onEdit: () => _editAddress(
                          context,
                          ref,
                          recipient,
                          recipient.addresses[i],
                        ),
                        onMakeDefault: () => _makeDefault(
                          context,
                          ref,
                          recipient,
                          recipient.addresses[i],
                        ),
                        onDelete: () => _deleteAddress(
                          context,
                          ref,
                          recipient,
                          recipient.addresses[i],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  DashedAddCard(
                    key: const Key('recipient-add-address'),
                    label: recipient.addresses.isEmpty
                        ? 'Add $firstName\'s address'
                        : 'Add another address',
                    icon: Icons.add_location_alt_outlined,
                    onTap: () => _addAddress(context, ref, recipient),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: TextButton.icon(
                      key: const Key('recipient-delete'),
                      onPressed: () =>
                          _deleteRecipient(context, ref, recipient),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.destructive,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text('Remove $firstName'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _firstName(String name) {
    final first = name.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'them' : first;
  }

  void _refresh(WidgetRef ref) => invalidateRecipients(ref, recipientId);

  /// Searches gifts as if this address had been typed on Home, so only
  /// gifts that can reach the recipient are shown.
  void _findGifts(
    BuildContext context,
    WidgetRef ref,
    RecipientAddress address,
  ) {
    final countries = ref.read(countriesProvider).valueOrNull ?? const [];
    String? countryCode;
    String? countryName;
    for (final country in countries) {
      if (country.id == address.countryId) {
        countryCode = country.isoCode;
        countryName = country.name;
      }
    }
    final current = ref.read(deliveryIntentProvider);
    ref
        .read(deliveryIntentProvider.notifier)
        .set(
          DeliveryIntent(
            address: [
              address.line1,
              address.city,
              countryName,
            ].where((v) => v != null && v.trim().isNotEmpty).join(', '),
            line1: address.line1,
            line2: address.line2,
            city: address.city,
            region: address.region,
            postalCode: address.postalCode,
            countryCode: countryCode,
            countryName: countryName,
            latitude: address.latitude,
            longitude: address.longitude,
            date: current?.date,
          ),
        );
    context.go(AppRoutes.explore);
  }

  Future<void> _editDetails(
    BuildContext context,
    WidgetRef ref,
    Recipient recipient,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius2xl),
        ),
      ),
      builder: (_) => _EditDetailsSheet(recipient: recipient),
    );
    if (saved == true) {
      _refresh(ref);
      if (context.mounted) showToast(context, 'Details saved.');
    }
  }

  Future<void> _addAddress(
    BuildContext context,
    WidgetRef ref,
    Recipient recipient,
  ) async {
    final saved = await showAddressFormSheet(
      context,
      title: 'Add an address',
      requirePoint: true,
      save: (draft) => ref
          .read(accountRepositoryProvider)
          .addRecipientAddress(recipient.id, draft),
    );
    if (saved == true) {
      _refresh(ref);
      if (context.mounted) showToast(context, 'Address added.');
    }
  }

  Future<void> _editAddress(
    BuildContext context,
    WidgetRef ref,
    Recipient recipient,
    RecipientAddress address,
  ) async {
    final saved = await showAddressFormSheet(
      context,
      title: 'Edit address',
      requirePoint: true,
      initial: address,
      save: (draft) => ref
          .read(accountRepositoryProvider)
          .updateRecipientAddress(recipient.id, address.id, draft),
    );
    if (saved == true) {
      _refresh(ref);
      if (context.mounted) showToast(context, 'Address saved.');
    }
  }

  Future<void> _makeDefault(
    BuildContext context,
    WidgetRef ref,
    Recipient recipient,
    RecipientAddress address,
  ) async {
    try {
      await ref
          .read(accountRepositoryProvider)
          .updateRecipient(recipient, defaultAddressId: address.id);
      _refresh(ref);
      if (context.mounted) showToast(context, 'Default address changed.');
    } catch (error) {
      if (context.mounted) {
        showToast(
          context,
          errorMessage(error, 'Could not change the default.'),
        );
      }
    }
  }

  Future<void> _deleteAddress(
    BuildContext context,
    WidgetRef ref,
    Recipient recipient,
    RecipientAddress address,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete this address?',
      body: address.formatted,
    );
    if (!confirmed) return;
    try {
      await ref
          .read(accountRepositoryProvider)
          .deleteRecipientAddress(recipient.id, address.id);
      _refresh(ref);
      if (context.mounted) showToast(context, 'Address deleted.');
    } catch (error) {
      if (context.mounted) {
        showToast(context, errorMessage(error, 'Could not delete address.'));
      }
    }
  }

  Future<void> _deleteRecipient(
    BuildContext context,
    WidgetRef ref,
    Recipient recipient,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Remove ${recipient.name}?',
      body:
          'Their saved addresses go too. Orders already sent to them are '
          'not affected.',
    );
    if (!confirmed) return;
    try {
      await ref.read(accountRepositoryProvider).deleteRecipient(recipient.id);
      ref.invalidate(recipientsProvider);
      if (!context.mounted) return;
      showToast(context, '${recipient.name} removed.');
      Navigator.of(context).pop();
    } catch (error) {
      if (context.mounted) {
        showToast(context, errorMessage(error, 'Could not remove recipient.'));
      }
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.recipient, required this.onEdit});

  final Recipient recipient;
  final VoidCallback onEdit;

  Future<void> _open(BuildContext context, Uri uri, String fallback) async {
    final opened = await launchUrl(uri);
    if (!opened && context.mounted) showToast(context, fallback);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phone = recipient.phone?.trim() ?? '';
    final email = recipient.email?.trim() ?? '';
    final relationship = recipient.relationship?.trim() ?? '';

    return BrandHero(
      icon: Icons.card_giftcard_rounded,
      child: Column(
        children: [
          RingAvatar(name: recipient.name, size: 76, onDark: true),
          const SizedBox(height: 12),
          Text(
            recipient.name,
            textAlign: TextAlign.center,
            style: AppTypography.display(26, color: Colors.white),
          ),
          if (relationship.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                relationship,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (phone.isNotEmpty || email.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              [phone, email].where((v) => v.isNotEmpty).join('  ·  '),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoundAction(
                icon: Icons.phone_rounded,
                label: 'Call',
                onTap: phone.isEmpty
                    ? null
                    : () => _open(
                        context,
                        Uri(
                          scheme: 'tel',
                          path: phone.replaceAll(RegExp(r'\s+'), ''),
                        ),
                        phone,
                      ),
              ),
              const SizedBox(width: 22),
              _RoundAction(
                icon: Icons.mail_rounded,
                label: 'Email',
                onTap: email.isEmpty
                    ? null
                    : () => _open(
                        context,
                        Uri(scheme: 'mailto', path: email),
                        email,
                      ),
              ),
              const SizedBox(width: 22),
              _RoundAction(
                key: const Key('recipient-edit'),
                icon: Icons.edit_rounded,
                label: 'Edit',
                onTap: onEdit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Find a gift for Amaya" — the reason a recipient is saved at all.
class _GiftShortcut extends StatelessWidget {
  const _GiftShortcut({
    required this.firstName,
    required this.address,
    required this.onTap,
  });

  final String firstName;
  final RecipientAddress? address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = address != null;
    return Material(
      color: ready ? AppColors.accent : AppColors.cream,
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: InkWell(
        key: const Key('recipient-find-gifts'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(
                  ready ? Icons.redeem_rounded : Icons.add_location_alt_rounded,
                  color: ready ? AppColors.accentForeground : AppColors.purple,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ready
                          ? 'Find a gift for $firstName'
                          : 'Add where $firstName lives',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ready
                          ? 'Only gifts that can reach ${address!.city.isEmpty ? 'them' : address!.city}'
                          : 'Then see gifts that can reach them.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: ready ? AppColors.accentForeground : AppColors.purple,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditDetailsSheet extends ConsumerStatefulWidget {
  const _EditDetailsSheet({required this.recipient});

  final Recipient recipient;

  @override
  ConsumerState<_EditDetailsSheet> createState() => _EditDetailsSheetState();
}

class _EditDetailsSheetState extends ConsumerState<_EditDetailsSheet> {
  late final _name = TextEditingController(text: widget.recipient.name);
  late final _relationship = TextEditingController(
    text: widget.recipient.relationship,
  );
  late final _phone = TextEditingController(text: widget.recipient.phone);
  late final _email = TextEditingController(text: widget.recipient.email);
  bool _saving = false;
  String? _error;

  static const _relationships = [
    'Partner',
    'Mother',
    'Father',
    'Friend',
    'Sibling',
    'Colleague',
  ];

  @override
  void dispose() {
    _name.dispose();
    _relationship.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter their name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Empty strings clear a field: the repository sends them as null.
      await ref
          .read(accountRepositoryProvider)
          .updateRecipient(
            widget.recipient,
            name: _name.text,
            relationship: _relationship.text,
            phone: _phone.text,
            email: _email.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = errorMessage(error, 'Could not save these details.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          10,
          AppTheme.gutter,
          24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(title: 'Edit details'),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _relationship,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Relationship (optional)',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final option in _relationships)
                  ChoiceChip(
                    label: Text(option),
                    selected:
                        _relationship.text.trim().toLowerCase() ==
                        option.toLowerCase(),
                    onSelected: (_) =>
                        setState(() => _relationship.text = option),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                hintText: '+94 77 123 4567',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.destructive),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
