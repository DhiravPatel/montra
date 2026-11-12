import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/budgets/data/budgets_api.dart';
import 'package:montra_mobile/features/budgets/presentation/budget_alerts_banner.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/people/data/people_api.dart';

import '../../helpers/budgets_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/people_fakes.dart';
import '../../helpers/router_app.dart';
import '../../helpers/test_app.dart';

void main() {
  late MockBudgetsApi api;
  late MockLabelsApi labels;
  late MockAccountsApi accounts;
  late MockPeopleApi people;

  setUpAll(registerBudgetFallbacks);

  setUp(() {
    api = MockBudgetsApi();
    labels = MockLabelsApi();
    accounts = MockAccountsApi();
    people = MockPeopleApi();
    stubLabels(labels);
    stubPeople(people);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
  });

  List<Override> overrides() => <Override>[
    budgetsApiProvider.overrideWithValue(api),
    labelsApiProvider.overrideWithValue(labels),
    accountsApiProvider.overrideWithValue(accounts),
    peopleApiProvider.overrideWithValue(people),
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

  testWidgets('lists budgets with progress, pace and status in words', (
    WidgetTester tester,
  ) async {
    stubBudgetBasics(api);
    when(() => api.list()).thenAnswer(
      (_) async => <BudgetDto>[
        budget(),
        budget(id: 'bud-2', name: 'Travel', type: 'category', status: 'paused'),
        budget(
          id: 'bud-3',
          name: 'Home groceries',
          access: 'editor',
          owner: 'u-asha',
          progress: progressJson(
            spent: '10500.00',
            remaining: '0.00',
            overspent: '500.00',
            percentBp: 10500,
            pace: 'over_budget',
          ),
        ),
      ],
    );
    when(() => api.get('bud-1')).thenAnswer((_) async => budget());
    when(() => api.progress('bud-1', date: any(named: 'date')))
        .thenAnswer((_) async => <ProgressDto>[progress()]);
    stubBudgetTransactions(api, 'bud-1', <TransactionDto>[]);
    final GoRouter router = await pump(tester, '/budgets');

    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('Monthly spending'), findsOneWidget);
    expect(find.text('Total spending · Monthly'), findsOneWidget);
    expect(find.text('₹4,000.00 spent of ₹10,000.00'), findsOneWidget);
    expect(find.text('40.0% used'), findsOneWidget);
    expect(find.text('₹6,000.00 left'), findsOneWidget);
    expect(find.text('On track'), findsOneWidget);

    expect(find.text('Travel'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
    expect(
      find.text("Progress isn't tracked while it's paused."),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Over the limit'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Total spending · Monthly · Shared by Asha Rao · can edit'),
      findsOneWidget,
    );
    expect(find.text('₹500.00 over the limit'), findsOneWidget);
    expect(find.text('105.0% used'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Monthly spending'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Monthly spending'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/budgets/bud-1');
  });

  testWidgets('shows an empty state and can include archived budgets', (
    WidgetTester tester,
  ) async {
    stubBudgetBasics(api);
    when(() => api.list()).thenAnswer((_) async => <BudgetDto>[]);
    when(() => api.list(includeArchived: true)).thenAnswer(
      (_) async => <BudgetDto>[
        budget(id: 'old', name: 'Last year', status: 'archived'),
      ],
    );
    final GoRouter router = await pump(tester, '/budgets');

    expect(find.text('No budgets yet'), findsOneWidget);
    await tester.tap(find.text('Show archived budgets'));
    await tester.pumpAndSettle();
    expect(find.text('Last year'), findsOneWidget);
    expect(find.text('Archived'), findsOneWidget);
    expect(find.text('Its history is kept.'), findsOneWidget);

    await tester.tap(find.text('New budget'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/budgets/new');
  });

  testWidgets('shows an offline state with a retry', (
    WidgetTester tester,
  ) async {
    stubBudgetBasics(api);
    int calls = 0;
    when(() => api.list()).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw offline;
      }
      return <BudgetDto>[budget()];
    });
    await pump(tester, '/budgets');

    expect(find.text("You're offline"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Monthly spending'), findsOneWidget);
  });

  group('alerts banner', () {
    testWidgets('counts active alerts and opens the alerts screen', (
      WidgetTester tester,
    ) async {
      stubBudgetBasics(
        api,
        activeAlerts: <AlertDto>[
          budgetAlert(),
          budgetAlert(id: 'alert-2', kind: 'forecast_overspend'),
        ],
      );
      when(() => api.list()).thenAnswer((_) async => <BudgetDto>[budget()]);
      final GoRouter router = await pump(tester, '/budgets');

      expect(find.text('2 budget alerts'), findsOneWidget);
      expect(
        find.text('Monthly spending: 90% of the limit used'),
        findsWidgets,
      );
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/budget-alerts');
      expect(
        find.text('Monthly spending may go over its limit'),
        findsOneWidget,
      );
    });

    testWidgets('stays hidden when there are no alerts or they fail', (
      WidgetTester tester,
    ) async {
      when(() => api.alerts(status: 'active'))
          .thenAnswer((_) async => <AlertDto>[]);
      await tester.pumpWidget(
        testApp(
          const Scaffold(body: BudgetAlertsBanner()),
          overrides: <Override>[
            ...signedInOverrides(),
            budgetsApiProvider.overrideWithValue(api),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsNothing);

      when(() => api.alerts(status: 'active')).thenThrow(offline);
      await tester.pumpWidget(
        testApp(
          const Scaffold(body: BudgetAlertsBanner(key: ValueKey<int>(2))),
          overrides: <Override>[
            ...signedInOverrides(),
            budgetsApiProvider.overrideWithValue(api),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
