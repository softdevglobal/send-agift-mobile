import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/core/widgets/app_bottom_nav.dart';
import 'package:send_agift_mobile/features/products/data/catalog_providers.dart';
import 'package:send_agift_mobile/features/products/data/sample_gifts.dart';
import 'package:send_agift_mobile/app/app.dart';
import 'package:send_agift_mobile/core/errors/app_exception.dart';
import 'package:send_agift_mobile/features/auth/data/auth_controller.dart';
import 'package:send_agift_mobile/features/auth/data/auth_repository.dart';
import 'package:send_agift_mobile/features/reels/data/reel_social_repository.dart';
import 'package:send_agift_mobile/features/reels/data/reels_providers.dart';
import 'package:send_agift_mobile/features/reels/data/reels_repository.dart';
import 'package:send_agift_mobile/features/reels/domain/reel.dart';
import 'package:send_agift_mobile/features/reels/domain/reel_social.dart';
import 'package:send_agift_mobile/features/reels/presentation/screens/reels_screen.dart';

/// The reels screen reads who is signed in. The real session is built on an
/// API client that reads dotenv, which tests do not load, so the screen runs
/// against a fake one. A guest unless [customer] is given.
Override _auth({Map<String, dynamic>? customer}) => authProvider
    .overrideWith((ref) => AuthController(_FakeAuthRepository(customer)));

const _navItems = [
  AppBottomNavItem(icon: Icons.home_rounded, label: 'Home'),
  AppBottomNavItem(icon: Icons.search_rounded, label: 'Explore'),
  AppBottomNavItem(
    icon: Icons.movie_filter_rounded,
    label: 'Reels',
    orb: true,
  ),
  AppBottomNavItem(icon: Icons.favorite_rounded, label: 'Saved'),
  AppBottomNavItem(icon: Icons.person_rounded, label: 'Account'),
];

Widget _navHarness({required int currentIndex, required ValueChanged<int> onChanged}) {
  return MaterialApp(
    home: Scaffold(
      bottomNavigationBar: AppBottomNav(
        currentIndex: currentIndex,
        onChanged: onChanged,
        items: _navItems,
      ),
    ),
  );
}

void main() {
  testWidgets('the centre orb renders and reports its own taps',
      (tester) async {
    var tapped = -1;

    await tester.pumpWidget(
      _navHarness(currentIndex: 0, onChanged: (i) => tapped = i),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.movie_filter_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.movie_filter_rounded));
    expect(tapped, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('five tabs fit a narrow phone', (tester) async {
    // The row of tabs is measured inside the bar's padding; get that wrong and
    // the fifth slot overflows.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_navHarness(currentIndex: 2, onChanged: (_) {}));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the orb stays centred whichever tab is selected',
      (tester) async {
    late Rect atHome;
    late Rect atSaved;

    for (final index in [0, 3]) {
      await tester.pumpWidget(_navHarness(currentIndex: index, onChanged: (_) {}));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byIcon(Icons.movie_filter_rounded));
      if (index == 0) {
        atHome = rect;
      } else {
        atSaved = rect;
      }
    }

    // The orb is the bar's anchor: an expanding label on either side must not
    // push it off centre, or a thumb aimed at it lands on a neighbour.
    expect(atSaved.center.dx, closeTo(atHome.center.dx, 0.5));
    expect(atHome.center.dx, closeTo(400, 1));
  });

  testWidgets('the bar draws no wording, but still names its tabs',
      (tester) async {
    await tester.pumpWidget(_navHarness(currentIndex: 3, onChanged: (_) {}));
    await tester.pumpAndSettle();

    for (final label in ['Home', 'Explore', 'Reels', 'Saved', 'Account']) {
      expect(find.text(label), findsNothing);
    }

    // Gone from the surface, still there for screen readers.
    expect(
      tester.getSemantics(find.byIcon(Icons.favorite_rounded)).label,
      'Saved',
    );
  });

  testWidgets('a shoppable reel offers to send its product as a gift',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reelsRepositoryProvider.overrideWithValue(_FakeReelsRepository()),
          _auth(),
        ],
        child: const MaterialApp(home: ReelsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Reels'), findsOneWidget);
    expect(find.text('Gift Box USA'), findsOneWidget);
    expect(find.text('Bay Area Gifts'), findsOneWidget);
    expect(find.text('Send as a gift'), findsOneWidget);
    expect(find.text('USD 42.00'), findsOneWidget);
  });

  testWidgets('a shop promo reel with no product shows no gift CTA',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reelsRepositoryProvider
              .overrideWithValue(_FakeReelsRepository(tagProduct: false)),
          _auth(),
        ],
        child: const MaterialApp(home: ReelsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Nothing to buy on a promo reel, so the CTA has to stay off rather than
    // pointing at a product that isn't there.
    expect(find.text('Bay Area Gifts'), findsOneWidget);
    expect(find.text('Send as a gift'), findsNothing);
  });

  testWidgets('opening the feed counts a view for the reel on screen',
      (tester) async {
    final repository = _FakeReelsRepository()
      ..reelsOverride = const [
        Reel(id: 'reel-1', shopName: 'Bay Area Gifts', imageUrl: 'x'),
        Reel(id: 'reel-2', shopName: 'Bay Area Gifts', imageUrl: 'y'),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reelsRepositoryProvider.overrideWithValue(repository),
          _auth(),
        ],
        child: const MaterialApp(home: ReelsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Only the reel actually on screen is counted. Not every reel in the
    // page of results the API returned.
    expect(repository.viewed, ['reel-1']);
  });

  testWidgets('a guest sees likes and comments but is asked to sign in to like',
      (tester) async {
    final social = _FakeSocialRepository();
    final repository = _FakeReelsRepository()
      ..reelsOverride = const [
        Reel(
          id: 'reel-1',
          shopName: 'Bay Area Gifts',
          imageUrl: 'x',
          likeCount: 3,
          commentCount: 2,
          recentLikers: [ReelLiker(type: 'customer', displayName: 'Aisha')],
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reelsRepositoryProvider.overrideWithValue(repository),
          reelSocialRepositoryProvider.overrideWithValue(social),
          _auth(),
        ],
        child: const MaterialApp(home: ReelsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Counts and names are public. No account needed to read them.
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Liked by Aisha and 2 others'), findsOneWidget);
    expect(find.text('View all 2 comments'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();

    // Liking is for signed-in customers: nothing reaches the API.
    expect(find.text('Sign in to like reels.'), findsOneWidget);
    expect(social.liked, isEmpty);
  });

  test('a signed-in like fills the heart and takes the count from the API',
      () async {
    final social = _FakeSocialRepository()..serverLikeCount = 8;
    final repository = _FakeReelsRepository()
      ..reelsOverride = const [
        Reel(id: 'reel-1', shopName: 'Shop', imageUrl: 'x', likeCount: 7),
      ];
    final container = ProviderContainer(
      overrides: [
        reelsRepositoryProvider.overrideWithValue(repository),
        reelSocialRepositoryProvider.overrideWithValue(social),
      ],
    );
    addTearDown(container.dispose);

    final feed = container.read(reelFeedProvider.notifier);
    await feed.refresh();
    await feed.toggleLike('reel-1');

    final reel = container.read(reelFeedProvider).value!.reels.single;
    expect(social.liked, ['reel-1']);
    expect(reel.likedByMe, isTrue);
    // The server's number wins over the optimistic +1.
    expect(reel.likeCount, 8);
    expect(reel.likersLine, 'Liked by Aisha and 7 others');
  });

  test('a like the API rejects puts the heart back', () async {
    final social = _FakeSocialRepository()..failLikes = true;
    final repository = _FakeReelsRepository()
      ..reelsOverride = const [
        Reel(id: 'reel-1', shopName: 'Shop', imageUrl: 'x', likeCount: 7),
      ];
    final container = ProviderContainer(
      overrides: [
        reelsRepositoryProvider.overrideWithValue(repository),
        reelSocialRepositoryProvider.overrideWithValue(social),
      ],
    );
    addTearDown(container.dispose);

    final feed = container.read(reelFeedProvider.notifier);
    await feed.refresh();
    await expectLater(feed.toggleLike('reel-1'), throwsA(isA<AppException>()));

    final reel = container.read(reelFeedProvider).value!.reels.single;
    expect(reel.likedByMe, isFalse);
    expect(reel.likeCount, 7);
  });

  test('refreshing counts re-reads the feed without counting views', () async {
    final repository = _FakeReelsRepository()
      ..reelsOverride = const [
        Reel(id: 'reel-1', shopName: 'Shop', imageUrl: 'x', viewCount: 1),
      ];
    final container = ProviderContainer(
      overrides: [reelsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    // Let the first page land.
    await container.read(reelFeedProvider.notifier).refresh();
    expect(container.read(reelFeedProvider).value!.reels.first.viewCount, 1);

    // Someone else watches it: the API's count moves on without us.
    repository.reelsOverride = const [
      Reel(id: 'reel-1', shopName: 'Shop', imageUrl: 'x', viewCount: 9),
    ];
    await container.read(reelFeedProvider.notifier).refreshViewCounts();

    expect(container.read(reelFeedProvider).value!.reels.first.viewCount, 9);
    // Listing reels does not increment anything, so nothing was counted.
    expect(repository.viewed, isEmpty);
  });

  testWidgets('an empty feed says so instead of showing a blank page',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reelsRepositoryProvider
              .overrideWithValue(_FakeReelsRepository(reels: const [])),
        ],
        child: const MaterialApp(home: ReelsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No reels yet'), findsOneWidget);
  });

  testWidgets('each tab opens its own page, reels included', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogProvider.overrideWith((ref) async => sampleGifts),
          reelsRepositoryProvider.overrideWithValue(_FakeReelsRepository()),
        ],
        child: const SendAGiftApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // The app opens on the storefront, not on a tab further along the bar.
    expect(find.text('Discover the best gifts for every moment.'), findsOneWidget);

    // Scoped to the bar: the same glyphs (search, heart) also appear inside
    // the pages themselves.
    Future<void> tapTab(IconData icon) async {
      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.byIcon(icon),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await tapTab(Icons.search_rounded);
    // Explore shows the heading and the "all" filter chip, hence widgets.
    expect(find.text('All gifts'), findsWidgets);

    await tapTab(Icons.movie_filter_rounded);
    expect(find.text('Reels'), findsOneWidget);

    await tapTab(Icons.favorite_rounded);
    expect(find.text('Saved gifts'), findsOneWidget);

    // Account is left out: it reads config through dotenv, which isn't
    // loaded in tests.
  });
}

/// A session with no API behind it: signed out, or signed in as [customer].
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.customer);

  final Map<String, dynamic>? customer;

  @override
  Future<bool> hasSession() async => customer != null;

  @override
  Future<Map<String, dynamic>?> me() async => customer;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Likes without a backend. Anything a test does not drive is left
/// unimplemented, so an unexpected call fails loudly.
class _FakeSocialRepository implements ReelSocialRepository {
  final liked = <String>[];
  int serverLikeCount = 4;
  bool failLikes = false;

  @override
  Future<ReelLikeResult> like(String reelId) async {
    if (failLikes) throw const AppException('Try again', statusCode: 500);
    liked.add(reelId);
    return ReelLikeResult(liked: true, likeCount: serverLikeCount);
  }

  @override
  Future<ReelLikes> getLikes(String reelId) async {
    return ReelLikes(
      likeCount: serverLikeCount,
      likedByRequester: liked.contains(reelId),
      recentLikers: const [ReelLiker(type: 'customer', displayName: 'Aisha')],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stands in for the API so the feed can be driven without a backend.
class _FakeReelsRepository implements ReelsRepository {
  _FakeReelsRepository({this.tagProduct = true, List<Reel>? reels})
      : _reels = reels;

  final bool tagProduct;
  final List<Reel>? _reels;

  /// Set to drive the feed with a specific list after construction.
  List<Reel>? reelsOverride;

  @override
  Future<ReelPage> loadFeed({String? cursor, String scope = 'all'}) async {
    return ReelPage(
      reels: reelsOverride ?? _reels ?? [_sample(tagProduct: tagProduct)],
    );
  }

  /// Records the reels the feed asked the API to count.
  final viewed = <String>[];

  @override
  Future<Reel?> registerView(String reelId) async {
    viewed.add(reelId);
    return _sample(tagProduct: tagProduct).withViewCount(43);
  }

  static Reel _sample({required bool tagProduct}) {
    return Reel(
      id: 'reel-1',
      shopName: 'Bay Area Gifts',
      caption: 'Unboxing the birthday hamper',
      hashtags: const ['giftbox', 'birthday'],
      imageUrl: 'https://example.test/public/reels/cover.jpg',
      product: tagProduct
          ? const ReelProduct(
              id: 'product-1',
              name: 'Gift Box USA',
              priceAmount: 4200,
              currency: 'USD',
            )
          : null,
    );
  }
}
