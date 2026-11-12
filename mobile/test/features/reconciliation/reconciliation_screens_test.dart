import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/reconciliation/data/reconciliation_api.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/insights_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockReconciliationApi api;
  late MockAccountsApi accounts;

  setUpAll(() {
    registerInsightsFallbacks();
    registerFinanceFallbacks();
  });

  setUp(() {
    api = MockReconciliationApi();
    accounts = MockAccountsApi();
    when(() => accounts.get('acc-1')).thenAnswer((_) async => account());
    when(() => accounts.get('card')).thenAnswer(
      (_) async =>
          account(id: 'card', name: 'Rewards card', type: 'credit_card'),
    );
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    when(() => api.balances(any(), cursor: any(named: 'cursor'))).thenAnswer(
      (_) async => CursorPage<ReconBalanceDto>(<ReconBalanceDto>[
        reconBalance(),
        reconBalance(
          id: 'rb-0',
          balanced: true,
          reconciled: 6,
          unreconciled: 0,
          notes: null,
        ),
      ], null),
    );
    when(
      () => api.candidates(
        any(),
        kind: any(named: 'kind'),
        batchId: any(named: 'batchId'),
      ),
    ).thenAnswer((_) async => <ReconCandidate>[reconCandidate()]);
    when(() => api.matches(any(), cursor: any(named: 'cursor'))).thenAnswer(
      (_) async =>
          CursorPage<ReconMatchDto>(<ReconMatchDto>[reconMatch()], null),
    );
  });

  List<Override> overrides() => <Override>[
    reconciliationApiProvider.overrideWithValue(api),
    accountsApiProvider.overrideWithValue(accounts),
  ];

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  testWidgets('balance checks show the server difference and what changed', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pump(tester, '/accounts/acc-1/reconcile');
    expect(find.text('Reconcile HDFC Savings'), findsOneWidget);
    expect(find.textContaining('Off by'), findsOneWidget);
    expect(find.textContaining('31,410.50'), findsWidgets);
    expect(
      find.text("6 transactions up to this date aren't reconciled yet."),
      findsOneWidget,
    );
    expect(find.text('October statement'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('6 transactions marked as reconciled.'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Matches'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Check a statement balance'),
      -200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Check a statement balance'));
    await tester.pumpAndSettle();
    // AppRoutes.newReconciliation adds an empty query today (reported).
    expect(Uri.parse(locationOf(router)).path, '/accounts/acc-1/reconcile/new');
  });

  testWidgets('a statement balance check sends the exact amount and shows '
      'the result', (WidgetTester tester) async {
    when(() => api.reconcile(any(), any()))
        .thenAnswer((_) async => reconBalance(balanced: true, reconciled: 6));
    await pump(tester, '/accounts/acc-1/reconcile/new');
    expect(
      find.text(
        'Enter the closing balance shown on a statement for HDFC Savings.',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Compare'));
    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();
    expect(find.text('Choose the statement date.'), findsOneWidget);
    verifyNever(() => api.reconcile(any(), any()));

    await tester.tap(find.text('Choose the date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '131410.50');
    await tester.ensureVisible(find.text('Compare'));
    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();

    final List<Object?> captured = verify(
      () => api.reconcile(captureAny(), captureAny()),
    ).captured;
    expect(captured.first, 'acc-1');
    expect((captured.last! as ReconBalanceInput).toJson(), <String, Object?>{
      'statement_date': LocalDates.format(LocalDates.today()),
      'statement_balance': '131410.50',
    });
    expect(find.text('The balances match.'), findsOneWidget);
    expect(find.text('6 transactions marked as reconciled.'), findsOneWidget);
  });

  testWidgets('cards take the amount owed as a positive number', (
    WidgetTester tester,
  ) async {
    when(() => api.reconcile(any(), any()))
        .thenAnswer((_) async => reconBalance(balanced: true, reconciled: 1));
    await pump(tester, '/accounts/card/reconcile/new');
    expect(find.text('Amount you owe'), findsOneWidget);
    expect(find.text('Amount owed on the statement'), findsOneWidget);
    await tester.tap(find.text('Choose the date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '2100');
    await tester.ensureVisible(find.text('Compare'));
    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();
    final ReconBalanceInput sent =
        verify(() => api.reconcile('card', captureAny())).captured.single
            as ReconBalanceInput;
    expect(sent.balanceKind, ReconBalanceInputBalanceKind.amountOwed);
    expect(sent.statementBalance, '2100.00');
  });

  testWidgets('a suggested pending/posted pair is confirmed after '
      'explaining what it removes', (WidgetTester tester) async {
    when(() => api.confirm(any())).thenAnswer((_) async => reconMatch());
    await pump(tester, '/accounts/acc-1/reconcile');
    await tester.tap(find.text('Suggestions'));
    await tester.pumpAndSettle();

    expect(find.text('Pending now posted'), findsOneWidget);
    expect(find.text('Match likelihood: 95%'), findsOneWidget);
    expect(
      find.text(
        'Why: Same amount and direction; Same date; Similar description',
      ),
      findsOneWidget,
    );
    expect(find.text('Pending'), findsOneWidget);
    await tester.ensureVisible(find.text('Confirm match'));
    await tester.tap(find.text('Confirm match'));
    await tester.pumpAndSettle();
    expect(find.text('Replace the pending transaction?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm match'));
    await tester.pumpAndSettle();
    final ReconMatchInput sent =
        verify(() => api.confirm(captureAny())).captured.single
            as ReconMatchInput;
    expect(sent.transactionIds, <String>['tx-pending', 'tx-posted']);
    expect(sent.kind, ReconMatchInputKind.pendingToPosted);
  });

  testWidgets('a transaction entered twice asks which one to keep', (
    WidgetTester tester,
  ) async {
    when(
      () => api.candidates(
        any(),
        kind: any(named: 'kind'),
        batchId: any(named: 'batchId'),
      ),
    ).thenAnswer(
      (_) async => <ReconCandidate>[
        reconCandidate(
          kind: 'manual_to_imported',
          left: reconItemJson(
            transactionId: 'tx-manual',
            status: 'posted/manual',
          ),
          right: <Map<String, Object?>>[
            reconItemJson(transactionId: 'tx-import', status: 'posted/import'),
          ],
        ),
      ],
    );
    when(() => api.confirm(any())).thenAnswer((_) async => reconMatch());
    await pump(tester, '/accounts/acc-1/reconcile');
    await tester.tap(find.text('Suggestions'));
    await tester.pumpAndSettle();
    expect(find.text('Entered twice'), findsOneWidget);
    await tester.ensureVisible(find.text('Confirm match'));
    await tester.tap(find.text('Confirm match'));
    await tester.pumpAndSettle();
    expect(find.text('Which one should stay?'), findsOneWidget);
    await tester.tap(find.text('Keep the imported one'));
    await tester.pumpAndSettle();
    final ReconMatchInput sent =
        verify(() => api.confirm(captureAny())).captured.single
            as ReconMatchInput;
    expect(sent.keepTransactionId, 'tx-import');
  });

  testWidgets('a confirmed match can be undone after confirming', (
    WidgetTester tester,
  ) async {
    when(() => api.unmatch(any()))
        .thenAnswer((_) async => reconMatch(status: 'unmatched'));
    await pump(tester, '/accounts/acc-1/reconcile');
    await tester.tap(find.text('Matched').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Removed (comes back if you undo)'),
      findsOneWidget,
    );
    expect(
      find.text('Why: The posted transaction replaces the pending one'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Undo match'));
    await tester.tap(find.text('Undo match'));
    await tester.pumpAndSettle();
    expect(find.text('Undo this match?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Undo match'));
    await tester.pumpAndSettle();
    verify(() => api.unmatch('match-1')).called(1);
    expect(find.text('Match undone.'), findsOneWidget);
  });

  testWidgets('empty tabs explain; a failed load can be retried', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    when(() => api.balances(any(), cursor: any(named: 'cursor')))
        .thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            throw offline;
          }
          return const CursorPage<ReconBalanceDto>(<ReconBalanceDto>[], null);
        });
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
    await pump(tester, '/accounts/acc-1/reconcile');
    expect(find.text("You're offline"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No statement balance checks yet.'), findsOneWidget);
    await tester.tap(find.text('Suggestions'));
    await tester.pumpAndSettle();
    expect(find.text('No suggested matches right now.'), findsOneWidget);
    await tester.tap(find.text('Matched').first);
    await tester.pumpAndSettle();
    expect(find.text('No matches yet.'), findsOneWidget);
  });
}
