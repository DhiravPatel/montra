import 'package:montra_mobile/core/storage/secure_store.dart';

/// Holds the session credentials (ADR-002, mobile variant).
///
/// * The **access token** lives in memory only and disappears with the
///   process. It is never written to disk.
/// * The **refresh token** is the only persisted credential, stored through
///   [SecureStore] (Keychain / Keystore).
class CredentialStore {
  /// Creates a store persisting the refresh token in [secureStore].
  CredentialStore(this._secureStore);

  /// Secure-storage key of the refresh token.
  static const String refreshTokenKey = 'montra.auth.refresh_token';

  final SecureStore _secureStore;
  String? _accessToken;
  DateTime? _accessExpiresAt;

  /// The current access token (memory only).
  String? get accessToken => _accessToken;

  /// When the current access token expires, if the server said so.
  DateTime? get accessExpiresAt => _accessExpiresAt;

  /// Replaces the in-memory access token.
  void setAccessToken(String token, DateTime? expiresAt) {
    _accessToken = token;
    _accessExpiresAt = expiresAt;
  }

  /// Reads the persisted refresh token.
  Future<String?> readRefreshToken() => _secureStore.read(refreshTokenKey);

  /// Persists a (rotated) refresh token. Returns false when secure storage
  /// failed; the session then lasts only as long as the process.
  Future<bool> writeRefreshToken(String token) async {
    try {
      await _secureStore.write(refreshTokenKey, token);
      return true;
    } on Exception {
      return false;
    }
  }

  /// Forgets every credential (memory and secure storage).
  Future<void> clear() async {
    _accessToken = null;
    _accessExpiresAt = null;
    await _secureStore.delete(refreshTokenKey);
  }
}
