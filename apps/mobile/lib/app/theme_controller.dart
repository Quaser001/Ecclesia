import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the app's light/dark theme choice and persists it across launches.
///
/// Call [init] once from `main()` before `runApp`, so the preferred theme
/// is applied on the very first frame.
class ThemeController {
  static const _storageKey = 'calfit.theme_mode';

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.dark);

  /// Loads the persisted theme choice. Safe to call multiple times.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      if (saved == 'light') {
        themeMode.value = ThemeMode.light;
      } else if (saved == 'dark') {
        themeMode.value = ThemeMode.dark;
      }
    } catch (_) {
      // SharedPreferences can fail in tests — ignore and keep the default.
    }
  }

  static Future<void> toggleTheme() async {
    final next = themeMode.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    themeMode.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _storageKey, next == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {
      // Non-fatal: the choice still applies for this session.
    }
  }
}
