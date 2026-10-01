import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/products/data/catalog_providers.dart';
import 'package:send_agift_mobile/features/products/data/sample_gifts.dart';
import 'package:send_agift_mobile/features/products/presentation/screens/explore_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth.dart';

void main() {
  testWidgets('all gifts fits a narrow phone and sorts by price', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakeAuth(),
          catalogProvider.overrideWith((ref) async => sampleGifts),
        ],
        child: const MaterialApp(home: ExploreScreen()),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('${sampleGifts.length} gifts'), findsOneWidget);
    expect(find.text('Birthday'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('explore-sort')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('explore-sort')));
    // Let the menu finish opening; it ignores taps until then.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Most points'), findsOneWidget);
    await tester.tap(find.text('Lowest price').last);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Lowest price'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
