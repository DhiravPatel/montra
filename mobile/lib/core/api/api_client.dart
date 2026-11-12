import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/interceptors/auth_interceptor.dart';
import 'package:montra_mobile/core/api/interceptors/safe_log_interceptor.dart';
import 'package:montra_mobile/core/auth/session_tokens.dart';
import 'package:montra_mobile/core/config/app_config.dart';

/// Creates a [Dio] configured for the Montra API.
///
/// Every request carries the contract's client headers
/// (`components.parameters.MontraClient` / `ClientVersion`):
/// `X-Montra-Client` (`android` or `ios`) and `X-Client-Version`. The backend
/// uses the client kind to return mobile tokens in the response body instead
/// of web cookies. On other platforms (tests, desktop) the client header is
/// omitted because the contract only allows `web | android | ios`; the
/// server then treats the caller as a non-web client. `X-CSRF-Token` is never
/// needed: it applies to cookie sessions only, and the app uses bearer
/// tokens. When [tokens] is given an [AuthInterceptor] is installed; the
/// refresh client is created without one so refreshing can never recurse.
Dio createApiDio(
  AppConfig config, {
  AuthTokenSource? tokens,
  HttpClientAdapter? adapter,
  bool enableLogging = kDebugMode,
}) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: config.apiRoot,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      contentType: Headers.jsonContentType,
      headers: <String, Object?>{
        Headers.acceptHeader: Headers.jsonContentType,
        if (AppConfig.declaredClientKinds.contains(config.clientKind))
          'X-Montra-Client': config.clientKind,
        'X-Client-Version': config.clientVersion,
      },
    ),
  );
  if (adapter != null) {
    dio.httpClientAdapter = adapter;
  }
  if (tokens != null) {
    dio.interceptors.add(AuthInterceptor(tokens: tokens, retryClient: dio));
  }
  if (enableLogging) {
    dio.interceptors.add(SafeLogInterceptor());
  }
  return dio;
}

/// The body of a file download (`GET /files/{fileId}/content`).
@immutable
class DownloadedBytes {
  /// Creates the download.
  const DownloadedBytes({
    required this.bytes,
    this.contentType,
    this.contentDisposition,
  });

  /// The file content.
  final Uint8List bytes;

  /// `Content-Type` as served.
  final String? contentType;

  /// `Content-Disposition` as served (carries the file name).
  final String? contentDisposition;

  @override
  String toString() => 'DownloadedBytes(${bytes.length} bytes)';
}

/// Thin typed wrapper around [Dio]: sends one [ApiEndpoint] and decodes the
/// success envelope, converting every failure into an [ApiException].
class ApiClient {
  /// Wraps [dio] (see [createApiDio]).
  ApiClient(this._dio);

  final Dio _dio;

  /// Sends [endpoint] with an optional JSON [body] and decodes the response
  /// object with [decode] (normally a generated `decodeEnvelope*` function).
  ///
  /// [query] values are encoded with [encodeQuery]; [headers] adds
  /// per-request headers such as `Idempotency-Key`. Neither is ever logged
  /// (see `SafeLogInterceptor`).
  Future<T> send<T>(
    ApiEndpoint endpoint, {
    required T Function(Map<String, Object?> json) decode,
    Map<String, Object?>? body,
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, Object?> query = const <String, Object?>{},
    Map<String, String> headers = const <String, String>{},
    CancelToken? cancelToken,
  }) async {
    final Response<Object?> response;
    try {
      response = await _dio.request<Object?>(
        endpoint.resolve(pathParameters),
        data: body,
        queryParameters: encodeQuery(query),
        cancelToken: cancelToken,
        options: Options(
          method: endpoint.method,
          headers: headers.isEmpty ? null : headers,
          extra: <String, Object?>{
            AuthExtras.requiresAuth: endpoint.requiresAuth,
            AuthExtras.endpoint: endpoint.path,
          },
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
    final Object? data = response.data;
    final String? requestId = response.headers.value('x-request-id');
    if (data is! Map<String, Object?>) {
      throw ApiException.invalidResponse(
        statusCode: response.statusCode,
        requestId: requestId,
      );
    }
    try {
      return decode(data);
    } on FormatException {
      throw ApiException.invalidResponse(
        statusCode: response.statusCode,
        requestId: requestId,
      );
    }
  }

  /// Sends raw [bytes] as `application/octet-stream` to [endpoint] (used for
  /// `PUT /files/{fileId}/content`) and decodes the JSON envelope answer.
  ///
  /// [onSendProgress] reports bytes sent so far; [headers] carries the
  /// upload token. Neither the body nor the headers are ever logged.
  Future<T> sendBytes<T>(
    ApiEndpoint endpoint, {
    required Uint8List bytes,
    required T Function(Map<String, Object?> json) decode,
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> headers = const <String, String>{},
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final Response<Object?> response;
    try {
      response = await _dio.request<Object?>(
        endpoint.resolve(pathParameters),
        data: bytes,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        options: Options(
          method: endpoint.method,
          contentType: 'application/octet-stream',
          headers: headers.isEmpty ? null : headers,
          extra: <String, Object?>{
            AuthExtras.requiresAuth: endpoint.requiresAuth,
            AuthExtras.endpoint: endpoint.path,
          },
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
    final Object? data = response.data;
    final String? requestId = response.headers.value('x-request-id');
    if (data is! Map<String, Object?>) {
      throw ApiException.invalidResponse(
        statusCode: response.statusCode,
        requestId: requestId,
      );
    }
    try {
      return decode(data);
    } on FormatException {
      throw ApiException.invalidResponse(
        statusCode: response.statusCode,
        requestId: requestId,
      );
    }
  }

  /// Downloads the bytes behind a signed URL from `GET /files/{id}/access`
  /// or `GET /reports/{id}/download` (`Access.url`).
  ///
  /// Only this API's own `files/{id}/content` downloads are accepted, and
  /// they are always fetched from the configured API origin: the server may
  /// sign URLs with its public host, which a device or emulator cannot
  /// always reach. The signature in the query string authorizes the
  /// download, so no bearer token is sent. The URL is never logged.
  Future<DownloadedBytes> downloadSigned(
    String signedUrl, {
    void Function(int received, int total)? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    final Uri url = resolveSignedUrl(signedUrl);
    final Response<List<int>> response;
    try {
      response = await _dio.getUri<List<int>>(
        url,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        options: Options(
          responseType: ResponseType.bytes,
          headers: <String, Object?>{Headers.acceptHeader: '*/*'},
          extra: <String, Object?>{
            AuthExtras.requiresAuth: false,
            AuthExtras.endpoint: ApiEndpoints.downloadFile.path,
          },
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(_withJsonErrorBody(error));
    }
    final List<int>? data = response.data;
    if (data == null) {
      throw ApiException.invalidResponse(statusCode: response.statusCode);
    }
    return DownloadedBytes(
      bytes: data is Uint8List ? data : Uint8List.fromList(data),
      contentType: response.headers.value(Headers.contentTypeHeader),
      contentDisposition: response.headers.value('content-disposition'),
    );
  }

  /// The URL [downloadSigned] fetches for [signedUrl]: the same path and
  /// signed query on the configured API origin. Throws an
  /// [ApiException] (invalid response) for anything that is not this
  /// API's file download.
  Uri resolveSignedUrl(String signedUrl) {
    final Uri? signed = Uri.tryParse(signedUrl);
    final Uri base = Uri.parse(_dio.options.baseUrl);
    final String apiPath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final bool ok =
        signed != null &&
        RegExp('^${RegExp.escape(apiPath)}/files/[A-Za-z0-9-]+/content\$')
            .hasMatch(signed.path);
    if (!ok) {
      throw const ApiException.invalidResponse();
    }
    return base.replace(path: signed.path, query: signed.query);
  }

  /// Error bodies of byte downloads arrive as bytes; decode the JSON error
  /// envelope so [ApiException.fromDio] can read its code.
  static DioException _withJsonErrorBody(DioException error) {
    final Response<Object?>? response = error.response;
    final Object? data = response?.data;
    if (response == null || data is! List<int>) {
      return error;
    }
    try {
      final Object? json = jsonDecode(utf8.decode(data));
      return error.copyWith(
        response: Response<Object?>(
          requestOptions: response.requestOptions,
          data: json,
          statusCode: response.statusCode,
          headers: response.headers,
        ),
      );
    } on FormatException {
      return error;
    }
  }

  /// Encodes query parameters the way the contract declares them.
  ///
  /// * `null`, empty strings and empty lists are left out.
  /// * Lists become one comma-separated value (`type=expense,refund`): the
  ///   contract declares every array parameter with `explode: false`, and
  ///   the server keeps only the first of repeated parameters.
  /// * Booleans and numbers use their canonical string form.
  static Map<String, String> encodeQuery(Map<String, Object?> query) {
    final Map<String, String> out = <String, String>{};
    for (final MapEntry<String, Object?> entry in query.entries) {
      final Object? value = entry.value;
      final String? encoded = switch (value) {
        null => null,
        final String s => s.isEmpty ? null : s,
        final Iterable<Object?> items => _joinList(items),
        final bool b => b ? 'true' : 'false',
        final num n => n.toString(),
        _ => throw ArgumentError('Unsupported query value for ${entry.key}'),
      };
      if (encoded != null) {
        out[entry.key] = encoded;
      }
    }
    return out;
  }

  static String? _joinList(Iterable<Object?> items) {
    final List<String> parts = <String>[
      for (final Object? item in items)
        if (item != null && item.toString().isNotEmpty) item.toString(),
    ];
    return parts.isEmpty ? null : parts.join(',');
  }
}
