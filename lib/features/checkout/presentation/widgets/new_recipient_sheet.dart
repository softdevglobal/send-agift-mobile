import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/dial_codes.dart';
import '../../../../core/widgets/sheet_header.dart';
import '../../../auth/data/countries_provider.dart';
import '../../../delivery/data/delivery_providers.dart';
import '../../../delivery/domain/delivery_intent.dart';
import '../../../delivery/domain/place.dart';
import '../../../delivery/presentation/widgets/address_search_sheet.dart';
import '../../data/checkout_repository.dart';
import '../../domain/checkout.dart';

/// Adds someone to send this gift to, and returns them once saved.
///
/// The same fields as the web checkout. Searching an address fills in the
/// street, city, region and postal code from Google, all still editable; the
/// address searched for on home or explore is filled in from the start, so
/// the shopper is not asked twice. The map point from the search is what
/// each shop prices delivery against, so one must be picked.
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

/// Sri Lanka, the same default as the web phone field.
const _defaultDialIso = 'LK';

class _NewRecipientSheet extends ConsumerStatefulWidget {
  const _NewRecipientSheet();

  @override
  ConsumerState<_NewRecipientSheet> createState() => _NewRecipientSheetState();
}

class _NewRecipientSheetState extends ConsumerState<_NewRecipientSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _label = TextEditingController();
  final _addressType = TextEditingController(text: 'shipping');
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _region = TextEditingController();
  final _postalCode = TextEditingController();

  /// The phone code by country, since several countries share one (+1).
  String _dialIso = _defaultDialIso;
  String? _countryId;

  /// The searched place's country, matched to [_countryId] once the
  /// country list has loaded.
  String? _placeCountryCode;
  bool _isDefault = true;

  /// The searched place: its text shown in the search box, its map point
  /// what delivery is priced to.
  PlaceDetails? _place;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final place = placeFromIntent(ref.read(deliveryIntentProvider));
    if (place != null) _fill(place);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _email,
      _label,
      _addressType,
      _line1,
      _line2,
      _city,
      _region,
      _postalCode,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Copies a picked place into the address fields, and its country into the
  /// country and phone code pickers.
  void _fill(PlaceDetails place) {
    // Some places have no city. The part before the country in the formatted
    // address is the next best thing, the same fallback the web uses.
    final parts = place.formattedAddress
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final city = place.city.trim().isNotEmpty
        ? place.city
        : (place.region?.trim().isNotEmpty ?? false)
        ? place.region!
        : parts.length > 1
        ? parts[parts.length - 2]
        : '';

    _place = place;
    _line1.text = place.line1.trim().isNotEmpty
        ? place.line1
        : place.formattedAddress;
    _line2.text = place.line2 ?? '';
    _city.text = city;
    _region.text = place.region ?? '';
    _postalCode.text = place.postalCode ?? '';

    final code = place.countryCode?.toUpperCase();
    if (code != null) {
      if (_phone.text.trim().isEmpty && dialCodes.any((d) => d.iso2 == code)) {
        _dialIso = code;
      }
      _placeCountryCode = code;
      _countryId = null;
    }
  }

  String get _dial => dialCodes
      .firstWhere(
        (d) => d.iso2 == _dialIso,
        orElse: () => dialCodes.firstWhere((d) => d.iso2 == _defaultDialIso),
      )
      .dial;

  Future<void> _searchAddress() async {
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
      _fill(choice.place!);
      _error = null;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final place = _place;
    final line1 = _line1.text.trim();
    final city = _city.text.trim();
    String? problem;
    if (name.isEmpty) {
      problem = 'Enter their name.';
    } else if (place == null ||
        place.latitude == null ||
        place.longitude == null) {
      problem =
          'Search their address and pick it from the list so delivery '
          'can be priced.';
    } else if (line1.isEmpty || city.isEmpty) {
      problem = 'Line 1 and city are needed.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(checkoutRepositoryProvider);
      final countryId = _countryId ?? await repository.myCountryId();
      final number = _phone.text.trim();
      final created = await repository.createRecipient(
        name: name,
        email: _email.text,
        phone: number.isEmpty ? null : '$_dial $number',
        countryId: countryId,
        label: _label.text,
        addressType: _addressType.text.trim(),
        isDefault: _isDefault,
        line1: line1,
        line2: _line2.text,
        city: city,
        region: _region.text,
        postalCode: _postalCode.text,
        latitude: place!.latitude,
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
    final countries = ref.watch(countriesProvider).valueOrNull ?? const [];
    final place = _place;
    if (_countryId == null && _placeCountryCode != null) {
      for (final country in countries) {
        if (country.isoCode.toUpperCase() == _placeCountryCode) {
          _countryId = country.id;
          break;
        }
      }
    }

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
            const SheetHeader(
              title: 'New recipient',
              subtitle: 'Saved to your recipients, so next time it is one tap.',
            ),
            const SizedBox(height: 18),
            TextField(
              key: const Key('new-recipient-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Jane Receiver',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 108,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('new-recipient-dial-$_dialIso'),
                    initialValue: _dialIso,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Code'),
                    selectedItemBuilder: (_) => [
                      for (final code in dialCodes) Text(code.dial),
                    ],
                    items: [
                      for (final code in dialCodes)
                        DropdownMenuItem(
                          value: code.iso2,
                          child: Text(
                            '${code.dial}  ${code.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _dialIso = value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('new-recipient-phone'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      hintText: '77 123 4567',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('new-recipient-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('new-recipient-country-$_countryId'),
              initialValue: countries.any((c) => c.id == _countryId)
                  ? _countryId
                  : null,
              isExpanded: true,
              hint: const Text('Select country'),
              decoration: const InputDecoration(labelText: 'Country'),
              items: [
                for (final country in countries)
                  DropdownMenuItem(
                    value: country.id,
                    child: Text(
                      '${country.name} (${country.isoCode})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _countryId = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('new-recipient-label'),
                    controller: _label,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      hintText: 'Home',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('new-recipient-type'),
                    controller: _addressType,
                    decoration: const InputDecoration(
                      labelText: 'Address type',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Search for an address', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            InkWell(
              key: const Key('new-recipient-address'),
              onTap: _searchAddress,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
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
                      place == null
                          ? Icons.search_rounded
                          : Icons.location_on_rounded,
                      size: 20,
                      color: place == null
                          ? AppColors.mutedForeground
                          : AppColors.purple,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        place == null
                            ? 'Start typing an address…'
                            : place.formattedAddress,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: place == null
                              ? AppColors.mutedForeground
                              : AppColors.foreground,
                        ),
                      ),
                    ),
                    if (place != null)
                      Text(
                        'Change',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.purple,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pick a result to fill the fields below. You can still edit '
              'them.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('new-recipient-line1'),
              controller: _line1,
              decoration: const InputDecoration(labelText: 'Line 1'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('new-recipient-line2'),
              controller: _line2,
              decoration: const InputDecoration(labelText: 'Line 2 (optional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('new-recipient-city'),
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('new-recipient-region'),
                    controller: _region,
                    decoration: const InputDecoration(labelText: 'Region'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('new-recipient-postal'),
              controller: _postalCode,
              decoration: const InputDecoration(labelText: 'Postal code'),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              key: const Key('new-recipient-default'),
              value: _isDefault,
              onChanged: (value) => setState(() => _isDefault = value ?? true),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: const Text('Default address'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.destructive,
                ),
              ),
            ],
            const SizedBox(height: 14),
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
                    : const Text('Create recipient'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
