import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key/value interface over the platform's secure storage
/// (iOS Keychain, Android Keystore-backed encrypted storage).
///
/// Only credentials belong here — today that is just the refresh token. The
/// access token stays in memory and finance data is never persisted
/// unencrypted (spec §20B.23). The interface exists so tests can verify what
/// is (and is not) written without touching platform channels.
abstract interface class SecureStore {
  /// Returns the stored value, or null when absent or unreadable.
  Future<String?> read(String key);

  /// Stores [value] under [key], replacing any previous value.
  Future<void> write(String key, String value);

  /// Removes [key]. Succeeds when the key is absent.
  Future<void> delete(String key);

  /// Removes every value written by this app.
  Future<void> deleteAll();
}

/// [SecureStore] backed by `flutter_secure_storage`.
class FlutterSecureStore implements SecureStore {
  /// Wraps [storage]; defaults to [defaultStorage].
  FlutterSecureStore([FlutterSecureStorage? storage])
    : _storage = storage ?? defaultStorage;

  /// Platform options used for every operation.
  ///
  /// * iOS: `first_unlock_this_device` keeps items available after the first
  ///   unlock (needed for background refresh) and prevents them from
  ///   migrating to another device through backups or iCloud Keychain.
  /// * Android: AES-GCM data encryption with a Keystore-wrapped key (the
  ///   plugin default). `resetOnError` drops unreadable data, e.g. after a
  ///   restore onto a device that lacks the original Keystore key.
  static const FlutterSecureStorage defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(),
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException {
      // A corrupted or inaccessible item is treated as absent; the user signs
      // in again instead of the app crashing. The error is not logged because
      // platform messages can echo stored values.
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } on PlatformException {
      // Nothing more can be done; a later write overwrites the item.
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } on PlatformException {
      // See delete().
    }
  }
}

/// The app-wide [SecureStore]. Overridden in tests.
final Provider<SecureStore> secureStoreProvider = Provider<SecureStore>(
  (Ref ref) => FlutterSecureStore(),
);
