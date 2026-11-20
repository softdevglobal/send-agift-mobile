import 'package:flutter/widgets.dart';

/// A tap anywhere outside a text or number field closes the keyboard, on
/// every screen. Taps on the field itself, its selection handles and its
/// copy/paste toolbar count as inside, so typing is unaffected.
class TapOutsideClosesKeyboard extends StatelessWidget {
  const TapOutsideClosesKeyboard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        EditableTextTapOutsideIntent:
            CallbackAction<EditableTextTapOutsideIntent>(
              onInvoke: (intent) {
                intent.focusNode.unfocus();
                return null;
              },
            ),
      },
      child: child,
    );
  }
}
