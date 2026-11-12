import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:montra_mobile/core/api/api_error_code.dart';
import 'package:montra_mobile/core/api/generated/models.dart';

/// Broad category of an API failure, used to pick the right UI state.
enum ApiErrorKind {
  /// The server answered with the standard error envelope.
  server,

  /// The device could not reach the server (offline, DNS, TLS, refused).
  network,

  /// The request timed out on the device.
  timeout,

  /// The request was cancelled by the app.
  cancelled,

  /// The server answered with something the client cannot decode.
  invalidResponse,

  /// The session ended (refresh rejected, signed out) before or during the
  /// request. The router takes the user to sign-in; screens stay quiet.
  sessionEnded,

  /// Anything else.
  unknown,
}

/// Signal used by the auth interceptor when a request cannot be authorized
/// because the session has ended.
class SessionEndedSignal implements Exception {
  /// Creates the signal.
  const SessionEndedSignal();
}

/// A failed API call, normalized from the error envelope
/// `{"error": {"code", "message", "details", "request_id"}}` or from a
/// transport failure.
///
/// [code] is the contract's closed error-code enum ([ErrorObjectCode]) for
/// server answers and null for failures detected on the device ([kind]
/// tells which). [message] is the server's safe, human-readable text;
/// screens prefer localized text keyed by [code] and fall back to it.
/// `toString()` never includes request data.
@immutable
class ApiException implements Exception {
  /// Creates an exception.
  const ApiException({
    required this.kind,
    this.code,
    this.rawCode,
    this.message = '',
    this.statusCode,
    this.details = const <Detail>[],
    this.requestId,
    this.retryAfter,
  });

  /// A 2xx response whose body does not match the contract.
  const ApiException.invalidResponse({this.statusCode, this.requestId})
    : kind = ApiErrorKind.invalidResponse,
      code = null,
      rawCode = null,
      message = '',
      details = const <Detail>[],
      retryAfter = null;

  /// Normalizes any [DioException].
  factory ApiException.fromDio(DioException error) {
    final Object? cause = error.error;
    if (cause is ApiException) {
      return cause;
    }
    if (cause is SessionEndedSignal) {
      return const ApiException(kind: ApiErrorKind.sessionEnded);
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(kind: ApiErrorKind.timeout);
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const ApiException(kind: ApiErrorKind.network);
      case DioExceptionType.cancel:
        return const ApiException(kind: ApiErrorKind.cancelled);
      case DioExceptionType.badResponse:
        final Response<Object?>? response = error.response;
        if (response != null) {
          return ApiException.fromResponse(response);
        }
        return const ApiException(kind: ApiErrorKind.unknown);
      case DioExceptionType.unknown:
        if (cause is SocketException || cause is HandshakeException) {
          return const ApiException(kind: ApiErrorKind.network);
        }
        return const ApiException(kind: ApiErrorKind.unknown);
    }
  }

  /// Parses an error response. Falls back to a status-derived code when the
  /// body is not the standard envelope (for example a proxy's HTML page).
  factory ApiException.fromResponse(
    Response<Object?> response, {
    DateTime? now,
  }) {
    final int status = response.statusCode ?? 0;
    final String? headerRequestId = response.headers.value('x-request-id');
    final Duration? retryAfter = parseRetryAfter(
      response.headers.value('retry-after'),
      now: now,
    );
    final ErrorObject? envelope = _tryParseError(response.data);
    if (envelope == null) {
      return ApiException(
        kind: ApiErrorKind.server,
        code: ApiErrorCodes.forStatus(status),
        statusCode: status,
        requestId: headerRequestId,
        retryAfter: retryAfter,
      );
    }
    return ApiException(
      kind: ApiErrorKind.server,
      code: envelope.code,
      // Keep the wire value: a newer server may send a code this client
      // decodes as `unrecognized`.
      rawCode: _rawCodeOf(response.data),
      message: envelope.message,
      statusCode: status,
      details: envelope.details,
      requestId: envelope.requestId.isNotEmpty
          ? envelope.requestId
          : headerRequestId,
      retryAfter: retryAfter,
    );
  }

  /// Failure category.
  final ApiErrorKind kind;

  /// Server error code from the contract enum; null for client-side
  /// failures (network, timeout, cancelled, invalid response, session ended).
  final ErrorObjectCode? code;

  /// The server's code exactly as received, useful when [code] is
  /// [ErrorObjectCode.unrecognized].
  final String? rawCode;

  /// Safe human-readable message from the server; empty for client errors.
  final String message;

  /// HTTP status, when a response was received.
  final int? statusCode;

  /// Field-level problems (`details[]`).
  final List<Detail> details;

  /// Correlation ID to quote to support.
  final String? requestId;

  /// How long to wait before retrying, from the `Retry-After` header.
  final Duration? retryAfter;

  /// True when the device could not reach the server.
  bool get isConnectivityProblem =>
      kind == ApiErrorKind.network || kind == ApiErrorKind.timeout;

  /// True for authorization failures that should show a permission state.
  bool get isPermissionDenied => code == ErrorObjectCode.forbidden;

  /// True when the server is throttling the caller.
  bool get isThrottled =>
      code == ErrorObjectCode.rateLimited ||
      code == ErrorObjectCode.loginThrottled;

  /// Field errors keyed by request body member, e.g. `password` for a detail
  /// whose field is `body.password`. The first message per field wins.
  Map<String, String> get bodyFieldErrors {
    final Map<String, String> result = <String, String>{};
    for (final Detail detail in details) {
      final String? key = bodyFieldOf(detail.field);
      if (key != null) {
        result.putIfAbsent(key, () => detail.message);
      }
    }
    return result;
  }

  /// Maps a detail location such as `body.password` or `body.items[0].x` to
  /// its top-level body member (`password`, `items`). Returns null for
  /// non-body locations (`path.sessionId`, `query.cursor`) or a missing field.
  static String? bodyFieldOf(String? field) {
    if (field == null || !field.startsWith('body.')) {
      return null;
    }
    final String rest = field.substring('body.'.length);
    final Match? match = RegExp(r'^[A-Za-z0-9_]+').firstMatch(rest);
    return match?.group(0);
  }

  /// Parses `Retry-After` as delta-seconds or an HTTP date.
  static Duration? parseRetryAfter(String? value, {DateTime? now}) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final String trimmed = value.trim();
    final int? seconds = int.tryParse(trimmed);
    if (seconds != null) {
      return seconds < 0 ? null : Duration(seconds: seconds);
    }
    try {
      final DateTime at = HttpDate.parse(trimmed);
      final Duration delta = at.difference((now ?? DateTime.now()).toUtc());
      return delta.isNegative ? Duration.zero : delta;
    } on HttpException {
      return null;
    }
  }

  static String? _rawCodeOf(Object? body) {
    if (body is Map<String, Object?>) {
      final Object? error = body['error'];
      if (error is Map<String, Object?>) {
        final Object? code = error['code'];
        return code is String ? code : null;
      }
    }
    return null;
  }

  static ErrorObject? _tryParseError(Object? body) {
    if (body is! Map<String, Object?>) {
      return null;
    }
    try {
      return ErrorResponse.fromJson(body).error;
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() =>
      'ApiException(${rawCode ?? code?.json ?? kind.name}, '
      'status: ${statusCode ?? '-'}, request: ${requestId ?? '-'})';
}
