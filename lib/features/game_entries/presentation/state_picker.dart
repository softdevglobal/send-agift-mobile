import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../games/data/games_providers.dart';
import '../../games/domain/game_entries.dart';

/// The state or region of a country, as a dropdown. The list comes from
/// Google Places: the server fetches a country's states the first time they
/// are asked for and keeps them, so the first person may wait a moment.
///
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
    if (countryId.isEmpty) return const SizedBox.shrink();
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
    if (states.isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 14),
        child: InputDecorator(
          decoration: InputDecoration(labelText: 'State or region'),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Loading states…'),
            ],
          ),
        ),
      );
    }
    final list = states.valueOrNull ?? const <StateOption>[];
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: DropdownButtonFormField<String>(
        key: const Key('state-dropdown'),
        initialValue: list.any((s) => s.id == value) ? value : null,
        isExpanded: true,
        hint: const Text('Choose your state or region'),
        decoration: const InputDecoration(
          labelText: 'State or region',
          helperText: 'Games are offered state by state.',
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
                : 'Games are offered state by state. Choose the one you live in.',
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
