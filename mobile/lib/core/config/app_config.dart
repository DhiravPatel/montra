import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Build-time and device configuration shared by the whole app.
///
/// Values come from `--dart-define` (see README) plus a few facts about the
/// running build (platform, version). Nothing here is secret: the mobile app
/// never holds privileged credentials (spec §1.4).
@immutable
class AppConfig {
  /// Creates a configuration. Prefer [AppConfig.resolve] in app code.
  const AppConfig({
    required this.apiBaseUrl,
    required this.clientKind,
    required this.clientVersion,
    this.deviceName,
    this.termsUrl,
    this.privacyUrl,
  });

  /// Resolves configuration from raw `--dart-define` values.
  ///
  /// Throws [AppConfigException] when the values are unusable, for example an
  /// `http://` API URL in a release build.
  factory AppConfig.resolve({
    required String apiBaseUrl,
    required TargetPlatform platform,
    required bool releaseMode,
    required String clientVersion,
    String? deviceName,
    String termsUrl = '',
    String privacyUrl = '',
  }) {
    final String raw = apiBaseUrl.trim().isNotEmpty
        ? apiBaseUrl.trim()
        : releaseMode
        ? throw const AppConfigException(
            'API_BASE_URL must be provided for release builds.',
          )
        : _developmentDefault(platform);
    final Uri? base = Uri.tryParse(raw);
    if (base == null ||
        !(base.scheme == 'https' || base.scheme == 'http') ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw const AppConfigException(
        'API_BASE_URL must be an absolute http(s) URL without credentials, '
        'query or fragment, e.g. https://api.example.com',
      );
    }
    if (releaseMode && base.scheme != 'https') {
      throw const AppConfigException(
        'Release builds must use an https:// API_BASE_URL.',
      );
    }
    return AppConfig(
      apiBaseUrl: base,
      clientKind: clientKindFor(platform),
      clientVersion: clientVersion.length > 32
          ? clientVersion.substring(0, 32)
          : clientVersion,
      deviceName: deviceName,
      termsUrl: _optionalHttpsUrl(termsUrl, releaseMode),
      privacyUrl: _optionalHttpsUrl(privacyUrl, releaseMode),
    );
  }

  /// Raw `--dart-define=API_BASE_URL=...` value (empty when not provided).
  static const String apiBaseUrlDefine = String.fromEnvironment('API_BASE_URL');

  /// Raw `--dart-define=TERMS_URL=...` value (empty when not provided).
  static const String termsUrlDefine = String.fromEnvironment('TERMS_URL');

  /// Raw `--dart-define=PRIVACY_URL=...` value (empty when not provided).
  static const String privacyUrlDefine = String.fromEnvironment('PRIVACY_URL');

  /// Terms of service version the sign-up form asks the user to accept.
  /// Must match the backend's `auth.TermsVersion`.
  static const String termsVersion = '2026-11-01';

  /// Privacy policy version the sign-up form asks the user to accept.
  /// Must match the backend's `auth.PrivacyVersion`.
  static const String privacyVersion = '2026-11-01';

  /// Origin (plus optional path prefix) of the Go API, without `/api/v1`.
  final Uri apiBaseUrl;

  /// Value of the `X-Montra-Client` header: `android`, `ios` or `unknown`.
  final String clientKind;

  /// Value of the `X-Client-Version` header, e.g. `1.0.0+1`.
  final String clientVersion;

  /// Human-readable device model sent as `device_name` at sign-in so the
  /// sessions list is recognizable. Never the user-assigned device name.
  final String? deviceName;

  /// Hosted terms of service, when configured.
  final Uri? termsUrl;

  /// Hosted privacy policy, when configured.
  final Uri? privacyUrl;

  /// Base URL for API requests: `<apiBaseUrl>/api/v1`.
  String get apiRoot {
    final String base = apiBaseUrl.toString();
    final String trimmed = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return '$trimmed/api/v1';
  }

  /// `X-Montra-Client` values this app may send (the contract also allows
  /// `web`, which is the browser portal).
  static const Set<String> declaredClientKinds = <String>{'android', 'ios'};

  /// Maps the running platform to the backend's client kinds.
  static String clientKindFor(TargetPlatform platform) => switch (platform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'unknown',
  };

  static String _developmentDefault(TargetPlatform platform) =>
      platform == TargetPlatform.android
      // The Android emulator reaches the host machine through 10.0.2.2.
      ? 'http://10.0.2.2:8080'
      : 'http://localhost:8080';

  static Uri? _optionalHttpsUrl(String raw, bool releaseMode) {
    final String value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    final Uri? uri = Uri.tryParse(value);
    final bool allowedScheme =
        uri != null &&
        (uri.scheme == 'https' || (!releaseMode && uri.scheme == 'http'));
    if (!allowedScheme || uri.host.isEmpty) {
      throw AppConfigException('Invalid document URL: $value');
    }
    return uri;
  }
}

/// Raised when build-time configuration is missing or unsafe.
class AppConfigException implements Exception {
  /// Creates the exception.
  const AppConfigException(this.message);

  /// Developer-facing explanation (contains no secrets).
  final String message;

  @override
  String toString() => 'AppConfigException: $message';
}

/// The resolved [AppConfig]. Overridden in `main()` (and in tests).
final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (Ref ref) => throw StateError('appConfigProvider must be overridden'),
);
