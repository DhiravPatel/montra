import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/bills/data/bills_api.dart';
import 'package:montra_mobile/features/bills/domain/bill_display.dart';

import '../../helpers/fakes.dart';
import '../../helpers/planning_fakes.dart';

/// The requests `BillsApi` sends, checked on the wire.
void main() {
  late FakeHttpAdapter adapter;
  late BillsApi api;

  setUp(() {
    adapter = FakeHttpAdapter(
      (RequestOptions o) async => jsonResponse(
        o.method == 'POST' && o.path.endsWith('/bills') ? 201 : 200,
        envelope(<String, Object?>{...billJson(), 'occurrences': <Object?>[]}),
      ),
    );
    api = BillsApi(
      ApiClient(
        createApiDio(testConfig, adapter: adapter, enableLogging: false),
      ),
    );
  });

  test('POST /bills sends the Idempotency-Key', () async {
    await api.create(
      const BillInput(
        frequency: BillInputFrequency.monthly,
        name: 'Water',
        startDate: '2026-11-05',
      ),
      key: 'bill-key-12345678',
    );
    final RequestOptions sent = adapter.requests.single;
    expect(sent.method, 'POST');
    expect(sent.uri.path, '/api/v1/bills');
    expect(sent.headers['Idempotency-Key'], 'bill-key-12345678');
    expect(sent.data, <String, Object?>{
      'frequency': 'monthly',
      'name': 'Water',
      'start_date': '2026-11-05',
    });
  });

  test('PATCH /bills/{id} sends only the changes, clears and the '
      'version', () async {
    final BillDetail original = billDetail(notes: 'Meter 42', version: 5);
    final BillInput edited = BillInput(
      name: original.name,
      providerName: 'BESCOM',
      amountIsVariable: false,
      expectedAmount: '1900.00',
      currency: 'INR',
      frequency: BillInputFrequency.weekly,
      byWeekday: 1,
      startDate: '2026-10-10',
      localTime: '09:00',
      timezone: 'Asia/Kolkata',
      reminderDaysBefore: const <int>[3],
    );
    await api.update(original.id, billPatchFor(original, edited));
    final RequestOptions sent = adapter.requests.single;
    expect(sent.method, 'PATCH');
    expect(sent.uri.path, '/api/v1/bills/bill-1');
    expect(sent.data, <String, Object?>{
      'expected_amount': '1900.00',
      'frequency': 'weekly',
      'by_weekday': 1,
      'notes': '',
      'clear': unorderedEquals(<String>['payment_account_id', 'by_month_day']),
      'version': 5,
    });
  });

  test('lifecycle actions use their own endpoints with ?version=', () async {
    for (final (BillAction action, String path) in <(BillAction, String)>[
      (BillAction.pause, 'pause'),
      (BillAction.resume, 'resume'),
      (BillAction.archive, 'archive'),
      (BillAction.restore, 'restore'),
    ]) {
      await api.act('bill-1', action, version: 4);
      final RequestOptions sent = adapter.requests.last;
      expect(sent.method, 'POST');
      expect(sent.uri.path, '/api/v1/bills/bill-1/$path');
      expect(sent.uri.queryParameters, <String, String>{'version': '4'});
    }
  });

  test(
    'payment candidates decode reason codes and the days from due',
    () async {
      adapter.handler = (RequestOptions o) async => jsonResponse(
        200,
        envelope(<Object?>[
          <String, Object?>{
            'transaction_id': 'tx-1',
            'account_name': 'HDFC',
            'local_date': '2026-11-08',
            'amount': <String, Object?>{
              'amount': '1800.00',
              'amount_minor': 180000,
              'currency': 'INR',
            },
            'reason_codes': <String>['same_provider', 'near_due_date'],
            'reasons': <String>['Same provider', 'Near the due date'],
            'days_from_due': -2,
          },
        ]),
      );
      final List<BillPaymentCandidate> list = await api.paymentCandidates(
        'bill-1',
        occurrenceId: 'occ-1',
      );
      expect(adapter.requests.single.uri.queryParameters, <String, String>{
        'occurrence_id': 'occ-1',
      });
      expect(list.single.reasonCodes, <BillPaymentCandidateReasonCodesItem>[
        BillPaymentCandidateReasonCodesItem.sameProvider,
        BillPaymentCandidateReasonCodesItem.nearDueDate,
      ]);
      expect(list.single.daysFromDue, -2);
    },
  );

  test('available actions follow the status', () {
    expect(billActionsFor(BillDetailStatus.active), <BillAction>[
      BillAction.pause,
      BillAction.archive,
    ]);
    expect(billActionsFor(BillDetailStatus.paused), <BillAction>[
      BillAction.resume,
      BillAction.archive,
    ]);
    expect(billActionsFor(BillDetailStatus.archived), <BillAction>[
      BillAction.restore,
    ]);
    expect(billActionsFor(BillDetailStatus.unrecognized), isEmpty);
  });
}
