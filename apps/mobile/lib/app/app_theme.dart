import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';

/// CalFit theme — warm, friendly, light-first.
///
/// Two typefaces, one job each:
///   • Fraunces (serif) — "verdict" moments only: scores, product names,
///     greetings. Serif reads as considered rather than clinical.
///   • Plus Jakarta Sans — everything else: buttons, labels, body.
///
/// Components are styled here once, so screens use plain `FilledButton`,
/// `OutlinedButton`, `FilterChip` and so on instead of one-off styles.
/// Flat surfaces only: no gradients, glows or sparkle ripples.
class AppTheme {
  AppTheme._();

  /// Corner radius shared by cards, buttons and inputs.
  static const double radius = 16;

  /// Serif used for scores and product names.
  static TextStyle display(double size,
      {FontWeight weight = FontWeight.w600, Color? color, double? height}) {
    return GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: -0.3,
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

  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        colors: CalfitColors.light,
        bg: AppColors.lightBg,
        surface: AppColors.lightSurface,
        text: AppColors.lightText,
      );

  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        colors: CalfitColors.dark,
        bg: AppColors.darkBg,
        surface: AppColors.darkSurface,
        text: AppColors.darkText,
      );

  static ThemeData _build({
    required Brightness brightness,
    required CalfitColors colors,
    required Color bg,
    required Color surface,
    required Color text,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.brand,
      onPrimary: colors.onBrand,
      primaryContainer: colors.brandSoft,
      onPrimaryContainer: colors.brand,
      secondary: colors.accent,
      onSecondary: brightness == Brightness.light ? Colors.white : AppColors.darkBg,
      error: colors.critical,
      onError: brightness == Brightness.light ? Colors.white : AppColors.darkBg,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: colors.muted,
      surfaceContainerHighest: colors.elevated,
      surfaceContainerHigh: colors.elevated,
      surfaceContainer: colors.elevated,
      outline: colors.divider,
      outlineVariant: colors.divider,
    );
    final buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    final textTheme = _textTheme(baseColor: text, mutedColor: colors.muted);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      textTheme: textTheme,
      dividerColor: colors.divider,
      iconTheme: IconThemeData(color: text),
      splashFactory: InkRipple.splashFactory,
      extensions: [colors],
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: text),
        titleTextStyle: ui(20, weight: FontWeight.w700, color: text),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: colors.divider),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.brand,
          foregroundColor: colors.onBrand,
          disabledBackgroundColor: colors.elevated,
          disabledForegroundColor: colors.muted,
          minimumSize: const Size(64, 52),
          shape: buttonShape,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: ui(15, weight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(64, 52),
          side: BorderSide(color: colors.divider, width: 1.2),
          shape: buttonShape,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: ui(15, weight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.brand,
          textStyle: ui(14, weight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: colors.brandSoft,
        checkmarkColor: colors.brand,
        side: BorderSide(color: colors.divider),
        shape: const StadiumBorder(),
        labelStyle: ui(14, weight: FontWeight.w500, color: text),
        secondaryLabelStyle: ui(14, weight: FontWeight.w700, color: colors.brand),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: ui(20, weight: FontWeight.w700, color: text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.elevated,
        hintStyle: ui(15, color: colors.muted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 4),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 4),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 4),
          borderSide: BorderSide(color: colors.brand, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: text,
        contentTextStyle: ui(14, weight: FontWeight.w500, color: bg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.brand,
        circularTrackColor: Colors.transparent,
        linearTrackColor: colors.brandSoft,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.muted,
        titleTextStyle: ui(16, weight: FontWeight.w600, color: text),
        subtitleTextStyle: ui(13, color: colors.muted),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? colors.onBrand : colors.muted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? colors.brand : colors.elevated),
      ),
    );
  }

  static TextTheme _textTheme(
      {required Color baseColor, required Color mutedColor}) {
    // Display sizes are for verdict moments only; everything else is UI.
    // Body text is never below 14, captions never below 12.
    return TextTheme(
      displayLarge: display(48, color: baseColor, height: 1.0),
      displayMedium: display(30, color: baseColor, height: 1.12),
      displaySmall: display(24, color: baseColor, height: 1.18),
      headlineMedium: ui(19, weight: FontWeight.w700, color: baseColor, height: 1.25),
      titleLarge: ui(17, weight: FontWeight.w700, color: baseColor, height: 1.3),
      titleMedium: ui(15, weight: FontWeight.w600, color: baseColor, height: 1.3),
      bodyLarge: ui(16, color: baseColor, height: 1.5),
      bodyMedium: ui(14, color: mutedColor, height: 1.45),
      bodySmall: ui(13, color: mutedColor, height: 1.4),
      labelLarge: ui(14, weight: FontWeight.w700, color: baseColor),
      labelMedium: ui(13, weight: FontWeight.w600, color: mutedColor),
      labelSmall: ui(12, weight: FontWeight.w700, color: mutedColor),
    );
  }
}
