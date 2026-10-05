import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:send_agift_mobile/core/widgets/app_bottom_nav.dart';

const _items = [
  AppBottomNavItem(icon: Icons.home_rounded, label: 'Home'),
  AppBottomNavItem(icon: Icons.card_giftcard_rounded, label: 'Gifts'),
  AppBottomNavItem(icon: Icons.play_circle_rounded, label: 'Play', orb: true),
  AppBottomNavItem(icon: Icons.chat_rounded, label: 'Chat'),
  AppBottomNavItem(icon: Icons.person_rounded, label: 'Account'),
];

Future<void> _pumpAt(WidgetTester tester, double width) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: AppBottomNav(
              currentIndex: 0,
              onChanged: (_) {},
              items: _items,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the rail lays out at a normal width', (tester) async {
    await _pumpAt(tester, 390);
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
  });

  testWidgets('a rail with no room to share does not take the screen down', (
    tester,
  ) async {
    // The orb's slot is a fixed width, so once the rail is narrow enough there
    // is less than nothing left for the flat tabs. A negative width is not a
    // tight squeeze to a SizedBox. It asserts, and the whole screen goes with
    // it. This is the crash seen on a real device mid-transition.
    await _pumpAt(tester, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rail survives every width on the way up from nothing', (
    tester,
  ) async {
    for (var width = 0.0; width <= 200; width += 10) {
      await _pumpAt(tester, width);
      expect(
        tester.takeException(),
        isNull,
        reason: 'the rail threw at ${width}px wide',
      );
    }
  });
}
