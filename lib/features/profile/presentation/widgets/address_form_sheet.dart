import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sheet_header.dart';
import '../../../auth/data/countries_provider.dart';
import '../../../checkout/data/checkout_repository.dart';
import '../../../checkout/domain/checkout.dart';
import '../../../delivery/domain/place.dart';
import '../../../delivery/presentation/widgets/address_search_sheet.dart';
import '../../data/account_repository.dart';

/// Adds or edits one address. Searching fills the street, city, region and
/// postal code from Google; every field stays editable.
///
/// [save] does the API call, so an error keeps the sheet open with the
/// message. When [requirePoint] is set the address must come from the search,
/// because shops price delivery to its map point.
Future<bool?> showAddressFormSheet(
  BuildContext context, {
  required String title,
  required Future<void> Function(AddressDraft draft) save,
  RecipientAddress? initial,
  bool requirePoint = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radius2xl),
      ),
    ),
    builder: (_) => _AddressFormSheet(
      title: title,
      save: save,
      initial: initial,
      requirePoint: requirePoint,
    ),
  );
}

class _AddressFormSheet extends ConsumerStatefulWidget {
  const _AddressFormSheet({
    required this.title,
    required this.save,
    required this.initial,
    required this.requirePoint,
  });

  final String title;
  final Future<void> Function(AddressDraft draft) save;
  final RecipientAddress? initial;
  final bool requirePoint;

  @override
  ConsumerState<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<_AddressFormSheet> {
  late final _label = TextEditingController(text: widget.initial?.label);
  late final _addressType = TextEditingController(
    text: widget.initial?.addressType ?? 'shipping',
  );
  late final _line1 = TextEditingController(text: widget.initial?.line1);
  late final _line2 = TextEditingController(text: widget.initial?.line2);
  late final _city = TextEditingController(text: widget.initial?.city);
  late final _region = TextEditingController(text: widget.initial?.region);
  late final _postalCode = TextEditingController(
    text: widget.initial?.postalCode,
  );

  late String? _countryId = widget.initial?.countryId;
  late bool _isDefault = widget.initial?.isDefault ?? false;
  late double? _latitude = widget.initial?.latitude;
  late double? _longitude = widget.initial?.longitude;

  /// The picked place's text, shown in the search box.
  String? _searched;

  /// A picked place's country, matched to [_countryId] once countries load.
  String? _placeCountryCode;

  bool _saving = false;
  bool _countryLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_countryId == null) _loadOwnCountry();
  }

  @override
  void dispose() {
    for (final controller in [
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

  /// New addresses start in the customer's own country.
  Future<void> _loadOwnCountry() async {
    setState(() => _countryLoading = true);
    try {
      final id = await ref.read(checkoutRepositoryProvider).myCountryId();
      if (mounted && _countryId == null) setState(() => _countryId = id);
    } catch (_) {
      // They can still pick one.
    } finally {
      if (mounted) setState(() => _countryLoading = false);
    }
  }

  void _fill(PlaceDetails place) {
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
    _searched = place.formattedAddress;
    _line1.text = place.line1.trim().isNotEmpty
        ? place.line1
        : place.formattedAddress;
    _line2.text = place.line2 ?? '';
    _city.text = city;
    _region.text = place.region ?? '';
    _postalCode.text = place.postalCode ?? '';
    _latitude = place.latitude;
    _longitude = place.longitude;
    final code = place.countryCode?.toUpperCase();
    if (code != null) {
      _placeCountryCode = code;
      _countryId = null;
    }
  }

  Future<void> _search() async {
    final choice = await showAddressSearchSheet(
      context,
      initialText: _searched ?? '',
      title: widget.title,
    );
    if (choice == null || !mounted) return;
    if (choice.place == null) {
      setState(() => _error = 'Pick the address from the list to fill it in.');
      return;
    }
    setState(() {
      _fill(choice.place!);
      _error = null;
    });
  }

  Future<void> _submit() async {
    final countryId = _countryId;
    String? problem;
    if (countryId == null || countryId.isEmpty) {
      problem = 'Choose a country.';
    } else if (_line1.text.trim().isEmpty || _city.text.trim().isEmpty) {
      problem = 'Line 1 and city are needed.';
    } else if (widget.requirePoint &&
        (_latitude == null || _longitude == null)) {
      problem =
          'Search the address and pick it from the list so shops can '
          'price delivery to it.';
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
      await widget.save(
        AddressDraft(
          countryId: countryId!,
          label: _label.text,
          addressType: _addressType.text,
          line1: _line1.text,
          line2: _line2.text,
          city: _city.text,
          region: _region.text,
          postalCode: _postalCode.text,
          latitude: _latitude,
          longitude: _longitude,
          isDefault: _isDefault,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = errorMessage(error, 'Could not save this address.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countries = ref.watch(countriesProvider).valueOrNull ?? const [];
    if (_countryId == null && _placeCountryCode != null) {
      for (final country in countries) {
        if (country.isoCode.toUpperCase() == _placeCountryCode) {
          _countryId = country.id;
          break;
        }
      }
    }
    final hasPoint = _latitude != null && _longitude != null;

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
            SheetHeader(title: widget.title),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              key: ValueKey('address-country-$_countryId-${countries.length}'),
              initialValue: countries.any((c) => c.id == _countryId)
                  ? _countryId
                  : null,
              isExpanded: true,
              hint: Text(_countryLoading ? 'Loading…' : 'Select country'),
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
              onTap: _search,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: hasPoint ? AppColors.cream : null,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: hasPoint ? AppColors.purple : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasPoint
                          ? Icons.location_on_rounded
                          : Icons.search_rounded,
                      size: 20,
                      color: hasPoint
                          ? AppColors.purple
                          : AppColors.mutedForeground,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _searched ??
                            (hasPoint
                                ? 'Located on the map'
                                : 'Start typing an address…'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _searched != null || hasPoint
                              ? AppColors.foreground
                              : AppColors.mutedForeground,
                        ),
                      ),
                    ),
                    if (hasPoint)
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
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _line1,
              decoration: const InputDecoration(labelText: 'Line 1'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _line2,
              decoration: const InputDecoration(labelText: 'Line 2 (optional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _region,
                    decoration: const InputDecoration(labelText: 'Region'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _postalCode,
              decoration: const InputDecoration(labelText: 'Postal code'),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              value: _isDefault,
              onChanged: (value) => setState(() => _isDefault = value ?? false),
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
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save address'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A readable message from anything an API call can throw.
String errorMessage(Object error, String fallback) =>
    error is AppException && error.message.trim().isNotEmpty
    ? error.message
    : fallback;
