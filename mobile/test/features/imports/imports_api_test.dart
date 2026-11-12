import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/imports/data/imports_api.dart';

import '../../helpers/fakes.dart';
import '../../helpers/imports_fakes.dart';

/// Request shapes of the statement import calls against the contract.
void main() {
  late FakeHttpAdapter adapter;
  late ImportsApi api;

  setUp(() {
    adapter = FakeHttpAdapter((RequestOptions o) async {
      final String path = o.uri.path;
      if (path.endsWith('/rows')) {
        return jsonResponse(
          200,
          envelope(<String, Object?>{
            'rows': <Object?>[importRow().toJson()],
            'next_cursor': 3,
          }),
        );
      }
      if (path.contains('/rows/')) {
        return jsonResponse(200, envelope(importRow().toJson()));
      }
      if (o.method == 'GET' && path.endsWith('/imports')) {
        return jsonResponse(200, envelope(<Object?>[importBatchJson()]));
      }
      final int status = path.endsWith('/confirm')
          ? 202
          : (o.method == 'POST' && path.endsWith('/imports') ? 201 : 200);
      return jsonResponse(status, envelope(importBatchJson()));
    });
    api = ImportsApi(
      ApiClient(
        createApiDio(testConfig, adapter: adapter, enableLogging: false),
      ),
    );
  });

  test('imports are created without AI extraction, with an '
      'Idempotency-Key; the history pages with a cursor', () async {
    await api.list(accountId: 'acc-1');
    await api.list(cursor: 'next-1', limit: 20);
    await api.create(accountId: 'acc-1', fileId: 'file-1', key: 'key-12345678');
    expect(adapter.requests[0].uri.queryParameters, <String, String>{
      'account_id': 'acc-1',
      'limit': '${ImportsApi.pageSize}',
    });
    expect(adapter.requests[1].uri.queryParameters, <String, String>{
      'cursor': 'next-1',
      'limit': '20',
    });
    expect(adapter.requests[2].method, 'POST');
    expect(adapter.requests[2].uri.path, '/api/v1/imports');
    expect(adapter.requests[2].headers['Idempotency-Key'], 'key-12345678');
    expect(adapter.requests[2].data, <String, Object?>{
      'account_id': 'acc-1',
      'file_id': 'file-1',
    });
  });

  test('the history has a next page only when the server says so', () async {
    adapter.handler = (RequestOptions o) async =>
        jsonResponse(200, <String, Object?>{
          'data': <Object?>[importBatchJson()],
          'meta': <String, Object?>{
            'request_id': 'r',
            'timestamp': '2026-11-12T06:00:00Z',
            'next_cursor': 'c2',
            'has_more': true,
          },
        });
    final CursorPage<ImportBatchDto> page = await api.list();
    expect(page.items.single.id, 'imp-1');
    expect(page.nextCursor, 'c2');
  });

  test('coded rows, notes and Money totals decode from the live shapes', () {
    final ImportBatchDto batch = importBatch(
      notes: const <String>['Dates could be day-first or month-first.'],
      noteCodes: const <String>['ambiguous_date_order'],
      noteParams: const <String, String>{
        'assumed_date_format': 'DD/MM/YYYY',
        'alternative_date_format': 'MM/DD/YYYY',
      },
      toImport: 3,
    );
    expect(
      batch.mappingNoteCodes.single,
      ImportBatchDtoMappingNoteCodesItem.ambiguousDateOrder,
    );
    expect(batch.mappingNoteParams['assumed_date_format'], 'DD/MM/YYYY');
    expect(batch.toImportRows, 3);
    expect(batch.totals!.inflow.amount, '60000.00');
    final ImportRowDto row = importRow(
      status: 'invalid',
      errorCode: 'bad_date',
      errorField: 'posted_date',
      errorParams: const <String, String>{'format': 'DD/MM/YYYY'},
    );
    expect(row.errorField, ImportRowDtoErrorField.postedDate);
    expect(row.errorParams, <String, String>{'format': 'DD/MM/YYYY'});
  });

  test('rows page by status with the integer cursor; corrections and '
      'decisions go to the row', () async {
    final ImportRowPage page = await api.rows(
      'imp-1',
      status: 'invalid',
      afterRow: 7,
      limit: 50,
    );
    expect(page.nextCursor, 3);
    expect(adapter.requests[0].uri.path, '/api/v1/imports/imp-1/rows');
    expect(adapter.requests[0].uri.queryParameters, <String, String>{
      'status': 'invalid',
      'after_row': '7',
      'limit': '50',
    });
    await api.rows('imp-1');
    expect(adapter.requests[1].uri.queryParameters, <String, String>{
      'limit': '${ImportsApi.rowPageSize}',
    });

    await api.updateRow(
      'imp-1',
      'row-7',
      const ImportRowUpdate(
        postedDate: '2026-10-28',
        amount: '120.00',
        direction: ImportRowUpdateDirection.outflow,
        description: 'BOOKSTORE',
      ),
    );
    await api.updateRow(
      'imp-1',
      'row-8',
      const ImportRowUpdate(decision: ImportRowUpdateDecision.skip),
    );
    expect(adapter.requests[2].method, 'PATCH');
    expect(adapter.requests[2].uri.path, '/api/v1/imports/imp-1/rows/row-7');
    expect(adapter.requests[2].data, <String, Object?>{
      'amount': '120.00',
      'description': 'BOOKSTORE',
      'direction': 'outflow',
      'posted_date': '2026-10-28',
    });
    expect(adapter.requests[3].data, <String, Object?>{'decision': 'skip'});
  });

  test('the mapping carries the chosen columns and the version', () async {
    await api.setMapping(
      'imp-1',
      const ColumnMapping(
        headerRow: 1,
        dateColumn: 0,
        dateFormat: 'DD/MM/YYYY',
        debitColumn: 3,
        creditColumn: 4,
        descriptionColumns: <int>[1],
        balanceColumn: 5,
        decimalSeparator: '.',
      ),
      version: 4,
    );
    final RequestOptions sent = adapter.requests.single;
    expect(sent.method, 'PATCH');
    expect(sent.uri.path, '/api/v1/imports/imp-1/mapping');
    expect(sent.data, <String, Object?>{
      'mapping': <String, Object?>{
        'balance_column': 5,
        'credit_column': 4,
        'date_column': 0,
        'date_format': 'DD/MM/YYYY',
        'debit_column': 3,
        'decimal_separator': '.',
        'description_columns': <int>[1],
        'header_row': 1,
      },
      'version': 4,
    });
  });

  test('confirming sends an Idempotency-Key and the version; lifecycle '
      'actions post to their own paths', () async {
    await api.confirm('imp-1', version: 5, key: 'import-key-123');
    await api.cancel('imp-1');
    await api.retryFailed('imp-1');
    await api.rollback('imp-1');
    expect(adapter.requests[0].uri.path, '/api/v1/imports/imp-1/confirm');
    expect(adapter.requests[0].headers['Idempotency-Key'], 'import-key-123');
    expect(adapter.requests[0].data, <String, Object?>{'version': 5});
    expect(
      <String>[
        for (final RequestOptions r in adapter.requests.skip(1))
          '${r.method} ${r.uri.path}',
      ],
      <String>[
        'POST /api/v1/imports/imp-1/cancel',
        'POST /api/v1/imports/imp-1/retry-failed',
        'POST /api/v1/imports/imp-1/rollback',
      ],
    );
  });
}
