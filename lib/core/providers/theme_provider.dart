import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _themeKey = 'theme_mode';
  SharedPreferences? _prefs;

  @override
  ThemeMode build() {
    _initPrefs();
    return ThemeMode.system;
  }

  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final themeIndex = _prefs!.getInt(_themeKey);
      if (themeIndex != null && themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
        state = ThemeMode.values[themeIndex];
      }
    } catch (_) {
      // Fallback is already system
    }
  }

  Future<void> toggleTheme() async {
    final currentMode = state;
    ThemeMode nextMode;

    if (currentMode == ThemeMode.system) {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      if (brightness == Brightness.dark) {
        nextMode = ThemeMode.light;
      } else {
        nextMode = ThemeMode.dark;
      }
    } else if (currentMode == ThemeMode.light) {
      nextMode = ThemeMode.dark;
    } else {
      nextMode = ThemeMode.system;
    }

    state = nextMode;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setInt(_themeKey, nextMode.index);
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setInt(_themeKey, mode.index);
    } catch (_) {}
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);
