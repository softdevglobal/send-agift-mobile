import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  /// Corner radii, keyed to the web's `--radius: 0.75rem` scale.
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 22;
  static const double radius2xl = 28;

  /// Buttons are solid blocks with barely rounded corners, not pills.
  static const double radiusButton = 8;

  /// Horizontal page gutter used by every screen.
  static const double gutter = 20;

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: AppColors.cardShadow, blurRadius: 24, offset: Offset(0, 8)),
  ];

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      secondary: AppColors.purple,
      onSecondary: AppColors.purpleForeground,
      tertiary: AppColors.teal,
      onTertiary: AppColors.tealForeground,
      surface: AppColors.surface,
      onSurface: AppColors.foreground,
      error: AppColors.destructive,
      onError: Colors.white,
      outline: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTypography.sansFamily,
      textTheme: AppTypography.textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.displayFamily,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: AppColors.foreground,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryForeground,
          disabledBackgroundColor: AppColors.mist,
          disabledForegroundColor: AppColors.mutedForeground,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTypography.sansFamily,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.foreground,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          side: const BorderSide(color: AppColors.foreground, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTypography.sansFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontFamily: AppTypography.sansFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryForeground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTypography.sansFamily,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(
          fontFamily: AppTypography.sansFamily,
          fontSize: 14,
          color: AppColors.mutedForeground,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(
          fontFamily: AppTypography.sansFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.foreground,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusButton),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius2xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.foreground,
        contentTextStyle: const TextStyle(
          fontFamily: AppTypography.sansFamily,
          fontSize: 13.5,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
    );
  }
}
