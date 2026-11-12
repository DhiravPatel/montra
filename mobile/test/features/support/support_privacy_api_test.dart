import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/privacy/data/privacy_api.dart';
import 'package:montra_mobile/features/support/data/support_api.dart';
import 'package:montra_mobile/features/support/domain/support_display.dart';

import '../../helpers/fakes.dart';
import '../../helpers/support_fakes.dart';

/// Request shapes of the help, support, privacy and data calls (checked
/// against the live API's answers, saved as fixtures).
void main() {
  late FakeHttpAdapter adapter;
  late SupportApi support;
  late PrivacyApi privacy;

  setUp(() {
    adapter = FakeHttpAdapter((RequestOptions o) async {
      final String path = o.uri.path.replaceFirst('/api/v1', '');
      return switch ((o.method, path)) {
        ('GET', '/support/requests') => jsonResponse(
          200,
          envelope(<Object?>[requestJson()]),
        ),
        ('POST', '/support/requests') => jsonResponse(
          201,
          envelope(requestJson()),
        ),
        ('GET', '/support/requests/req-1') => jsonResponse(
          200,
          envelope(requestJson(messages: 1)),
        ),
        ('GET', '/support/requests/req-1/messages') => jsonResponse(
          200,
          envelope(<Object?>[supportMessage().toJson()]),
        ),
        ('POST', '/support/requests/req-1/messages') => jsonResponse(
          201,
          envelope(supportMessage().toJson()),
        ),
        ('POST', '/support/contact') => jsonResponse(
          202,
          envelope(<String, Object?>{'reference': 'C0FFEE12'}),
        ),
        ('GET', '/legal') => jsonResponse(200, envelope(legalDto().toJson())),
        ('GET', '/me/consents') => jsonResponse(
          200,
          envelope(<Object?>[consentDto('terms').toJson()]),
        ),
        ('POST', '/me/consents') => jsonResponse(
          201,
          envelope(consentDto('location').toJson()),
        ),
        ('DELETE', '/me/consents/location') => jsonResponse(
          200,
          envelope(<String, Object?>{'ok': true}),
        ),
        ('POST', '/me/export') => jsonResponse(
          202,
          envelope(exportDto(status: 'queued').toJson()),
        ),
        ('GET', '/me/exports') => jsonResponse(
          200,
          envelope(<Object?>[exportDto().toJson()]),
        ),
        ('GET', '/me/export/exp-1') => jsonResponse(
          200,
          envelope(exportDto().toJson()),
        ),
        ('POST', '/me/deactivate') => jsonResponse(
          200,
          envelope(<String, Object?>{'ok': true}),
        ),
        ('GET', '/me/deletion-request') => jsonResponse(
          200,
          envelope(deletionDto().toJson()),
        ),
        ('POST', '/me/deletion-request') => jsonResponse(
          200,
          envelope(deletionDto(status: 'scheduled').toJson()),
        ),
        ('DELETE', '/me/deletion-request') => jsonResponse(
          200,
          envelope(deletionDto(status: 'cancelled').toJson()),
        ),
        _ => jsonResponse(404, errorBody(ErrorObjectCode.notFound)),
      };
    });
    final ApiClient client = ApiClient(
      createApiDio(testConfig, adapter: adapter, enableLogging: false),
    );
    support = SupportApi(client);
    privacy = PrivacyApi(client);
  });

  RequestOptions last() => adapter.requests.last;

  group('support', () {
    test('requests, one request and its thread', () async {
      expect((await support.list()).single.reference, 'AD0B4A0D');
      expect(last().uri.path, '/api/v1/support/requests');
      expect((await support.get('req-1')).messageCount, 1);
      final List<MessageDto> thread = await support.messages('req-1');
      expect(thread.single.authorRole, MessageDtoAuthorRole.requester);
      expect(last().uri.path, '/api/v1/support/requests/req-1/messages');
    });

    test('a new request and a reply send the typed bodies', () async {
      await support.create(
        const RequestInput(
          kind: RequestInputKind.bug,
          subject: 'Export stuck',
          body: 'It says waiting.',
        ),
      );
      expect(last().method, 'POST');
      expect(last().data, <String, Object?>{
        'body': 'It says waiting.',
        'kind': 'bug',
        'subject': 'Export stuck',
      });
      await support.reply('req-1', 'Thanks!');
      expect(last().uri.path, '/api/v1/support/requests/req-1/messages');
      expect(last().data, <String, Object?>{'body': 'Thanks!'});
    });

    test('the contact form needs no sign-in and returns a reference', () async {
      final ContactResult result = await support.contact(
        const ContactInput(
          kind: ContactInputKind.support,
          subject: 'Cannot sign in',
          body: 'Locked out.',
          contactEmail: 'me@example.com',
        ),
      );
      expect(result.reference, 'C0FFEE12');
      expect(last().uri.path, '/api/v1/support/contact');
      expect(last().headers.containsKey('Authorization'), isFalse);
      expect(
        (last().data as Map<String, Object?>)['contact_email'],
        'me@example.com',
      );
    });

    test('secrets are caught before sending, like the API does', () {
      expect(containsSecret('my card 4111 1111 1111 1111'), isTrue);
      expect(containsSecret('pin: 1234'), isTrue);
      expect(containsSecret('OTP 482913'), isTrue);
      expect(containsSecret('password: hunter22'), isTrue);
      expect(containsSecret('Order 1234 5678 9012 3456 failed'), isFalse);
      expect(containsSecret('How do I share a budget?'), isFalse);
    });
  });

  group('privacy', () {
    test('consents use the versions from GET /legal', () async {
      final LegalDto legal = await privacy.legal();
      expect(legal.consents, hasLength(9));
      expect(last().uri.path, '/api/v1/legal');
      expect((await privacy.consents()).single.consentType, 'terms');
      await privacy.grant(
        MeConsentsGrantRequestConsentType.location,
        legal.consents
            .firstWhere(
              (ConsentVersionDto c) =>
                  c.typeValue == ConsentVersionDtoType.location,
            )
            .version,
      );
      expect(last().data, <String, Object?>{
        'consent_type': 'location',
        'version': '2026-11-01',
      });
      await privacy.revoke('location');
      expect(last().method, 'DELETE');
      expect(last().uri.path, '/api/v1/me/consents/location');
    });

    test('exports: request, list and one export', () async {
      expect((await privacy.requestExport()).status, ExportDtoStatus.queued);
      expect(last().method, 'POST');
      expect(last().uri.path, '/api/v1/me/export');
      expect((await privacy.exports()).single.fileId, 'file-exp');
      expect((await privacy.export('exp-1')).status, ExportDtoStatus.completed);
      expect(last().uri.path, '/api/v1/me/export/exp-1');
    });

    test('deactivate and deletion send what the API expects', () async {
      await privacy.deactivate();
      expect(last().uri.path, '/api/v1/me/deactivate');
      expect((await privacy.deletion()).status, DeletionDtoStatus.none);
      await privacy.requestDeletion(reason: '  moving on ');
      expect(last().method, 'POST');
      expect(last().data, <String, Object?>{
        'confirm': 'DELETE',
        'reason': 'moving on',
      });
      await privacy.requestDeletion(reason: '   ');
      expect(last().data, <String, Object?>{'confirm': 'DELETE'});
      expect(
        (await privacy.cancelDeletion()).status,
        DeletionDtoStatus.cancelled,
      );
      expect(last().method, 'DELETE');
    });

    test('a refused secret arrives as a coded field error', () async {
      adapter.handler = (RequestOptions o) async => jsonResponse(
        422,
        errorBody(
          ErrorObjectCode.validationError,
          details: <Map<String, Object?>>[
            <String, Object?>{
              'field': 'body.body',
              'code': 'contains_secret',
              'message': 'Remove card numbers…',
            },
          ],
        ),
      );
      await expectLater(
        support.create(
          const RequestInput(
            kind: RequestInputKind.support,
            subject: 'Card',
            body: 'x',
          ),
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.details.single.code,
            'code',
            'contains_secret',
          ),
        ),
      );
    });
  });
}
