import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/api_error_code.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_api.dart';
import 'package:montra_mobile/core/auth/credential_store.dart';
import 'package:montra_mobile/core/auth/session_tokens.dart';

import '../../helpers/fakes.dart';

/// A tiny fake Montra API: a protected `/me/sessions` that accepts exactly
/// one access token, and `/auth/refresh` that rotates tokens.
class FakeApi {
  FakeApi() {
    adapter = FakeHttpAdapter(_handle);
  }

  late final FakeHttpAdapter adapter;

  String validAccess = 'access-2';
  String validRefresh = 'refresh-1';
  int rotation = 1;
  int refreshCalls = 0;

  /// Overrides the refresh behaviour.
  Future<ResponseBody> Function(RequestOptions options)? refreshOverride;

  /// Overrides the protected endpoint behaviour.
  Future<ResponseBody> Function(RequestOptions options)? sessionsOverride;

  Future<ResponseBody> _handle(RequestOptions options) async {
    final String path = options.uri.path;
    if (path.endsWith('/auth/refresh')) {
      refreshCalls++;
      if (refreshOverride != null) {
        return refreshOverride!(options);
      }
      // Simulate latency so concurrent 401s pile up behind one refresh.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final Object? body = options.data;
      final String? token = body is Map<String, Object?>
          ? body['refresh_token'] as String?
          : null;
      if (token != validRefresh) {
        return jsonResponse(401, errorBody(ErrorObjectCode.unauthenticated));
      }
      rotation++;
      validAccess = 'access-$rotation';
      validRefresh = 'refresh-$rotation';
      return jsonResponse(
        200,
        envelope(authResultJson(access: validAccess, refresh: validRefresh)),
      );
    }
    if (path.endsWith('/me/sessions')) {
      if (sessionsOverride != null) {
        return sessionsOverride!(options);
      }
      if (options.headers['Authorization'] != 'Bearer $validAccess') {
        return jsonResponse(401, errorBody(ErrorObjectCode.unauthenticated));
      }
      return jsonResponse(200, envelope(<Object?>[sessionJson()]));
    }
    if (path.endsWith('/auth/email/verify')) {
      return jsonResponse(200, envelope(<String, Object?>{'ok': true}));
    }
    return jsonResponse(404, errorBody(ErrorObjectCode.notFound));
  }
}

void main() {
  late FakeApi api;
  late MemorySecureStore secure;
  late CredentialStore credentials;
  late SessionTokenManager tokens;
  late ApiClient client;
  late List<SessionEndReason> endedReasons;

  setUp(() {
    api = FakeApi();
    secure = MemorySecureStore();
    credentials = CredentialStore(secure);
    final AuthApi refreshApi = AuthApi(
      ApiClient(
        createApiDio(testConfig, adapter: api.adapter, enableLogging: false),
      ),
    );
    tokens = SessionTokenManager(
      store: credentials,
      refresh: refreshApi.refresh,
    );
    endedReasons = <SessionEndReason>[];
    tokens.onSessionEnded = endedReasons.add;
    client = ApiClient(
      createApiDio(
        testConfig,
        tokens: tokens,
        adapter: api.adapter,
        enableLogging: false,
      ),
    );
  });

  Future<void> signInWith({
    String access = 'access-1',
    String refresh = 'refresh-1',
    DateTime? accessExpiresAt,
  }) async {
    credentials.setAccessToken(access, accessExpiresAt);
    await credentials.writeRefreshToken(refresh);
  }

  Future<List<SessionDto>> listSessions() => client.send(
    ApiEndpoints.listSessions,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListSessionDto(json).data,
  );

  test('adds the bearer token and client headers to protected calls', () async {
    await signInWith(access: 'access-2');
    final List<SessionDto> sessions = await listSessions();
    expect(sessions, hasLength(1));
    final RequestOptions sent = api.adapter.requests.single;
    expect(sent.headers['Authorization'], 'Bearer access-2');
    expect(sent.headers['X-Montra-Client'], 'android');
    expect(sent.headers['X-Client-Version'], '1.0.0+1');
  });

  test('never sends the token to public endpoints', () async {
    await signInWith(access: 'access-2');
    await client.send(
      ApiEndpoints.verifyEmail,
      body: const TokenBody(token: 't').toJson(),
      decode: decodeEnvelopeEmpty,
    );
    expect(api.adapter.requests.single.headers['Authorization'], isNull);
  });

  test(
    'refreshes once on 401, stores the rotated refresh token and retries',
    () async {
      await signInWith(access: 'stale-access');
      final List<SessionDto> sessions = await listSessions();

      expect(sessions, hasLength(1));
      expect(api.refreshCalls, 1);
      final List<RequestOptions> calls = api.adapter.requestsTo('/me/sessions');
      expect(calls, hasLength(2));
      expect(calls.last.headers['Authorization'], 'Bearer access-2');
      expect(
        api.adapter.requestsTo('/auth/refresh').single.data,
        <String, Object?>{'refresh_token': 'refresh-1'},
      );
      // Rotated refresh token persisted; access token only in memory.
      expect(secure.values, <String, String>{
        CredentialStore.refreshTokenKey: 'refresh-2',
      });
      expect(credentials.accessToken, 'access-2');
    },
  );

  test('concurrent 401s share a single refresh (single-flight)', () async {
    await signInWith(access: 'stale-access');
    final List<List<SessionDto>> results = await Future.wait(
      <Future<List<SessionDto>>>[
        listSessions(),
        listSessions(),
        listSessions(),
      ],
    );

    expect(results, everyElement(hasLength(1)));
    expect(api.refreshCalls, 1);
    final List<RequestOptions> retries = api.adapter
        .requestsTo('/me/sessions')
        .where(
          (RequestOptions r) => r.headers['Authorization'] == 'Bearer access-2',
        )
        .toList();
    expect(retries, hasLength(3));
  });

  test('requests issued during a refresh wait for the new token', () async {
    await signInWith(access: 'stale-access');
    final Future<List<SessionDto>> first = listSessions();
    // Let the first request fail and start the (20 ms) refresh.
    for (int i = 0; i < 200 && !tokens.isRefreshing; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(tokens.isRefreshing, isTrue);
    final Future<List<SessionDto>> second = listSessions();
    await Future.wait(<Future<List<SessionDto>>>[first, second]);

    expect(api.refreshCalls, 1);
    expect(
      api.adapter.requestsTo('/me/sessions').last.headers['Authorization'],
      'Bearer access-2',
    );
  });

  test('a rejected refresh clears credentials and ends the session', () async {
    await signInWith(access: 'stale-access', refresh: 'revoked-refresh');

    await expectLater(
      listSessions(),
      throwsA(
        isA<ApiException>().having(
          (ApiException e) => e.kind,
          'kind',
          ApiErrorKind.sessionEnded,
        ),
      ),
    );
    expect(credentials.accessToken, isNull);
    expect(secure.values, isEmpty);
    expect(endedReasons, <SessionEndReason>[SessionEndReason.expired]);
  });

  test(
    'business 401s (REAUTH_REQUIRED, MFA_*) pass through without refresh',
    () async {
      await signInWith(access: 'access-2');
      // Only UNAUTHENTICATED may trigger a refresh (docs/API.md).
      expect(ApiErrorCodes.noRefresh401, <ErrorObjectCode>{
        ErrorObjectCode.reauthRequired,
        ErrorObjectCode.mfaRequired,
        ErrorObjectCode.mfaCodeInvalid,
        ErrorObjectCode.mfaChallengeExpired,
      });
      for (final ErrorObjectCode code in ApiErrorCodes.noRefresh401) {
        api.sessionsOverride = (RequestOptions o) async =>
            jsonResponse(401, errorBody(code));
        await expectLater(
          listSessions(),
          throwsA(
            isA<ApiException>().having(
              (ApiException e) => e.code,
              'code',
              code,
            ),
          ),
        );
      }
      expect(api.refreshCalls, 0);
      expect(secure.values, isNotEmpty);
    },
  );

  test(
    'an offline refresh keeps credentials and reports the network error',
    () async {
      await signInWith(access: 'stale-access');
      api.refreshOverride = (RequestOptions o) async =>
          throw DioException.connectionError(
            requestOptions: o,
            reason: 'offline',
          );

      await expectLater(
        listSessions(),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiErrorKind.network,
          ),
        ),
      );
      expect(secure.values[CredentialStore.refreshTokenKey], 'refresh-1');
      expect(endedReasons, isEmpty);
    },
  );

  test('retries at most once', () async {
    await signInWith(access: 'stale-access');
    // Every call is rejected, even with the fresh token.
    api.sessionsOverride = (RequestOptions o) async =>
        jsonResponse(401, errorBody(ErrorObjectCode.unauthenticated));

    await expectLater(listSessions(), throwsA(isA<ApiException>()));
    expect(api.refreshCalls, 1);
    expect(api.adapter.requestsTo('/me/sessions'), hasLength(2));
  });

  test('without credentials, protected calls fail locally', () async {
    await expectLater(
      listSessions(),
      throwsA(
        isA<ApiException>().having(
          (ApiException e) => e.kind,
          'kind',
          ApiErrorKind.sessionEnded,
        ),
      ),
    );
    expect(api.adapter.requestsTo('/me/sessions'), isEmpty);
  });

  test(
    'refreshes proactively when the access token is about to expire',
    () async {
      await signInWith(
        access: 'stale-access',
        accessExpiresAt: DateTime.now().add(const Duration(seconds: 5)),
      );
      await listSessions();
      expect(api.refreshCalls, 1);
      final List<RequestOptions> calls = api.adapter.requestsTo('/me/sessions');
      expect(calls, hasLength(1));
      expect(calls.single.headers['Authorization'], 'Bearer access-2');
    },
  );

  test(
    'a refresh finishing after sign-out cannot restore the session',
    () async {
      await signInWith(access: 'stale-access');
      final Future<TokenRefreshResult> refreshing = tokens.refresh();
      await tokens.clear();
      final TokenRefreshResult result = await refreshing;

      expect(result, isA<TokenRefreshRejected>());
      expect(credentials.accessToken, isNull);
      expect(secure.values, isEmpty);
    },
  );
}
