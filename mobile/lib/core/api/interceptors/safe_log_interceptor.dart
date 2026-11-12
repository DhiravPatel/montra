import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:montra_mobile/core/api/interceptors/auth_interceptor.dart';

/// Debug-only request logging that cannot leak secrets or personal data.
///
/// Logs the method, the endpoint *template* (never concrete IDs, query
/// strings, headers or bodies), the status and the request ID. It is only
/// installed in debug builds.
class SafeLogInterceptor extends Interceptor {
  /// Creates the interceptor; [log] defaults to [debugPrint].
  SafeLogInterceptor({void Function(String line)? log})
    : _log = log ?? ((String line) => debugPrint(line));

  final void Function(String line) _log;

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    _log(
      '[api] ${_describe(response.requestOptions)} -> ${response.statusCode} '
      '(${response.headers.value('x-request-id') ?? '-'})',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final Response<Object?>? response = err.response;
    _log(
      '[api] ${_describe(err.requestOptions)} -> '
      '${response?.statusCode ?? err.type.name} '
      '(${response?.headers.value('x-request-id') ?? '-'})',
    );
    handler.next(err);
  }

  static String _describe(RequestOptions options) {
    final Object? template = options.extra[AuthExtras.endpoint];
    return '${options.method} ${template is String ? template : '?'}';
  }
}
