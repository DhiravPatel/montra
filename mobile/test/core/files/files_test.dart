import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:montra_mobile/core/files/file_source.dart';
import 'package:montra_mobile/core/files/file_uploader.dart';
import 'package:montra_mobile/core/files/sha256.dart';

import '../../helpers/fakes.dart';

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

Map<String, Object?> fileJson({
  String id = 'f0000000-0000-4000-8000-000000000001',
  String status = 'ready',
  String purpose = 'receipt',
}) => <String, Object?>{
  'id': id,
  'purpose': purpose,
  'status': status,
  'original_filename': 'receipt.jpg',
  'content_type': 'image/jpeg',
  'size_bytes': 4,
  'created_at': '2026-11-05T10:00:00Z',
};

void main() {
  group('sha256Hex', () {
    test('matches the FIPS 180-4 examples', () {
      expect(
        sha256Hex(Uint8List(0)),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        sha256Hex(_bytes('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(
        sha256Hex(
          _bytes('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
        ),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
      expect(
        sha256Hex(
          _bytes(
            'abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmn'
            'hijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu',
          ),
        ),
        'cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1',
      );
    });

    test('handles every padding boundary', () {
      const Map<int, String> expected = <int, String>{
        55: 'e7313d333c272e639f790978283f9eb392e843d0f29b7016828bb1daa4aac70b',
        56: '4324d65f3c103567f5589c710bc08f8523f929a9272e3af36fc968e52abc6c27',
        63: '81c80242132f230c3bd41b3e63bbcff16107339549214a99614ff26664625055',
        64: '39e3d7b6b5d075d37d053ad89b24b41bef4f3c29760c84447cab3f3be1882241',
        65: 'aacca6ff74fdbb296d165a45cecfa04e5127bc008770fbbdd48006f2d2fae95e',
        119: '9ce7368e4daf32341631b492e80359dc9f594b48453cd0dd5bf0b19279cc177e',
        120: '7836b787757e95e58b3ca5aec90b1b004e8deba1e50e9675af9cabf1a13a04b5',
        127: 'a8d23e75d936f303d248888d9b165ee543f4cbafcad3c9dd2a79bd84faa11d07',
        128: 'd2742f1f4ac6bb7ca2b239ee18402ba8b3f9f8e652d2a72973c2b9ba11c08cf6',
      };
      for (final MapEntry<int, String> e in expected.entries) {
        final Uint8List data = Uint8List.fromList(
          List<int>.generate(e.key, (int i) => (i * 7 + 3) % 256),
        );
        expect(sha256Hex(data), e.value, reason: '${e.key} bytes');
      }
    });

    test('hashes a million bytes', () {
      expect(
        sha256Hex(Uint8List(1000000)..fillRange(0, 1000000, 0x61)),
        'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0',
      );
    });
  });

  group('upload policies mirror backend/internal/files/files.go', () {
    test('receipts take photos and PDFs up to 15 MB', () {
      const UploadPurpose p = UploadPurpose.receipt;
      expect(p.wire, 'receipt');
      expect(p.maxBytes, 15 << 20);
      for (final String name in <String>[
        'a.jpg',
        'a.JPEG',
        'a.png',
        'a.webp',
        'a.heic',
        'a.heif',
        'a.pdf',
      ]) {
        expect(p.check(name, 10), isNull, reason: name);
      }
      expect(p.check('a.csv', 10), FileProblem.unsupportedType);
      expect(p.check('a.jpg', 0), FileProblem.empty);
      expect(p.check('a.jpg', (15 << 20) + 1), FileProblem.tooLarge);
      expect(p.kindOf('scan.JPEG'), FileKind.jpeg);
      expect(p.acceptsImages, isTrue);
    });

    test('statement imports take CSV, XLSX and OFX only (no PDF: that '
        'needs AI reading)', () {
      const UploadPurpose p = UploadPurpose.statementImport;
      expect(p.wire, 'statement_import');
      expect(p.maxBytes, 10 << 20);
      expect(p.check('bank.csv', 1), isNull);
      expect(p.check('bank.txt', 1), isNull);
      expect(p.check('bank.xlsx', 1), isNull);
      expect(p.check('bank.ofx', 1), isNull);
      expect(p.check('bank.qfx', 1), isNull);
      expect(p.check('bank.pdf', 1), FileProblem.unsupportedType);
      expect(p.acceptsImages, isFalse);
      expect(
        p.pickerExtensions,
        containsAll(<String>['csv', 'xlsx', 'ofx', 'qfx', 'txt']),
      );
      expect(p.pickerExtensions, isNot(contains('pdf')));
    });

    test('attachments match receipts; every purpose is a contract value', () {
      expect(
        UploadPurpose.transactionAttachment.kinds,
        UploadPurpose.receipt.kinds,
      );
      for (final UploadPurpose p in UploadPurpose.values) {
        expect(
          UploadIntentInputPurpose.fromJson(p.wire),
          isNot(UploadIntentInputPurpose.unrecognized),
          reason: p.wire,
        );
      }
    });
  });

  group('FileUploader', () {
    late FakeHttpAdapter adapter;
    late ApiClient client;

    setUp(() {
      adapter = FakeHttpAdapter((RequestOptions o) async {
        if (o.path.endsWith('/files/upload-intent')) {
          return jsonResponse(
            201,
            envelope(<String, Object?>{
              'file': fileJson(status: 'pending_upload'),
              'upload_url': 'http://public.example/api/v1/files/f0000000-0000-4000-8000-000000000001/content',
              'method': 'PUT',
              'headers': <String, String>{
                'X-Upload-Token': 'token-123',
                'Content-Type': 'application/octet-stream',
              },
              'expires_at': '2026-11-05T10:15:00Z',
              'max_bytes': 15 << 20,
            }),
          );
        }
        if (o.path.endsWith('/content')) {
          return jsonResponse(200, envelope(fileJson(status: 'uploaded')));
        }
        return jsonResponse(200, envelope(fileJson()));
      });
      client = ApiClient(
        createApiDio(testConfig, adapter: adapter, enableLogging: false),
      );
    });

    test('asks for an upload, sends the bytes with the token and checksum '
        'to the configured API, then completes it', () async {
      final List<UploadStage> stages = <UploadStage>[];
      final FileDto file =
          await FileUploader(
            client,
            checksum: (Uint8List b) async => sha256Hex(b),
          ).upload(
            PickedFile(name: 'receipt.jpg', bytes: _bytes('jpeg')),
            UploadPurpose.receipt,
            onStage: stages.add,
          );

      expect(file.status, FileDtoStatus.ready);
      expect(stages, UploadStage.values);
      expect(adapter.requests.map((RequestOptions r) => r.method), <String>[
        'POST',
        'PUT',
        'POST',
      ]);
      final String checksum = sha256Hex(_bytes('jpeg'));
      final RequestOptions intent = adapter.requests[0];
      expect(intent.uri.path, '/api/v1/files/upload-intent');
      expect(intent.data, <String, Object?>{
        'checksum_sha256': checksum,
        'content_type': 'image/jpeg',
        'filename': 'receipt.jpg',
        'purpose': 'receipt',
        'size_bytes': 4,
      });

      final RequestOptions put = adapter.requests[1];
      expect(put.uri.host, 'localhost', reason: 'never the upload_url host');
      expect(
        put.uri.path,
        '/api/v1/files/f0000000-0000-4000-8000-000000000001/content',
      );
      expect(put.headers['X-Upload-Token'], 'token-123');
      expect(put.headers['X-Upload-Checksum'], checksum);
      expect(put.contentType, 'application/octet-stream');
      expect(put.data, _bytes('jpeg'));

      expect(
        adapter.requests[2].uri.path,
        '/api/v1/files/f0000000-0000-4000-8000-000000000001/complete',
      );
    });

    test('refuses files the purpose does not accept before sending '
        'anything', () async {
      final FileUploader uploader = FileUploader(
        client,
        checksum: (Uint8List b) async => 'x',
      );
      await expectLater(
        uploader.upload(
          PickedFile(name: 'statement.pdf', bytes: _bytes('%PDF')),
          UploadPurpose.statementImport,
        ),
        throwsA(
          isA<FileRejected>().having(
            (FileRejected e) => e.problem,
            'problem',
            FileProblem.unsupportedType,
          ),
        ),
      );
      await expectLater(
        uploader.upload(
          PickedFile(name: 'big.jpg', bytes: Uint8List((15 << 20) + 1)),
          UploadPurpose.receipt,
        ),
        throwsA(isA<FileRejected>()),
      );
      expect(adapter.requests, isEmpty);
    });

    test('server refusals surface as ApiException', () async {
      adapter.handler = (RequestOptions o) async => jsonResponse(
        422,
        errorBody(
          ErrorObjectCode.domainRuleViolation,
          details: <Map<String, Object?>>[
            <String, Object?>{
              'code': 'storage_quota_exceeded',
              'message': 'This upload would exceed your storage.',
              'params': <String, String>{
                'used_bytes': '100',
                'quota_bytes': '1073741824',
              },
            },
          ],
        ),
      );
      await expectLater(
        FileUploader(client, checksum: (Uint8List b) async => 'x').upload(
          PickedFile(name: 'r.png', bytes: _bytes('png')),
          UploadPurpose.receipt,
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            ErrorObjectCode.domainRuleViolation,
          ),
        ),
      );
    });
  });

  group('signed downloads', () {
    test('fetch the signed path on the configured API without a bearer '
        'token', () async {
      final FakeHttpAdapter adapter = FakeHttpAdapter(
        (RequestOptions o) async => ResponseBody.fromBytes(
          <int>[1, 2, 3],
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['image/png'],
          },
        ),
      );
      final ApiClient client = ApiClient(
        createApiDio(testConfig, adapter: adapter, enableLogging: false),
      );
      final DownloadedBytes body = await client.downloadSigned(
        'https://api.montra.example/api/v1/files/f-1/content?exp=1&sub=u&sig=s',
      );
      expect(body.bytes, <int>[1, 2, 3]);
      expect(body.contentType, 'image/png');
      final RequestOptions sent = adapter.requests.single;
      expect(sent.uri.toString(), startsWith('http://localhost:8080/'));
      expect(sent.uri.path, '/api/v1/files/f-1/content');
      expect(sent.uri.queryParameters, <String, String>{
        'exp': '1',
        'sub': 'u',
        'sig': 's',
      });
      expect(sent.headers.containsKey('Authorization'), isFalse);
    });

    test('refuse anything but a file download', () {
      final ApiClient client = ApiClient(
        createApiDio(testConfig, enableLogging: false),
      );
      for (final String url in <String>[
        'https://evil.example/steal',
        'http://localhost:8080/api/v1/auth/session',
        'not a url',
      ]) {
        expect(
          () => client.resolveSignedUrl(url),
          throwsA(isA<ApiException>()),
          reason: url,
        );
      }
    });

    test('decode JSON error bodies of byte downloads', () async {
      final FakeHttpAdapter adapter = FakeHttpAdapter(
        (RequestOptions o) async => jsonResponse(
          410,
          errorBody(ErrorObjectCode.gone, message: 'Expired.'),
        ),
      );
      final ApiClient client = ApiClient(
        createApiDio(testConfig, adapter: adapter, enableLogging: false),
      );
      await expectLater(
        client.downloadSigned(
          'http://localhost:8080/api/v1/files/f-1/content?sig=s',
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            ErrorObjectCode.gone,
          ),
        ),
      );
    });
  });
}
