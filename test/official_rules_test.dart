import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/games/presentation/widgets/official_rules.dart';

void main() {
  test('numbered rules with a title line', () {
    final r = parseOfficialRules('''
Official Rules and Regulations – Sri Lanka

1. Participation is open to Sri Lankan residents only.

2. Participants must provide accurate personal information
when creating an account.

3. Each participant must use their own registered account.
''');
    expect(r.title, 'Official Rules and Regulations – Sri Lanka');
    expect(r.count, 3);
    expect(
      r.sections.single.clauses[1],
      'Participants must provide accurate personal information when creating an account.',
    );
  });

  test('sections and bullets', () {
    final r = parseOfficialRules('''
Eligibility
- Open to adults.
- One account each.
HOW TO PLAY:
- Each play costs one entry.
''');
    expect(r.title, 'Eligibility');
    expect(r.sections.map((s) => s.title), [null, 'HOW TO PLAY']);
    expect(r.count, 3);
  });

  test('one plain paragraph is one rule', () {
    final r = parseOfficialRules('Prizes are paid within 30 days.');
    expect(r.title, isNull);
    expect(r.count, 1);
  });

  testWidgets('the rules list fits a phone screen', (tester) async {
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OfficialRulesList(
              rules:
                  'Official Rules and Regulations – Sri Lanka\n\n'
                  '1. Participation is open to Sri Lankan residents only.\n\n'
                  '2. Cheating, hacking, modifying game files, using bots, or '
                  'exploiting game bugs to gain an unfair advantage is '
                  'strictly prohibited.',
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('2 rules'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
