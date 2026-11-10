import 'package:flutter/material.dart';

import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../domain/gift.dart';
import 'gift_card.dart';

/// Gift grid shared by explore, saved and the home shelf: two columns on a
/// phone, more on a tablet so cards stay a sensible size.
class GiftGrid extends StatelessWidget {
  const GiftGrid({
    super.key,
    required this.gifts,
    this.sliver = false,
    this.heroPrefix,
  });

  final List<Gift> gifts;

  /// Passed to each card so hero tags stay unique across the live tab
  /// branches. See [GiftCard.heroPrefix].
  final String? heroPrefix;

  /// When true, returns a sliver for embedding in a CustomScrollView.
  final bool sliver;

  static const double _spacing = 12;

  /// Narrowest a card gets before the grid drops a column.
  static const double _minCardWidth = 190;

  /// Cards are sized from the actual column width rather than a fixed aspect
  /// ratio: the photo is square, so the cell is width + the text block, which
  /// scales with the user's font size. A guessed ratio overflows on devices
  /// whose text renders taller than the design assumed.
  SliverGridDelegate _delegate(BuildContext context, double maxWidth) {
    final columns = gridColumns(
      maxWidth,
      minTileWidth: _minCardWidth,
      spacing: _spacing,
      max: 5,
    );
    final columnWidth = (maxWidth - _spacing * (columns - 1)) / columns;

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: _spacing,
      mainAxisSpacing: _spacing,
      mainAxisExtent: columnWidth + GiftCard.textBlockHeight(context),
    );
  }

  /// Cards ease in as they're built, staggered by column so the two-up grid
  /// arrives as a small cascade rather than popping in as one block. Capped
  /// at eight cards' worth of delay. Everything after that is already off
  /// the first screen, so there is no visible queue to sit through.
  Widget _animatedCard(int index) {
    final delay = Duration(milliseconds: 45 * (index % 8));
    return FadeSlideIn(
      delay: delay,
      child: GiftCard(gift: gifts[index], heroPrefix: heroPrefix),
    );
  }

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: AppTheme.gutter);

    if (sliver) {
      return SliverPadding(
        padding: padding,
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) => SliverGrid.builder(
            gridDelegate: _delegate(context, constraints.crossAxisExtent),
            itemCount: gifts.length,
            itemBuilder: (context, index) => _animatedCard(index),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: padding,
        gridDelegate: _delegate(
          context,
          constraints.maxWidth - AppTheme.gutter * 2,
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: gifts.length,
        itemBuilder: (context, index) => _animatedCard(index),
      ),
    );
  }
}
