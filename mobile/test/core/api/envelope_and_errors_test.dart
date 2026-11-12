import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/app/l10n/generated/app_localizations_en.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/api_error_code.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';

import '../../helpers/fakes.dart';

Response<Object?> response(
  int status,
  Object? data, {
  Map<String, List<String>> headers = const <String, List<String>>{},
}) => Response<Object?>(
  requestOptions: RequestOptions(path: '/x'),
  statusCode: status,
  data: data,
  headers: Headers.fromMap(headers),
);

void main() {
  group('success envelope', () {
    test('decodes data and meta', () {
      final EnvelopeAuthResult env = decodeEnvelopeAuthResult(
        envelope(authResultJson(), requestId: 'req-123'),
      );
      expect(env.meta.requestId, 'req-123');
      expect(env.meta.timestamp, DateTime.utc(2026, 11, 4, 10));
      expect(env.data.status, AuthResultStatus.authenticated);
      expect(env.data.user?.displayName, 'Asha');
      expect(env.data.session?.clientKind, SessionDtoClientKind.android);
      expect(env.data.accessExpiresAt, DateTime.utc(2099, 1, 1, 0, 15));
    });

    test('carries pagination metadata when present', () {
      final Map<String, Object?> json = envelope(<Object?>[]);
      (json['meta']! as Map<String, Object?>)
        ..['next_cursor'] = 'abc'
        ..['has_more'] = true;
      final EnvelopeListSessionDto env = decodeEnvelopeListSessionDto(json);
      expect(env.meta.nextCursor, 'abc');
      expect(env.meta.hasMore, isTrue);
      expect(env.data, isEmpty);
    });

    test('list data is never null: a null list is rejected', () {
      expect(
        () => decodeEnvelopeListSessionDto(envelope(null)),
        throwsA(isA<FormatException>()),
      );
    });

    test('unknown enum values do not break decoding', () {
      final EnvelopeListSessionDto env = decodeEnvelopeListSessionDto(
        envelope(<Object?>[sessionJson(clientKind: 'smartwatch')]),
      );
      expect(env.data.single.clientKind, SessionDtoClientKind.unrecognized);
    });

    test('missing required fields fail with the path, never the value', () {
      final Map<String, Object?> user = userJson()..remove('email');
      expect(
        () => UserDto.fromJson(user),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            'UserDTO.email is missing',
          ),
        ),
      );
      final Map<String, Object?> wrongType = userJson()
        ..['email_verified'] = 'yes';
      expect(
        () => UserDto.fromJson(wrongType),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            isNot(contains('yes')),
          ),
        ),
      );
    });

    test('request bodies omit absent optional fields', () {
      const LoginBody body = LoginBody(email: 'a@b.co', password: 'pw');
      expect(body.toJson(), <String, Object?>{
        'email': 'a@b.co',
        'password': 'pw',
      });
      const RefreshBody refresh = RefreshBody(refreshToken: 'rt');
      expect(refresh.toJson(), <String, Object?>{'refresh_token': 'rt'});
    });

    test('toString never exposes tokens or personal data', () {
      final AuthResult result = AuthResult.fromJson(authResultJson());
      expect(result.toString(), isNot(contains('access-1')));
      expect(result.user.toString(), isNot(contains('asha@example.com')));
      expect(
        const LoginBody(email: 'a@b.co', password: 'secret').toString(),
        isNot(contains('secret')),
      );
    });
  });

  group('error envelope', () {
    test('parses code, message, details and request id', () {
      final ApiException e = ApiException.fromResponse(
        response(
          422,
          errorBody(
            ErrorObjectCode.validationError,
            message: 'The request could not be processed.',
            details: <Map<String, Object?>>[
              <String, Object?>{
                'field': 'body.password',
                'message': 'Password must be at least 10 characters.',
              },
              <String, Object?>{
                'field': 'path.sessionId',
                'message': 'Invalid ID.',
              },
            ],
            requestId: 'req-42',
          ),
        ),
      );
      expect(e.kind, ApiErrorKind.server);
      expect(e.code, ErrorObjectCode.validationError);
      expect(e.statusCode, 422);
      expect(e.requestId, 'req-42');
      expect(e.details, hasLength(2));
      expect(e.bodyFieldErrors, <String, String>{
        'password': 'Password must be at least 10 characters.',
      });
    });

    test('decodes the contract error codes, including the MFA outcomes', () {
      for (final ErrorObjectCode code in <ErrorObjectCode>[
        ErrorObjectCode.mfaCodeInvalid,
        ErrorObjectCode.mfaChallengeExpired,
        ErrorObjectCode.loginThrottled,
      ]) {
        final ApiException e = ApiException.fromResponse(
          response(401, errorBody(code)),
        );
        expect(e.code, code);
        expect(e.rawCode, code.json);
      }
    });

    test('keeps the wire value of codes newer than this client', () {
      final ApiException e = ApiException.fromResponse(
        response(400, <String, Object?>{
          'error': <String, Object?>{
            'code': 'BRAND_NEW_CODE',
            'message': 'Something new happened.',
            'details': <Object?>[],
            'request_id': 'req-new',
          },
        }),
      );
      expect(e.code, ErrorObjectCode.unrecognized);
      expect(e.rawCode, 'BRAND_NEW_CODE');
      expect(e.message, 'Something new happened.');
      expect(e.toString(), contains('BRAND_NEW_CODE'));
    });

    test('client-side failures carry no server code', () {
      final ApiException e = ApiException.fromDio(
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/x'),
          reason: 'offline',
        ),
      );
      expect(e.kind, ApiErrorKind.network);
      expect(e.code, isNull);
      expect(e.toString(), contains('network'));
    });

    test('maps nested and indexed detail locations to body members', () {
      expect(ApiException.bodyFieldOf('body.items[0].amount'), 'items');
      expect(ApiException.bodyFieldOf('body.email'), 'email');
      expect(ApiException.bodyFieldOf('query.cursor'), isNull);
      expect(ApiException.bodyFieldOf(null), isNull);
    });

    test('falls back to a status code mapping for non-envelope bodies', () {
      final ApiException e = ApiException.fromResponse(
        response(
          502,
          '<html>Bad gateway</html>',
          headers: <String, List<String>>{
            'x-request-id': <String>['req-proxy'],
          },
        ),
      );
      expect(e.code, ErrorObjectCode.internalError);
      expect(e.requestId, 'req-proxy');
      expect(ApiErrorCodes.forStatus(410), ErrorObjectCode.gone);
      expect(ApiErrorCodes.forStatus(429), ErrorObjectCode.rateLimited);
    });

    test('reads Retry-After as seconds or HTTP date', () {
      final ApiException e = ApiException.fromResponse(
        response(
          429,
          errorBody(ErrorObjectCode.rateLimited),
          headers: <String, List<String>>{
            'retry-after': <String>['30'],
          },
        ),
      );
      expect(e.retryAfter, const Duration(seconds: 30));
      expect(e.isThrottled, isTrue);
      expect(
        ApiException.parseRetryAfter(
          'Wed, 04 Nov 2026 10:00:45 GMT',
          now: DateTime.utc(2026, 11, 4, 10),
        ),
        const Duration(seconds: 45),
      );
      expect(ApiException.parseRetryAfter('soon'), isNull);
    });

    test('classifies transport failures', () {
      final RequestOptions options = RequestOptions(path: '/x');
      expect(
        ApiException.fromDio(
          DioException.connectionError(requestOptions: options, reason: 'x'),
        ).kind,
        ApiErrorKind.network,
      );
      expect(
        ApiException.fromDio(
          DioException.connectionTimeout(
            timeout: const Duration(seconds: 1),
            requestOptions: options,
          ),
        ).kind,
        ApiErrorKind.timeout,
      );
      expect(
        ApiException.fromDio(
          DioException(requestOptions: options, type: DioExceptionType.cancel),
        ).kind,
        ApiErrorKind.cancelled,
      );
      expect(
        ApiException.fromDio(
          DioException(
            requestOptions: options,
            error: const SessionEndedSignal(),
          ),
        ).kind,
        ApiErrorKind.sessionEnded,
      );
    });

    test('toString omits messages and details', () {
      final ApiException e = ApiException.fromResponse(
        response(
          401,
          errorBody(ErrorObjectCode.unauthenticated, message: 'Hi'),
        ),
      );
      expect(e.toString(), isNot(contains('Hi')));
    });
  });

  group('form error mapping', () {
    final AppLocalizationsEn l10n = AppLocalizationsEn();

    test('maps details to fields (with aliases) and keeps unmapped ones', () {
      final ApiException e = ApiException.fromResponse(
        response(
          422,
          errorBody(
            ErrorObjectCode.validationError,
            details: <Map<String, Object?>>[
              <String, Object?>{
                'field': 'body.password',
                'message': 'Too common.',
              },
              <String, Object?>{
                'field': 'body.captcha_token',
                'message': 'Complete the security check.',
              },
            ],
          ),
        ),
      );
      final ServerFormErrors errors = ServerFormErrors.from(
        l10n,
        e,
        fieldMap: const <String, String>{
          'new_password': 'next',
          'password': 'next',
        },
      );
      expect(errors['next'], 'Too common.');
      expect(errors.general, 'Complete the security check.');
      expect(errors.requestId, isNull);
    });

    test('server failures without details get a message and reference', () {
      final ApiException e = ApiException.fromResponse(
        response(
          500,
          errorBody(ErrorObjectCode.internalError, requestId: 'req-500'),
        ),
      );
      final ServerFormErrors errors = ServerFormErrors.from(
        l10n,
        e,
        fieldMap: const <String, String>{},
      );
      expect(errors.general, l10n.errorGenericBody);
      expect(errors.requestId, 'req-500');
    });
  });

  group('ApiClient', () {
    late FakeHttpAdapter adapter;
    late ApiClient client;

    setUp(() {
      adapter = FakeHttpAdapter(
        (RequestOptions o) async =>
            jsonResponse(200, envelope(<String, Object?>{'ok': true})),
      );
      client = ApiClient(
        createApiDio(testConfig, adapter: adapter, enableLogging: false),
      );
    });

    test(
      'sends to /api/v1 with client headers and decodes the envelope',
      () async {
        await client.send(
          ApiEndpoints.verifyEmail,
          body: const TokenBody(token: 'tok').toJson(),
          decode: decodeEnvelopeEmpty,
        );
        final RequestOptions sent = adapter.requests.single;
        expect(
          sent.uri.toString(),
          'http://localhost:8080/api/v1/auth/email/verify',
        );
        expect(sent.method, 'POST');
        expect(sent.headers['X-Montra-Client'], 'android');
        expect(sent.headers['X-Client-Version'], '1.0.0+1');
        expect(sent.data, <String, Object?>{'token': 'tok'});
      },
    );

    test('encodes path parameters', () async {
      await client.send(
        ApiEndpoints.revokeSession,
        pathParameters: const <String, String>{'sessionId': 'a/b'},
        decode: decodeEnvelopeEmpty,
      );
      expect(adapter.requests.single.uri.path, '/api/v1/me/sessions/a%2Fb');
    });

    test('turns error responses into ApiException', () async {
      adapter.handler = (RequestOptions o) async => jsonResponse(
        410,
        errorBody(ErrorObjectCode.gone, message: 'This link has expired.'),
      );
      await expectLater(
        client.send(ApiEndpoints.verifyEmail, decode: decodeEnvelopeEmpty),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.code, 'code', ErrorObjectCode.gone)
              .having((ApiException e) => e.statusCode, 'status', 410),
        ),
      );
    });

    test('rejects 2xx bodies that do not match the contract', () async {
      adapter.handler = (RequestOptions o) async =>
          jsonResponse(200, envelope(<String, Object?>{'unexpected': 1}));
      await expectLater(
        client.send(ApiEndpoints.verifyEmail, decode: decodeEnvelopeEmpty),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiErrorKind.invalidResponse,
          ),
        ),
      );
    });
  });
}
