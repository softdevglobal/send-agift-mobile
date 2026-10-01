import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/delivery_providers.dart';
import '../../data/delivery_repository.dart';
import '../../domain/place.dart';

/// What the shopper settled on: a looked-up place, or text they typed and
/// kept without picking one. Only a place can be checked against delivery
/// zones; typed text is still remembered for checkout.
class AddressChoice {
  const AddressChoice.place(PlaceDetails this.place) : typed = null;
  const AddressChoice.typed(String this.typed) : place = null;

  final PlaceDetails? place;
  final String? typed;
}

/// Opens the address lookup as a tall sheet and returns what was chosen, or
/// null when it was dismissed.
Future<AddressChoice?> showAddressSearchSheet(
  BuildContext context, {
  String initialText = '',
  String title = 'Where is it going?',
}) {
  return showModalBottomSheet<AddressChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radius2xl),
      ),
    ),
    builder: (_) => _AddressSearchSheet(initialText: initialText, title: title),
  );
}

class _AddressSearchSheet extends ConsumerStatefulWidget {
  const _AddressSearchSheet({required this.initialText, required this.title});

  final String initialText;
  final String title;

  @override
  ConsumerState<_AddressSearchSheet> createState() =>
      _AddressSearchSheetState();
}

class _AddressSearchSheetState extends ConsumerState<_AddressSearchSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  final String _session = DeliveryRepository.newSessionToken();

  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  bool _searching = false;
  String? _resolving;
  String? _error;

  /// The input the visible suggestions belong to, so a slow answer for an
  /// older input never replaces a newer one.
  String _latest = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialText.trim().isNotEmpty) _search(widget.initialText);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 280), () => _search(value));
  }

  Future<void> _search(String value) async {
    final input = value.trim();
    _latest = input;
    if (input.length < 3) {
      setState(() {
        _suggestions = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final found = await ref
          .read(deliveryRepositoryProvider)
          .autocomplete(input, sessionToken: _session);
      if (!mounted || input != _latest) return;
      setState(() {
        _suggestions = found;
        _error = null;
      });
    } on AppException {
      if (!mounted || input != _latest) return;
      setState(() {
        _suggestions = const [];
        _error = 'Address lookup is unavailable right now.';
      });
    } finally {
      if (mounted && input == _latest) setState(() => _searching = false);
    }
  }

  Future<void> _pick(PlaceSuggestion suggestion) async {
    setState(() {
      _resolving = suggestion.placeId;
      _error = null;
    });
    try {
      final place = await ref
          .read(deliveryRepositoryProvider)
          .placeDetails(suggestion.placeId, sessionToken: _session);
      if (!mounted) return;
      Navigator.of(context).pop(AddressChoice.place(place));
    } on AppException {
      if (!mounted) return;
      setState(() {
        _resolving = null;
        _error = 'Could not open that address. Try another.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typed = _controller.text.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                16,
                AppTheme.gutter,
                4,
              ),
              child: Text(widget.title, style: AppTypography.display(22)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
              child: Text(
                'Pick the address from the list so we can show gifts a shop '
                'can deliver there.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                14,
                AppTheme.gutter,
                8,
              ),
              child: TextField(
                key: const Key('address-search-input'),
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Street, suburb or city',
                  prefixIcon: const Icon(
                    Icons.place_outlined,
                    color: AppColors.purple,
                  ),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : typed.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                          },
                        ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.gutter,
                  vertical: 4,
                ),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.destructive,
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter - 8,
                  4,
                  AppTheme.gutter - 8,
                  24,
                ),
                children: [
                  for (final suggestion in _suggestions)
                    ListTile(
                      key: Key('place-${suggestion.placeId}'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.cream,
                          shape: BoxShape.circle,
                        ),
                        child: _resolving == suggestion.placeId
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.location_on_rounded,
                                size: 18,
                                color: AppColors.purple,
                              ),
                      ),
                      title: Text(
                        suggestion.mainText.isNotEmpty
                            ? suggestion.mainText
                            : suggestion.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: suggestion.secondaryText.isEmpty
                          ? null
                          : Text(
                              suggestion.secondaryText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: _resolving == null
                          ? () => _pick(suggestion)
                          : null,
                    ),
                  // An address typed but never picked still counts: the
                  // shopper told us where it is going, it just cannot be
                  // checked against delivery zones.
                  if (typed.length >= 3 && !_searching)
                    ListTile(
                      key: const Key('address-use-typed'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      leading: const Icon(
                        Icons.edit_location_alt_outlined,
                        color: AppColors.mutedForeground,
                      ),
                      title: Text('Use “$typed”'),
                      subtitle: const Text(
                        'Remembered for checkout; gifts are not filtered',
                      ),
                      onTap: () =>
                          Navigator.of(context).pop(AddressChoice.typed(typed)),
                    ),
                  if (typed.length < 3 && _suggestions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Start typing an address — at least 3 letters.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
