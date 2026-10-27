import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import '../models/scan_result.dart';
import '../services/api_service.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

/// Languages offered in Settings, with each name written in that language.
const supportedLanguages = <(Locale, String)>[
  (Locale('en'), 'English'),
  (Locale('hi'), 'हिन्दी'),
  (Locale('as'), 'অসমীয়া'),
  (Locale('bn'), 'বাংলা'),
  (Locale('kha'), 'Khasi'),
];

/// Delegates for MaterialApp. Flutter ships no Material/Cupertino strings
/// for Khasi, so those few system labels (date pickers, copy/paste) fall
/// back to English while all CalFit text stays in Khasi.
const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  _FallbackMaterialDelegate(),
  _FallbackCupertinoDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

class _FallbackMaterialDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _FallbackMaterialDelegate();
  @override
  bool isSupported(Locale locale) =>
      !GlobalMaterialLocalizations.delegate.isSupported(locale);
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('en'));
  @override
  bool shouldReload(_FallbackMaterialDelegate old) => false;
}

class _FallbackCupertinoDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const _FallbackCupertinoDelegate();
  @override
  bool isSupported(Locale locale) =>
      !GlobalCupertinoLocalizations.delegate.isSupported(locale);
  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('en'));
  @override
  bool shouldReload(_FallbackCupertinoDelegate old) => false;
}

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Labels for the profile's stored keys (e.g. `weight_loss`). An unknown key
/// (added on the server later) is shown humanised rather than hidden.
extension ProfileLabels on AppLocalizations {
  static String _humanize(String raw) => raw
      .split('_')
      .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');

  String goalLabel(String key) => switch (key) {
        'weight_loss' => goal_weight_loss,
        'muscle_gain' => goal_muscle_gain,
        'maintain_weight' => goal_maintain_weight,
        'improve_energy' => goal_improve_energy,
        'improve_digestion' => goal_improve_digestion,
        'reduce_inflammation' => goal_reduce_inflammation,
        'manage_blood_sugar' => goal_manage_blood_sugar,
        'heart_health' => goal_heart_health,
        _ => _humanize(key),
      };

  String conditionLabel(String key) => switch (key) {
        'diabetes_type_1' => condition_diabetes_type_1,
        'diabetes_type_2' => condition_diabetes_type_2,
        'prediabetes' => condition_prediabetes,
        'hypertension' => condition_hypertension,
        'high_cholesterol' => condition_high_cholesterol,
        'celiac_disease' => condition_celiac_disease,
        'ibs' => condition_ibs,
        'kidney_disease' => condition_kidney_disease,
        'heart_disease' => condition_heart_disease,
        'obesity' => condition_obesity,
        'lactose_intolerance' => condition_lactose_intolerance,
        'anaemia' => condition_anaemia,
        _ => _humanize(key),
      };

  String dietLabel(String key) => switch (key) {
        'vegetarian' => diet_vegetarian,
        'vegan' => diet_vegan,
        'gluten_free' => diet_gluten_free,
        'dairy_free' => diet_dairy_free,
        'halal' => diet_halal,
        'kosher' => diet_kosher,
        'low_carb' => diet_low_carb,
        'keto' => diet_keto,
        'paleo' => diet_paleo,
        _ => _humanize(key),
      };

  String activityLabel(String key) => switch (key) {
        'sedentary' => activity_sedentary,
        'light' => activity_light,
        'moderate' => activity_moderate,
        'active' => activity_active,
        'very_active' => activity_very_active,
        _ => _humanize(key),
      };

  String activityHint(String key) => switch (key) {
        'sedentary' => activity_sedentary_hint,
        'light' => activity_light_hint,
        'moderate' => activity_moderate_hint,
        'active' => activity_active_hint,
        'very_active' => activity_very_active_hint,
        _ => '',
      };

  String sexLabel(String key) => switch (key) {
        'female' => sexFemale,
        'male' => sexMale,
        _ => sexOther,
      };

  String bmiCategoryLabel(String key) => switch (key) {
        'underweight' => bmiUnderweight,
        'normal' => bmiNormal,
        'overweight' => bmiOverweight,
        _ => bmiObese,
      };

  String suitabilityLabel(SuitabilityStatus s) => switch (s) {
        SuitabilityStatus.excellent => suitabilityExcellent,
        SuitabilityStatus.good => suitabilityGood,
        SuitabilityStatus.fair => suitabilityFair,
        SuitabilityStatus.poor => suitabilityPoor,
        SuitabilityStatus.notSuitable => suitabilityNotSuitable,
        SuitabilityStatus.unknown => suitabilityUnknown,
      };

  /// "just now", "5m", "2h", "3d", then a short date.
  String relativeTime(DateTime date, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(date);
    if (diff.inSeconds < 60) return timeJustNow;
    if (diff.inMinutes < 60) return timeMinutes(diff.inMinutes);
    if (diff.inHours < 24) return timeHours(diff.inHours);
    if (diff.inDays < 7) return timeDays(diff.inDays);
    return shortDate(date);
  }

  /// "15 Oct" style date in the current language (English for Khasi, which
  /// has no date data in intl).
  String shortDate(DateTime d) {
    try {
      return DateFormat.MMMd(localeName).format(d);
    } catch (_) {
      return DateFormat.MMMd('en').format(d);
    }
  }

  /// A short, user-facing error message. Never shows server internals.
  String errorMessage(Object error) {
    if (error is ApiException) {
      return switch (error.kind) {
        ApiErrorKind.network => errorNetwork,
        ApiErrorKind.timeout => errorTimeout,
        ApiErrorKind.server => errorServer,
        ApiErrorKind.notFound => errorNotFound,
        ApiErrorKind.unauthorized => errorUnauthorized,
        ApiErrorKind.rateLimited => errorScanLimit,
        _ => errorGeneric,
      };
    }
    final text = error.toString().toLowerCase();
    if (text.contains('socket') || text.contains('connection')) return errorNetwork;
    if (text.contains('timeout')) return errorTimeout;
    return errorGeneric;
  }
}
