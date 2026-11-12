import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive, per-device preferences (unencrypted platform storage).
///
/// Never store credentials, personal data or finance data here — use
/// `SecureStore` for credentials. Current contents: the theme override and a
/// marker that tells a fresh install apart from an app update.
abstract interface class PreferencesStore {
  /// The saved theme override, or null for "follow the system".
  Future<ThemeMode?> readThemeMode();

  /// Saves the theme override ([ThemeMode.system] clears it).
  Future<void> writeThemeMode(ThemeMode mode);

  /// Whether this installation already ran once.
  Future<bool> hasInstallMarker();

  /// Records that this installation has run.
  Future<void> writeInstallMarker();
}

/// [PreferencesStore] backed by `shared_preferences`.
class SharedPreferencesStore implements PreferencesStore {
  /// Wraps [preferences]; defaults to a [SharedPreferencesAsync] instance.
  SharedPreferencesStore([SharedPreferencesAsync? preferences])
    : _prefs = preferences ?? SharedPreferencesAsync();

  static const String _themeKey = 'montra.pref.theme_mode';
  static const String _installKey = 'montra.pref.install_marker';

  final SharedPreferencesAsync _prefs;

  @override
  Future<ThemeMode?> readThemeMode() async {
    try {
      return switch (await _prefs.getString(_themeKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => null,
      };
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> writeThemeMode(ThemeMode mode) async {
    try {
      if (mode == ThemeMode.system) {
        await _prefs.remove(_themeKey);
      } else {
        await _prefs.setString(_themeKey, mode.name);
      }
    } on Exception {
      // Preference persistence is best effort.
    }
  }

  @override
  Future<bool> hasInstallMarker() async {
    try {
      return await _prefs.getBool(_installKey) ?? false;
    } on Exception {
      // When unknown, behave like an existing install (never wipe on error).
      return true;
    }
  }

  @override
  Future<void> writeInstallMarker() async {
    try {
      await _prefs.setBool(_installKey, true);
    } on Exception {
      // Best effort.
    }
  }
}

/// The app-wide [PreferencesStore]. Overridden in tests.
final Provider<PreferencesStore> preferencesStoreProvider =
    Provider<PreferencesStore>((Ref ref) => SharedPreferencesStore());
