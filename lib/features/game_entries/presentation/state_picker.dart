import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../games/data/games_providers.dart';
import '../../games/domain/game_entries.dart';

/// The state or region of a country, chosen from the list the country has.
/// Renders nothing for a country without states. [onRequired] tells the form
/// whether a choice is needed, so it can hold sign-up until one is made.
class StatePicker extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final states = ref.watch(statesProvider(countryId));
    ref.listen<AsyncValue<List<StateOption>>>(statesProvider(countryId), (
      _,
      next,
    ) {
      final list = next.valueOrNull;
      if (list == null) return;
      onRequired?.call(list.isNotEmpty);
      if (value != null && !list.any((s) => s.id == value)) onChanged(null);
    });
    final list = states.valueOrNull ?? const <StateOption>[];
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: DropdownButtonFormField<String>(
        initialValue: list.any((s) => s.id == value) ? value : null,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'State or region',
          helperText: 'Games and competitions are offered state by state.',
        ),
        items: [
          for (final s in list)
            DropdownMenuItem(value: s.id, child: Text(s.name)),
        ],
        onChanged: enabled ? onChanged : null,
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
                : 'Games and competitions are offered state by state. Choose the one you live in to use games and game entries.',
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
