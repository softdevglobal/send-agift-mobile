import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_shell.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/cart/presentation/screens/cart_screen.dart';
import '../../features/cart/presentation/screens/checkout_screen.dart';
import '../../features/games/presentation/game_definitions.dart';
import '../../features/games/presentation/screens/competition_screen.dart';
import '../../features/games/presentation/screens/chance_play_screen.dart';
import '../../features/games/presentation/screens/points_screen.dart';
import '../../features/games/presentation/screens/game_leaderboard_screen.dart';
import '../../features/games/presentation/screens/game_play_screen.dart';
import '../../features/games/presentation/screens/games_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/messages/presentation/screens/chat_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import '../../features/orders/presentation/screens/order_list_screen.dart';
import '../../features/reviews/presentation/screens/my_reviews_screen.dart';
import '../../features/products/presentation/screens/explore_screen.dart';
import '../../features/products/presentation/screens/gift_detail_screen.dart';
import '../../features/profile/presentation/screens/account_screen.dart';
import '../../features/profile/presentation/screens/addresses_screen.dart';
import '../../features/profile/presentation/screens/help_centre_screen.dart';
import '../../features/profile/presentation/screens/recipient_detail_screen.dart';
import '../../features/profile/presentation/screens/recipients_screen.dart';
import '../../features/profile/presentation/screens/terms_screen.dart';
import '../../features/reels/presentation/screens/reels_screen.dart';
import '../../features/saved/presentation/screens/saved_screen.dart';

class AppRoutes {
  AppRoutes._();

  // Tabs
  static const home = '/';
  static const explore = '/explore';
  static const reels = '/reels';
  static const saved = '/saved';
  static const account = '/account';

  // Pushed screens
  static const gift = '/gift';
  // Not a tab: opens as a right-side panel over whatever's on screen.
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orders = '/orders';
  static const login = '/login';
  static const register = '/register';
  static const messages = '/messages';
  static const reviews = '/reviews';
  static const games = '/games';
  static const competitions = '/competitions';

  /// The customer's SendAgift Points balance and history.
  static const points = '/points';

  static const addresses = '/addresses';
  static const recipients = '/recipients';
  static const help = '/help';
  static const terms = '/terms';

  static String recipientPath(String id) => '$recipients/$id';

  static String chatPath(String conversationId) => '$messages/$conversationId';

  /// Opens one game. The slug picks the engine, so a new game ships without a
  /// new route.
  static String gamePath(String slug) => '$games/$slug';

  /// The practice leaderboard for one game.
  static String gameLeaderboardPath(String slug) => '$games/$slug/leaderboard';

  static String competitionPath(String id) => '$competitions/$id';

  /// An official attempt. The game travels with the route so the right
  /// engine opens straight away.
  static String competitionPlayPath(String id, String slug) =>
      '$competitions/$id/play?game=${Uri.encodeComponent(slug)}';

  /// One play of a chance game (spin, scratch, treasure, instant win, draw).
  static String competitionChancePath(String id) => '$competitions/$id/chance';

  /// Asks a shop about a gift — reopens the customer's existing thread about
  /// it when there is one, otherwise the thread starts on the first send.
  static String askAboutGiftPath(String productId) =>
      '$messages/new?product=${Uri.encodeComponent(productId)}';

  /// Messages the shop about one order item — reopens that item's thread when
  /// there is one. [productId] only labels the chat before it exists.
  static String askAboutOrderItemPath(String orderItemId, {String? productId}) {
    final query = {
      'orderItem': orderItemId,
      if (productId != null && productId.isNotEmpty) 'product': productId,
    };
    return Uri(path: '$messages/new', queryParameters: query).toString();
  }

  static String orderDetailPath(String orderId) => '$orders/$orderId';

  /// The hero tag travels with the route so the detail screen animates from
  /// whichever surface the card was tapped on.
  static String giftDetailPath(String id, {String? heroTag}) {
    if (heroTag == null) return '$gift/$id';
    return '$gift/$id?hero=${Uri.encodeComponent(heroTag)}';
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Fade-and-rise transition for every pushed (non-tab) route, so moving
/// deeper into the app — a gift, checkout, sign-in — feels like a step
/// forward rather than the platform's default hard slide.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// A game opens like its own window: it zooms up from the tile and takes over
/// the whole screen.
CustomTransitionPage<void> _gameWindowPage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.86, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Slide-in panel from the right, dimming (rather than replacing) whatever
/// tab is behind it — the cart is a quick check, not a new destination.
CustomTransitionPage<void> _rightSheetPage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    opaque: false,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    barrierLabel: 'Close',
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return Align(
        alignment: Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: 0.8,
          heightFactor: 1,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: Material(
              elevation: 16,
              shadowColor: Colors.black,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// The app opens straight onto the storefront — browsing, search, cart and
/// saved gifts all work without an account, so there is no auth redirect here.
/// Sign-in is requested only at checkout and for order history.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.explore,
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
          // Centre tab: the raised button in the nav bar.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reels,
                builder: (context, state) => const ReelsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.saved,
                builder: (context, state) => const SavedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.account,
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.cart,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _rightSheetPage(state, const CartScreen()),
      ),
      GoRoute(
        path: '${AppRoutes.gift}/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          GiftDetailScreen(
            giftId: state.pathParameters['id'] ?? '',
            heroTag: state.uri.queryParameters['hero'],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const CheckoutScreen()),
      ),
      GoRoute(
        path: AppRoutes.orders,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const OrderListScreen()),
      ),
      GoRoute(
        path: '${AppRoutes.orders}/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          OrderDetailScreen(orderId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: AppRoutes.reviews,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const MyReviewsScreen()),
      ),
      GoRoute(
        path: AppRoutes.messages,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const MessagesScreen()),
      ),
      GoRoute(
        path: '${AppRoutes.messages}/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _fadePage(
            state,
            id == 'new'
                ? ChatScreen(
                    productId: state.uri.queryParameters['product'],
                    orderItemId: state.uri.queryParameters['orderItem'],
                  )
                : ChatScreen(conversationId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.games,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(state, const GamesScreen()),
      ),
      GoRoute(
        path: '${AppRoutes.games}/:slug',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final definition =
              gameDefinitions[state.pathParameters['slug'] ?? ''];
          // A game this build of the app has no engine for falls back to
          // the list rather than a broken screen.
          if (definition == null) {
            return _fadePage(state, const GamesScreen());
          }
          return _gameWindowPage(state, GamePlayScreen(definition: definition));
        },
      ),
      GoRoute(
        path: '${AppRoutes.games}/:slug/leaderboard',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          GameLeaderboardScreen(slug: state.pathParameters['slug'] ?? ''),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.competitions}/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          CompetitionScreen(competitionId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.competitions}/:id/play',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final definition =
              gameDefinitions[state.uri.queryParameters['game'] ?? ''];
          if (definition == null) {
            return _fadePage(state, CompetitionScreen(competitionId: id));
          }
          return _gameWindowPage(
            state,
            GamePlayScreen(definition: definition, competitionId: id),
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.competitions}/:id/chance',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          ChancePlayScreen(competitionId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: AppRoutes.points,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(state, const PointsScreen()),
      ),
      GoRoute(
        path: AppRoutes.addresses,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const AddressesScreen()),
      ),
      GoRoute(
        path: AppRoutes.recipients,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const RecipientsScreen()),
      ),
      GoRoute(
        path: '${AppRoutes.recipients}/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          RecipientDetailScreen(recipientId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: AppRoutes.help,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const HelpCentreScreen()),
      ),
      GoRoute(
        path: AppRoutes.terms,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(state, const TermsScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.register,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const RegisterScreen()),
      ),
    ],
  );
});
