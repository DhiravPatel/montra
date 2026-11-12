import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:montra_mobile/core/api/connectivity.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/config/app_config.dart';
import 'package:montra_mobile/core/storage/secure_store.dart';

/// Configuration used by tests (no network access happens: every request is
/// answered by a [FakeHttpAdapter] or a mock API).
final AppConfig testConfig = AppConfig.resolve(
  apiBaseUrl: 'http://localhost:8080',
  platform: TargetPlatform.android,
  releaseMode: false,
  clientVersion: '1.0.0+1',
  deviceName: 'Google Pixel 8',
);

/// Records requests and answers them with [handler].
class FakeHttpAdapter implements HttpClientAdapter {
  /// Creates the adapter.
  FakeHttpAdapter(this.handler);

  /// Produces the response for a request.
  Future<ResponseBody> Function(RequestOptions options) handler;

  /// Every request received, in order.
  final List<RequestOptions> requests = <RequestOptions>[];

  /// Requests whose path ends with [suffix].
  List<RequestOptions> requestsTo(String suffix) => requests
      .where((RequestOptions r) => r.uri.path.endsWith(suffix))
      .toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// A JSON response body.
ResponseBody jsonResponse(
  int status,
  Object? body, {
  Map<String, List<String>> headers = const <String, List<String>>{},
}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    ...headers,
  },
);

/// Standard success envelope.
Map<String, Object?> envelope(Object? data, {String requestId = 'req-ok'}) =>
    <String, Object?>{
      'data': data,
      'meta': <String, Object?>{
        'request_id': requestId,
        'timestamp': '2026-11-04T10:00:00Z',
      },
    };

/// Standard error envelope for a contract error [code].
Map<String, Object?> errorBody(
  ErrorObjectCode code, {
  String message = 'Server message',
  List<Map<String, Object?>> details = const <Map<String, Object?>>[],
  String requestId = 'req-err',
}) => <String, Object?>{
  'error': <String, Object?>{
    'code': code.json,
    'message': message,
    'details': details,
    'request_id': requestId,
  },
};

/// A `UserDTO` JSON object. [onboardingCompleted] defaults to true (a
/// returning user); pass false for a brand-new account.
Map<String, Object?> userJson({
  bool mfaEnabled = false,
  bool onboardingCompleted = true,
}) => <String, Object?>{
  'id': '7b0b6a52-9d7e-4a4e-9d43-1d3f0c3a9a11',
  'email': 'asha@example.com',
  'email_verified': true,
  'display_name': 'Asha',
  'locale': 'en-IN',
  'timezone': 'Asia/Kolkata',
  'base_currency': 'INR',
  'mfa_enabled': mfaEnabled,
  'onboarding_completed': onboardingCompleted,
  'platform_role': 'user',
  'created_at': '2026-11-01T08:00:00Z',
};

/// A `SessionDTO` JSON object.
Map<String, Object?> sessionJson({
  String id = 'a1b2c3d4-0000-4000-8000-000000000001',
  String clientKind = 'android',
  String? deviceName = 'Google Pixel 8',
  bool current = true,
  String lastSeenAt = '2026-11-04T09:55:00Z',
  bool mfaVerified = false,
}) => <String, Object?>{
  'id': id,
  'client_kind': clientKind,
  'device_name': ?deviceName,
  'created_at': '2026-11-01T08:00:00Z',
  'last_seen_at': lastSeenAt,
  'mfa_verified': mfaVerified,
  'current': current,
};

/// An authenticated `AuthResult` JSON object.
Map<String, Object?> authResultJson({
  String access = 'access-1',
  String refresh = 'refresh-1',
  bool mfaEnabled = false,
  bool onboardingCompleted = true,
}) => <String, Object?>{
  'status': 'authenticated',
  'access_token': access,
  'refresh_token': refresh,
  'access_expires_at': '2099-01-01T00:15:00Z',
  'refresh_expires_at': '2099-01-31T00:00:00Z',
  'user': userJson(
    mfaEnabled: mfaEnabled,
    onboardingCompleted: onboardingCompleted,
  ),
  'session': sessionJson(),
};

/// [SecureStore] kept in memory.
class MemorySecureStore implements SecureStore {
  /// Stored values.
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}

/// [ConnectivityMonitor] with a controllable state.
class FakeConnectivityMonitor implements ConnectivityMonitor {
  /// Creates the monitor, initially [online].
  FakeConnectivityMonitor({this._online = true});

  bool _online;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  /// Changes the reported state.
  void set(bool online) {
    _online = online;
    _changes.add(online);
  }

  @override
  Stream<bool> watchOnline() async* {
    yield _online;
    yield* _changes.stream;
  }

  /// Releases the stream.
  Future<void> dispose() => _changes.close();
}
