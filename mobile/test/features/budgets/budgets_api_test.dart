import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/budgets/data/budgets_api.dart';

import '../../helpers/budgets_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/finance_fakes.dart';

/// The requests `BudgetsApi` sends, checked against the contract's shapes.
void main() {
  late FakeHttpAdapter adapter;
  late BudgetsApi api;

  Map<String, Object?> page(List<Object?> data, {String? next}) =>
      <String, Object?>{
        'data': data,
        'meta': <String, Object?>{
          'request_id': 'req-ok',
          'timestamp': '2026-11-05T10:00:00Z',
          'next_cursor': ?next,
        },
      };

  setUp(() {
    adapter = FakeHttpAdapter((RequestOptions o) async {
      if (o.path.endsWith('/transactions')) {
        return jsonResponse(
          200,
          page(<Object?>[transactionJson()], next: 'c2'),
        );
      }
      if (o.path.endsWith('/budget-alerts')) {
        return jsonResponse(200, page(<Object?>[]));
      }
      return jsonResponse(200, envelope(budgetJson()));
    });
    api = BudgetsApi(
      ApiClient(
        createApiDio(testConfig, adapter: adapter, enableLogging: false),
      ),
    );
  });

  test('PATCH sends only the patch fields with the version', () async {
    await api.update(
      'bud-1',
      BudgetPatch.fromJson(<String, Object?>{
        'alert_thresholds': <int>[],
        'notes': '',
        'version': 3,
      }),
    );
    final RequestOptions sent = adapter.requests.single;
    expect(sent.method, 'PATCH');
    expect(sent.uri.path, '/api/v1/budgets/bud-1');
    expect(sent.data, <String, Object?>{
      'alert_thresholds': <int>[],
      'notes': '',
      'version': 3,
    });
  });

  test('lifecycle actions send the displayed version; restore has its own '
      'endpoint', () async {
    await api.pause('bud-1', version: 3);
    await api.resume('bud-1', version: 4);
    await api.archive('bud-1', version: 5);
    await api.restore('bud-1', version: 6);
    expect(
      adapter.requests.map((RequestOptions r) => '${r.method} ${r.uri}'),
      <String>[
        'POST http://localhost:8080/api/v1/budgets/bud-1/pause?version=3',
        'POST http://localhost:8080/api/v1/budgets/bud-1/resume?version=4',
        'DELETE http://localhost:8080/api/v1/budgets/bud-1?version=5',
        'POST http://localhost:8080/api/v1/budgets/bud-1/restore?version=6',
      ],
    );
  });

  test('counted transactions and alerts page with a cursor', () async {
    final CursorPage<TransactionDto> first = await api.transactions(
      'bud-1',
      date: '2026-10-31',
    );
    expect(first.items.single.id, 'tx-1');
    expect(first.nextCursor, 'c2');
    await api.transactions('bud-1', cursor: 'c2');
    await api.alertsPage(status: 'active', cursor: 'a2');
    await api.alerts(status: 'snoozed');
    expect(adapter.requests[0].uri.queryParameters, <String, String>{
      'date': '2026-10-31',
      'limit': '50',
    });
    expect(adapter.requests[1].uri.queryParameters, <String, String>{
      'cursor': 'c2',
      'limit': '50',
    });
    expect(adapter.requests[2].uri.queryParameters, <String, String>{
      'status': 'active',
      'cursor': 'a2',
      'limit': '50',
    });
    expect(adapter.requests[3].uri.queryParameters, <String, String>{
      'status': 'snoozed',
      'limit': '200',
    });

    // One budget's alerts (`?budget_id=`).
    await api.alerts(status: 'active', budgetId: 'bud-1');
    expect(adapter.requests[4].uri.queryParameters, <String, String>{
      'status': 'active',
      'budget_id': 'bud-1',
      'limit': '200',
    });
  });
}
