import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/receipts/data/receipts_api.dart';
import 'package:montra_mobile/features/receipts/domain/receipt_codes.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';

import '../../helpers/fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/receipts_fakes.dart';

/// Request shapes of the receipt and attachment calls against the live API
/// (and the contract where it already describes them).
void main() {
  late FakeHttpAdapter adapter;
  late ApiClient client;

  Map<String, Object?> page(List<Object?> data, {String? next}) =>
      <String, Object?>{
        'data': data,
        'meta': <String, Object?>{
          'request_id': 'req-ok',
          'timestamp': '2026-11-04T10:00:00Z',
          'has_more': next != null,
          'next_cursor': ?next,
        },
      };

  setUp(() {
    adapter = FakeHttpAdapter((RequestOptions o) async {
      final String path = o.uri.path;
      if (o.method == 'DELETE') {
        return jsonResponse(200, envelope(<String, Object?>{'ok': true}));
      }
      if (o.method == 'GET' && path.endsWith('/receipts')) {
        return jsonResponse(
          200,
          page(<Object?>[receiptJson()], next: 'cursor-2'),
        );
      }
      if (path.endsWith('/match-candidates')) {
        return jsonResponse(
          200,
          envelope(<Object?>[
            <String, Object?>{
              ...matchCandidate().toJson(),
              'reason_codes': <String>['amount_close', 'near_date'],
            },
          ]),
        );
      }
      if (o.method == 'GET' && path.endsWith('/receipts/rc-1')) {
        return jsonResponse(
          200,
          envelope(<String, Object?>{
            ...receiptJson(
              status: 'reviewed',
              current: extractionJson(
                warnings: <String>[
                  'Line items add up to 1100.00, not the subtotal.',
                  'Some note',
                ],
                warningCodes: <String>['line_items_mismatch', 'reader_note'],
                warningParams: <Map<String, String>>[
                  <String, String>{
                    'line_items_total': '1100.00',
                    'subtotal': '1200.50',
                    'currency': 'INR',
                  },
                  <String, String>{},
                ],
              ),
            ),
            'history': <Object?>[],
          }),
        );
      }
      if (path.contains('/transactions/')) {
        return jsonResponse(200, envelope(transactionJson()));
      }
      return jsonResponse(
        o.method == 'POST' && path.endsWith('/receipts') ? 201 : 200,
        envelope(receiptJson(status: 'reviewed')),
      );
    });
    client = ApiClient(
      createApiDio(testConfig, adapter: adapter, enableLogging: false),
    );
  });

  test('a new receipt is for manual entry: an Idempotency-Key, no '
      'skip_extraction, no read_automatically, and automatic reading is '
      'never requested', () async {
    final ReceiptsApi api = ReceiptsApi(client);
    await api.create(
      <String>['file-1', 'file-2'],
      notes: 'Lunch',
      key: 'receipt-create-key',
    );
    final CursorPage<ReceiptDto> first = await api.list(status: 'needs_review');
    await api.list(cursor: first.nextCursor, limit: 20);
    final ReceiptView view = await api.get('rc-1');
    await api.review(
      'rc-1',
      const ReceiptReviewInput(
        receiptDate: '2026-11-03',
        total: '1250.50',
        version: 3,
        merchantName: 'Fresh Mart',
        currency: 'INR',
        tax: '50.00',
        paymentHint: 'UPI',
        lineItems: <ReceiptLineItemInput>[
          ReceiptLineItemInput(
            description: 'Rice',
            quantity: '2',
            unitPrice: '100.00',
            amount: '200.00',
          ),
        ],
      ),
    );
    final List<ReceiptMatchCandidate> suggestions = await api.matchCandidates(
      'rc-1',
    );
    await api.match('rc-1', 'tx-9');
    await api.unlink('rc-1');
    await api.discard('rc-1', version: 4);
    await api.restore('rc-1', version: 5);

    final List<String> calls = <String>[
      for (final RequestOptions r in adapter.requests)
        '${r.method} ${r.uri.path}',
    ];
    expect(calls, <String>[
      'POST /api/v1/receipts',
      'GET /api/v1/receipts',
      'GET /api/v1/receipts',
      'GET /api/v1/receipts/rc-1',
      'PATCH /api/v1/receipts/rc-1/review',
      'GET /api/v1/receipts/rc-1/match-candidates',
      'POST /api/v1/receipts/rc-1/match-transaction',
      'POST /api/v1/receipts/rc-1/unlink',
      'POST /api/v1/receipts/rc-1/discard',
      'POST /api/v1/receipts/rc-1/restore',
    ]);
    expect(calls.where((String c) => c.endsWith('/process')), isEmpty);

    final RequestOptions create = adapter.requests[0];
    expect(create.headers['Idempotency-Key'], 'receipt-create-key');
    expect(create.data, <String, Object?>{
      'file_ids': <String>['file-1', 'file-2'],
      'notes': 'Lunch',
    });
    final Map<String, Object?> body = create.data as Map<String, Object?>;
    expect(body.containsKey('skip_extraction'), isFalse);
    expect(body['read_automatically'], isNot(true));

    expect(adapter.requests[1].uri.queryParameters, <String, String>{
      'status': 'needs_review',
      'limit': '${ReceiptsApi.pageSize}',
    });
    expect(first.nextCursor, 'cursor-2');
    expect(adapter.requests[2].uri.queryParameters, <String, String>{
      'cursor': 'cursor-2',
      'limit': '20',
    });

    expect(view.warnings, hasLength(2));
    expect(
      view.warnings.first.code,
      ReceiptExtractionDtoWarningCodesItem.lineItemsMismatch,
    );
    expect(view.warnings.first.params['subtotal'], '1200.50');
    expect(
      view.warnings.last.code,
      ReceiptExtractionDtoWarningCodesItem.readerNote,
    );

    expect(
      suggestions.single.reasonCodes,
      <ReceiptMatchCandidateReasonCodesItem>[
        ReceiptMatchCandidateReasonCodesItem.amountClose,
        ReceiptMatchCandidateReasonCodesItem.nearDate,
      ],
    );
    expect(adapter.requests[6].data, <String, Object?>{
      'transaction_id': 'tx-9',
    });
    expect(adapter.requests[8].uri.queryParameters, <String, String>{
      'version': '4',
    });
    expect(adapter.requests[9].uri.queryParameters, <String, String>{
      'version': '5',
    });
  });

  test('a page that never became part of a receipt is deleted by its file '
      'ID', () async {
    await ReceiptsApi(client).deleteUpload('file-9');
    final RequestOptions sent = adapter.requests.single;
    expect('${sent.method} ${sent.uri.path}', 'DELETE /api/v1/files/file-9');
  });

  test('unknown warning codes keep the English text', () {
    final List<ReceiptWarning> warnings = receiptWarningsOf(
      ReceiptExtractionDto.fromJson(
        extractionJson(
          warnings: <String>['Subtotal, tax, tip and discount differ.', 'x'],
          warningCodes: <String>['something_new', 'totals_mismatch'],
          warningParams: <Map<String, String>>[
            <String, String>{},
            <String, String>{},
          ],
        ),
      ),
    );
    expect(warnings.first.code, isNull);
    expect(warnings.first.text, 'Subtotal, tax, tip and discount differ.');
    expect(
      warnings.last.code,
      ReceiptExtractionDtoWarningCodesItem.totalsMismatch,
    );
    expect(receiptWarningsOf(null), isEmpty);
  });

  test('recording the purchase sends an Idempotency-Key', () async {
    await ReceiptsApi(client).createTransaction(
      'rc-1',
      const ReceiptCreateTransactionInput(
        accountId: 'acc-1',
        categoryId: 'cat-1',
      ),
      key: 'receipt-key-123',
    );
    final RequestOptions sent = adapter.requests.single;
    expect(sent.method, 'POST');
    expect(sent.uri.path, '/api/v1/receipts/rc-1/create-transaction');
    expect(sent.headers['Idempotency-Key'], 'receipt-key-123');
    expect(sent.data, <String, Object?>{
      'account_id': 'acc-1',
      'category_id': 'cat-1',
    });
  });

  test('an uploaded file is attached to a transaction by its ID', () async {
    await TransactionsApi(client).attach('tx-1', 'file-7');
    final RequestOptions sent = adapter.requests.single;
    expect(sent.method, 'POST');
    expect(sent.uri.path, '/api/v1/transactions/tx-1/attachments');
    expect(sent.data, <String, Object?>{'file_id': 'file-7'});
  });
}
