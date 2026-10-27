import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';

/// CalFit theme.
///
/// Two typefaces, one job each:
///   • Fraunces (serif, variable) — "verdict" moments: score, product name,
///     hero greetings. Serif reads as considered, not clinical.
///   • Plus Jakarta Sans — everything UI: buttons, labels, body.
///
/// We never ship `fontFamily: 'Segoe UI'` or any other OS-specific face —
/// those don't exist on Android.
class AppTheme {
  /// Serif used for scores and product names.
  static TextStyle display(double size,
      {FontWeight weight = FontWeight.w500, Color? color, double? height}) {
    return GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: -0.5,
    );
  }

  /// UI sans — buttons, labels, body.
  static TextStyle ui(double size,
      {FontWeight weight = FontWeight.w400, Color? color, double? height}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.verdict,
        secondary: AppColors.ember,
        surface: AppColors.surface,
        surfaceContainerHighest: AppColors.elevated,
        error: AppColors.critical,
        onPrimary: AppColors.bg,
        onSurface: AppColors.text,
      ),
      textTheme: _textTheme(baseColor: AppColors.text, mutedColor: AppColors.muted),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        titleTextStyle: ui(18, weight: FontWeight.w600, color: AppColors.text),
      ),
      dividerColor: AppColors.divider,
      iconTheme: const IconThemeData(color: AppColors.text),
      splashFactory: InkSparkle.splashFactory,
      filledButtonTheme: _filledButton(),
      snackBarTheme: _snackBar(),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(circularTrackColor: Colors.transparent),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.verdictDark,
        secondary: AppColors.ember,
        surface: AppColors.lightSurface,
        surfaceContainerHighest: AppColors.lightElevated,
        error: AppColors.critical,
        onPrimary: Colors.white,
        onSurface: AppColors.lightText,
      ),
      textTheme: _textTheme(baseColor: AppColors.lightText, mutedColor: AppColors.lightMuted),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.lightText),
        titleTextStyle: ui(18, weight: FontWeight.w600, color: AppColors.lightText),
      ),
      dividerColor: AppColors.lightDivider,
      iconTheme: const IconThemeData(color: AppColors.lightText),
      splashFactory: InkSparkle.splashFactory,
      filledButtonTheme: _filledButton(),
      snackBarTheme: _snackBar(),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(circularTrackColor: Colors.transparent),
    );
  }

  static FilledButtonThemeData _filledButton() => FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: ui(14, weight: FontWeight.w700),
        ),
      );

  static SnackBarThemeData _snackBar() => SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );

  static TextTheme _textTheme(
      {required Color baseColor, required Color mutedColor}) {
    // Scale: display = verdict moments only. The rest is UI.
    return TextTheme(
      displayLarge: display(48, weight: FontWeight.w500, color: baseColor, height: 1.0),
      displayMedium: display(32, weight: FontWeight.w500, color: baseColor, height: 1.1),
      displaySmall: display(24, weight: FontWeight.w500, color: baseColor, height: 1.15),
      headlineMedium: ui(20, weight: FontWeight.w600, color: baseColor, height: 1.25),
      titleLarge: ui(17, weight: FontWeight.w600, color: baseColor, height: 1.3),
      titleMedium: ui(15, weight: FontWeight.w600, color: baseColor, height: 1.3),
      bodyLarge: ui(16, weight: FontWeight.w400, color: baseColor, height: 1.5),
      bodyMedium: ui(14, weight: FontWeight.w400, color: mutedColor, height: 1.45),
      labelLarge: ui(14, weight: FontWeight.w600, color: baseColor),
      labelMedium: ui(12, weight: FontWeight.w500, color: mutedColor),
      labelSmall: ui(11, weight: FontWeight.w600, color: mutedColor),
    );
  }
}
