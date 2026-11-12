import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/recurring/data/recurring_api.dart';
import 'package:montra_mobile/features/recurring/domain/recurring_display.dart';

import '../../helpers/fakes.dart';
import '../../helpers/planning_fakes.dart';

/// The requests `RecurringApi` sends, checked on the wire.
void main() {
  late FakeHttpAdapter adapter;
  late RecurringApi api;

  setUp(() {
    adapter = FakeHttpAdapter(
      (RequestOptions o) async => jsonResponse(200, envelope(ruleJson())),
    );
    api = RecurringApi(
      ApiClient(
        createApiDio(testConfig, adapter: adapter, enableLogging: false),
      ),
    );
  });

  test('POST /recurring-rules sends the Idempotency-Key', () async {
    await api.create(
      const RecurringRuleInput(
        frequency: RecurringRuleInputFrequency.monthly,
        kind: RecurringRuleInputKind.expense,
        name: 'Gym',
        startDate: '2026-11-05',
      ),
      key: 'rule-key-12345678',
    );
    final RequestOptions sent = adapter.requests.single;
    expect(sent.method, 'POST');
    expect(sent.uri.path, '/api/v1/recurring-rules');
    expect(sent.headers['Idempotency-Key'], 'rule-key-12345678');
  });

  test(
    'PATCH /recurring-rules/{id} sends only the changes and clears',
    () async {
      final RecurringRuleDetail original = ruleDetail(
        merchantId: 'm-1',
        merchantName: 'Landlord',
        description: 'Flat 4B',
        version: 6,
      );
      final RecurringRuleInput before = recurringInputFrom(original);
      final RecurringRuleInput edited = RecurringRuleInput(
        kind: before.kind,
        name: 'Home rent',
        amount: before.amount,
        amountIsVariable: before.amountIsVariable,
        currency: before.currency,
        autoPost: before.autoPost,
        frequency: before.frequency,
        byMonthDay: before.byMonthDay,
        startDate: before.startDate,
        localTime: before.localTime,
        timezone: before.timezone,
        reminderDaysBefore: before.reminderDaysBefore,
      );
      await api.update(original.id, recurringPatchFor(original, edited));
      final RequestOptions sent = adapter.requests.single;
      expect(sent.method, 'PATCH');
      expect(sent.uri.path, '/api/v1/recurring-rules/rule-1');
      expect(sent.data, <String, Object?>{
        'name': 'Home rent',
        'description': '',
        'merchant_name': '',
        'clear': <String>['account_id'],
        'version': 6,
      });
    },
  );

  test('rule actions send ?version=', () async {
    await api.pause('rule-1', version: 2);
    await api.resume('rule-1', version: 3);
    await api.skipNext('rule-1', version: 4);
    await api.stop('rule-1', version: 5);
    expect(
      <String>[
        for (final RequestOptions r in adapter.requests)
          '${r.method} ${r.uri.path}?${r.uri.query}',
      ],
      <String>[
        'POST /api/v1/recurring-rules/rule-1/pause?version=2',
        'POST /api/v1/recurring-rules/rule-1/resume?version=3',
        'POST /api/v1/recurring-rules/rule-1/skip-next?version=4',
        'POST /api/v1/recurring-rules/rule-1/stop?version=5',
      ],
    );
  });

  test('a moved occurrence stays open and says where it went', () {
    final OccurrenceDto moved = OccurrenceDto.fromJson(
      occurrenceJson(date: '2026-12-05', effectiveDate: '2026-12-12'),
    );
    expect(movedTo(moved), '2026-12-12');
    expect(isOpenOccurrence(moved), isTrue);
    expect(movedTo(occurrence()), isNull);
    final OccurrenceDto overdue = OccurrenceDto.fromJson(
      occurrenceJson(status: 'overdue', effectiveDate: '2026-12-09'),
    );
    expect(isOpenOccurrence(overdue), isTrue);
    expect(
      isOpenOccurrence(occurrence(status: 'skipped')),
      isFalse,
      reason: 'skipped ones are done',
    );
  });
}
