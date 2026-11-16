import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:send_agift_mobile/app/app.dart';
import 'package:send_agift_mobile/features/messages/data/messages_providers.dart';
import 'package:send_agift_mobile/features/products/data/catalog_providers.dart';

import 'support/fake_auth.dart';
import 'support/sample_gifts.dart';

void main() {
  testWidgets('App opens on the storefront without asking anyone to sign in',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The real session and inbox sit on an API client that reads
          // dotenv, which tests do not load.
          fakeAuth(),
          unreadMessagesProvider.overrideWith((ref) => 0),
          catalogProvider.overrideWith((ref) async => sampleGifts),
        ],
        child: const SendAGiftApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // The hero, not a login wall, is the first thing a new user sees.
    expect(find.text('UNFORGETTABLE'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);

    // The nav bar is icons-only, so the tabs are found by the semantics
    // labels that announce them to screen readers. Cart is a side panel now,
    // not a tab; Reels sits in the centre.
    for (final tab in ['Home', 'Explore', 'Reels', 'Saved', 'Account']) {
      expect(find.bySemanticsLabel(tab), findsOneWidget);
    }

    // Let the hero carousel's timer go before the tree is torn down.
    await tester.pumpWidget(const SizedBox());
  });
}
