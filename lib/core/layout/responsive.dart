import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Widths that keep tablet (and landscape) layouts readable.
///
/// The screens are designed for phones. On a tablet they would otherwise
/// stretch edge to edge: rows of text twice as long as they should be, and
/// grids whose two tiles each fill half an iPad. Instead each page is laid out
/// in a column no wider than one of these, centred on the screen.
abstract final class ContentWidth {
  /// Forms, details, lists and settings: one comfortable reading column.
  static const double reading = 720;

  /// Image-led pages (home, explore, saved, games): wider, with grids that
  /// add columns to fill it.
  static const double browse = 1100;

  /// A game board, which is played with one thumb on a phone.
  static const double game = 720;

  /// Reels: a tall video column, like a phone held upright.
  static const double reel = 560;

  /// The cart, opening over the page from the right.
  static const double sidePanel = 480;
}

/// Lays [child] out in a centred column at most [maxWidth] wide.
///
/// Inside the column [MediaQuery] reports the column's width rather than the
/// screen's, so a screen that sizes itself from the screen width (a carousel,
/// a game board, a video) fits the column instead of overflowing it. On a
/// screen no wider than [maxWidth] this returns [child] untouched.
class ResponsiveFrame extends StatelessWidget {
  const ResponsiveFrame({
    super.key,
    required this.child,
    this.maxWidth = ContentWidth.reading,
    this.backgroundColor = AppColors.background,
  });

  final Widget child;
  final double maxWidth;

  /// Shown either side of the column.
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= maxWidth) return child;

    return ColoredBox(
      color: backgroundColor,
      child: Center(
        child: SizedBox(
          width: maxWidth,
          child: MediaQuery(
            data: media.copyWith(
              size: Size(maxWidth, media.size.height),
              // The column sits clear of the screen's side edges (the notch
              // in landscape), so only top and bottom insets still apply.
              padding: media.padding.copyWith(left: 0, right: 0),
              viewPadding: media.viewPadding.copyWith(left: 0, right: 0),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Draws the whole app larger on tablets.
///
/// The app is designed for phones. Shown at phone size on a tablet, text and
/// buttons are tiny and the screen is mostly empty. Instead the app lays out
/// as if the tablet's short side were [targetShortestSide] points (a large
/// phone) and is then scaled up to fill the screen, so a tablet shows the same
/// design, bigger. Phones are left untouched.
///
/// Put this above the navigator (in `MaterialApp.builder`) so dialogs, sheets
/// and menus are scaled along with the pages.
class TabletScale extends StatelessWidget {
  const TabletScale({super.key, required this.child});

  final Widget child;

  /// Short sides from here up are tablets (Material's own breakpoint).
  static const double tabletShortestSide = 600;

  /// The short side a tablet lays out at, before scaling.
  static const double targetShortestSide = 640;

  /// Never more than this, so a large tablet doesn't look blown up.
  static const double maxScale = 1.6;

  /// How much to enlarge a screen of [size]; 1 on phones.
  static double scaleFor(Size size) {
    if (size.shortestSide < tabletShortestSide) return 1;
    return (size.shortestSide / targetShortestSide).clamp(1.0, maxScale);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = scaleFor(media.size);
    if (scale == 1) return child;

    EdgeInsets down(EdgeInsets insets) => insets / scale;
    final virtual = media.size / scale;

    return MediaQuery(
      data: media.copyWith(
        size: virtual,
        // Images still decode at the screen's full resolution.
        devicePixelRatio: media.devicePixelRatio * scale,
        padding: down(media.padding),
        viewPadding: down(media.viewPadding),
        viewInsets: down(media.viewInsets),
        systemGestureInsets: down(media.systemGestureInsets),
      ),
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(size: virtual, child: child),
      ),
    );
  }
}

/// How many grid columns fit [width] with tiles at least [minTileWidth] wide,
/// never fewer than [min] or more than [max].
int gridColumns(
  double width, {
  required double minTileWidth,
  double spacing = 12,
  int min = 2,
  int max = 6,
}) {
  final fit = ((width + spacing) / (minTileWidth + spacing)).floor();
  return math.max(min, math.min(max, fit));
}
