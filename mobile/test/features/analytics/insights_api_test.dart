import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/features/analytics/data/analytics_api.dart';
import 'package:montra_mobile/features/analytics/domain/analytics_query.dart';
import 'package:montra_mobile/features/fx/data/fx_api.dart';
import 'package:montra_mobile/features/fx/domain/fx_display.dart';
import 'package:montra_mobile/features/reconciliation/data/reconciliation_api.dart';
import 'package:montra_mobile/features/reconciliation/domain/reconciliation_display.dart';
import 'package:montra_mobile/features/reports/data/reports_api.dart';
import 'package:montra_mobile/features/reports/domain/report_display.dart';

import '../../helpers/fakes.dart';
import '../../helpers/files_fakes.dart';
import '../../helpers/insights_fakes.dart';

/// Request shapes of the analytics, reports, exchange-rate and
/// reconciliation calls (method, path, query and body as the contract
/// declares them).
void main() {
  late FakeHttpAdapter adapter;
  late ApiClient client;
  Object? answer = <String, Object?>{};

  setUp(() {
    answer = <String, Object?>{};
    adapter = FakeHttpAdapter(
      (RequestOptions o) async => jsonResponse(200, envelope(answer)),
    );
    client = ApiClient(
      createApiDio(testConfig, adapter: adapter, enableLogging: false),
    );
  });

  RequestOptions last() => adapter.requests.last;

  group('analytics', () {
    test('a named range is sent as range, custom dates as from/to; currency '
        'and bucket size go along', () async {
      answer = cashFlowReport().toJson();
      final AnalyticsApi api = AnalyticsApi(client);
      await api.cashFlow(
        const DateRangeChoice.named('last_month'),
        currency: 'INR',
        granularity: 'week',
      );
      expect(last().method, 'GET');
      expect(last().uri.path, '/api/v1/analytics/cash-flow');
      expect(last().uri.queryParameters, <String, String>{
        'range': 'last_month',
        'currency': 'INR',
        'granularity': 'week',
      });

      await api.expenses(
        const DateRangeChoice.custom('2026-10-01', '2026-10-31'),
      );
      expect(last().uri.path, '/api/v1/analytics/expenses');
      expect(last().uri.queryParameters, <String, String>{
        'from': '2026-10-01',
        'to': '2026-10-31',
      });

      await api.income(const DateRangeChoice.named('this_month'));
      expect(last().uri.path, '/api/v1/analytics/income');
    });

    test('categories, merchants and accounts send their options', () async {
      final AnalyticsApi api = AnalyticsApi(client);
      answer = categoryReport().toJson();
      await api.categories(
        const DateRangeChoice.named('this_month'),
        currency: 'INR',
        subcategories: true,
      );
      expect(last().uri.path, '/api/v1/analytics/categories');
      expect(last().uri.queryParameters, <String, String>{
        'range': 'this_month',
        'currency': 'INR',
        'subcategories': 'true',
      });

      // Income per category (`kind=income`).
      answer = categoryReport().toJson();
      await api.categories(
        const DateRangeChoice.named('this_month'),
        currency: 'INR',
        income: true,
      );
      expect(last().uri.queryParameters, <String, String>{
        'range': 'this_month',
        'currency': 'INR',
        'kind': 'income',
      });

      answer = merchantReport().toJson();
      await api.merchants(
        const DateRangeChoice.named('this_month'),
        currency: 'USD',
      );
      expect(last().uri.path, '/api/v1/analytics/merchants');
      expect(last().uri.queryParameters, <String, String>{
        'range': 'this_month',
        'currency': 'USD',
        'limit': '20',
      });

      answer = accountsReport().toJson();
      await api.accounts(overviewOnly: true);
      expect(last().uri.path, '/api/v1/analytics/accounts');
      expect(last().uri.queryParameters, <String, String>{
        'overview_only': 'true',
      });
    });

    test('planning summaries and compare', () async {
      final AnalyticsApi api = AnalyticsApi(client);
      answer = budgetPerformance().toJson();
      expect((await api.budgets()).overCount, 1);
      expect(last().uri.path, '/api/v1/analytics/budgets');
      answer = goalReport().toJson();
      expect((await api.goals()).goals.single.name, 'Goa trip');
      expect(last().uri.path, '/api/v1/analytics/goals');
      answer = subscriptionSummary().toJson();
      expect((await api.subscriptions()).totals.single.count, 1);
      expect(last().uri.path, '/api/v1/analytics/subscriptions');
      answer = recurringReport().toJson();
      expect(
        (await api.recurring()).noteCode,
        RecurringReportNoteCode.fixedAmountsExpectations,
      );
      expect(last().uri.path, '/api/v1/analytics/recurring');

      answer = comparison().toJson();
      await api.compare(
        const DateRangeChoice.named('this_month'),
        compareFrom: '2026-10-01',
        compareTo: '2026-10-31',
      );
      expect(last().uri.path, '/api/v1/analytics/compare');
      expect(last().uri.queryParameters, <String, String>{
        'range': 'this_month',
        'compare_from': '2026-10-01',
        'compare_to': '2026-10-31',
      });
    });

    test('route queries round-trip and bad values fall back', () {
      final AnalyticsQuery q = AnalyticsQuery.fromQuery(<String, String>{
        'from': '2026-10-01',
        'to': '2026-10-31',
        'currency': 'USD',
        'granularity': 'month',
      });
      expect(q.range, const DateRangeChoice.custom('2026-10-01', '2026-10-31'));
      expect(AnalyticsQuery.fromQuery(q.toQuery()), q);
      final AnalyticsQuery bad = AnalyticsQuery.fromQuery(<String, String>{
        'range': 'forever',
        'currency': 'usd',
        'granularity': 'hour',
        'from': '2026-10-31',
        'to': '2026-10-01',
      });
      expect(bad, const AnalyticsQuery());
      expect(previousPeriod('2026-11-01', 30), (
        from: '2026-10-02',
        to: '2026-10-31',
      ));
      expect(
        orderCurrencies(<String>['USD', 'INR', 'EUR', 'USD'], 'INR'),
        <String>['INR', 'EUR', 'USD'],
      );
      expect(pickCurrency(<String>['EUR', 'USD'], 'INR', 'INR'), 'EUR');
      expect(pickCurrency(<String>['INR', 'USD'], 'USD', 'INR'), 'USD');
      expect(pickCurrency(const <String>[], 'USD', 'INR'), isNull);
    });
  });

  group('reports', () {
    test('create sends the type, format, title and filters', () async {
      answer = reportJson(status: 'queued');
      await ReportsApi(client).create(
        const ReportInput(
          reportType: ReportInputReportType.transactions,
          format: ReportInputFormat.pdf,
          title: 'Tax papers',
          filters: Filters(from: '2026-10-01', to: '2026-11-30'),
        ),
      );
      expect(last().method, 'POST');
      expect(last().uri.path, '/api/v1/reports');
      expect(last().data, <String, Object?>{
        'report_type': 'transactions',
        'format': 'pdf',
        'title': 'Tax papers',
        'filters': <String, Object?>{'from': '2026-10-01', 'to': '2026-11-30'},
      });
    });

    test('download asks for a signed link; schedules are created and '
        'deleted', () async {
      final ReportsApi api = ReportsApi(client);
      answer = access(fileId: 'f-9', filename: 'monthly-summary.csv').toJson();
      final Access link = await api.download('rep-1');
      expect(last().uri.path, '/api/v1/reports/rep-1/download');
      expect(link.filename, 'monthly-summary.csv');

      answer = schedule().toJson();
      await api.createSchedule(
        const ScheduleInput(
          reportType: ScheduleInputReportType.cashFlow,
          format: ScheduleInputFormat.xlsx,
          cadence: ScheduleInputCadence.monthly,
        ),
      );
      expect(last().uri.path, '/api/v1/reports/schedules');
      expect(last().data, <String, Object?>{
        'report_type': 'cash_flow',
        'format': 'xlsx',
        'cadence': 'monthly',
      });
      answer = <String, Object?>{'ok': true};
      await api.deleteSchedule('sch-1');
      expect(last().method, 'DELETE');
      expect(last().uri.path, '/api/v1/reports/schedules/sch-1');
    });

    test('a report is deleted; a schedule is edited, paused and resumed '
        'with PATCH and its version', () async {
      final ReportsApi api = ReportsApi(client);
      answer = <String, Object?>{'ok': true};
      await api.delete('rep-1');
      expect(last().method, 'DELETE');
      expect(last().uri.path, '/api/v1/reports/rep-1');

      answer = schedule().toJson();
      await api.updateSchedule(
        'sch-1',
        const SchedulePatch(
          cadence: SchedulePatchCadence.weekly,
          title: '',
          version: 3,
        ),
      );
      expect(last().method, 'PATCH');
      expect(last().uri.path, '/api/v1/reports/schedules/sch-1');
      expect(last().data, <String, Object?>{
        'cadence': 'weekly',
        'title': '',
        'version': 3,
      });
      await api.updateSchedule(
        'sch-1',
        const SchedulePatch(enabled: false, version: 4),
      );
      expect(last().data, <String, Object?>{'enabled': false, 'version': 4});
    });

    test('making a report again asks for the same dates', () {
      final ReportDto r = ReportDto.fromJson(<String, Object?>{
        ...reportJson(filters: <String, Object?>{'range': 'last_month'}),
        'window': windowJson(from: '2026-10-01', to: '2026-10-31', days: 31),
      });
      expect(againFilters(r).toJson(), <String, Object?>{
        'from': '2026-10-01',
        'to': '2026-10-31',
      });
      // Current-state reports keep their filters.
      expect(againFilters(report()).toJson(), <String, Object?>{
        'range': 'this_month',
      });
    });
  });

  group('exchange rates', () {
    test('list filters, manual rates and deletes', () async {
      final FxApi api = FxApi(client);
      answer = <Object?>[rateDto().toJson()];
      await api.rates(base: 'USD');
      expect(last().uri.path, '/api/v1/fx/rates');
      expect(last().uri.queryParameters, <String, String>{'base': 'USD'});

      answer = rateDto().toJson();
      await api.setRate(
        const ManualRateInput(
          baseValue: 'USD',
          quote: 'INR',
          rate: '83.1234',
          asOf: '2026-11-01',
        ),
      );
      expect(last().method, 'POST');
      expect(last().data, <String, Object?>{
        'base': 'USD',
        'quote': 'INR',
        'rate': '83.1234',
        'as_of': '2026-11-01',
      });
      answer = <String, Object?>{'ok': true};
      await api.deleteRate('rate-1');
      expect(last().method, 'DELETE');
      expect(last().uri.path, '/api/v1/fx/rates/rate-1');
    });

    test('convert sends the latest-rate policy, or the date for a '
        'historical rate', () async {
      final FxApi api = FxApi(client);
      answer = conversion().toJson();
      await api.convert(amount: '100.00', from: 'USD', to: 'INR');
      expect(last().uri.path, '/api/v1/fx/convert');
      expect(last().uri.queryParameters, <String, String>{
        'amount': '100.00',
        'from': 'USD',
        'to': 'INR',
        'policy': 'current',
      });
      await api.convert(
        amount: '10.00',
        from: 'EUR',
        to: 'INR',
        historical: true,
        date: '2026-11-02',
      );
      expect(last().uri.queryParameters, <String, String>{
        'amount': '10.00',
        'from': 'EUR',
        'to': 'INR',
        'policy': 'historical',
        'date': '2026-11-02',
      });
    });

    test('typed rates are exact decimals', () {
      expect(parseRate('83.1234'), '83.1234');
      expect(parseRate(' 90,5 '), '90.5');
      expect(parseRate('0.000000000001'), '0.000000000001');
      expect(parseRate('0'), isNull);
      expect(parseRate('-2'), isNull);
      expect(parseRate('1.0000000000001'), isNull);
      expect(parseRate('1e3'), isNull);
      expect(parseRate(''), isNull);
    });
  });

  group('reconciliation', () {
    test('balances and checks use the account path', () async {
      final ReconciliationApi api = ReconciliationApi(client);
      answer = <Object?>[reconBalance().toJson()];
      await api.balances('acc-1', cursor: 'c2');
      expect(last().uri.path, '/api/v1/accounts/acc-1/reconciliations');
      expect(last().uri.queryParameters, <String, String>{
        'cursor': 'c2',
        'limit': '${ReconciliationApi.pageSize}',
      });

      answer = reconBalance().toJson();
      await api.reconcile(
        'acc-card',
        const ReconBalanceInput(
          statementDate: '2026-11-04',
          statementBalance: '2100.00',
          balanceKind: ReconBalanceInputBalanceKind.amountOwed,
        ),
      );
      expect(last().method, 'POST');
      expect(last().uri.path, '/api/v1/accounts/acc-card/reconciliations');
      expect(last().data, <String, Object?>{
        'statement_date': '2026-11-04',
        'statement_balance': '2100.00',
        'balance_kind': 'amount_owed',
      });
    });

    test('candidates, matches and unmatch', () async {
      final ReconciliationApi api = ReconciliationApi(client);
      answer = <Object?>[reconCandidate().toJson()];
      await api.candidates(
        'acc-1',
        kind: 'statement_to_ledger',
        batchId: 'b-1',
      );
      expect(last().uri.path, '/api/v1/reconciliation/candidates');
      expect(last().uri.queryParameters, <String, String>{
        'account_id': 'acc-1',
        'kind': 'statement_to_ledger',
        'batch_id': 'b-1',
      });
      answer = <Object?>[reconMatch().toJson()];
      await api.matches('acc-1');
      expect(last().uri.path, '/api/v1/reconciliation/matches');
      expect(last().uri.queryParameters, <String, String>{
        'account_id': 'acc-1',
        'limit': '${ReconciliationApi.pageSize}',
      });

      answer = reconMatch().toJson();
      await api.confirm(confirmInput('acc-1', reconCandidate()));
      expect(last().method, 'POST');
      expect(last().data, <String, Object?>{
        'account_id': 'acc-1',
        'kind': 'pending_to_posted',
        'transaction_ids': <Object?>['tx-pending', 'tx-posted'],
      });
      await api.unmatch('match-1');
      expect(last().method, 'DELETE');
      expect(last().uri.path, '/api/v1/reconciliation/matches/match-1');
    });

    test('statement lines page by status; a line is matched by hand with '
        'chosen transactions', () async {
      final ReconciliationApi api = ReconciliationApi(client);
      answer = <Object?>[statementLineJson()];
      final page = await api.statementLines('acc-1', cursor: 'c1', limit: 20);
      expect(last().uri.path, '/api/v1/accounts/acc-1/statement-lines');
      expect(last().uri.queryParameters, <String, String>{
        'status': 'unmatched',
        'cursor': 'c1',
        'limit': '20',
      });
      expect(page.items.single.importRowId, 'row-2');
      await api.statementLines('acc-1', matched: true, batchId: 'b-1');
      expect(last().uri.queryParameters, <String, String>{
        'status': 'matched',
        'batch_id': 'b-1',
        'limit': '${ReconciliationApi.pageSize}',
      });

      answer = reconMatch().toJson();
      await api.confirm(
        manualMatchInput('acc-1', page.items.single, <String>['tx-1', 'tx-2']),
      );
      expect(last().method, 'POST');
      expect(last().uri.path, '/api/v1/reconciliation/matches');
      expect(last().data, <String, Object?>{
        'account_id': 'acc-1',
        'kind': 'statement_to_ledger',
        'statement_row_ids': <Object?>['row-2'],
        'transaction_ids': <Object?>['tx-1', 'tx-2'],
      });
    });

    test('statement matches send rows and transactions; duplicates say '
        'which to keep', () {
      final ReconCandidate statement = reconCandidate(
        kind: 'statement_to_ledger',
        left: reconItemJson(
          side: 'statement',
          transactionId: null,
          importRowId: 'row-1',
          status: 'duplicate',
        ),
      );
      expect(confirmInput('acc-1', statement).toJson(), <String, Object?>{
        'account_id': 'acc-1',
        'kind': 'statement_to_ledger',
        'statement_row_ids': <String>['row-1'],
        'transaction_ids': <String>['tx-posted'],
      });
      final ReconCandidate twice = reconCandidate(
        kind: 'manual_to_imported',
        left: reconItemJson(
          transactionId: 'tx-manual',
          status: 'posted/manual',
        ),
        right: <Map<String, Object?>>[
          reconItemJson(transactionId: 'tx-import', status: 'posted/import'),
        ],
      );
      expect(
        confirmInput('acc-1', twice, keepTransactionId: 'tx-import').toJson(),
        <String, Object?>{
          'account_id': 'acc-1',
          'kind': 'manual_to_imported',
          'transaction_ids': <String>['tx-manual', 'tx-import'],
          'keep_transaction_id': 'tx-import',
        },
      );
      expect(confidencePercent('0.950'), 95);
      expect(confidencePercent(null), isNull);
    });
  });
}
