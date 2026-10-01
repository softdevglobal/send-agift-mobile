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
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../auth/data/auth_controller.dart';
import '../../../games/data/games_providers.dart';
import '../../../messages/data/messages_providers.dart';
import '../../../orders/data/orders_repository.dart';
import '../../../saved/data/saved_controller.dart';

/// Customer account hub. The mobile app is customer-only — there are no
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
                        value: orderCount?.toString() ?? '—',
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
                        value: points == null ? '—' : _compact(points),
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
              child: _MenuSection(
                title: 'Shopping',
                items: [
                  _MenuItem(
                    icon: Icons.receipt_long_outlined,
                    color: AppColors.primary,
                    label: 'My orders',
                    subtitle: 'Track deliveries and view history',
                    onTap: () => context.push(AppRoutes.orders),
                  ),
                  _MenuItem(
                    icon: Icons.stars_rounded,
                    color: AppColors.purple,
                    label: 'My points',
                    subtitle: 'Balance and points history',
                    onTap: () => signedInOnly(AppRoutes.points),
                  ),
                  _MenuItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    color: AppColors.teal,
                    label: 'Messages',
                    subtitle: 'Chat with shops about gifts',
                    badge: unreadMessages,
                    onTap: () => signedInOnly(AppRoutes.messages),
                  ),
                  _MenuItem(
                    icon: Icons.star_outline_rounded,
                    color: AppColors.star,
                    label: 'My reviews',
                    subtitle: 'Ratings you left on delivered gifts',
                    onTap: () => signedInOnly(AppRoutes.reviews),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FadeSlideIn(
              delay: const Duration(milliseconds: 130),
              child: _MenuSection(
                title: 'Gifting',
                items: [
                  _MenuItem(
                    icon: Icons.favorite_border_rounded,
                    color: const Color(0xFFE0457B),
                    label: 'Saved gifts',
                    subtitle: savedCount == 0
                        ? 'Nothing saved yet'
                        : '$savedCount saved',
                    onTap: () => context.go(AppRoutes.saved),
                  ),
                  _MenuItem(
                    icon: Icons.people_alt_outlined,
                    color: AppColors.purple,
                    label: 'Recipients',
                    subtitle: 'People you send gifts to',
                    onTap: () => signedInOnly(AppRoutes.recipients),
                  ),
                  _MenuItem(
                    icon: Icons.location_on_outlined,
                    color: AppColors.accentForeground,
                    label: 'Addresses',
                    subtitle: 'Delivery and return addresses',
                    onTap: () => signedInOnly(AppRoutes.addresses),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
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
                      icon: Icons.logout_rounded,
                      color: AppColors.destructive,
                      label: 'Sign out',
                      destructive: true,
                      onTap: () => _confirmSignOut(context, ref),
                    ),
                ],
              ),
            ),
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
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          "You'll need to sign in again to check out, track orders, or "
          'message shops.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
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
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.brandGradient,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.purple.withValues(alpha: 0.28),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
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
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
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
                    gradient: LinearGradient(
                      colors: [AppColors.teal, Colors.white],
                    ),
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
          child: AppPanel(
            padding: const EdgeInsets.symmetric(vertical: 6),
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
    this.badge = 0,
    this.destructive = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? subtitle;
  final int badge;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontSize: 14.5,
      color: destructive ? AppColors.destructive : null,
    );
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
            if (badge > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.purple,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge > 99 ? '99+ new' : '$badge new',
                  style: const TextStyle(
                    fontFamily: AppTypography.sansFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.purpleForeground,
                  ),
                ),
              ),
            ],
            if (!destructive) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.mutedForeground,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
