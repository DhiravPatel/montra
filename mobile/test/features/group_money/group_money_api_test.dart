import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/group_money/data/group_money_api.dart';
import 'package:montra_mobile/features/group_money/domain/group_export.dart';

import '../../helpers/fakes.dart';
import '../../helpers/group_money_fakes.dart';

/// The requests `GroupMoneyApi` sends, checked on the wire, for every group
/// money operation.
void main() {
  late FakeHttpAdapter adapter;
  late GroupMoneyApi api;
  Object? answer = envelope(expenseJson());
  int status = 200;

  setUp(() {
    answer = envelope(expenseJson());
    status = 200;
    adapter = FakeHttpAdapter(
      (RequestOptions o) async => jsonResponse(status, answer),
    );
    final Dio dio = createApiDio(
      testConfig,
      adapter: adapter,
      enableLogging: false,
    );
    api = GroupMoneyApi(ApiClient(dio), dio);
  });

  RequestOptions sent() => adapter.requests.single;

  group('expenses', () {
    test('list pages with the cursor and sends every filter', () async {
      answer = <String, Object?>{
        'data': <Object?>[expenseJson()],
        'meta': <String, Object?>{
          'request_id': 'r',
          'timestamp': '2026-11-12T06:00:00Z',
          'next_cursor': 'c2',
          'has_more': true,
        },
      };
      final CursorPage<GroupExpenseDto> page = await api.expenses(
        gid,
        filter: const GroupExpenseFilter(
          status: 'deleted',
          from: '2026-11-01',
          to: '2026-11-30',
          payerUserId: ravi,
          categoryKey: 'uncategorized',
        ),
        cursor: 'c1',
      );
      expect(sent().method, 'GET');
      expect(sent().uri.path, '/api/v1/groups/$gid/expenses');
      expect(sent().uri.queryParameters, <String, String>{
        'status': 'deleted',
        'include_deleted': 'true',
        'from': '2026-11-01',
        'to': '2026-11-30',
        'payer_user_id': ravi,
        'category_key': 'uncategorized',
        'cursor': 'c1',
        'limit': '50',
      });
      expect(page.items.single.id, 'exp-1');
      expect(page.nextCursor, 'c2');
    });

    test('the last page has no cursor', () async {
      answer = <String, Object?>{
        'data': <Object?>[],
        'meta': <String, Object?>{
          'request_id': 'r',
          'timestamp': '2026-11-12T06:00:00Z',
          'has_more': false,
          'next_cursor': 'ignored',
        },
      };
      final CursorPage<GroupExpenseDto> page = await api.expenses(gid);
      expect(page.hasMore, isFalse);
      expect(sent().uri.queryParameters, <String, String>{'limit': '50'});
    });

    test('create sends the Idempotency-Key and the split, payers, items '
        'and foreign currency', () async {
      status = 201;
      await api.createExpense(
        gid,
        const GroupExpenseInput(
          description: 'Boat tour',
          originalAmount: '40.00',
          originalCurrency: 'USD',
          fxRateSource: GroupExpenseInputFxRateSource.lookup,
          splitMethod: GroupExpenseInputSplitMethod.shares,
          participants: <ExpenseParticipantInput>[
            ExpenseParticipantInput(userId: me, value: '1'),
            ExpenseParticipantInput(userId: ravi, value: '2'),
          ],
        ),
        key: 'exp-key-12345678',
      );
      expect(sent().method, 'POST');
      expect(sent().uri.path, '/api/v1/groups/$gid/expenses');
      expect(sent().headers['Idempotency-Key'], 'exp-key-12345678');
      expect(sent().data, <String, Object?>{
        'description': 'Boat tour',
        'original_amount': '40.00',
        'original_currency': 'USD',
        'fx_rate_source': 'lookup',
        'split_method': 'shares',
        'participants': <Object?>[
          <String, Object?>{'user_id': me, 'value': '1'},
          <String, Object?>{'user_id': ravi, 'value': '2'},
        ],
      });
      expect(ApiEndpoints.createGroupExpense.idempotent, isTrue);
    });

    test('get, update with version and delete', () async {
      await api.expense(gid, 'exp-1');
      expect(
        adapter.requests.last.uri.path,
        '/api/v1/groups/$gid/expenses/exp-1',
      );
      await api.updateExpense(
        gid,
        'exp-1',
        const GroupExpenseInput(
          description: 'Dinner',
          amount: '3300.00',
          participants: <ExpenseParticipantInput>[
            ExpenseParticipantInput(userId: me),
          ],
          payers: <ExpensePayerInput>[
            ExpensePayerInput(userId: me, amount: '3300.00'),
          ],
          version: 4,
        ),
      );
      final RequestOptions patch = adapter.requests.last;
      expect(patch.method, 'PATCH');
      expect((patch.data as Map<String, Object?>)['version'], 4);
      expect((patch.data as Map<String, Object?>)['payers'], isNotEmpty);
      answer = envelope(<String, Object?>{'ok': true});
      await api.deleteExpense(gid, 'exp-1');
      expect(adapter.requests.last.method, 'DELETE');
      expect(
        adapter.requests.last.uri.path,
        '/api/v1/groups/$gid/expenses/exp-1',
      );
    });

    test('comments, disputes and resolving them', () async {
      status = 201;
      answer = envelope(<String, Object?>{
        'id': 'c-1',
        'author_id': me,
        'body': 'With tip?',
        'created_at': '2026-11-12T06:01:35Z',
      });
      final GroupCommentDto c = await api.comment(gid, 'exp-1', 'With tip?');
      expect(c.body, 'With tip?');
      expect(
        adapter.requests.last.uri.path,
        endsWith('/expenses/exp-1/comments'),
      );
      expect(adapter.requests.last.data, <String, Object?>{
        'body': 'With tip?',
      });
      answer = envelope(<String, Object?>{
        'id': 'd-1',
        'raised_by': me,
        'reason': 'Wrong',
        'status': 'open',
        'created_at': '2026-11-12T06:01:35Z',
      });
      await api.dispute(gid, 'exp-1', 'Wrong');
      expect(
        adapter.requests.last.uri.path,
        endsWith('/expenses/exp-1/disputes'),
      );
      expect(adapter.requests.last.data, <String, Object?>{'reason': 'Wrong'});
      status = 200;
      answer = envelope(<String, Object?>{'ok': true});
      await api.resolveDispute(gid, 'd-1', withdraw: true);
      expect(
        adapter.requests.last.uri.path,
        '/api/v1/groups/$gid/disputes/d-1/resolve',
      );
      expect(adapter.requests.last.data, <String, Object?>{'withdraw': true});
      await api.resolveDispute(gid, 'd-1', resolution: 'Checked');
      expect(adapter.requests.last.data, <String, Object?>{
        'resolution': 'Checked',
      });
    });

    test('my-record links to an account and unlinks', () async {
      await api.myRecord(gid, 'exp-1', accountId: 'acc-1');
      expect(
        adapter.requests.last.uri.path,
        endsWith('/expenses/exp-1/my-record'),
      );
      expect(adapter.requests.last.data, <String, Object?>{
        'account_id': 'acc-1',
        'action': 'link',
      });
      await api.myRecord(gid, 'exp-1');
      expect(adapter.requests.last.data, <String, Object?>{'action': 'unlink'});
    });

    test('coded answers keep their detail code', () async {
      status = 409;
      answer = errorBody(
        ErrorObjectCode.conflict,
        details: <Map<String, Object?>>[
          <String, Object?>{
            'code': 'expense_already_recorded',
            'message': 'This expense is already recorded in your account.',
          },
        ],
      );
      await expectLater(
        api.myRecord(gid, 'exp-1', accountId: 'acc-1'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.details.single.code,
            'code',
            'expense_already_recorded',
          ),
        ),
      );
    });
  });

  group('balances and suggestions', () {
    test('balances and suggestions (mine)', () async {
      answer = envelope(balances().toJson());
      final GroupBalancesDto b = await api.balances(gid);
      expect(b.myNet.amount, '7754.43');
      expect(adapter.requests.last.uri.path, '/api/v1/groups/$gid/balances');
      answer = envelope(suggestions().toJson());
      await api.suggestions(gid, mine: true);
      expect(
        adapter.requests.last.uri.path,
        '/api/v1/groups/$gid/settlement-suggestions',
      );
      expect(adapter.requests.last.uri.queryParameters, <String, String>{
        'mine': 'true',
      });
    });
  });

  group('settlements', () {
    test('list (voided too), get, create with the key, correct', () async {
      answer = envelope(<Object?>[settlement().toJson()]);
      await api.settlements(gid, includeVoided: true);
      expect(adapter.requests.last.uri.queryParameters, <String, String>{
        'include_voided': 'true',
      });
      answer = envelope(settlement().toJson());
      await api.settlement(gid, 'st-1');
      expect(
        adapter.requests.last.uri.path,
        '/api/v1/groups/$gid/settlements/st-1',
      );
      status = 201;
      await api.createSettlement(
        gid,
        const SettlementInput(
          payerUserId: ravi,
          payeeUserId: me,
          amount: '500.00',
          method: SettlementInputMethod.upi,
          state: SettlementInputState.proposed,
        ),
        key: 'st-key-12345678',
      );
      expect(adapter.requests.last.uri.path, '/api/v1/groups/$gid/settlements');
      expect(
        adapter.requests.last.headers['Idempotency-Key'],
        'st-key-12345678',
      );
      expect(adapter.requests.last.data, <String, Object?>{
        'amount': '500.00',
        'method': 'upi',
        'payee_user_id': me,
        'payer_user_id': ravi,
        'state': 'proposed',
      });
      await api.correctSettlement(
        gid,
        'st-1',
        const SettlementInput(
          payerUserId: ravi,
          payeeUserId: me,
          amount: '450.00',
        ),
        key: 'fix-key-12345678',
      );
      expect(
        adapter.requests.last.uri.path,
        '/api/v1/groups/$gid/settlements/st-1/correct',
      );
      expect(
        adapter.requests.last.headers['Idempotency-Key'],
        'fix-key-12345678',
      );
      expect(ApiEndpoints.createGroupSettlement.idempotent, isTrue);
      expect(ApiEndpoints.correctGroupSettlement.idempotent, isTrue);
    });

    test('every lifecycle action sends the version', () async {
      answer = envelope(settlement().toJson());
      for (final (SettlementAction action, String path)
          in <(SettlementAction, String)>[
            (SettlementAction.markPaid, 'mark-paid'),
            (SettlementAction.confirm, 'confirm'),
            (SettlementAction.dispute, 'dispute'),
            (SettlementAction.voidIt, 'void'),
            (SettlementAction.record, 'record'),
            (SettlementAction.unlink, 'unlink'),
          ]) {
        await api.settlementAction(
          gid,
          'st-1',
          action,
          version: 3,
          accountId: action == SettlementAction.record ? 'acc-1' : null,
          reason: action == SettlementAction.voidIt ? 'Twice' : null,
        );
        final RequestOptions r = adapter.requests.last;
        expect(r.method, 'POST');
        expect(r.uri.path, '/api/v1/groups/$gid/settlements/st-1/$path');
        expect((r.data as Map<String, Object?>)['version'], 3);
      }
      expect(adapter.requests[4].data, <String, Object?>{
        'account_id': 'acc-1',
        'version': 3,
      });
      expect(adapter.requests[3].data, <String, Object?>{
        'reason': 'Twice',
        'version': 3,
      });
    });
  });

  group('recurring shared expenses', () {
    test('list, get, create with the key, update with version', () async {
      answer = envelope(<Object?>[recurring().toJson()]);
      await api.recurring(gid);
      expect(
        adapter.requests.last.uri.path,
        '/api/v1/groups/$gid/recurring-expenses',
      );
      answer = envelope(recurring().toJson());
      await api.recurringRule(gid, 'rule-1');
      expect(
        adapter.requests.last.uri.path,
        '/api/v1/groups/$gid/recurring-expenses/rule-1',
      );
      status = 201;
      await api.createRecurring(
        gid,
        const GroupRecurringInput(
          name: 'Cleaning',
          amount: '600.00',
          frequency: GroupRecurringInputFrequency.daily,
          startDate: '2026-11-01',
          participants: <ExpenseParticipantInput>[
            ExpenseParticipantInput(userId: me),
          ],
        ),
        key: 'rec-key-12345678',
      );
      expect(
        adapter.requests.last.headers['Idempotency-Key'],
        'rec-key-12345678',
      );
      expect(ApiEndpoints.createGroupRecurring.idempotent, isTrue);
      status = 200;
      await api.updateRecurring(
        gid,
        'rule-1',
        const GroupRecurringUpdate(
          name: 'Cleaning',
          amount: '650.00',
          version: 2,
          participants: <ExpenseParticipantInput>[
            ExpenseParticipantInput(userId: me),
          ],
        ),
      );
      expect(adapter.requests.last.method, 'PATCH');
      expect(
        (adapter.requests.last.data as Map<String, Object?>)['version'],
        2,
      );
    });

    test('pause, resume, stop; add (with key) and skip occurrences', () async {
      answer = envelope(recurring().toJson());
      for (final GroupRecurringAction a in GroupRecurringAction.values) {
        await api.recurringAction(gid, 'rule-1', a);
        expect(
          adapter.requests.last.uri.path,
          '/api/v1/groups/$gid/recurring-expenses/rule-1/${a.name}',
        );
        expect(adapter.requests.last.method, 'POST');
      }
      await api.skipOccurrence(gid, 'rule-1', 'occ-3');
      expect(
        adapter.requests.last.uri.path,
        '/api/v1/groups/$gid/recurring-expenses/rule-1/occurrences/occ-3/skip',
      );
      status = 201;
      answer = envelope(expenseJson());
      await api.addOccurrence(gid, 'rule-1', 'occ-3', key: 'occ-key-12345678');
      expect(
        adapter.requests.last.uri.path,
        '/api/v1/groups/$gid/recurring-expenses/rule-1/occurrences/occ-3/add',
      );
      expect(
        adapter.requests.last.headers['Idempotency-Key'],
        'occ-key-12345678',
      );
      expect(ApiEndpoints.addGroupRecurringOccurrence.idempotent, isTrue);
    });
  });

  group('reports and export', () {
    test('report with a period', () async {
      answer = envelope(groupReport().toJson());
      final GroupReportDto r = await api.report(
        gid,
        from: '2026-11-01',
        to: '2026-11-02',
      );
      expect(r.totalSpent.amount, '23541.38');
      expect(adapter.requests.last.uri.queryParameters, <String, String>{
        'from': '2026-11-01',
        'to': '2026-11-02',
      });
    });

    test('export reads text/csv with its file name', () async {
      adapter.handler = (RequestOptions o) async => ResponseBody.fromString(
        groupExport.csv,
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['text/csv; charset=utf-8'],
          'content-disposition': <String>[
            'attachment; filename="goa-trip-expenses-2026-11-12.csv"',
          ],
        },
      );
      final GroupExport export = await api.export(gid);
      expect(adapter.requests.last.uri.path, '/api/v1/groups/$gid/export');
      expect(adapter.requests.last.headers['Accept'], 'text/csv');
      expect(export.fileName, 'goa-trip-expenses-2026-11-12.csv');
      expect(export.rowCount, 2);
      expect(export.toFile().bytes.take(3), <int>[0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(export.toFile().bytes), startsWith('record'));
    });

    test('export errors are decoded from the JSON envelope', () async {
      adapter.handler = (RequestOptions o) async => ResponseBody.fromString(
        jsonEncode(errorBody(ErrorObjectCode.notFound)),
        404,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      );
      await expectLater(
        api.export(gid),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            ErrorObjectCode.notFound,
          ),
        ),
      );
    });
  });
}
