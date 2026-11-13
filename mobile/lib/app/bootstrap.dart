import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:montra_mobile/app/theme/theme_mode_controller.dart';
import 'package:montra_mobile/core/config/app_config.dart';
import 'package:montra_mobile/core/storage/preferences_store.dart';
import 'package:montra_mobile/core/storage/secure_store.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Startup work that must finish before the first frame: configuration,
/// app version, device model and stored preferences.
abstract final class Bootstrap {
  /// Loads everything and returns the provider overrides for the app.
  ///
  /// Throws [AppConfigException] when the build is misconfigured.
  static Future<List<Override>> load() async {
    final String version = await _clientVersion();
    final String? deviceName = await _deviceName();
    final AppConfig config = AppConfig.resolve(
      apiBaseUrl: AppConfig.apiBaseUrlDefine,
      platform: defaultTargetPlatform,
      releaseMode: kReleaseMode,
      clientVersion: version,
      deviceName: deviceName,
      termsUrl: AppConfig.termsUrlDefine,
      privacyUrl: AppConfig.privacyUrlDefine,
      statusPageUrl: AppConfig.statusPageUrlDefine,
    );

    final PreferencesStore preferences = SharedPreferencesStore();
    final SecureStore secureStore = FlutterSecureStore();
    // iOS keeps Keychain items after an app is deleted. On the first launch
    // of a fresh install, drop anything a previous install left behind so a
    // reinstall never silently restores an old session.
    if (!await preferences.hasInstallMarker()) {
      await secureStore.deleteAll();
      await preferences.writeInstallMarker();
    }
    final ThemeMode themeMode =
        await preferences.readThemeMode() ?? ThemeMode.system;

    return <Override>[
      appConfigProvider.overrideWithValue(config),
      preferencesStoreProvider.overrideWithValue(preferences),
      secureStoreProvider.overrideWithValue(secureStore),
      initialThemeModeProvider.overrideWithValue(themeMode),
    ];
  }

  static Future<String> _clientVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      return info.buildNumber.isEmpty
          ? info.version
          : '${info.version}+${info.buildNumber}';
    } on Exception {
      return '0.0.0';
    }
  }

  /// Device model for the sessions list ("Google Pixel 8", "iPhone 15").
  /// Deliberately not the user-assigned device name, which often contains
  /// the owner's name.
  static Future<String?> _deviceName() async {
    try {
      final DeviceInfoPlugin plugin = DeviceInfoPlugin();
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final AndroidDeviceInfo info = await plugin.androidInfo;
          final String maker = info.manufacturer.isEmpty
              ? ''
              : info.manufacturer[0].toUpperCase() +
                    info.manufacturer.substring(1);
          final String model = info.model;
          final String name =
              model.toLowerCase().startsWith(maker.toLowerCase())
              ? model
              : '$maker $model';
          return _clip(name.trim());
        case TargetPlatform.iOS:
          final IosDeviceInfo info = await plugin.iosInfo;
          return _clip(info.modelName.isNotEmpty ? info.modelName : info.model);
        default:
          return null;
      }
    } on Exception {
      return null;
    }
  }

  static String? _clip(String value) {
    if (value.isEmpty) {
      return null;
    }
    return value.length > 120 ? value.substring(0, 120) : value;
  }
}
