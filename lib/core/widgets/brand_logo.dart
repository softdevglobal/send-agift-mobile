import 'package:flutter/material.dart';

/// The SendAGift logo.
///
/// Three variants ship as assets so each placement uses artwork drawn at the
/// right proportions rather than a squashed crop of one file:
///
/// * [BrandMark]. The gift graphic alone, for tight square slots.
/// * [BrandWordmark]. "Send A Gift" set as drawn, for horizontal bars.
/// * [BrandLockup]. Mark stacked over wordmark, for splash-style moments.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});

  /// Height of the mark in logical pixels; width follows the artwork.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_mark.png',
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'SendAGift',
    );
  }
}

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.height = 18});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_wordmark.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'SendAGift',
    );
  }
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.width = 200});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'SendAGift',
    );
  }
}
