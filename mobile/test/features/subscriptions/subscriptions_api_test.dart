import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/subscriptions/data/subscriptions_api.dart';
import 'package:montra_mobile/features/subscriptions/domain/subscription_display.dart';

import '../../helpers/fakes.dart';
import '../../helpers/subscriptions_fakes.dart';

/// The requests `SubscriptionsApi` sends, checked on the wire.
void main() {
  late FakeHttpAdapter adapter;
  late SubscriptionsApi api;

  setUp(() {
    adapter = FakeHttpAdapter(
      (RequestOptions o) async => jsonResponse(
        200,
        envelope(subscriptionJson(events: <Map<String, Object?>>[])),
      ),
    );
    api = SubscriptionsApi(
      ApiClient(
        createApiDio(testConfig, adapter: adapter, enableLogging: false),
      ),
    );
  });

  String line(RequestOptions r) =>
      '${r.method} ${r.uri.path}${r.uri.hasQuery ? '?${r.uri.query}' : ''}';

  test('POST /subscriptions sends the Idempotency-Key', () async {
    await api.create(
      const SubscriptionInput(
        amount: '199.00',
        billingFrequency: SubscriptionInputBillingFrequency.monthly,
        name: 'Musicly',
        startDate: '2026-11-05',
      ),
      key: 'sub-key-12345678',
    );
    final RequestOptions sent = adapter.requests.single;
    expect(line(sent), 'POST /api/v1/subscriptions');
    expect(sent.headers['Idempotency-Key'], 'sub-key-12345678');
  });

  test('PATCH /subscriptions/{id} sends the partial body', () async {
    final SubscriptionDetail d = subscriptionDetail(
      json: subscriptionJson(
        groupId: 'grp-1',
        events: <Map<String, Object?>>[],
      ),
    );
    await api.update(
      d.id,
      subscriptionPatchFor(
        d,
        <String, Object?>{...subscriptionFormJson(d), 'plan_name': 'Family'}
          ..remove('group_id'),
      ),
    );
    final RequestOptions sent = adapter.requests.single;
    expect(line(sent), 'PATCH /api/v1/subscriptions/sub-1');
    expect(sent.data, <String, Object?>{
      'plan_name': 'Family',
      'clear': <String>['group_id'],
      'version': 3,
    });
  });

  test('lifecycle actions send ?version= and the cancellation date', () async {
    await api.act(
      'sub-1',
      SubscriptionAction.cancelled,
      input: const SubscriptionActionInput(
        confirm: true,
        cancelledOn: '2026-11-03',
      ),
      version: 3,
    );
    await api.act('sub-1', SubscriptionAction.pause, version: 4);
    expect(
      line(adapter.requests.first),
      'POST /api/v1/subscriptions/sub-1/cancelled?version=3',
    );
    expect(adapter.requests.first.data, <String, Object?>{
      'cancelled_on': '2026-11-03',
      'confirm': true,
    });
    expect(
      line(adapter.requests.last),
      'POST /api/v1/subscriptions/sub-1/pause?version=4',
    );
  });

  test('payment candidates, unlink and one checklist step', () async {
    adapter.handler = (RequestOptions o) async {
      if (o.path.endsWith('/payment-candidates')) {
        return jsonResponse(
          200,
          envelope(<Object?>[
            <String, Object?>{
              'transaction_id': 'tx-1',
              'account_name': 'HDFC',
              'local_date': '2026-11-09',
              'amount': <String, Object?>{
                'amount': '499.00',
                'amount_minor': 49900,
                'currency': 'INR',
              },
              'reason_codes': <String>['same_merchant', 'near_renewal_date'],
              'reasons': <String>['Same merchant', 'Near the renewal date'],
              'days_from_renewal': -1,
              'expected_date': '2026-11-10',
            },
          ]),
        );
      }
      return jsonResponse(
        200,
        envelope(subscriptionJson(events: <Map<String, Object?>>[])),
      );
    };
    final List<SubscriptionPaymentCandidate> list = await api.paymentCandidates(
      'sub-1',
    );
    expect(
      list.single.reasonCodes.last,
      SubscriptionPaymentCandidateReasonCodesItem.nearRenewalDate,
    );
    await api.unlinkPayment('sub-1', 'tx-1');
    await api.updateChecklistItem(
      'sub-1',
      2,
      const ChecklistItemPatch(done: true, version: 3),
    );
    expect(adapter.requests.map(line), <String>[
      'GET /api/v1/subscriptions/sub-1/payment-candidates',
      'DELETE /api/v1/subscriptions/sub-1/payments/tx-1',
      'PATCH /api/v1/subscriptions/sub-1/cancellation-checklist/2',
    ]);
    expect(adapter.requests.last.data, <String, Object?>{
      'done': true,
      'version': 3,
    });
  });
}
