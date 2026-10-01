import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/stat_hero.dart';
import '../../../products/domain/gift.dart';
import '../../../products/presentation/widgets/gift_grid.dart';
import '../../data/saved_controller.dart';

enum _Sort { saved, priceLow, priceHigh, rating }

/// Wishlist. Works for guests — the list lives on the device and syncs once
/// there is an account.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  _Sort _sort = _Sort.saved;

  /// An occasion tag to narrow to, or null for every gift.
  String? _occasion;

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedGiftListProvider).valueOrNull ?? const [];

    // The occasions the saved gifts cover, most common first.
    final tagCounts = <String, int>{};
    for (final gift in saved) {
      for (final tag in gift.occasionTags) {
        final clean = tag.trim();
        if (clean.isNotEmpty) tagCounts[clean] = (tagCounts[clean] ?? 0) + 1;
      }
    }
    final occasions = tagCounts.keys.toList()
      ..sort((a, b) => tagCounts[b]!.compareTo(tagCounts[a]!));
    final occasion = occasions.contains(_occasion) ? _occasion : null;

    final shown =
        saved
            .where((g) => occasion == null || g.occasionTags.contains(occasion))
            .toList()
          ..sort(
            (a, b) => switch (_sort) {
              _Sort.saved => 0,
              _Sort.priceLow => a.priceAmount.compareTo(b.priceAmount),
              _Sort.priceHigh => b.priceAmount.compareTo(a.priceAmount),
              _Sort.rating => b.rating.compareTo(a.rating),
            },
          );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: FadeSlideIn(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.gutter,
                    10,
                    AppTheme.gutter,
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saved gifts', style: AppTypography.display(28)),
                      const SizedBox(height: 4),
                      Text(
                        'Ideas you have kept, on this device. Sign in to '
                        'keep them across devices.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      _Hero(gifts: saved),
                    ],
                  ),
                ),
              ),
            ),
            if (saved.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: FadeSlideIn(
                  delay: Duration(milliseconds: 70),
                  child: _EmptyHint(),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 60),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.gutter,
                      0,
                      AppTheme.gutter,
                      14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (occasions.length > 1) ...[
                          Text('BY OCCASION', style: AppTypography.eyebrow),
                          const SizedBox(height: 10),
                          FilterChipRow<String?>(
                            options: [
                              (null, 'All · ${saved.length}'),
                              for (final tag in occasions.take(8))
                                (tag, '${_title(tag)} · ${tagCounts[tag]}'),
                            ],
                            selected: occasion,
                            onSelected: (value) =>
                                setState(() => _occasion = value),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Row(
                          children: [
                            Text(
                              '${shown.length} '
                              '${shown.length == 1 ? 'gift' : 'gifts'}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            _SortButton(
                              value: _sort,
                              onChanged: (value) =>
                                  setState(() => _sort = value),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GiftGrid(gifts: shown, sliver: true, heroPrefix: 'saved'),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ],
        ),
      ),
    );
  }

  static String _title(String tag) =>
      tag.isEmpty ? tag : tag[0].toUpperCase() + tag.substring(1);
}

class _Hero extends StatelessWidget {
  const _Hero({required this.gifts});

  final List<Gift> gifts;

  @override
  Widget build(BuildContext context) {
    final currency = gifts.isEmpty ? null : gifts.first.currency;
    final oneCurrency =
        currency != null && gifts.every((g) => g.currency == currency);
    final worth = gifts.fold<int>(0, (sum, g) => sum + g.priceAmount);
    final points = gifts.fold<int>(0, (sum, g) => sum + g.rewardPoints);
    final parts = [
      if (oneCurrency) 'Worth ${Money.format(worth, currency)}',
      if (points > 0) 'earn up to $points points',
    ];

    return StatHero(
      label: 'Your wishlist',
      icon: Icons.favorite_rounded,
      value: Text('${gifts.length} ${gifts.length == 1 ? 'gift' : 'gifts'}'),
      caption: gifts.isEmpty
          ? 'Tap the heart on any gift to keep it here.'
          : parts.isEmpty
          ? null
          : parts.join(' · '),
      trailing: ElevatedButton.icon(
        onPressed: () => context.go(AppRoutes.explore),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        icon: const Icon(Icons.search_rounded, size: 18),
        label: Text(gifts.isEmpty ? 'Find gifts' : 'Find more'),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.value, required this.onChanged});

  final _Sort value;
  final ValueChanged<_Sort> onChanged;

  static const _labels = {
    _Sort.saved: 'Saved order',
    _Sort.priceLow: 'Price: low to high',
    _Sort.priceHigh: 'Price: high to low',
    _Sort.rating: 'Top rated',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Sort>(
      key: const Key('saved-sort'),
      tooltip: 'Sort',
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final entry in _labels.entries)
          PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.swap_vert_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              _labels[value]!,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// Three hearts and a nudge, shown when nothing is saved.
class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget heart(double size, Color color, double angle) => Transform.rotate(
      angle: angle,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(Icons.favorite_rounded, color: color, size: size * 0.5),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              heart(52, AppColors.teal, -0.2),
              const SizedBox(width: 12),
              heart(72, const Color(0xFFE0457B), 0),
              const SizedBox(width: 12),
              heart(52, AppColors.purple, 0.2),
            ],
          ),
          const SizedBox(height: 20),
          Text('Nothing saved yet', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Collect gift ideas as you browse — no account needed. Tap the '
            'heart on any gift and it lands here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}
