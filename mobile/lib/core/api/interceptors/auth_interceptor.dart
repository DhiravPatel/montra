import 'package:dio/dio.dart';
import 'package:montra_mobile/core/api/api_error_code.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/auth/session_tokens.dart';

/// `RequestOptions.extra` keys understood by [AuthInterceptor].
abstract final class AuthExtras {
  /// Set to true for operations that need `Authorization: Bearer`.
  static const String requiresAuth = 'montra.requiresAuth';

  /// Set on the single retry after a token refresh (prevents loops).
  static const String retried = 'montra.authRetried';

  /// Endpoint path template, used for privacy-safe logging.
  static const String endpoint = 'montra.endpoint';
}

/// Attaches the in-memory access token and recovers from expired tokens.
///
/// * Public operations are sent untouched.
/// * Protected operations wait for any in-flight refresh, then carry
///   `Authorization: Bearer <access token>`.
/// * A `401` whose code is `UNAUTHENTICATED` triggers one single-flight
///   `POST /auth/refresh` (concurrent failures share it) and one retry.
///   Other 401 codes (`REAUTH_REQUIRED`, `MFA_REQUIRED`, `MFA_CODE_INVALID`,
///   `MFA_CHALLENGE_EXPIRED`) are business responses and pass through
///   unchanged.
/// * If the server rejects the refresh token, [AuthTokenSource] clears the
///   credentials and ends the session; the caller receives a
///   [ApiErrorKind.sessionEnded] error and the router shows sign-in.
class AuthInterceptor extends Interceptor {
  /// Creates the interceptor. [retryClient] re-sends requests after a refresh
  /// and is normally the same [Dio] instance this interceptor is added to.
  AuthInterceptor({required this._tokens, required this._retryClient});

  final AuthTokenSource _tokens;
  final Dio _retryClient;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[AuthExtras.requiresAuth] != true) {
      handler.next(options);
      return;
    }
    final String? token = await _tokens.accessTokenForRequest();
    if (token == null) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: const SessionEndedSignal(),
        ),
      );
      return;
    }
    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions options = err.requestOptions;
    final Response<Object?>? response = err.response;
    if (options.extra[AuthExtras.requiresAuth] != true ||
        options.extra[AuthExtras.retried] == true ||
        response?.statusCode != 401 ||
        !_isSessionFailure(response?.data)) {
      handler.next(err);
      return;
    }

    final TokenRefreshResult result = await _tokens.refreshAfterUnauthorized(
      _bearerOf(options),
    );
    switch (result) {
      case TokenRefreshSucceeded():
        final String? token = _tokens.currentAccessToken;
        if (token == null) {
          handler.next(_sessionEnded(options));
          return;
        }
        final RequestOptions retry = options.copyWith(
          headers: <String, Object?>{
            ...options.headers,
            'Authorization': 'Bearer $token',
          },
          extra: <String, Object?>{...options.extra, AuthExtras.retried: true},
        );
        try {
          handler.resolve(await _retryClient.fetch<Object?>(retry));
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      case TokenRefreshUnavailable(:final ApiException error):
        // Keep credentials; surface the transport problem (e.g. offline) so
        // the screen can offer a retry.
        handler.next(DioException(requestOptions: options, error: error));
      case TokenRefreshRejected() || TokenRefreshNoCredentials():
        handler.next(_sessionEnded(options));
    }
  }

  static DioException _sessionEnded(RequestOptions options) =>
      DioException(requestOptions: options, error: const SessionEndedSignal());

  static String? _bearerOf(RequestOptions options) {
    final Object? header = options.headers['Authorization'];
    if (header is String && header.startsWith('Bearer ')) {
      return header.substring('Bearer '.length);
    }
    return null;
  }

  /// A 401 means "session expired" unless the body names another code.
  static bool _isSessionFailure(Object? body) {
    if (body is Map<String, Object?>) {
      final Object? error = body['error'];
      if (error is Map<String, Object?>) {
        final Object? code = error['code'];
        if (code is String) {
          // Only UNAUTHENTICATED means "expired session". MFA_REQUIRED,
          // MFA_CODE_INVALID, MFA_CHALLENGE_EXPIRED and REAUTH_REQUIRED are
          // 401 business answers (docs/API.md) and must not refresh.
          return ErrorObjectCode.fromJson(code) ==
              ErrorObjectCode.unauthenticated;
        }
      }
    }
    return true;
  }
}
