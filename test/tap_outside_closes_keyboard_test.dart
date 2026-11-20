import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/core/widgets/tap_outside_closes_keyboard.dart';

void main() {
  testWidgets('a tap outside a field closes the keyboard', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TapOutsideClosesKeyboard(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: focus, keyboardType: TextInputType.number),
              const SizedBox(height: 300, child: Text('blank space')),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    // Tapping the field again keeps the keyboard up.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    await tester.tap(find.text('blank space'));
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  });
}
