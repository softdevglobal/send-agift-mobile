import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/profile/presentation/screens/help_centre_screen.dart';
import 'package:send_agift_mobile/features/profile/presentation/screens/terms_screen.dart';

void main() {
  testWidgets('help centre search narrows the questions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpCentreScreen()));
    expect(find.text('Can I cancel an order?'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('help-search')), 'refund');
    await tester.pumpAndSettle();

    expect(find.text('Can I cancel an order?'), findsNothing);
    expect(
      find.text('What happens to points if an order is cancelled or refunded?'),
      findsOneWidget,
    );
  });

  testWidgets('terms and privacy each have their own tab', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TermsScreen()));
    expect(find.text('Who we are'), findsOneWidget);

    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();

    expect(find.text('What we collect'), findsOneWidget);
  });
}
