import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/core/widgets/sheet_header.dart';

void main() {
  testWidgets('the close button dismisses the sheet with no result', (
    tester,
  ) async {
    String? result = 'untouched';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showModalBottomSheet<String>(
                context: context,
                builder: (_) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: SheetHeader(title: 'New recipient'),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('New recipient'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sheet-close')));
    await tester.pumpAndSettle();
    expect(find.text('New recipient'), findsNothing);
    expect(result, isNull);
  });
}
