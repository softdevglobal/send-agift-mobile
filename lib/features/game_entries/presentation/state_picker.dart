import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/countries_provider.dart';
import '../../delivery/data/delivery_providers.dart';
import '../../delivery/data/delivery_repository.dart';
import '../../delivery/domain/place.dart';

import '../../games/data/games_providers.dart';
import '../../games/domain/game_entries.dart';

/// The customer's state or region, searched on Google Places within their
/// country. Picking a suggestion checks it on the server and hands
/// [onChanged] our state's id; typing again clears it.
///
/// Shown as soon as a country is chosen, and [onRequired] is told a state is
/// needed. Someone whose country has no states can say so.
class StatePicker extends ConsumerStatefulWidget {
  const StatePicker({
    super.key,
    required this.countryId,
    required this.value,
    required this.onChanged,
    this.onRequired,
    this.enabled = true,
  });

  final String countryId;
  final String? value;
  final ValueChanged<String?> onChanged;
  final ValueChanged<bool>? onRequired;
  final bool enabled;

  @override
  ConsumerState<StatePicker> createState() => _StatePickerState();
}

class _StatePickerState extends ConsumerState<StatePicker> {
  final _query = TextEditingController();
  final _session = DeliveryRepository.newSessionToken();
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  bool _searching = false;
  bool _resolving = false;
  bool _noStates = false;
  String? _picked;
  String? _error;

  /// Ignores a search answer when a newer one was asked for.
  int _searchId = 0;

  @override
  void initState() {
    super.initState();
    _countryChanged();
  }

  @override
  void didUpdateWidget(StatePicker old) {
    super.didUpdateWidget(old);
    if (old.countryId != widget.countryId) _countryChanged();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  /// A new country: clear the search, ask for a state, and show the one
  /// already chosen by name.
  void _countryChanged() {
    _debounce?.cancel();
    _query.clear();
    _suggestions = const [];
    _picked = null;
    _error = null;
    _noStates = false;
    final countryId = widget.countryId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onRequired?.call(countryId.isNotEmpty);
    });
    final value = widget.value;
    if (countryId.isEmpty || value == null) return;
    ref.read(statesProvider(countryId).future).then((list) {
      if (!mounted || widget.countryId != countryId) return;
      final current = list.where((s) => s.id == value).firstOrNull;
      if (current == null) {
        widget.onChanged(null);
        return;
      }
      setState(() {
        _picked = current.name;
        _query.text = current.name;
      });
    }, onError: (_) {});
  }

  /// The country's ISO code, so Google only suggests states inside it.
  Future<String?> _countryCode() async {
    try {
      final countries = await ref.read(countriesProvider.future);
      final iso = countries
          .where((c) => c.id == widget.countryId)
          .firstOrNull
          ?.isoCode;
      return iso == null || iso.isEmpty ? null : iso;
    } catch (_) {
      return null;
    }
  }

  void _typed(String text) {
    if (_picked != null && text != _picked) {
      _picked = null;
      widget.onChanged(null);
    }
    _debounce?.cancel();
    setState(() => _error = null);
    if (text.trim().length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(text));
  }

  Future<void> _search(String text) async {
    final id = ++_searchId;
    setState(() => _searching = true);
    try {
      final found = await ref
          .read(deliveryRepositoryProvider)
          .autocomplete(
            text,
            sessionToken: _session,
            types: 'states',
            countryCode: await _countryCode(),
          );
      if (!mounted || id != _searchId) return;
      setState(() => _suggestions = found);
    } on AppException catch (error) {
      if (mounted && id == _searchId) setState(() => _error = error.message);
    } finally {
      if (mounted && id == _searchId) setState(() => _searching = false);
    }
  }

  Future<void> _pick(PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    final label = suggestion.mainText.isNotEmpty
        ? suggestion.mainText
        : suggestion.description;
    setState(() {
      _resolving = true;
      _suggestions = const [];
      _query.text = label;
      _error = null;
    });
    try {
      final state = await ref
          .read(gamesRepositoryProvider)
          .resolveState(widget.countryId, suggestion.placeId);
      if (!mounted) return;
      setState(() {
        _picked = state.name;
        _query.text = state.name;
      });
      widget.onChanged(state.id);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      widget.onChanged(null);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _toggleNoStates() {
    setState(() {
      _noStates = !_noStates;
      _query.clear();
      _suggestions = const [];
      _picked = null;
      _error = null;
    });
    widget.onChanged(null);
    widget.onRequired?.call(!_noStates);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.countryId.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final busy = _searching || _resolving;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_noStates)
            TextField(
              key: const Key('state-search'),
              controller: _query,
              enabled: widget.enabled && !_resolving,
              onChanged: _typed,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'State or region',
                hintText: 'Start typing your state or region',
                prefixIcon: const Icon(Icons.map_outlined),
                suffixIcon: busy
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _picked != null && widget.value != null
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.teal,
                      )
                    : null,
              ),
            ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (final s in _suggestions.take(6))
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined, size: 20),
                      title: Text(
                        s.mainText.isNotEmpty ? s.mainText : s.description,
                      ),
                      subtitle: s.secondaryText.isEmpty
                          ? null
                          : Text(s.secondaryText),
                      onTap: () => _pick(s),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          if (_error != null)
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.destructive,
              ),
            ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _noStates
                    ? 'No state needed.'
                    : 'Games are offered state by state, so we need yours.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              TextButton(
                key: const Key('state-none'),
                onPressed: widget.enabled ? _toggleNoStates : null,
                child: Text(
                  _noStates ? 'Choose a state' : 'My country has no states',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The state on the account, in Edit profile: shows it, and opens the
/// state sheet to add or change it.
class StateSettingTile extends ConsumerWidget {
  const StateSettingTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(myStateProvider).valueOrNull;
    if (current == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final name = current.state?.name;
    final until = current.canChangeAt;
    final locked =
        name != null && until != null && until.isAfter(DateTime.now());
    final needsPhone = name != null && !current.phoneVerified;
    final subtitle = name == null
        ? 'Not given yet. Games are offered state by state.'
        : locked
        ? 'Can be changed again on ${until.day}/${until.month}/${until.year}.'
        : needsPhone
        ? 'Verify your phone number to change it.'
        : 'Tap to change it.';
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        key: const Key('profile-state'),
        leading: const Icon(Icons.map_outlined),
        title: Text(name ?? 'State or region'),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: locked || needsPhone
            ? const Icon(Icons.lock_outline_rounded, size: 18)
            : const Icon(Icons.chevron_right_rounded),
        onTap: locked || needsPhone
            ? null
            : () => askForState(context, ref, current),
      ),
    );
  }
}

/// Asks for the customer's state when their country has states and they
/// have not given one. Returns true when a state was saved.
Future<bool> askForState(
  BuildContext context,
  WidgetRef ref,
  CustomerState current,
) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _StateSheet(current: current),
  );
  if (saved == true) {
    ref
      ..invalidate(myStateProvider)
      ..invalidate(gameEntriesProvider);
  }
  return saved == true;
}

class _StateSheet extends ConsumerStatefulWidget {
  const _StateSheet({required this.current});

  final CustomerState current;

  @override
  ConsumerState<_StateSheet> createState() => _StateSheetState();
}

class _StateSheetState extends ConsumerState<_StateSheet> {
  String? _choice;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    final choice = _choice;
    if (choice == null) {
      setState(() => _error = 'Choose your state or region.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(gamesRepositoryProvider).setMyState(choice);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final changing = widget.current.state != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            changing
                ? 'Change your state or region'
                : 'Which state or region do you live in?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            changing
                ? 'You can change it once in a while, and only with a verified phone number.'
                : 'Games are offered state by state. Search for the one you live in.',
          ),
          StatePicker(
            countryId: widget.current.countryId,
            value: _choice,
            onChanged: (v) => setState(() => _choice = v),
            enabled: !_busy,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
          ),
        ],
      ),
    );
  }
}
