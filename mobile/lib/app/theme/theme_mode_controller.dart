import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/storage/preferences_store.dart';

/// Theme override loaded at startup (null = follow the system). Overridden
/// in `main()` with the persisted value.
final Provider<ThemeMode> initialThemeModeProvider = Provider<ThemeMode>(
  (Ref ref) => ThemeMode.system,
);

/// The active theme mode: system by default, or the user's override.
final NotifierProvider<ThemeModeController, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// Holds and persists the theme override (non-sensitive preference).
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(initialThemeModeProvider);

  /// Applies [mode] immediately and persists it in the background.
  void select(ThemeMode mode) {
    state = mode;
    unawaited(ref.read(preferencesStoreProvider).writeThemeMode(mode));
  }
}
