import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_bottom_nav.dart';
import '../features/messages/data/messages_providers.dart';
import '../features/reels/data/reels_providers.dart';
import '../features/saved/data/saved_controller.dart';

/// Scaffold for the five customer tabs, using the floating pill nav bar.
///
/// Reels sits in the middle as the raised button. It is the most-swiped
/// surface once someone is browsing, so it gets the spot the thumb reaches
/// first.
///
/// Cart isn't a tab: it opens as a right-side panel over whatever tab is
/// showing (from the home top bar, or a "View cart" prompt), so it never
/// needs its own place in the stack.
class AppShell extends ConsumerWidget {
  /// Reels is the branch at the centre of the bar.
  static const int _reelsBranch = 2;

  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedCount = ref.watch(savedGiftsProvider).length;
    // Watching this keeps the inbox polling, so a shop's reply shows on the
    // Account tab without the customer having to open Messages.
    final unreadMessages = ref.watch(unreadMessagesProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        onChanged: (index) {
          // The reels branch stays alive in the shell's stack, so its view
          // counts would otherwise show whatever they were when the tab was
          // first opened. Listing reels does not count a view, so this only
          // refreshes the numbers.
          if (index == _reelsBranch) {
            ref.read(reelFeedProvider.notifier).refreshViewCounts();
          }
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        items: [
          const AppBottomNavItem(icon: Icons.home_rounded, label: 'Home'),
          const AppBottomNavItem(icon: Icons.search_rounded, label: 'Explore'),
          const AppBottomNavItem(
            icon: Icons.movie_filter_rounded,
            label: 'Reels',
            orb: true,
          ),
          AppBottomNavItem(
            icon: Icons.favorite_rounded,
            label: 'Saved',
            badgeCount: savedCount,
          ),
          AppBottomNavItem(
            icon: Icons.person_rounded,
            label: 'Account',
            badgeCount: unreadMessages,
          ),
        ],
      ),
    );
  }
}
