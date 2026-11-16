import 'package:flutter/widgets.dart';

/// The part of the screen a full-screen game can put its own gauges, labels
/// and prompts in: below the play screen's title and score panels and above
/// its hint line. The play screen measures those and passes them down as
/// the padding, so whatever sits in here is never hidden under them.
class GameOverlayArea extends StatelessWidget {
  const GameOverlayArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.only(top: p.top, bottom: p.bottom),
      child: child,
    );
  }
}
