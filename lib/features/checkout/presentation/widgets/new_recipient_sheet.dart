import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/data/countries_provider.dart';
import '../../../delivery/data/delivery_providers.dart';
import '../../../delivery/domain/delivery_intent.dart';
import '../../../delivery/domain/place.dart';
import '../../../delivery/presentation/widgets/address_search_sheet.dart';
import '../../data/checkout_repository.dart';
import '../../domain/checkout.dart';

/// Adds someone to send this gift to, and returns them once saved.
///
/// The address searched for on home or explore is already filled in, so the
/// shopper is not asked twice. It must be picked from the lookup: delivery is
/// priced by the distance from each shop to its map point.
Future<Recipient?> showNewRecipientSheet(BuildContext context) {
  return showModalBottomSheet<Recipient>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radius2xl),
      ),
    ),
    builder: (_) => const _NewRecipientSheet(),
  );
}

/// The searched address as a place, when it was picked from the lookup.
PlaceDetails? placeFromIntent(DeliveryIntent? intent) {
  if (intent == null || !intent.hasPoint) return null;
  return PlaceDetails(
    placeId: '',
    formattedAddress: intent.address ?? '',
    line1: intent.line1 ?? intent.address ?? '',
    line2: intent.line2,
    city: intent.city ?? '',
    region: intent.region,
    postalCode: intent.postalCode,
    countryCode: intent.countryCode,
    countryName: intent.countryName,
    latitude: intent.latitude,
    longitude: intent.longitude,
  );
}

class _NewRecipientSheet extends ConsumerStatefulWidget {
  const _NewRecipientSheet();

  @override
  ConsumerState<_NewRecipientSheet> createState() => _NewRecipientSheetState();
}

class _NewRecipientSheetState extends ConsumerState<_NewRecipientSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  late PlaceDetails? _place = placeFromIntent(ref.read(deliveryIntentProvider));
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickAddress() async {
    final choice = await showAddressSearchSheet(
      context,
      initialText: _place?.formattedAddress ?? '',
      title: 'Their address',
    );
    if (choice == null || !mounted) return;
    if (choice.place == null) {
      setState(
        () => _error =
            'Pick the address from the list so delivery can be priced.',
      );
      return;
    }
    setState(() {
      _place = choice.place;
      _error = null;
    });
  }

  /// The address's country from the lookup, else the customer's own.
  Future<String> _countryId(PlaceDetails place) async {
    final code = place.countryCode?.toLowerCase();
    if (code != null) {
      try {
        final countries = await ref.read(countriesProvider.future);
        for (final country in countries) {
          if (country.isoCode.toLowerCase() == code) return country.id;
        }
      } on AppException {
        // Fall through to the customer's own country.
      }
    }
    return ref.read(checkoutRepositoryProvider).myCountryId();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final place = _place;
    if (name.isEmpty) {
      setState(() => _error = 'Enter their name.');
      return;
    }
    if (place == null || place.latitude == null || place.longitude == null) {
      setState(
        () => _error =
            'Pick their address from the list so delivery can be '
            'priced.',
      );
      return;
    }
    final line1 = place.line1.trim().isNotEmpty
        ? place.line1
        : place.formattedAddress;
    final city = place.city.trim().isNotEmpty
        ? place.city
        : (place.region ?? '');
    if (line1.trim().isEmpty || city.trim().isEmpty) {
      setState(
        () => _error = 'That place has no street or city. Pick a full address.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final countryId = await _countryId(place);
      final created = await ref
          .read(checkoutRepositoryProvider)
          .createRecipient(
            name: name,
            email: _email.text,
            phone: _phone.text,
            countryId: countryId,
            line1: line1,
            line2: place.line2,
            city: city,
            region: place.region,
            postalCode: place.postalCode,
            latitude: place.latitude,
            longitude: place.longitude,
          );
      ref.invalidate(recipientsProvider);
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = _place;

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
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Who is it for?', style: AppTypography.display(22)),
            const SizedBox(height: 4),
            Text(
              'Saved to your recipients, so next time it is one tap.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('new-recipient-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            InkWell(
              key: const Key('new-recipient-address'),
              onTap: _pickAddress,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: place == null ? null : AppColors.cream,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: place == null ? AppColors.border : AppColors.purple,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      color: place == null
                          ? AppColors.mutedForeground
                          : AppColors.purple,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery address',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            place == null
                                ? 'Search their address'
                                : place.formattedAddress,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: place == null
                                  ? AppColors.mutedForeground
                                  : AppColors.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      place == null ? 'Search' : 'Change',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.purple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('new-recipient-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                helperText: 'Needed to send them points with the gift.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('new-recipient-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                helperText: 'Helps the shop if they cannot find the door.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.destructive,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                key: const Key('new-recipient-save'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save and send to them'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
