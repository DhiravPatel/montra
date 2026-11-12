import 'package:montra_mobile/core/api/generated/models.dart';

export 'package:montra_mobile/core/api/generated/models.dart'
    show ErrorObjectCode;

/// Helpers around the contract's closed error-code enum ([ErrorObjectCode],
/// generated from `ErrorObject.code`). `docs/API.md` lists the HTTP status
/// and the expected client action for every code; clients branch on the
/// code, never on message text or on the status alone.
abstract final class ApiErrorCodes {
  /// Code for an error response whose body is not the standard envelope
  /// (for example a proxy's HTML page), mirroring the backend's
  /// `apperr.CodeForStatus`.
  static ErrorObjectCode forStatus(int status) => switch (status) {
    400 || 422 => ErrorObjectCode.validationError,
    401 => ErrorObjectCode.unauthenticated,
    403 => ErrorObjectCode.forbidden,
    404 => ErrorObjectCode.notFound,
    409 => ErrorObjectCode.conflict,
    410 => ErrorObjectCode.gone,
    413 => ErrorObjectCode.payloadTooLarge,
    415 => ErrorObjectCode.unsupportedMediaType,
    429 => ErrorObjectCode.rateLimited,
    408 || 504 => ErrorObjectCode.timeout,
    503 => ErrorObjectCode.serviceUnavailable,
    >= 500 => ErrorObjectCode.internalError,
    _ => ErrorObjectCode.badRequest,
  };

  /// The 401 codes that are business answers, not an expired session: the
  /// auth interceptor must never refresh tokens for them.
  static const Set<ErrorObjectCode> noRefresh401 = <ErrorObjectCode>{
    ErrorObjectCode.mfaRequired,
    ErrorObjectCode.mfaCodeInvalid,
    ErrorObjectCode.mfaChallengeExpired,
    ErrorObjectCode.reauthRequired,
  };
}
