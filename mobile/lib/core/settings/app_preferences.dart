import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';

/// The signed-in user's preferences as last read (`GET /me/preferences`) or
/// saved (`PATCH /me/preferences`), without fetching anything itself. Null
/// until known and after the account changes.
///
/// App-wide settings (accessibility, language, number format) read this, so
/// drawing an amount never triggers a request; the app loads the
/// preferences once a user is signed in (see `MontraApp`).
final NotifierProvider<PreferencesSnapshot, PreferencesDto?>
preferencesSnapshotProvider =
    NotifierProvider<PreferencesSnapshot, PreferencesDto?>(
      PreferencesSnapshot.new,
    );

/// See [preferencesSnapshotProvider].
class PreferencesSnapshot extends Notifier<PreferencesDto?> {
  @override
  PreferencesDto? build() {
    ref.watch(currentUserIdProvider);
    return null;
  }

  /// Records the latest preferences from the server.
  void update(PreferencesDto preferences) => state = preferences;
}

/// The account's accessibility preferences.
@immutable
class AccessibilitySettings {
  /// Creates the settings.
  const AccessibilitySettings({
    this.reducedMotion = false,
    this.highContrast = false,
    this.textScalePercent = 100,
  });

  /// From the server's preferences.
  factory AccessibilitySettings.of(PreferencesDto? p) => p == null
      ? const AccessibilitySettings()
      : AccessibilitySettings(
          reducedMotion: p.reducedMotion,
          highContrast: p.highContrast,
          textScalePercent: p.textScalePercent.clamp(
            minTextScalePercent,
            maxTextScalePercent,
          ),
        );

  /// Smallest text size the server accepts.
  static const int minTextScalePercent = 80;

  /// Largest text size the server accepts.
  static const int maxTextScalePercent = 200;

  /// Turn animations and page transitions off.
  final bool reducedMotion;

  /// Use the high-contrast themes.
  final bool highContrast;

  /// Multiplies the device's text size (100 = unchanged).
  final int textScalePercent;

  @override
  bool operator ==(Object other) =>
      other is AccessibilitySettings &&
      other.reducedMotion == reducedMotion &&
      other.highContrast == highContrast &&
      other.textScalePercent == textScalePercent;

  @override
  int get hashCode =>
      Object.hash(reducedMotion, highContrast, textScalePercent);
}

/// The signed-in user's accessibility settings (defaults when unknown).
final Provider<AccessibilitySettings> accessibilitySettingsProvider =
    Provider<AccessibilitySettings>(
      (Ref ref) =>
          AccessibilitySettings.of(ref.watch(preferencesSnapshotProvider)),
    );

/// [data] with the account's accessibility [settings] added to the
/// device's: either one asking to reduce motion or for high contrast turns
/// it on, and the text size multiplies the device's (so 200 % on a phone
/// already set to large text gets larger still).
MediaQueryData applyAccessibility(
  MediaQueryData data,
  AccessibilitySettings settings,
) => data.copyWith(
  disableAnimations: data.disableAnimations || settings.reducedMotion,
  highContrast: data.highContrast || settings.highContrast,
  textScaler: settings.textScalePercent == 100
      ? data.textScaler
      : ScaledTextScaler(data.textScaler, settings.textScalePercent / 100),
);

/// A [TextScaler] that multiplies another one (keeps the platform's
/// nonlinear scaling).
@immutable
class ScaledTextScaler implements TextScaler {
  /// Multiplies [base] by [factor].
  const ScaledTextScaler(this.base, this.factor);

  /// The device's scaler.
  final TextScaler base;

  /// The account's multiplier (1.0 = unchanged).
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use, the interface still declares it.
  double get textScaleFactor => base.scale(14) / 14 * factor;

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) => minScaleFactor == maxScaleFactor
      ? TextScaler.linear(minScaleFactor)
      : _Clamped(this, minScaleFactor, maxScaleFactor);

  @override
  bool operator ==(Object other) =>
      other is ScaledTextScaler && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);

  @override
  String toString() => 'ScaledTextScaler($base × $factor)';
}

@immutable
class _Clamped implements TextScaler {
  const _Clamped(this.inner, this.min, this.max);

  final TextScaler inner;
  final double min;
  final double max;

  @override
  double scale(double fontSize) =>
      inner.scale(fontSize).clamp(fontSize * min, fontSize * max);

  @override
  // ignore: deprecated_member_use, the interface still declares it.
  double get textScaleFactor => scale(14) / 14;

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) => _Clamped(
    inner,
    minScaleFactor > min ? minScaleFactor : min,
    maxScaleFactor < max ? maxScaleFactor : max,
  );
}

/// Languages the app is translated into.
const Set<String> appLanguages = <String>{'en', 'hi'};

/// The app language for the account's [locale] (`hi-IN` → Hindi); null to
/// follow the device when the account has none the app is translated into.
Locale? appLocaleFor(String? locale) {
  final String language = (locale ?? '').split(RegExp('[-_]')).first;
  return appLanguages.contains(language) ? Locale(language) : null;
}

/// The app language chosen in the account's preferences (null: device).
final Provider<Locale?> appLocaleProvider = Provider<Locale?>(
  (Ref ref) => appLocaleFor(
    ref.watch(
      preferencesSnapshotProvider.select((PreferencesDto? p) => p?.locale),
    ),
  ),
);

/// The account's number format preference (`locale`, `indian` or
/// `international`); null when unknown.
final Provider<String?> numberFormatPreferenceProvider = Provider<String?>(
  (Ref ref) => ref.watch(
    preferencesSnapshotProvider.select(
      (PreferencesDto? p) => p?.numberFormat.json,
    ),
  ),
);

/// The account's date format and first day of the week (the language
/// decides both until the preferences are known).
final Provider<DateSettings> dateSettingsProvider = Provider<DateSettings>(
  (Ref ref) => ref.watch(
    preferencesSnapshotProvider.select(
      (PreferencesDto? p) => p == null
          ? DateSettings.languageDefault
          : DateSettings.fromWire(
              dateFormat: p.dateFormat.json,
              weekStart: p.weekStart,
            ),
    ),
  ),
);
