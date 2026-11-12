import 'dart:convert';
import 'dart:math';

/// `Idempotency-Key` handling for financial creates (docs/API.md).
///
/// The server stores the first result for a key: retrying with the same key
/// and the same body returns that result (`Idempotent-Replayed: true`), so a
/// retry after a timeout or lost connection can never create a second
/// record. The same key with a different body is refused
/// (`IDEMPOTENCY_CONFLICT`).
abstract final class Idempotency {
  /// Header name.
  static const String header = 'Idempotency-Key';

  /// Contract bounds for the key length.
  static const int minLength = 8;

  /// Contract bounds for the key length.
  static const int maxLength = 128;

  /// A fresh random key: 24 bytes from a cryptographically secure source,
  /// base64url without padding (32 characters). Keys carry no user data.
  static String generateKey([Random? random]) {
    final Random source = random ?? Random.secure();
    final List<int> bytes = List<int>.generate(24, (_) => source.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}

/// Keeps one idempotency key per logical submission of a form.
///
/// [keyFor] returns the same key while the request body stays the same, so
/// pressing "Save" again after a network failure retries the original
/// request instead of creating a duplicate. Changing any field produces a
/// new key (a different request). Call [reset] after success or after an
/// `IDEMPOTENCY_CONFLICT`.
class IdempotentSubmission {
  /// Creates the holder; [generate] is injectable for tests.
  IdempotentSubmission({String Function()? generate})
    : _generate = generate ?? Idempotency.generateKey;

  final String Function() _generate;
  String? _key;
  String? _fingerprint;

  /// The key for a request with [body].
  String keyFor(Map<String, Object?> body) {
    final String fingerprint = jsonEncode(body);
    final String? current = _key;
    if (current != null && fingerprint == _fingerprint) {
      return current;
    }
    _fingerprint = fingerprint;
    return _key = _generate();
  }

  /// Forgets the current key; the next submission gets a new one.
  void reset() {
    _key = null;
    _fingerprint = null;
  }
}
