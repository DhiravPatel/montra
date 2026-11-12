import 'dart:async';

import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/credential_store.dart';

/// Why a session ended, shown on the sign-in screen.
enum SessionEndReason {
  /// The server rejected the refresh token (expired, revoked, reused).
  expired,

  /// The user signed out on this device.
  signedOut,

  /// The user signed out of every device.
  signedOutEverywhere,

  /// A password reset revoked every session.
  passwordReset,
}

/// Outcome of a token refresh.
sealed class TokenRefreshResult {
  const TokenRefreshResult();
}

/// Fresh tokens are available. [result] is null when another request had
/// already rotated the tokens.
final class TokenRefreshSucceeded extends TokenRefreshResult {
  /// Creates the result.
  const TokenRefreshSucceeded([this.result]);

  /// The refresh response, when this call performed the refresh.
  final AuthResult? result;
}

/// The server rejected the refresh token; credentials were cleared.
final class TokenRefreshRejected extends TokenRefreshResult {
  /// Creates the result.
  const TokenRefreshRejected(this.error);

  /// The rejection.
  final ApiException error;
}

/// The refresh could not complete (offline, timeout, 5xx, throttled).
/// Credentials are kept so a later attempt can succeed.
final class TokenRefreshUnavailable extends TokenRefreshResult {
  /// Creates the result.
  const TokenRefreshUnavailable(this.error);

  /// The transient failure.
  final ApiException error;
}

/// No refresh token is stored.
final class TokenRefreshNoCredentials extends TokenRefreshResult {
  /// Creates the result.
  const TokenRefreshNoCredentials();
}

/// What the auth interceptor needs from the session layer.
abstract interface class AuthTokenSource {
  /// The in-memory access token, if any.
  String? get currentAccessToken;

  /// The token to send now: waits for an in-flight refresh and proactively
  /// refreshes a token that is about to expire. Null means "not signed in".
  Future<String?> accessTokenForRequest();

  /// Called after a `401 UNAUTHENTICATED` for a request sent with
  /// [rejectedToken]. Refreshes once (single-flight) unless the token has
  /// already been rotated by a concurrent request.
  Future<TokenRefreshResult> refreshAfterUnauthorized(String? rejectedToken);
}

/// Calls `POST /auth/refresh` with a refresh token.
typedef RefreshTokenCall = Future<AuthResult> Function(String refreshToken);

/// Owns token lifetime: storing, single-flight rotation and clearing.
class SessionTokenManager implements AuthTokenSource {
  /// Creates a manager over [store] that refreshes with [refresh].
  SessionTokenManager({
    required this._store,
    required this._refresh,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Refresh this long before the access token's stated expiry, to absorb
  /// clock skew and request latency.
  static const Duration expiryMargin = Duration(seconds: 30);

  final CredentialStore _store;
  final RefreshTokenCall _refresh;
  final DateTime Function() _now;

  Future<TokenRefreshResult>? _inFlight;

  /// Incremented whenever credentials are cleared, so a refresh that was in
  /// flight during sign-out cannot resurrect the session.
  int _generation = 0;

  /// Notified when the server ends the session (refresh rejected). The auth
  /// controller uses it to route to sign-in.
  void Function(SessionEndReason reason)? onSessionEnded;

  @override
  String? get currentAccessToken => _store.accessToken;

  /// Whether an access token is held in memory.
  bool get hasAccessToken => _store.accessToken != null;

  /// Whether a refresh is currently running.
  bool get isRefreshing => _inFlight != null;

  /// Stores the tokens of a sign-in, MFA or refresh response: the access
  /// token in memory, the refresh token in secure storage.
  Future<void> adopt(AuthResult result) async {
    final String? access = result.accessToken;
    final String? refresh = result.refreshToken;
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      // A mobile client must receive body tokens; without them the request
      // probably lacked X-Montra-Client.
      throw const ApiException.invalidResponse();
    }
    _store.setAccessToken(access, result.accessExpiresAt);
    await _store.writeRefreshToken(refresh);
  }

  /// Rotates the tokens. Concurrent callers share one network call.
  Future<TokenRefreshResult> refresh() {
    final Future<TokenRefreshResult>? pending = _inFlight;
    if (pending != null) {
      return pending;
    }
    final Future<TokenRefreshResult> started = _performRefresh();
    _inFlight = started;
    unawaited(
      started.whenComplete(() {
        if (identical(_inFlight, started)) {
          _inFlight = null;
        }
      }),
    );
    return started;
  }

  @override
  Future<TokenRefreshResult> refreshAfterUnauthorized(
    String? rejectedToken,
  ) async {
    final Future<TokenRefreshResult>? pending = _inFlight;
    if (pending != null) {
      return pending;
    }
    final String? current = _store.accessToken;
    if (current != null && rejectedToken != null && current != rejectedToken) {
      return const TokenRefreshSucceeded();
    }
    return refresh();
  }

  @override
  Future<String?> accessTokenForRequest() async {
    final Future<TokenRefreshResult>? pending = _inFlight;
    if (pending != null) {
      await pending;
    }
    final DateTime? expiresAt = _store.accessExpiresAt;
    final bool expiring =
        expiresAt != null && !_now().isBefore(expiresAt.subtract(expiryMargin));
    if (_store.accessToken == null || expiring) {
      await refresh();
    }
    return _store.accessToken;
  }

  /// Forgets all credentials locally (does not call the server).
  Future<void> clear() async {
    _generation++;
    await _store.clear();
  }

  Future<TokenRefreshResult> _performRefresh() async {
    final int generation = _generation;
    final String? refreshToken = await _store.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return const TokenRefreshNoCredentials();
    }
    try {
      final AuthResult result = await _refresh(refreshToken);
      if (generation != _generation) {
        return const TokenRefreshRejected(_signedOutMeanwhile);
      }
      await adopt(result);
      return TokenRefreshSucceeded(result);
    } on ApiException catch (error) {
      if (generation != _generation) {
        return TokenRefreshRejected(error);
      }
      if (_isDefinitiveRejection(error)) {
        await clear();
        onSessionEnded?.call(SessionEndReason.expired);
        return TokenRefreshRejected(error);
      }
      return TokenRefreshUnavailable(error);
    }
  }

  static const ApiException _signedOutMeanwhile = ApiException(
    kind: ApiErrorKind.sessionEnded,
  );

  /// The server said the refresh token is unusable: clear it. Throttling,
  /// outages and transport errors are transient and keep the credentials.
  static bool _isDefinitiveRejection(ApiException error) {
    if (error.kind != ApiErrorKind.server) {
      return false;
    }
    final int status = error.statusCode ?? 0;
    return status == 400 || status == 401 || status == 403 || status == 422;
  }
}
