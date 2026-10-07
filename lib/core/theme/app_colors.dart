import 'package:flutter/material.dart';

/// Brand palette, sampled straight from the Send A Gift mark: the deep navy
/// gift box, the violet ribbon bow, and the teal paper plane cutting through
/// it. Every screen reads off these tokens, so retuning a value here
/// reskins the whole app in one place.
class AppColors {
  AppColors._();

  /// The gift box. Primary brand colour, used for CTAs, headings-on-fill,
  /// and anywhere the app needs to feel unmistakably "Send A Gift".
  static const Color primary = Color(0xFF0F1B45);
  static const Color primaryForeground = Color(0xFFFAFAFF);

  /// The ribbon bow. Secondary accent for highlights, marker blocks, and
  /// the bottom nav's active pill.
  static const Color purple = Color(0xFF6D28D9);
  static const Color purpleForeground = Color(0xFFFFFFFF);

  /// The paper plane in flight. Tertiary accent, used sparingly for motion
  /// and "in progress" moments (delivery, tracking, the send action itself).
  static const Color teal = Color(0xFF14B8B8);
  static const Color tealForeground = Color(0xFF06302F);

  /// Cool near-white page ground and pure-white card surface.
  static const Color background = Color(0xFFF7F7FC);
  static const Color surface = Color(0xFFFFFFFF);

  /// Ink-navy body copy, and a cool slate for secondary text.
  static const Color foreground = Color(0xFF12172E);
  static const Color mutedForeground = Color(0xFF676E86);

  /// Cool neutrals used for section bands, placeholders, and disabled states.
  static const Color muted = Color(0xFFEEF0F8);
  static const Color mist = Color(0xFFE4E7F3);

  /// Soft violet tint for panels that want to feel branded without shouting.
  /// delivery notes, info banners, feature tiles.
  static const Color cream = Color(0xFFF1EDFB);

  /// Soft teal tint used for icon chips and "active/selected" fills, paired
  /// with [accentForeground] for the icon or label on top of it.
  static const Color accent = Color(0xFFDCF6F3);
  static const Color accentForeground = Color(0xFF0B6E68);

  static const Color border = Color(0xFFE3E5F1);

  /// The website's box-template edge: ink at about 15%, a soft ash line that
  /// still reads clearly on white and on tinted tiles.
  static const Color boxBorder = Color(0x2612172E);

  /// Fill behind a box tab bar, as the web's `bg-accent` strip.
  static const Color boxTrack = Color(0xFFEDEBF7);
  static const Color destructive = Color(0xFFDC2626);
  static const Color star = Color(0xFFEEA23A);

  /// Soft tints behind the category tiles, cycling the three brand hues (and
  /// their blends) so the strip reads as colourful without leaving the
  /// palette.
  static const List<Color> categoryTints = [
    Color(0xFFE7EAFB), // navy
    Color(0xFFF1E9FC), // violet
    Color(0xFFDCF6F3), // teal
    Color(0xFFEAEAFC), // navy × violet
    Color(0xFFE3F1FC), // navy × teal
    Color(0xFFF3EAF9), // violet × teal
  ];

  /// Shadow used on cards. A soft navy-tinted lift, not a grey drop shadow.
  static const Color cardShadow = Color(0x1E0F1B45);

  /// Brand colours are always used flat: no gradients anywhere in the app.
}
