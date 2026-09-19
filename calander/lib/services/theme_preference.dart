import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's chosen appearance on this device -- light, dark, or
/// follow the phone's own setting. Deliberately local (not synced through
/// Firestore like the rest of the app's settings): "follow my phone" is
/// inherently a per-device choice, and a phone in light mode syncing a
/// forced dark choice from a desktop session would be a surprise, not a
/// feature.
abstract class ThemePreferenceStore {
  Future<ThemeMode> load();

  Future<void> save(ThemeMode mode);
}

class SharedPreferencesThemeStore implements ThemePreferenceStore {
  static const _key = 'themeMode';

  @override
  Future<ThemeMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }

  @override
  Future<void> save(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
