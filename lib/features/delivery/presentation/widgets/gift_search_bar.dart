import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sheet_header.dart';
import '../../data/delivery_providers.dart';
import '../../domain/delivery_intent.dart';
import 'address_search_sheet.dart';

/// "Deliver to" and "Arrive by", then Find gifts. The same search as the
/// top of the web home page.
///
/// Edits stay a draft until Find gifts, so half-made choices never reload
/// the gift list. Clearing a field takes effect at once, as on the web.
class GiftSearchBar extends ConsumerStatefulWidget {
  const GiftSearchBar({super.key, this.onSubmitted});

  /// Runs after Find gifts saved the search. Home uses it to open Explore.
  final VoidCallback? onSubmitted;

  @override
  ConsumerState<GiftSearchBar> createState() => _GiftSearchBarState();
}

class _GiftSearchBarState extends ConsumerState<GiftSearchBar> {
  /// The address part of the draft: everything but the date.
  DeliveryIntent? _place;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _loadFrom(ref.read(deliveryIntentProvider));
  }

  void _loadFrom(DeliveryIntent? intent) {
    _place = intent != null && intent.hasAddress ? intent.withDate(null) : null;
    _date = intent?.date;
  }

  DeliveryIntent _draft() => (_place ?? const DeliveryIntent()).withDate(_date);

  Future<void> _pickAddress() async {
    final choice = await showAddressSearchSheet(
      context,
      initialText: _place?.address ?? '',
    );
    if (choice == null || !mounted) return;
    final place = choice.place;
    setState(() {
      _place = place != null
          ? DeliveryIntent(
              address: place.formattedAddress.isNotEmpty
                  ? place.formattedAddress
                  : place.line1,
              line1: place.line1.isNotEmpty ? place.line1 : null,
              line2: place.line2,
              countryCode: place.countryCode,
              countryName: place.countryName,
              city: place.city.isNotEmpty ? place.city : null,
              region: place.region,
              postalCode: place.postalCode,
              latitude: place.latitude,
              longitude: place.longitude,
            )
          : DeliveryIntent(address: choice.typed, line1: choice.typed);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showArrivalDateSheet(context, selected: _date);
    if (picked == null || !mounted) return;
    setState(() => _date = picked.date);
  }

  void _clearAddress() {
    setState(() => _place = null);
    final saved = ref.read(deliveryIntentProvider);
    ref.read(deliveryIntentProvider.notifier).set(saved?.withoutAddress());
  }

  void _clearDate() {
    setState(() => _date = null);
    final saved = ref.read(deliveryIntentProvider);
    ref.read(deliveryIntentProvider.notifier).set(saved?.withDate(null));
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    ref.read(deliveryIntentProvider.notifier).set(_draft());
    widget.onSubmitted?.call();
  }

  @override
  Widget build(BuildContext context) {
    // A search saved elsewhere (the other tab, or a clear on the summary)
    // replaces this draft so the two never disagree.
    ref.listen(deliveryIntentProvider, (_, next) {
      setState(() => _loadFrom(next));
    });

    final theme = Theme.of(context);
    final finding =
        ref.watch(giftAvailabilityProvider).isLoading &&
        (ref.watch(deliveryIntentProvider)?.hasPoint ?? false);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        // A solid ink edge with a hard offset shadow: a flat block, no glow.
        color: AppColors.foreground,
        boxShadow: const [
          BoxShadow(color: AppColors.foreground, offset: Offset(4, 4)),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius2xl - 1.5),
        ),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Field(
              key: const Key('gift-search-address'),
              icon: Icons.location_on_rounded,
              label: 'Deliver to',
              value: _place?.address,
              placeholder: 'Search an address',
              onTap: _pickAddress,
              onClear: _place == null ? null : _clearAddress,
            ),
            const Divider(height: 1, indent: 58, endIndent: 12),
            _Field(
              key: const Key('gift-search-date'),
              icon: Icons.event_rounded,
              label: 'Arrive by',
              value: _date == null ? null : _longDate(_date!),
              placeholder: 'Any day',
              onTap: _pickDate,
              onClear: _date == null ? null : _clearDate,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  key: const Key('gift-search-submit'),
                  onPressed: finding ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  icon: finding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryForeground,
                          ),
                        )
                      : const Icon(Icons.search_rounded, size: 19),
                  label: Text(
                    finding ? 'Finding gifts…' : 'Find gifts',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.primaryForeground,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _longDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[date.weekday - 1]}, ${DeliveryIntent.shortDate(date)}';
  }
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null && value!.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.cream,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 19, color: AppColors.purple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.mutedForeground,
                      letterSpacing: 1.1,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? value! : placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasValue
                          ? AppColors.foreground
                          : AppColors.mutedForeground,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                tooltip: 'Clear $label',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.mutedForeground,
              )
            else
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.mutedForeground,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The arrival day picked on the sheet. [date] null means any day.
class ArrivalChoice {
  const ArrivalChoice(this.date);
  final DateTime? date;
}

/// Quick picks for the arrival day, with the full calendar one tap away.
/// Returns null when dismissed.
Future<ArrivalChoice?> showArrivalDateSheet(
  BuildContext context, {
  DateTime? selected,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime inDays(int days) => today.add(Duration(days: days));
  bool same(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  return showModalBottomSheet<ArrivalChoice>(
    context: context,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radius2xl),
      ),
    ),
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final presets = [
        ('Tomorrow', inDays(1)),
        ('In 3 days', inDays(3)),
        ('Next week', inDays(7)),
      ];
      final isPreset = presets.any((preset) => same(selected, preset.$2));

      Widget option({
        required String label,
        required IconData icon,
        required bool active,
        required VoidCallback onTap,
        String? detail,
        Key? key,
      }) {
        return ListTile(
          key: key,
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          tileColor: active ? AppColors.cream : null,
          leading: Icon(
            icon,
            color: active ? AppColors.purple : AppColors.mutedForeground,
          ),
          title: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: active ? AppColors.purple : AppColors.foreground,
            ),
          ),
          trailing: detail == null
              ? (active
                    ? const Icon(Icons.check_rounded, color: AppColors.purple)
                    : null)
              : Text(detail, style: theme.textTheme.bodySmall),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 4, 10),
              child: SheetHeader(
                title: 'When should it arrive?',
                titleStyle: theme.textTheme.titleMedium,
              ),
            ),
            option(
              key: const Key('arrival-any-day'),
              label: 'Any day',
              icon: Icons.all_inclusive_rounded,
              active: selected == null,
              onTap: () =>
                  Navigator.of(sheetContext).pop(const ArrivalChoice(null)),
            ),
            for (final preset in presets)
              option(
                label: preset.$1,
                icon: Icons.bolt_rounded,
                active: same(selected, preset.$2),
                detail: same(selected, preset.$2)
                    ? null
                    : DeliveryIntent.shortDate(preset.$2),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ArrivalChoice(preset.$2)),
              ),
            option(
              label: selected != null && !isPreset
                  ? DeliveryIntent.shortDate(selected)
                  : 'Pick a date…',
              icon: Icons.calendar_month_rounded,
              active: selected != null && !isPreset,
              onTap: () async {
                final picked = await showDatePicker(
                  context: sheetContext,
                  initialDate: selected ?? inDays(1),
                  firstDate: today,
                  lastDate: today.add(const Duration(days: 365)),
                );
                if (picked != null && sheetContext.mounted) {
                  Navigator.of(sheetContext).pop(ArrivalChoice(picked));
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

/// What was searched, still in hand while browsing, with a way to drop it.
class DeliveryIntentSummary extends ConsumerWidget {
  const DeliveryIntentSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intent = ref.watch(deliveryIntentProvider);
    if (intent == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_shipping_rounded,
            size: 16,
            color: AppColors.accentForeground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              intent.hasPoint
                  ? 'Showing gifts that can reach ${intent.describe()}'
                  : intent.describe(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.accentForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            key: const Key('delivery-intent-clear'),
            tooltip: 'Clear delivery search',
            visualDensity: VisualDensity.compact,
            onPressed: () => ref.read(deliveryIntentProvider.notifier).clear(),
            icon: const Icon(Icons.close_rounded, size: 16),
            color: AppColors.accentForeground,
          ),
        ],
      ),
    );
  }
}
