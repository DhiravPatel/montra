import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/reconciliation/data/reconciliation_api.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/insights_fakes.dart';
import '../../helpers/router_app.dart';

/// Matching statement lines by hand (`GET /accounts/{id}/statement-lines`,
/// `POST /reconciliation/matches`).
void main() {
  late MockReconciliationApi api;
  late MockAccountsApi accounts;
  late MockTransactionsApi transactions;
  late MockLabelsApi labels;

  setUpAll(() {
    registerInsightsFallbacks();
    registerFinanceFallbacks();
  });

  CursorPage<StatementLineDto> lines(List<StatementLineDto> items) =>
      CursorPage<StatementLineDto>(items, null);

  void stubLines({
    List<StatementLineDto>? unmatched,
    List<StatementLineDto> matched = const <StatementLineDto>[],
  }) {
    when(
      () => api.statementLines(
        any(),
        matched: false,
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer(
      (_) async => lines(unmatched ?? <StatementLineDto>[statementLine()]),
    );
    when(
      () => api.statementLines(
        any(),
        matched: true,
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async => lines(matched));
  }

  setUp(() {
    api = MockReconciliationApi();
    accounts = MockAccountsApi();
    transactions = MockTransactionsApi();
    labels = MockLabelsApi();
    stubLabels(labels);
    when(() => accounts.get('acc-1')).thenAnswer((_) async => account());
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    when(
      () => transactions.list(
        any(),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => page(<TransactionDto>[
        transaction(
          id: 'tx-cab',
          amount: '415.00',
          description: 'Cab to airport',
          merchant: null,
        ),
        transaction(
          id: 'tx-salary',
          type: 'income',
          direction: 'inflow',
          amount: '60000.00',
          description: 'Salary',
          merchant: null,
        ),
      ]),
    );
  });

  List<Override> overrides() => <Override>[
    reconciliationApiProvider.overrideWithValue(api),
    accountsApiProvider.overrideWithValue(accounts),
    transactionsApiProvider.overrideWithValue(transactions),
    labelsApiProvider.overrideWithValue(labels),
  ];

  Future<GoRouter> pump(
    WidgetTester tester,
    String location, {
    Locale locale = const Locale('en'),
  }) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(),
      locale: locale,
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  testWidgets('a line is matched by hand with transactions going the same '
      'way', (WidgetTester tester) async {
    stubLines();
    when(() => api.confirm(any())).thenAnswer((_) async => reconMatch());
    await pump(tester, '/accounts/acc-1/reconcile/lines');

    expect(find.text('Match by hand'), findsOneWidget);
    expect(find.text('CAB AIRPORT 9921'), findsOneWidget);
    expect(find.text('Looked like a duplicate, not imported'), findsOneWidget);

    await tester.tap(find.text('CAB AIRPORT 9921'));
    await tester.pumpAndSettle();
    expect(find.text('Choose the transactions'), findsOneWidget);
    // Only money going out, like the line, is offered.
    expect(find.text('Cab to airport'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);
    final TransactionFilter filter =
        verify(
              () => transactions.list(
                captureAny(),
                cursor: any(named: 'cursor'),
                limit: any(named: 'limit'),
              ),
            ).captured.last
            as TransactionFilter;
    expect(filter.accountIds, <String>{'acc-1'});
    expect(filter.reconciliationState, 'unreconciled');

    await tester.tap(find.text('Cab to airport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match 1 transaction'));
    await tester.pumpAndSettle();
    final ReconMatchInput sent =
        verify(() => api.confirm(captureAny())).captured.single
            as ReconMatchInput;
    expect(sent.toJson(), <String, Object?>{
      'account_id': 'acc-1',
      'kind': 'statement_to_ledger',
      'statement_row_ids': <String>['row-2'],
      'transaction_ids': <String>['tx-cab'],
    });
    expect(find.text('Matched'), findsOneWidget);
  });

  testWidgets('a line matched by hand can be unmatched after confirming', (
    WidgetTester tester,
  ) async {
    stubLines(matched: <StatementLineDto>[statementLine(matchId: 'm-1')]);
    when(() => api.unmatch('m-1'))
        .thenAnswer((_) async => reconMatch(status: 'unmatched'));
    await pump(tester, '/accounts/acc-1/reconcile/lines?status=matched');
    expect(find.text('Matched by hand'), findsWidgets);
    await tester.tap(find.text('CAB AIRPORT 9921'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Undo match'));
    await tester.pumpAndSettle();
    verify(() => api.unmatch('m-1')).called(1);
  });

  testWidgets('amounts that do not add up are explained', (
    WidgetTester tester,
  ) async {
    stubLines();
    when(() => api.confirm(any())).thenThrow(
      serverError(
        ErrorObjectCode.domainRuleViolation,
        details: const <Detail>[
          Detail(
            code: 'sums_differ',
            message: 'The statement side 415.00 differs.',
            params: <String, String>{
              'statement': '415.00',
              'ledger': '400.00',
              'currency': 'INR',
            },
          ),
        ],
      ),
    );
    await pump(tester, '/accounts/acc-1/reconcile/lines');
    await tester.tap(find.text('CAB AIRPORT 9921'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cab to airport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match 1 transaction'));
    await tester.pumpAndSettle();
    expect(find.textContaining('415.00'), findsWidgets);
    expect(find.text('Matched'), findsNothing);
  });

  testWidgets('empty lists say so; a failed load can be retried', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    when(
      () => api.statementLines(
        any(),
        matched: false,
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw offline;
      }
      return lines(<StatementLineDto>[]);
    });
    when(
      () => api.statementLines(
        any(),
        matched: true,
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async => lines(<StatementLineDto>[]));
    await pump(tester, '/accounts/acc-1/reconcile/lines');
    expect(find.text("You're offline"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(
      find.text('Every statement line is imported or matched.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Matched by hand'));
    await tester.pumpAndSettle();
    expect(find.text("You haven't matched any lines by hand."), findsOneWidget);
  });

  testWidgets('the reconciliation screen links to matching by hand', (
    WidgetTester tester,
  ) async {
    stubLines();
    when(() => api.balances(any(), cursor: any(named: 'cursor'))).thenAnswer(
      (_) async => const CursorPage<ReconBalanceDto>(<ReconBalanceDto>[], null),
    );
    when(
      () => api.candidates(
        any(),
        kind: any(named: 'kind'),
        batchId: any(named: 'batchId'),
      ),
    ).thenAnswer((_) async => <ReconCandidate>[]);
    when(() => api.matches(any(), cursor: any(named: 'cursor'))).thenAnswer(
      (_) async => const CursorPage<ReconMatchDto>(<ReconMatchDto>[], null),
    );
    final GoRouter router = await pump(tester, '/accounts/acc-1/reconcile');
    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match by hand'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/accounts/acc-1/reconcile/lines');
  });

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('matching by hand fits at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      stubLines(
        unmatched: <StatementLineDto>[
          statementLine(
            description: 'UBER INDIA SYSTEMS PRIVATE LIMITED BANGALORE 7781',
          ),
          statementLine(id: 'row-3', description: null),
        ],
        matched: <StatementLineDto>[statementLine(matchId: 'm-1')],
      );
      await pump(tester, '/accounts/acc-1/reconcile/lines', locale: locale);
      expect(tester.takeException(), isNull);
      final Finder line = find.text(
        'UBER INDIA SYSTEMS PRIVATE LIMITED BANGALORE 7781',
      );
      await tester.scrollUntilVisible(
        line,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(line);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The lines matched by hand.
      await pump(
        tester,
        '/accounts/acc-1/reconcile/lines?status=matched',
        locale: locale,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
