import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../auth/data/auth_controller.dart';
import '../../../games/data/games_providers.dart';
import '../../../messages/data/messages_providers.dart';
import '../../../orders/data/orders_repository.dart';
import '../../../saved/data/saved_controller.dart';
import '../widgets/sign_out_sheet.dart';

/// Customer account hub. The mobile app is customer-only. There are no
/// seller or admin surfaces here; those stay on the web app.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final savedCount = ref.watch(savedGiftsProvider).length;
    final unreadMessages = ref.watch(unreadMessagesProvider);
    // Only signed-in customers have a wallet or orders to load.
    final points = auth.isSignedIn
        ? ref.watch(pointsWalletProvider).whenOrNull(data: (w) => w.balance)
        : null;
    final orderCount = auth.isSignedIn
        ? ref.watch(customerOrdersProvider).whenOrNull(data: (o) => o.length)
        : null;

    void signedInOnly(String route) =>
        context.push(auth.isSignedIn ? route : AppRoutes.login);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                10,
                AppTheme.gutter,
                18,
              ),
              child: Text('Account', style: AppTypography.display(28)),
            ),
            FadeSlideIn(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.gutter,
                ),
                child: auth.isSignedIn
                    ? _ProfileHero(
                        name: auth.displayName,
                        email: auth.email,
                        imageUrl: auth.imageUrl,
                        points: points,
                        onPointsTap: () => context.push(AppRoutes.points),
                        onEdit: () => context.push(AppRoutes.editProfile),
                      )
                    : const _GuestHero(),
              ),
            ),
            if (auth.isSignedIn && auth.passwordChangeRequired) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.gutter,
                ),
                child: _TemporaryPasswordPrompt(
                  onTap: () => context.push(AppRoutes.changePassword),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.gutter,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.receipt_long_rounded,
                        value: orderCount?.toString() ?? '-',
                        label: 'Orders',
                        tint: AppColors.categoryTints[0],
                        iconColor: AppColors.primary,
                        onTap: () => context.push(AppRoutes.orders),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.stars_rounded,
                        value: points == null ? '-' : _compact(points),
                        label: 'Points',
                        tint: AppColors.categoryTints[1],
                        iconColor: AppColors.purple,
                        onTap: () => signedInOnly(AppRoutes.points),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.favorite_rounded,
                        value: '$savedCount',
                        label: 'Saved',
                        tint: AppColors.categoryTints[2],
                        iconColor: AppColors.accentForeground,
                        onTap: () => context.go(AppRoutes.saved),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            FadeSlideIn(
              delay: const Duration(milliseconds: 90),
              child: _ShortcutSection(
                title: 'Shopping',
                items: [
                  _Shortcut(
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    tint: AppColors.categoryTints[0],
                    label: 'My orders',
                    subtitle: 'Track deliveries and history',
                    onTap: () => context.push(AppRoutes.orders),
                  ),
                  _Shortcut(
                    icon: Icons.stars_rounded,
                    color: AppColors.purple,
                    tint: AppColors.categoryTints[1],
                    label: 'My points',
                    subtitle: 'Balance and history',
                    onTap: () => signedInOnly(AppRoutes.points),
                  ),
                  _Shortcut(
                    icon: Icons.chat_bubble_rounded,
                    color: AppColors.accentForeground,
                    tint: AppColors.categoryTints[2],
                    label: 'Messages',
                    subtitle: 'Chat with shops',
                    badge: unreadMessages,
                    onTap: () => signedInOnly(AppRoutes.messages),
                  ),
                  _Shortcut(
                    icon: Icons.star_rounded,
                    color: const Color(0xFFB7791F),
                    tint: const Color(0xFFFDF3E1),
                    label: 'My reviews',
                    subtitle: 'Ratings you left',
                    onTap: () => signedInOnly(AppRoutes.reviews),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FadeSlideIn(
              delay: const Duration(milliseconds: 130),
              child: _ShortcutSection(
                title: 'Gifting',
                items: [
                  _Shortcut(
                    icon: Icons.card_giftcard_rounded,
                    color: const Color(0xFFDB2777),
                    tint: const Color(0xFFFCE7F1),
                    label: 'Gifts received',
                    subtitle: 'Gifts sent to you. Review them here',
                    onTap: () => signedInOnly(AppRoutes.receivedGifts),
                  ),
                  _Shortcut(
                    icon: Icons.people_alt_rounded,
                    color: AppColors.purple,
                    tint: AppColors.categoryTints[5],
                    label: 'Recipients',
                    subtitle: 'People you gift',
                    onTap: () => signedInOnly(AppRoutes.recipients),
                  ),
                  _Shortcut(
                    icon: Icons.location_on_rounded,
                    color: AppColors.accentForeground,
                    tint: AppColors.categoryTints[4],
                    label: 'Addresses',
                    subtitle: 'Delivery and return',
                    onTap: () => signedInOnly(AppRoutes.addresses),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FadeSlideIn(
              delay: const Duration(milliseconds: 170),
              child: _MenuSection(
                title: 'Support',
                items: [
                  _MenuItem(
                    icon: Icons.headset_mic_outlined,
                    color: AppColors.primary,
                    label: 'Help centre',
                    subtitle: 'Orders, points, and competitions',
                    onTap: () => context.push(AppRoutes.help),
                  ),
                  _MenuItem(
                    icon: Icons.description_outlined,
                    color: AppColors.mutedForeground,
                    label: 'Terms & privacy',
                    onTap: () => context.push(AppRoutes.terms),
                  ),
                  if (auth.isSignedIn)
                    _MenuItem(
                      icon: Icons.key_rounded,
                      color: AppColors.primary,
                      label: 'Change password',
                      onTap: () => context.push(AppRoutes.changePassword),
                    ),
                ],
              ),
            ),
            if (auth.isSignedIn) ...[
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.gutter,
                  ),
                  child: _SignOutButton(
                    onTap: () => _confirmSignOut(
                      context,
                      ref,
                      points: points,
                      savedCount: savedCount,
                      orderCount: orderCount,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 1250 → "1.2k", so a large balance still fits a stat tile.
  static String _compact(int value) {
    if (value < 10000) return '$value';
    if (value < 1000000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '${(value / 1000000).toStringAsFixed(1)}m';
  }

  static Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref, {
    required int? points,
    required int savedCount,
    required int? orderCount,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final signedOut = await showSignOutSheet(
      context,
      // The real name only: displayName falls back to the email address,
      // which would make an odd greeting.
      name: ref.read(authProvider).customer?['display_name'] as String?,
      points: points,
      savedCount: savedCount,
      orderCount: orderCount,
      onSignOut: () => ref.read(authProvider.notifier).logout(),
    );
    if (signedOut) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Signed out. See you soon!')),
      );
    }
  }
}

/// Navy-to-violet card shared by the signed-in and guest headers, with soft
/// ribbon-like circles drifting off the corner for depth.
class _HeroBackground extends StatelessWidget {
  const _HeroBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius2xl),
      child: Container(
        decoration: BoxDecoration(color: AppColors.foreground),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -50,
              child: _Glow(size: 170, color: AppColors.teal, alpha: 0.30),
            ),
            Positioned(
              right: 50,
              bottom: -70,
              child: _Glow(size: 140, color: Colors.white, alpha: 0.10),
            ),
            Positioned(
              right: 18,
              top: 16,
              child: Icon(
                Icons.card_giftcard_rounded,
                size: 64,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Padding(padding: const EdgeInsets.all(20), child: child),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color, required this.alpha});

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // A flat translucent disc; no colour fade.
        color: color.withValues(alpha: alpha * 0.5),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.email,
    required this.points,
    required this.onPointsTap,
    required this.onEdit,
    this.imageUrl,
  });

  final String name;
  final String? email;
  final String? imageUrl;
  final int? points;
  final VoidCallback onPointsTap;
  final VoidCallback onEdit;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
  }

  String get _firstName {
    final first = name.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'there' : first;
  }

  @override
  Widget build(BuildContext context) {
    return _HeroBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Teal-to-white ring around the photo or initials, echoing
              // the plane. Tapping it edits the profile.
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.teal,
                  ),
                  child: Container(
                    height: 58,
                    width: 58,
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: imageUrl != null
                        ? AppNetworkImage(url: imageUrl!, width: 58, height: 58)
                        : Text(
                            _initials,
                            style: AppTypography.display(
                              22,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, $_firstName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(
                        22,
                        color: AppColors.primaryForeground,
                      ),
                    ),
                    if (email != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                key: const Key('account-edit-profile'),
                tooltip: 'Edit profile',
                onPressed: onEdit,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.edit_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 18),
          PressableScale(
            onTap: onPointsTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Row(
                children: [
                  Container(
                    height: 32,
                    width: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.star,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: points?.toString() ?? '…',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(text: '  points to spend'),
                        ],
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primaryForeground,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Guest header. Reinforces that an account is optional and says exactly what
/// signing in adds.
class _GuestHero extends StatelessWidget {
  const _GuestHero();

  @override
  Widget build(BuildContext context) {
    return _HeroBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "You're browsing as a guest",
            style: AppTypography.display(
              21,
              color: AppColors.primaryForeground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search, save gifts, and build a cart without an account. Sign in '
            'to check out, track deliveries, and earn points.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push(AppRoutes.login),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                  ),
                  child: const Text('Sign in'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push(AppRoutes.register),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Text('Register'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.tint,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color tint;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: AppColors.boxBorder, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 30,
              width: 30,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(value, style: AppTypography.display(22)),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// The website's box card: a soft ash outline, flat, no shadow.
class _InkPanel extends StatelessWidget {
  const _InkPanel({required this.child, this.color = AppColors.surface});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppColors.boxBorder, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: Material(color: Colors.transparent, child: child),
      ),
    );
  }
}

class _Shortcut {
  const _Shortcut({
    required this.icon,
    required this.color,
    required this.tint,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final Color color;
  final Color tint;
  final String label;
  final String subtitle;
  final int badge;
  final VoidCallback onTap;
}

/// A titled group of shortcut tiles, two to a row. With an odd count the
/// first tile runs the full width, so the grid never ends on a lone half.
class _ShortcutSection extends StatelessWidget {
  const _ShortcutSection({required this.title, required this.items});

  final String title;
  final List<_Shortcut> items;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final wide = items.length.isOdd ? items.first : null;
    final rest = wide == null ? items : items.skip(1).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(title.toUpperCase(), style: AppTypography.eyebrow),
          ),
          if (wide != null) ...[
            _ShortcutTile(item: wide, wide: true),
            if (rest.isNotEmpty) const SizedBox(height: _gap),
          ],
          for (var i = 0; i < rest.length; i += 2) ...[
            if (i > 0) const SizedBox(height: _gap),
            // IntrinsicHeight keeps both tiles in a row the same height when
            // one subtitle wraps and the other does not.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _ShortcutTile(item: rest[i])),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: i + 1 < rest.length
                        ? _ShortcutTile(item: rest[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.item, this.wide = false});

  final _Shortcut item;

  /// Lays the icon beside the text instead of above it.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Icon(item.icon, size: 20, color: item.color),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          item.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
    final arrow = Container(
      height: 26,
      width: 26,
      decoration: const BoxDecoration(
        color: AppColors.foreground,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.arrow_forward_rounded,
        size: 15,
        color: Colors.white,
      ),
    );

    return PressableScale(
      onTap: item.onTap,
      child: _InkPanel(
        color: item.tint,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: wide
                  ? Row(
                      children: [
                        icon,
                        const SizedBox(width: 14),
                        Expanded(child: text),
                        const SizedBox(width: 10),
                        arrow,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [icon, const Spacer(), arrow],
                        ),
                        const SizedBox(height: 14),
                        text,
                      ],
                    ),
            ),
            if (item.badge > 0)
              Positioned(
                top: 10,
                left: 42,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.purple,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    item.badge > 99 ? '99+' : '${item.badge}',
                    style: const TextStyle(
                      fontFamily: AppTypography.sansFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.purpleForeground,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Box-template button, as in the game menus: crisp corners, white with
    // an ash outline, and the warning colour only on the label.
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: AppTheme.box(),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, size: 19, color: AppColors.destructive),
            SizedBox(width: 8),
            Text(
              'Sign out',
              style: TextStyle(
                fontFamily: AppTypography.sansFamily,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.destructive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.items});

  final String title;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter + 4,
            0,
            AppTheme.gutter,
            10,
          ),
          child: Text(title.toUpperCase(), style: AppTypography.eyebrow),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
          child: _InkPanel(
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i != items.length - 1)
                    const Padding(
                      padding: EdgeInsets.only(left: 70, right: 16),
                      child: Divider(height: 1),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontSize: 14.5);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: labelStyle),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown while a gift recipient is still on the temporary password their
/// gift email gave them.
class _TemporaryPasswordPrompt extends StatelessWidget {
  const _TemporaryPasswordPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF7E6),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        key: const Key('temporary-password-prompt'),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: const Color(0xFFFCD34D)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFFB45309)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You're using a temporary password",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF78350F),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Set your own so only you can get into your account.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Color(0xFFB45309)),
            ],
          ),
        ),
      ),
    );
  }
}
