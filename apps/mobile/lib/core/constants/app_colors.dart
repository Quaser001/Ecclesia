import 'package:flutter/material.dart';

/// CalFit palette.
///
/// Deep green-black base with an amber "ember" signature. The ember replaces
/// the generic emerald-wellness look for warnings, highlights and findings,
/// and lets the primary green stay reserved for "verdict / this fits you".
///
/// Scores and severities use their own semantic ramps (see `scoreColor` and
/// `severityColor` below) rather than being pulled out of thin air at the
/// call site.
class AppColors {
  // Dark theme — the default.
  static const Color bg = Color(0xFF0A1512);
  static const Color surface = Color(0xFF0F1E1A);
  static const Color elevated = Color(0xFF152824);
  static const Color text = Color(0xFFECFEF8);
  static const Color muted = Color(0xFF7A8E89);
  static const Color divider = Color(0x1AFFFFFF);

  // Light theme.
  static const Color lightBg = Color(0xFFF5F8F3);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFEFF2EC);
  static const Color lightText = Color(0xFF0D1A16);
  static const Color lightMuted = Color(0xFF5A6B65);
  static const Color lightDivider = Color(0x14000000);

  // Brand accents (shared across themes).
  static const Color verdict = Color(0xFF4ADE9A);   // "good fit" primary
  static const Color verdictDark = Color(0xFF059669);
  static const Color ember = Color(0xFFF59E3C);     // signature warning
  static const Color critical = Color(0xFFEF5856);  // genuine stop

  // Score ramp — one place, matched to the suitability buckets in the backend.
  // 80-100 excellent, 60-79 good, 40-59 fair, 20-39 poor, 0-19 not suitable.
  static Color scoreColor(int score) {
    if (score >= 80) return verdict;
    if (score >= 60) return const Color(0xFFBEE86E); // bright lime — "mostly good"
    if (score >= 40) return ember;
    if (score >= 20) return const Color(0xFFF07A4C); // between ember & red
    return critical;
  }
}
