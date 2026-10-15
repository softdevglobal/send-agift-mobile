import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:send_agift_mobile/core/theme/app_theme.dart';
import 'package:send_agift_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:send_agift_mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:send_agift_mobile/features/cart/data/cart_controller.dart';
import 'package:send_agift_mobile/features/cart/presentation/screens/cart_screen.dart';
import 'package:send_agift_mobile/features/cart/presentation/screens/checkout_screen.dart';
import 'package:send_agift_mobile/features/free_gift/presentation/screens/free_gift_screen.dart';
import 'package:send_agift_mobile/features/games/presentation/screens/games_screen.dart';
import 'package:send_agift_mobile/features/games/presentation/screens/points_screen.dart';
import 'package:send_agift_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:send_agift_mobile/features/orders/presentation/screens/order_list_screen.dart';
import 'package:send_agift_mobile/features/products/data/catalog_providers.dart';
import 'package:send_agift_mobile/features/products/presentation/screens/explore_screen.dart';
import 'package:send_agift_mobile/features/products/presentation/screens/gift_detail_screen.dart';
import 'package:send_agift_mobile/features/profile/presentation/screens/account_screen.dart';
import 'package:send_agift_mobile/features/profile/presentation/screens/addresses_screen.dart';
import 'package:send_agift_mobile/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:send_agift_mobile/features/profile/presentation/screens/help_centre_screen.dart';
import 'package:send_agift_mobile/features/profile/presentation/screens/recipients_screen.dart';
import 'package:send_agift_mobile/features/profile/presentation/screens/terms_screen.dart';
import 'package:send_agift_mobile/features/saved/presentation/screens/saved_screen.dart';

import 'support/fake_auth.dart';
import 'support/sample_gifts.dart';

/// Real device sizes, in logical pixels, plus a large text setting, which is
/// what usually breaks a layout on a phone someone has set up for easier
/// reading.
const _sizes = <(String, Size)>[
  ('Small Android 320x568', Size(320, 568)),
  ('Android 360x640', Size(360, 640)),
  ('iPhone SE 375x667', Size(375, 667)),
  ('iPhone 15 393x852', Size(393, 852)),
  ('Pixel 9 412x915', Size(412, 915)),
  ('Pro Max 430x932', Size(430, 932)),
  ('Foldable/tablet 600x960', Size(600, 960)),
  ('Tablet 820x1180', Size(820, 1180)),
];
const _textScales = [1.0, 1.4];

final _screens = <(String, Widget Function())>[
  ('Home', () => const HomeScreen()),
  ('Explore', () => const ExploreScreen()),
  ('Saved', () => const SavedScreen()),
  ('Account', () => const AccountScreen()),
  ('Gift detail', () => GiftDetailScreen(giftId: sampleGifts.first.id)),
  ('Cart', () => const CartScreen()),
  ('Checkout', () => const CheckoutScreen()),
  ('Free gift', () => const FreeGiftScreen()),
  ('Orders', () => const OrderListScreen()),
  ('Games', () => const GamesScreen()),
  ('Points', () => const PointsScreen()),
  ('Edit profile', () => const EditProfileScreen()),
  ('Addresses', () => const AddressesScreen()),
  ('Recipients', () => const RecipientsScreen()),
  ('Help', () => const HelpCentreScreen()),
  ('Terms', () => const TermsScreen()),
  ('Login', () => const LoginScreen()),
  ('Register', () => const RegisterScreen()),
];

void main() {
  // The app loads .env in main(); tests do not, and any screen that builds
  // an API client would throw before it could be laid out.
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api/v1');
  });

  for (final (screenName, build) in _screens) {
    testWidgets(
      '$screenName lays out on every device size',
      (tester) async {
        final problems = <String>[];
        final previous = FlutterError.onError;

        for (final (deviceName, size) in _sizes) {
          for (final scale in _textScales) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;

            FlutterError.onError = (details) {
              final text = details.exceptionAsString().split('\n').first;
              // Overflows and layout errors only; network noise is expected.
              if (text.contains('overflow') ||
                  text.contains('RenderFlex') ||
                  text.contains('RenderBox') ||
                  text.contains('constraints') ||
                  text.contains('unbounded')) {
                problems.add('$screenName @ $deviceName x$scale: $text');
              }
            };

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  fakeAuth(
                    customer: {
                      'id': 'c1',
                      'email': 'tester@example.com',
                      'display_name': 'Tester',
                    },
                  ),
                  catalogProvider.overrideWith((ref) async => sampleGifts),
                ],
                child: MaterialApp(
                  // The app's own theme, so text uses the real Geist and
                  // Fraunces fonts rather than the test font's fixed-width
                  // squares.
                  theme: AppTheme.light,
                  home: Builder(
                    builder: (context) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ProviderScope.containerOf(
                          context,
                          listen: false,
                        ).read(cartProvider.notifier).add(sampleGifts.first.id);
                      });
                      return build();
                    },
                  ),
                ),
              ),
            );
            for (var i = 0; i < 8; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          }
        }
        FlutterError.onError = previous;
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.view.reset();

        final unique = problems.toSet().toList()..sort();
        // ignore: avoid_print
        print('LAYOUT[$screenName] (${unique.length})\n${unique.join('\n')}');
        expect(unique, isEmpty);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}
