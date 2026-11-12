import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/group_money_fakes.dart';
import '../../helpers/people_fakes.dart';
import '../../helpers/router_app.dart';

/// Every group money screen at 200 % text in English and Hindi must lay
/// out without overflow (an overflow fails the test).
void main() {
  late MockGroupMoneyApi api;
  late MockPeopleApi people;
  late MockAccountsApi accounts;

  setUpAll(registerGroupMoneyFallbacks);

  setUp(() {
    api = MockGroupMoneyApi();
    people = MockPeopleApi();
    accounts = MockAccountsApi();
    stubGroupMoney(api, people, accounts);
    when(() => api.expense(any(), any())).thenAnswer(
      (_) async => expenseDetail(
        split: 'itemized',
        original: '40.00',
        originalCurrency: 'USD',
        fxRate: '83.5',
        fxSource: 'ecb',
        amount: '3340.00',
        revisions: 3,
        myTransactionId: 'tx-1',
        receiptFileId: 'file-1',
        items: <Map<String, Object?>>[
          <String, Object?>{
            'description': 'Sunscreen and a very long item description',
            'amount': moneyJson('400.00'),
            'shares': <Object?>[
              <String, Object?>{'user_id': me, 'share': moneyJson('133.33')},
              <String, Object?>{'user_id': meera, 'share': moneyJson('266.67')},
            ],
          },
        ],
        comments: <Map<String, Object?>>[
          <String, Object?>{
            'id': 'c-1',
            'author_id': ravi,
            'body': 'Was this with the tip? It looked higher than the menu.',
            'created_at': '2026-11-12T06:01:35Z',
          },
        ],
        disputes: <Map<String, Object?>>[
          <String, Object?>{
            'id': 'd-1',
            'raised_by': me,
            'reason': 'Amount was 3000',
            'status': 'open',
            'created_at': '2026-11-12T06:01:35Z',
          },
        ],
      ),
    );
    when(() => api.settlement(any(), any())).thenAnswer(
      (_) async => settlement(
        status: 'disputed',
        correctsId: 'st-0',
        myTransactionId: 'tx-2',
      ),
    );
  });

  Future<void> walk(
    WidgetTester tester,
    Locale locale,
    List<String> locations,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final ({Widget app, GoRouter router}) r = routedApp(
      '/groups/$gid/expenses',
      overrides: groupMoneyOverrides(api, people, accounts),
      locale: locale,
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'expenses');
    for (final String location in locations) {
      unawaited(r.router.push<Object?>(location));
      await tester.pumpAndSettle();
      for (int i = 0; i < 10; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: location);
      r.router.pop();
      await tester.pumpAndSettle();
    }
  }

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('group money screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      await walk(tester, locale, <String>[
        '/groups/$gid/expenses/new',
        '/groups/$gid/expenses/exp-1',
        '/groups/$gid/expenses/exp-1/edit',
        '/groups/$gid/balances',
        '/groups/$gid/settlements',
        '/groups/$gid/settlements/new?payer=$meera&payee=$former&amount=10',
        '/groups/$gid/settlements/st-1',
        '/groups/$gid/settlements/st-1/correct',
        '/groups/$gid/recurring',
        '/groups/$gid/recurring/new',
        '/groups/$gid/recurring/rule-1',
        '/groups/$gid/recurring/rule-1/edit',
        '/groups/$gid/reports',
      ]);
    });
  }

  testWidgets('empty states fit at 200% text (hi)', (
    WidgetTester tester,
  ) async {
    when(
      () => api.expenses(
        any(),
        filter: any(named: 'filter'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => expensePage(<GroupExpenseDto>[]));
    when(
      () => api.settlements(any(), includeVoided: any(named: 'includeVoided')),
    ).thenAnswer((_) async => <SettlementDto>[]);
    when(() => api.recurring(any()))
        .thenAnswer((_) async => <GroupRecurringDto>[]);
    when(
      () => api.report(
        any(),
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => groupReport(empty: true));
    when(() => api.balances(any()))
        .thenAnswer((_) async => balances(settled: true, disputed: 1));
    await walk(tester, const Locale('hi'), <String>[
      '/groups/$gid/balances',
      '/groups/$gid/settlements',
      '/groups/$gid/recurring',
      '/groups/$gid/reports',
    ]);
  });
}
