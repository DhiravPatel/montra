import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/budgets/data/budgets_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/people/data/people_api.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';

import '../../helpers/budgets_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/people_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockBudgetsApi api;
  late MockLabelsApi labels;
  late MockAccountsApi accounts;
  late MockPeopleApi people;
  late MockTransactionsApi transactions;

  setUpAll(registerBudgetFallbacks);

  setUp(() {
    api = MockBudgetsApi();
    labels = MockLabelsApi();
    accounts = MockAccountsApi();
    people = MockPeopleApi();
    transactions = MockTransactionsApi();
    stubLabels(labels, categories: <CategoryDto>[category()]);
    stubPeople(people);
    stubBudgetBasics(api);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    when(() => api.progress('bud-1', date: any(named: 'date')))
        .thenAnswer((_) async => <ProgressDto>[progress()]);
    stubBudgetTransactions(api, 'bud-1', <TransactionDto>[]);
  });

  Future<GoRouter> pump(WidgetTester tester, {String? from}) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      from ?? '/budgets/bud-1',
      overrides: <Override>[
        budgetsApiProvider.overrideWithValue(api),
        labelsApiProvider.overrideWithValue(labels),
        accountsApiProvider.overrideWithValue(accounts),
        peopleApiProvider.overrideWithValue(people),
        transactionsApiProvider.overrideWithValue(transactions),
      ],
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    if (from != null) {
      unawaited(r.router.push<Object?>('/budgets/bud-1'));
      await tester.pumpAndSettle();
    }
    return r.router;
  }

  Future<void> scrollTo(
    WidgetTester tester,
    Finder finder, {
    double delta = 250,
  }) async {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String action) async {
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action).last);
    await tester.pumpAndSettle();
  }

  testWidgets('the owner sees progress, how it is calculated, earlier '
      'periods and the counted transactions', (WidgetTester tester) async {
    when(() => api.get('bud-1')).thenAnswer(
      (_) async => budget(
        type: 'category',
        allocations: <Map<String, Object?>>[
          allocationJson(categoryId: 'cat-groceries'),
        ],
      ),
    );
    when(() => api.progress('bud-1')).thenAnswer(
      (_) async => <ProgressDto>[
        progress(),
        progress(
          spent: '9000.00',
          percentBp: 9000,
          pace: 'under_pace',
          periodStart: '2026-10-01',
          periodEnd: '2026-10-31',
        ),
      ],
    );
    when(() => api.progress('bud-1', date: '2026-10-31')).thenAnswer(
      (_) async => <ProgressDto>[
        progress(
          spent: '9000.00',
          percentBp: 9000,
          pace: 'under_pace',
          periodStart: '2026-10-01',
          periodEnd: '2026-10-31',
        ),
      ],
    );
    when(() => api.transactions('bud-1', cursor: any(named: 'cursor')))
        .thenAnswer((_) async => budgetPage(<TransactionDto>[transaction()]));
    when(() => transactions.get('tx-1')).thenAnswer((_) async => transaction());
    when(() => transactions.audit('tx-1'))
        .thenAnswer((_) async => <AuditEventDto>[]);
    when(() => transactions.attachments('tx-1'))
        .thenAnswer((_) async => <AttachmentDto>[]);
    final GoRouter router = await pump(tester);

    expect(find.text('Monthly spending'), findsOneWidget);
    expect(find.text('By category · Monthly'), findsOneWidget);
    expect(
      find.text('Nov 1, 2026 – Nov 30, 2026 · Day 12 of 30'),
      findsOneWidget,
    );
    expect(find.text('₹4,000.00 spent of ₹10,000.00'), findsOneWidget);
    expect(find.text('On track'), findsOneWidget);

    await scrollTo(tester, find.text('How this is calculated'));
    expect(find.text('Left to spend'), findsOneWidget);
    expect(find.text('₹333.33'), findsOneWidget);
    await tester.tap(find.text('How this is calculated'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '• Spent ₹4,000.00 of ₹10,000.00 between Nov 1, 2026 and '
        'Nov 30, 2026.',
      ),
      findsOneWidget,
    );
    expect(find.text('• Only posted transactions count.'), findsOneWidget);
    expect(find.textContaining('This is an estimate'), findsOneWidget);

    await scrollTo(tester, find.byTooltip('Earlier period'));
    expect(
      find.textContaining(
        'Oct 1, 2026 – Oct 31, 2026: spent ₹9,000.00 of ₹10,000.00.',
      ),
      findsOneWidget,
    );
    await scrollTo(tester, find.text('Big Bazaar'));
    expect(find.text('Counted transactions'), findsOneWidget);

    await scrollTo(tester, find.byTooltip('Earlier period'), delta: -250);
    await tester.tap(find.byTooltip('Earlier period'));
    await tester.pumpAndSettle();
    verify(() => api.progress('bud-1', date: '2026-10-31')).called(1);
    verify(
      () => api.transactions(
        'bud-1',
        date: '2026-10-31',
        cursor: any(named: 'cursor'),
      ),
    ).called(1);
    await scrollTo(tester, find.textContaining('Nothing counts toward'));
    await scrollTo(tester, find.byTooltip('Later period'), delta: -250);
    await tester.tap(find.byTooltip('Later period'));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('₹1,500.00 of ₹6,000.00'));
    expect(find.text('Limits within this budget'), findsOneWidget);
    expect(find.text('25.0% used · ₹4,500.00 left'), findsOneWidget);
    await scrollTo(tester, find.text('Only you can see this budget.'));
    expect(find.text('Add a person'), findsOneWidget);
    await scrollTo(tester, find.text('Alert levels'));
    expect(find.text('50%, 75%, 90%, 100%'), findsOneWidget);

    await scrollTo(tester, find.text('Big Bazaar'), delta: -250);
    await tester.tap(find.text('Big Bazaar'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/transactions/tx-1');
  });

  testWidgets('a collaborator sees the owner totals only and can leave', (
    WidgetTester tester,
  ) async {
    when(() => api.list()).thenAnswer((_) async => <BudgetDto>[]);
    when(() => api.get('bud-1')).thenAnswer(
      (_) async => budget(
        access: 'viewer',
        owner: 'u-asha',
        progress: progressJson(asOf: '2026-11-04T08:15:00Z'),
        members: <Map<String, Object?>>[
          budgetMemberJson(id: testUserId, name: 'Budget Tester'),
        ],
      ),
    );
    when(() => api.removeMember('bud-1', testUserId)).thenAnswer((_) async {});
    final GoRouter router = await pump(tester, from: '/budgets');

    expect(find.textContaining('Totals as of'), findsOneWidget);
    expect(
      find.text('Total spending · Monthly · Shared by Asha Rao · can view'),
      findsOneWidget,
    );
    await scrollTo(tester, find.textContaining('Only the owner can see'));
    verifyNever(
      () => api.transactions(
        any(),
        date: any(named: 'date'),
        cursor: any(named: 'cursor'),
      ),
    );

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Pause'), findsNothing);
    await tester.tap(find.text('Leave this budget').last);
    await tester.pumpAndSettle();
    expect(find.text('Leave this budget?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Leave this budget'));
    await tester.pumpAndSettle();
    verify(() => api.removeMember('bud-1', testUserId)).called(1);
    expect(locationOf(router), '/budgets');
    expect(find.text('You left the budget.'), findsOneWidget);
  });

  testWidgets('the owner pauses, archives after confirming and restores', (
    WidgetTester tester,
  ) async {
    when(() => api.get('bud-1')).thenAnswer((_) async => budget());
    when(() => api.pause('bud-1', version: 3))
        .thenAnswer((_) async => budget(status: 'paused', version: 4));
    when(() => api.archive('bud-1', version: 4))
        .thenAnswer((_) async => budget(status: 'archived', version: 5));
    when(() => api.restore('bud-1', version: 5))
        .thenAnswer((_) async => budget(version: 6));
    await pump(tester);

    await choose(tester, 'Pause');
    expect(find.text('Budget paused.'), findsOneWidget);
    expect(find.textContaining('This budget is paused.'), findsOneWidget);

    await choose(tester, 'Archive');
    expect(find.text('Archive this budget?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();
    verify(() => api.archive('bud-1', version: 4)).called(1);
    expect(find.textContaining('This budget is archived.'), findsOneWidget);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsNothing);
    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();
    verify(() => api.restore('bud-1', version: 5)).called(1);
    verifyNever(() => api.resume(any(), version: any(named: 'version')));
    expect(find.text('Budget restored.'), findsOneWidget);
    expect(find.textContaining('This budget is archived.'), findsNothing);
  });

  testWidgets('the owner shares with a friend, then removes them', (
    WidgetTester tester,
  ) async {
    bool shared = false;
    when(() => api.get('bud-1')).thenAnswer((_) async => budget());
    MemberInput? added;
    when(() => api.addMember('bud-1', any())).thenAnswer((Invocation i) async {
      added = i.positionalArguments[1] as MemberInput;
      shared = true;
      return budget(
        members: <Map<String, Object?>>[
          budgetMemberJson(role: 'editor', allocation: '2500.00'),
        ],
      );
    });
    when(() => api.removeMember('bud-1', 'u-asha')).thenAnswer((_) async {
      shared = false;
    });
    await pump(tester);

    await scrollTo(tester, find.text('Add a person'));
    await tester.tap(find.text('Add a person'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asha Rao'));
    await tester.pumpAndSettle();
    expect(find.text('Share with Asha Rao'), findsOneWidget);
    await tester.tap(find.text('Can view'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Can edit').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Their share of the limit (optional)'),
      '2500',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await tester.pumpAndSettle();

    expect(added?.userId, 'u-asha');
    expect(added?.role, MemberInputRole.editor);
    expect(added?.allocation, '2500.00');
    expect(find.text('Asha Rao can now see this budget.'), findsOneWidget);
    await scrollTo(tester, find.text('Can edit · Share: ₹2,500.00'));

    when(() => api.get('bud-1')).thenAnswer(
      (_) async => shared
          ? budget(members: <Map<String, Object?>>[budgetMemberJson()])
          : budget(),
    );
    await scrollTo(tester, find.text('Asha Rao'), delta: -100);
    await tester.tap(find.text('Asha Rao'));
    await tester.pumpAndSettle();
    expect(find.text("Asha Rao's access"), findsOneWidget);
    await tester.tap(find.text('Remove from budget'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Asha Rao?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove from budget'));
    await tester.pumpAndSettle();
    verify(() => api.removeMember('bud-1', 'u-asha')).called(1);
    expect(find.text('Asha Rao was removed.'), findsOneWidget);
    await scrollTo(tester, find.text('Only you can see this budget.'));
  });

  testWidgets('a group budget names members and points to the group', (
    WidgetTester tester,
  ) async {
    when(() => people.group('grp-home')).thenAnswer(
      (_) async => groupDetail(
        members: <Map<String, Object?>>[
          groupMemberJson(id: testUserId, name: 'Me', role: 'owner'),
          groupMemberJson(id: 'u-ravi', name: 'Ravi'),
        ],
      ),
    );
    when(() => api.get('bud-1')).thenAnswer(
      (_) async => budget(
        groupId: 'grp-home',
        visibility: 'members',
        allocations: <Map<String, Object?>>[
          allocationJson(memberUserId: 'u-ravi'),
          allocationJson(id: 'alloc-2', memberUserId: testUserId),
        ],
      ),
    );
    await pump(tester);

    expect(find.text('Total spending · Monthly · Group: Home'), findsOneWidget);
    await scrollTo(tester, find.textContaining('Group budgets count'));
    await scrollTo(tester, find.text("Ravi's share"));
    expect(find.text('Your share'), findsOneWidget);
    await scrollTo(tester, find.text('Everyone in the group'));
    expect(find.text('What counts'), findsNothing);
    verifyNever(
      () => api.transactions(
        any(),
        date: any(named: 'date'),
        cursor: any(named: 'cursor'),
      ),
    );
  });

  testWidgets('the budget shows its own active alerts (?budget_id=)', (
    WidgetTester tester,
  ) async {
    stubBudgetBasics(
      api,
      activeAlerts: <AlertDto>[
        budgetAlert(),
        budgetAlert(id: 'alert-2', budgetId: 'bud-other'),
      ],
    );
    when(() => api.get('bud-1')).thenAnswer((_) async => budget());
    await pump(tester);
    expect(find.text('1 alert for this budget'), findsOneWidget);
    verify(() => api.alerts(status: 'active', budgetId: 'bud-1')).called(1);
  });

  testWidgets('shows not-found and failed-action messages', (
    WidgetTester tester,
  ) async {
    when(() => api.get('bud-1'))
        .thenThrow(serverError(ErrorObjectCode.notFound, status: 404));
    await pump(tester);
    expect(find.textContaining("We couldn't find that"), findsOneWidget);

    when(() => api.get('bud-1')).thenAnswer((_) async => budget());
    when(() => api.pause('bud-1', version: 3)).thenThrow(offline);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    await choose(tester, 'Pause');
    expect(
      find.textContaining('Check your internet connection'),
      findsOneWidget,
    );
    expect(find.textContaining('This budget is paused.'), findsNothing);
  });

  testWidgets('counted transactions page with Load more', (
    WidgetTester tester,
  ) async {
    when(() => api.get('bud-1')).thenAnswer(
      (_) async => budget(progress: progressJson(transactionCount: 7)),
    );
    final List<TransactionDto> first = <TransactionDto>[
      for (int i = 1; i <= 6; i++)
        transaction(id: 'tx-$i', description: 'Purchase $i', merchant: null),
    ];
    when(() => api.transactions('bud-1', cursor: any(named: 'cursor')))
        .thenAnswer((_) async => budgetPage(first, next: 'c2'));
    when(() => api.transactions('bud-1', cursor: 'c2')).thenAnswer(
      (_) async => budgetPage(<TransactionDto>[
        transaction(id: 'tx-7', description: 'Purchase 7', merchant: null),
      ]),
    );
    await pump(tester);

    await scrollTo(tester, find.text('Show all 7'));
    await tester.tap(find.text('Show all 7'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Showing 6 of 7'));
    await scrollTo(tester, find.text('Load more'));
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    verify(() => api.transactions('bud-1', cursor: 'c2')).called(1);
    await scrollTo(tester, find.text('Purchase 7'));
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('a refused transaction list explains that only the owner sees '
      'transactions', (WidgetTester tester) async {
    when(() => api.get('bud-1')).thenAnswer((_) async => budget());
    when(
      () => api.transactions(
        'bud-1',
        date: any(named: 'date'),
        cursor: any(named: 'cursor'),
      ),
    ).thenThrow(serverError(ErrorObjectCode.forbidden, status: 403));
    await pump(tester);
    await scrollTo(
      tester,
      find.text(
        'Only the owner can see the individual transactions. You see the '
        "owner's totals.",
      ),
    );
  });

  testWidgets('a stale or refused lifecycle change is explained', (
    WidgetTester tester,
  ) async {
    when(() => api.get('bud-1')).thenAnswer((_) async => budget());
    when(() => api.pause('bud-1', version: 3))
        .thenThrow(serverError(ErrorObjectCode.versionConflict, status: 409));
    await pump(tester);
    await choose(tester, 'Pause');
    expect(
      find.textContaining('This was changed somewhere else'),
      findsOneWidget,
    );
    verify(() => api.get('bud-1')).called(greaterThanOrEqualTo(2));

    when(() => api.pause('bud-1', version: 3)).thenThrow(
      serverError(
        ErrorObjectCode.domainRuleViolation,
        details: const <Detail>[
          Detail(
            code: 'invalid_status_transition',
            message: 'A budget cannot move from archived to paused.',
            params: <String, String>{'from': 'archived', 'to': 'paused'},
          ),
        ],
      ),
    );
    await choose(tester, 'Pause');
    expect(
      find.text(
        "This can't change from archived to paused. Reload to see where it "
        'stands now.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a person who cannot be added is explained', (
    WidgetTester tester,
  ) async {
    when(() => api.get('bud-1')).thenAnswer((_) async => budget());
    when(() => api.addMember('bud-1', any())).thenThrow(
      serverError(
        ErrorObjectCode.validationError,
        details: const <Detail>[
          Detail(
            field: 'body.user_id',
            message: 'You can only share budgets with friends.',
          ),
        ],
      ),
    );
    await pump(tester);
    await scrollTo(tester, find.text('Add a person'));
    await tester.tap(find.text('Add a person'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asha Rao'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await tester.pumpAndSettle();
    expect(find.textContaining("This person can't be added."), findsOneWidget);
  });
}
