import 'package:flutter/material.dart';

/// CalFit palette — warm and friendly, light-first.
///
/// Three tiers (Refactoring UI): one brand green, a warm-tinted neutral ramp
/// that makes up most of the screen, and a few supporting colours used
/// sparingly for meaning. No gradients and no glows anywhere.
///
/// Every text colour here passes WCAG AA (4.5:1) on its theme's background
/// and card colours; the ratios were measured when the palette was chosen.
///
/// Widgets never use these constants directly. They read the active set
/// through `context.colors`, so light and dark mode can't drift apart.
class AppColors {
  AppColors._();

  // Light theme.
  static const Color lightBg = Color(0xFFFAF7F2); // warm off-white
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFF2EEE7);
  static const Color lightText = Color(0xFF1F1C18);
  static const Color lightMuted = Color(0xFF665E54);
  static const Color lightDivider = Color(0xFFE6E0D6);
  static const Color lightBrand = Color(0xFF1F6B4F); // deep green
  static const Color lightBrandSoft = Color(0xFFE3F0E8);
  static const Color lightAccent = Color(0xFFB54A33); // coral
  static const Color lightWarning = Color(0xFF8F5E0C); // amber
  static const Color lightCritical = Color(0xFFC2373A);

  // Dark theme.
  static const Color darkBg = Color(0xFF161513);
  static const Color darkSurface = Color(0xFF201E1B);
  static const Color darkElevated = Color(0xFF2A2723);
  static const Color darkText = Color(0xFFF2EEE7);
  static const Color darkMuted = Color(0xFFACA497);
  static const Color darkDivider = Color(0xFF36322C);
  static const Color darkBrand = Color(0xFF6CCB9C);
  static const Color darkBrandSoft = Color(0xFF1F3329);
  static const Color darkAccent = Color(0xFFF08A72);
  static const Color darkWarning = Color(0xFFE8B04F);
  static const Color darkCritical = Color(0xFFF07470);
}

/// The active colour set, attached to [ThemeData] as an extension.
@immutable
class CalfitColors extends ThemeExtension<CalfitColors> {
  final Color brand;
  final Color onBrand;
  final Color brandSoft;
  final Color accent;
  final Color warning;
  final Color critical;
  final Color muted;
  final Color divider;
  final Color elevated;

  // Score ramp, matched to the backend's suitability buckets:
  // 80-100 excellent, 60-79 good, 40-59 fair, 20-39 poor, 0-19 not suitable.
  final Color excellent;
  final Color good;
  final Color fair;
  final Color poor;
  final Color notSuitable;

  const CalfitColors({
    required this.brand,
    required this.onBrand,
    required this.brandSoft,
    required this.accent,
    required this.warning,
    required this.critical,
    required this.muted,
    required this.divider,
    required this.elevated,
    required this.excellent,
    required this.good,
    required this.fair,
    required this.poor,
    required this.notSuitable,
  });

  static const light = CalfitColors(
    brand: AppColors.lightBrand,
    onBrand: Colors.white,
    brandSoft: AppColors.lightBrandSoft,
    accent: AppColors.lightAccent,
    warning: AppColors.lightWarning,
    critical: AppColors.lightCritical,
    muted: AppColors.lightMuted,
    divider: AppColors.lightDivider,
    elevated: AppColors.lightElevated,
    excellent: Color(0xFF23784F),
    good: Color(0xFF4C7119),
    fair: Color(0xFF8C5D0A),
    poor: Color(0xFFB4522D),
    notSuitable: Color(0xFFB8322F),
  );

  static const dark = CalfitColors(
    brand: AppColors.darkBrand,
    onBrand: AppColors.darkBg,
    brandSoft: AppColors.darkBrandSoft,
    accent: AppColors.darkAccent,
    warning: AppColors.darkWarning,
    critical: AppColors.darkCritical,
    muted: AppColors.darkMuted,
    divider: AppColors.darkDivider,
    elevated: AppColors.darkElevated,
    excellent: Color(0xFF5FC48F),
    good: Color(0xFFA3C95A),
    fair: Color(0xFFE3AE47),
    poor: Color(0xFFEE8E62),
    notSuitable: Color(0xFFF07470),
  );

  /// Colour for a 0-100 score. Always shown next to the score or its label,
  /// never as the only signal.
  Color score(int value) {
    if (value >= 80) return excellent;
    if (value >= 60) return good;
    if (value >= 40) return fair;
    if (value >= 20) return poor;
    return notSuitable;
  }

  /// A soft background tint for a coloured element (chips, badges, callouts).
  Color tint(Color c, Brightness b) =>
      c.withValues(alpha: b == Brightness.dark ? 0.16 : 0.10);

  @override
  CalfitColors copyWith({
    Color? brand,
    Color? onBrand,
    Color? brandSoft,
    Color? accent,
    Color? warning,
    Color? critical,
    Color? muted,
    Color? divider,
    Color? elevated,
    Color? excellent,
    Color? good,
    Color? fair,
    Color? poor,
    Color? notSuitable,
  }) {
    return CalfitColors(
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      brandSoft: brandSoft ?? this.brandSoft,
      accent: accent ?? this.accent,
      warning: warning ?? this.warning,
      critical: critical ?? this.critical,
      muted: muted ?? this.muted,
      divider: divider ?? this.divider,
      elevated: elevated ?? this.elevated,
      excellent: excellent ?? this.excellent,
      good: good ?? this.good,
      fair: fair ?? this.fair,
      poor: poor ?? this.poor,
      notSuitable: notSuitable ?? this.notSuitable,
    );
  }

  @override
  CalfitColors lerp(ThemeExtension<CalfitColors>? other, double t) {
    if (other is! CalfitColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return CalfitColors(
      brand: l(brand, other.brand),
      onBrand: l(onBrand, other.onBrand),
      brandSoft: l(brandSoft, other.brandSoft),
      accent: l(accent, other.accent),
      warning: l(warning, other.warning),
      critical: l(critical, other.critical),
      muted: l(muted, other.muted),
      divider: l(divider, other.divider),
      elevated: l(elevated, other.elevated),
      excellent: l(excellent, other.excellent),
      good: l(good, other.good),
      fair: l(fair, other.fair),
      poor: l(poor, other.poor),
      notSuitable: l(notSuitable, other.notSuitable),
    );
  }
}

extension CalfitColorsContext on BuildContext {
  /// The active CalFit colour set for this part of the tree.
  CalfitColors get colors =>
      Theme.of(this).extension<CalfitColors>() ?? CalfitColors.light;
}
