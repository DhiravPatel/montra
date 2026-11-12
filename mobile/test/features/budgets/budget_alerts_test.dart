import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/budgets/data/budgets_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';

import '../../helpers/budgets_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockBudgetsApi api;
  late MockLabelsApi labels;
  late MockAccountsApi accounts;
  late List<BudgetAlertsUpdateRequest> sent;

  setUpAll(registerBudgetFallbacks);

  setUp(() {
    api = MockBudgetsApi();
    labels = MockLabelsApi();
    accounts = MockAccountsApi();
    sent = <BudgetAlertsUpdateRequest>[];
    stubLabels(labels);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    when(() => api.updateAlert(any(), any())).thenAnswer((Invocation i) async {
      sent.add(i.positionalArguments[1] as BudgetAlertsUpdateRequest);
    });
  });

  Future<GoRouter> pump(WidgetTester tester) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      '/budget-alerts',
      overrides: <Override>[
        budgetsApiProvider.overrideWithValue(api),
        labelsApiProvider.overrideWithValue(labels),
        accountsApiProvider.overrideWithValue(accounts),
      ],
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  testWidgets('lists active alerts in words and dismisses one', (
    WidgetTester tester,
  ) async {
    bool dismissed = false;
    when(
      () => api.alertsPage(
        status: 'active',
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer(
      (_) async => budgetPage(<AlertDto>[
        if (!dismissed) budgetAlert(threshold: 100),
        budgetAlert(
          id: 'alert-2',
          budgetName: 'Travel',
          kind: 'forecast_overspend',
          threshold: 0,
        ),
        budgetAlert(
          id: 'alert-3',
          budgetName: 'Groceries',
          kind: 'unusual_spend',
          threshold: 0,
        ),
      ]),
    );
    when(() => api.updateAlert('alert-1', any()))
        .thenAnswer((Invocation i) async {
          sent.add(i.positionalArguments[1] as BudgetAlertsUpdateRequest);
          dismissed = true;
        });
    await pump(tester);

    expect(
      find.text('Monthly spending: the whole limit is used'),
      findsOneWidget,
    );
    expect(find.text('Travel may go over its limit'), findsOneWidget);
    expect(find.textContaining('This is an estimate.'), findsOneWidget);
    expect(find.text('Unusual spending in Groceries'), findsOneWidget);
    expect(find.textContaining('Period from Nov 1, 2026'), findsNWidgets(3));

    await tester.tap(find.text('Dismiss').first);
    await tester.pumpAndSettle();
    expect(sent.single.status, BudgetAlertsUpdateRequestStatus.dismissed);
    expect(sent.single.snoozedUntil, isNull);
    expect(find.text('Alert dismissed.'), findsOneWidget);
    expect(
      find.text('Monthly spending: the whole limit is used'),
      findsNothing,
    );
  });

  testWidgets('snoozes for a week with a future time', (
    WidgetTester tester,
  ) async {
    when(
      () => api.alertsPage(
        status: 'active',
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async => budgetPage(<AlertDto>[budgetAlert()]));
    await pump(tester);

    expect(
      find.text('Monthly spending: 90% of the limit used'),
      findsOneWidget,
    );
    await tester.tap(find.text('Snooze'));
    await tester.pumpAndSettle();
    expect(find.text('Snooze until'), findsOneWidget);
    await tester.tap(find.text('For a week'));
    await tester.pumpAndSettle();

    final BudgetAlertsUpdateRequest request = sent.single;
    expect(request.status, BudgetAlertsUpdateRequestStatus.snoozed);
    final Duration ahead = request.snoozedUntil!.difference(DateTime.now());
    expect(ahead.inDays, inInclusiveRange(6, 7));
    expect(request.snoozedUntil!.isUtc, isTrue);
    expect(find.textContaining('Alert snoozed until'), findsOneWidget);
  });

  testWidgets('snoozed alerts can be shown again; each opens its budget', (
    WidgetTester tester,
  ) async {
    when(
      () => api.alertsPage(
        status: 'active',
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async => budgetPage(<AlertDto>[]));
    when(
      () => api.alertsPage(
        status: 'snoozed',
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer(
      (_) async => budgetPage(<AlertDto>[
        budgetAlert(status: 'snoozed', snoozedUntil: '2026-11-08T03:30:00Z'),
      ]),
    );
    when(() => api.get('bud-1')).thenAnswer((_) async => budget());
    when(() => api.progress('bud-1', date: any(named: 'date')))
        .thenAnswer((_) async => <ProgressDto>[progress()]);
    stubBudgetTransactions(api, 'bud-1', <TransactionDto>[]);
    final GoRouter router = await pump(tester);

    expect(find.textContaining('No active alerts'), findsOneWidget);
    await tester.tap(find.text('Snoozed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Snoozed until Nov 8, 2026'), findsOneWidget);
    expect(find.text('Snooze'), findsNothing);

    await tester.tap(find.text('Show again'));
    await tester.pumpAndSettle();
    expect(sent.single.status, BudgetAlertsUpdateRequestStatus.active);
    expect(find.text('The alert is active again.'), findsOneWidget);

    await tester.tap(find.text('Monthly spending: 90% of the limit used'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/budgets/bud-1');
  });

  testWidgets('shows an error with a retry and a calm empty state', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    when(
      () => api.alertsPage(
        status: 'active',
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw serverError(ErrorObjectCode.internalError, status: 500);
      }
      return budgetPage(<AlertDto>[]);
    });
    when(
      () => api.alertsPage(
        status: 'dismissed',
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async => budgetPage(<AlertDto>[]));
    await pump(tester);

    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No active alerts'), findsOneWidget);
    await tester.tap(find.text('Dismissed'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing here.'), findsOneWidget);
  });

  testWidgets('a failed update explains why and keeps the alert', (
    WidgetTester tester,
  ) async {
    when(
      () => api.alertsPage(
        status: 'active',
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async => budgetPage(<AlertDto>[budgetAlert()]));
    when(() => api.updateAlert(any(), any())).thenThrow(offline);
    await pump(tester);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Check your internet connection'),
      findsOneWidget,
    );
    expect(
      find.text('Monthly spending: 90% of the limit used'),
      findsOneWidget,
    );
  });

  testWidgets('more alerts load page by page', (WidgetTester tester) async {
    when(
      () => api.alertsPage(
        status: 'active',
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer(
      (_) async => budgetPage(<AlertDto>[budgetAlert()], next: 'c2'),
    );
    when(() => api.alertsPage(status: 'active', cursor: 'c2')).thenAnswer(
      (_) async => budgetPage(<AlertDto>[
        budgetAlert(id: 'alert-9', budgetName: 'Fuel', threshold: 50),
      ]),
    );
    await pump(tester);
    expect(find.text('Fuel: 50% of the limit used'), findsNothing);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    verify(() => api.alertsPage(status: 'active', cursor: 'c2')).called(1);
    expect(find.text('Fuel: 50% of the limit used'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });
}
