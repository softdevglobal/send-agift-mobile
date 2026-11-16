import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/storefront_decor.dart';
import '../../data/catalog_providers.dart';
import '../../domain/shop.dart';
import '../widgets/gift_grid.dart';

/// A shop's own page, opened from a gift: its cover photo, who runs it, what
/// it offers, every gift it sells and how returns work.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key, required this.shopId});

  /// How far the shop card rides up over the cover photo.
  static const double _cardOverlap = 72;

  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(shopPageProvider(shopId));
    void retry() => ref.invalidate(shopPageProvider(shopId));
    return Scaffold(
      body: page.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Missing(onRetry: retry),
        data: (value) {
          if (value == null) return _Missing(onRetry: retry);
          final (shop, gifts) = value;
          final sorted = [
            ...gifts.where((g) => g.sponsored),
            ...gifts.where((g) => !g.sponsored),
          ];
          final width = MediaQuery.sizeOf(context).width;
          // Taller on a wide screen, so the photo is not a thin strip.
          final coverHeight = (width * 0.55).clamp(210.0, 320.0);
          final top = MediaQuery.paddingOf(context).top;
          final about =
              (shop.description ?? '').isNotEmpty || shop.categories.isNotEmpty;
          return Stack(
            children: [
              RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => ref.refresh(shopPageProvider(shopId).future),
                child: CustomScrollView(
                  slivers: [
                    // The cover photo, with the shop card layered over its
                    // bottom edge (drawn after the photo, so it sits on top).
                    SliverToBoxAdapter(
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: coverHeight + top,
                            child: _CoverPhoto(url: shop.imageUrl),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              AppTheme.gutter,
                              coverHeight + top - _cardOverlap,
                              AppTheme.gutter,
                              0,
                            ),
                            child: FadeSlideIn(
                              child: _ShopCard(
                                shop: shop,
                                giftCount: gifts.length,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: FadeSlideIn(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.gutter,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 28),
                              if (shop.giftOptions.isNotEmpty) ...[
                                const _Heading('Gift extras'),
                                const SizedBox(height: 12),
                                _GiftOptions(options: shop.giftOptions),
                                const SizedBox(height: 28),
                              ],
                              if (about) ...[
                                const _Heading('About'),
                                const SizedBox(height: 12),
                                _About(shop: shop),
                                const SizedBox(height: 28),
                              ],
                              _Heading('Gifts', count: gifts.length),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (sorted.isEmpty)
                      const SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Icons.storefront_outlined,
                          title: 'Nothing on sale yet',
                          description:
                              'This shop has not published a gift yet.',
                        ),
                      )
                    else
                      // The grid pads itself to the page gutter.
                      GiftGrid(gifts: sorted, sliver: true, heroPrefix: 'shop'),
                    if (shop.returnsPolicy != null)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.gutter,
                          28,
                          AppTheme.gutter,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _Returns(policy: shop.returnsPolicy!),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              ),
              // Always on top, whatever is scrolled under it.
              Positioned(
                left: 12,
                top: top + 8,
                child: _CircleButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () =>
                      context.canPop() ? context.pop() : context.go('/'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The shop's own photo, or the brand colour with sparkles when it has none.
class _CoverPhoto extends StatelessWidget {
  const _CoverPhoto({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return const ColoredBox(
        color: AppColors.purple,
        child: Stack(
          children: [
            Positioned(
              right: 44,
              top: 70,
              child: Sparkle(size: 28, color: AppColors.teal),
            ),
            Positioned(
              left: 90,
              bottom: 60,
              child: Sparkle(size: 16, color: Colors.white),
            ),
            Positioned(
              right: 120,
              bottom: 44,
              child: Dot(size: 8, color: AppColors.teal),
            ),
          ],
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        AppNetworkImage(url: url!),
        // A flat shade keeps the back button readable on any photo.
        ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
      ],
    );
  }
}

/// A white round button, like the gift page's.
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              boxShadow: AppTheme.cardShadow,
            ),
            child: Icon(icon, size: 19, color: AppColors.foreground),
          ),
        ),
      ),
    );
  }
}

/// A plain section title in the app's poster type, with an optional count.
class _Heading extends StatelessWidget {
  const _Heading(this.title, {this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title.toUpperCase(), style: AppTypography.poster(20)),
        if (count != null && count! > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.purple,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The shop at a glance: photo, name, place, website and three facts.
class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop, required this.giftCount});

  final Shop shop;
  final int giftCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatar = shop.sellerImageUrl ?? shop.imageUrl;
    final days = shop.workingDays.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: avatar != null
                    ? AppNetworkImage(url: avatar, width: 68, height: 68)
                    : const SizedBox(
                        width: 68,
                        height: 68,
                        child: ColoredBox(
                          color: AppColors.accent,
                          child: Icon(
                            Icons.storefront_rounded,
                            size: 28,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            shop.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.poster(24),
                          ),
                        ),
                        if (shop.verified) ...[
                          const SizedBox(width: 6),
                          const Tooltip(
                            message: 'Verified business',
                            child: Icon(
                              Icons.verified_rounded,
                              size: 20,
                              color: AppColors.teal,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if ((shop.location ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 15,
                            color: AppColors.mutedForeground,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              shop.location!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (shop.website != null) ...[
                      const SizedBox(height: 4),
                      InkWell(
                        key: const Key('shop-website'),
                        onTap: () => _openWebsite(context, shop.website!),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.language_rounded,
                              size: 15,
                              color: AppColors.purple,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _host(shop.website!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.purple,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _Fact(
                    value: '$giftCount',
                    label: giftCount == 1 ? 'Gift' : 'Gifts',
                  ),
                ),
                VerticalDivider(width: 1, color: AppColors.border),
                Expanded(
                  child: _Fact(
                    value: days == 7
                        ? 'Daily'
                        : (days == 0 ? '-' : '$days days'),
                    label: 'Delivers',
                  ),
                ),
                VerticalDivider(width: 1, color: AppColors.border),
                Expanded(
                  child: _Fact(
                    value: shop.pickupEnabled ? 'Yes' : 'No',
                    label: 'Pickup',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _host(String url) {
    final host = Uri.tryParse(url)?.host ?? url;
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  static Future<void> _openWebsite(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the website.')),
      );
    }
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.poster(20),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// Extras the shop offers on a gift, as small tiles.
class _GiftOptions extends StatelessWidget {
  const _GiftOptions({required this.options});

  final List<String> options;

  static const _known = {
    'message': (Icons.mail_outline_rounded, 'Gift message', AppColors.purple),
    'wrapping': (Icons.redeem_rounded, 'Gift wrapping', AppColors.teal),
    'personalisation': (Icons.draw_rounded, 'Personalised', AppColors.star),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, option) in options.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (_known[option]?.$3 ?? AppColors.purple)
                          .withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _known[option]?.$1 ?? Icons.check_rounded,
                      size: 20,
                      color: _known[option]?.$3 ?? AppColors.purple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _known[option]?.$2 ?? _label(option),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The shop's description, folded when long, and what it sells.
class _About extends StatefulWidget {
  const _About({required this.shop});

  final Shop shop;

  @override
  State<_About> createState() => _AboutState();
}

class _AboutState extends State<_About> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = widget.shop.description?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (text.isNotEmpty) ...[
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            alignment: Alignment.topCenter,
            child: Text(
              text,
              maxLines: _open ? null : 4,
              overflow: _open ? null : TextOverflow.fade,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.foreground.withValues(alpha: 0.78),
                height: 1.55,
              ),
            ),
          ),
          if (text.length > 180)
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => setState(() => _open = !_open),
              child: Text(_open ? 'Show less' : 'Read more'),
            ),
        ],
        if (widget.shop.categories.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in widget.shop.categories)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    _label(c),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The shop's returns policy, folded to a few lines.
class _Returns extends StatefulWidget {
  const _Returns({required this.policy});

  final String policy;

  @override
  State<_Returns> createState() => _ReturnsState();
}

class _ReturnsState extends State<_Returns> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            leading: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.purple,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            title: Text('Returns policy', style: theme.textTheme.titleSmall),
            subtitle: Text(
              _open ? 'Tap to fold' : 'How this shop handles returns',
              style: theme.textTheme.bodySmall,
            ),
            trailing: Icon(
              _open
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
            ),
            onTap: () => setState(() => _open = !_open),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      widget.policy,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.foreground.withValues(alpha: 0.78),
                        height: 1.5,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// "flowers-plants" → "Flowers plants".
String _label(String raw) {
  final words = raw.replaceAll(RegExp(r'[-_]+'), ' ').trim();
  if (words.isEmpty) return raw;
  return words[0].toUpperCase() + words.substring(1);
}

class _Missing extends StatelessWidget {
  const _Missing({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: EmptyState(
          icon: Icons.storefront_outlined,
          title: 'Shop not found',
          description: 'It may have closed, or the connection dropped.',
          action: FilledButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ),
      ),
    );
  }
}
