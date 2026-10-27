import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide display preferences, persisted across launches: theme, text size
/// and language.
///
/// Call [init] once from `main()` before `runApp`, so the saved choices apply
/// on the very first frame. Light is the default theme; "system" follows the
/// phone.
class ThemeController {
  static const _themeKey = 'calfit.theme_mode';
  static const _textScaleKey = 'calfit.text_scale';
  static const _localeKey = 'calfit.locale';

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  /// Multiplies the phone's own text size, so both settings are respected.
  static final ValueNotifier<double> textScale = ValueNotifier(1.0);

  /// Null means "same as the phone" (falls back to English if unsupported).
  static final ValueNotifier<Locale?> locale = ValueNotifier(null);

  /// The text sizes offered in Settings.
  static const textScales = <double>[0.9, 1.0, 1.15, 1.3];

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      themeMode.value = switch (prefs.getString(_themeKey)) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
      final scale = prefs.getDouble(_textScaleKey);
      if (scale != null && textScales.contains(scale)) textScale.value = scale;
      final code = prefs.getString(_localeKey);
      if (code != null && code.isNotEmpty) locale.value = Locale(code);
    } catch (_) {
      // SharedPreferences can fail in tests — keep the defaults.
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    await _save((p) => p.setString(_themeKey, mode.name));
  }

  /// Quick light/dark switch (Home header).
  static Future<void> toggleTheme() => setThemeMode(
      themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  static Future<void> setTextScale(double scale) async {
    textScale.value = scale;
    await _save((p) => p.setDouble(_textScaleKey, scale));
  }

  static Future<void> setLocale(Locale? value) async {
    locale.value = value;
    await _save((p) => value == null
        ? p.remove(_localeKey)
        : p.setString(_localeKey, value.languageCode));
  }

  static Future<void> _save(Future<bool> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {
      // Non-fatal: the choice still applies for this session.
    }
  }
}
