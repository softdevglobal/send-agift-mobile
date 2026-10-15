import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  testWidgets('policies list every customer and seller policy', (tester) async {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://api.sendagift.win/api/v1');
    await tester.pumpWidget(const MaterialApp(home: TermsScreen()));
    for (final title in [
      'Privacy Policy',
      'Marketplace Customer Terms',
      'Delivery Policy',
      'Returns, Refunds and Cancellations',
      'Free Gift Promotion Terms',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    // Each opens the website's page for it.
    expect(
      policyLinks.first.url.toString(),
      'https://sendagift.win/legal/privacy',
    );
  });
}
