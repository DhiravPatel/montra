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

import '../../helpers/budgets_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/people_fakes.dart';
import '../../helpers/router_app.dart';

/// Budget screens at 200 % text in English and Hindi must lay out without
/// overflow (overflow is reported as a test failure).
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
    stubLabels(labels, categories: <CategoryDto>[category()]);
    stubPeople(people);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    final BudgetDto big = budget(
      name: 'A rather long household budget name for the month',
      type: 'envelope',
      progress: progressJson(
        spent: '1234567.89',
        limit: '1000000.00',
        remaining: '0.00',
        overspent: '234567.89',
        percentBp: 12345,
        pace: 'over_budget',
        rolloverIn: '1500.00',
        otherCurrencyCount: 3,
      ),
      allocations: <Map<String, Object?>>[
        allocationJson(categoryId: 'cat-groceries'),
        allocationJson(id: 'alloc-2', label: 'Weekend outings and dinners'),
      ],
      members: <Map<String, Object?>>[
        budgetMemberJson(role: 'editor', allocation: '250000.00'),
      ],
      notes: 'Shared with the family; keep it calm and simple.',
    );
    when(() => api.list()).thenAnswer(
      (_) async => <BudgetDto>[big, budget(id: 'bud-2', status: 'paused')],
    );
    when(() => api.get('bud-1')).thenAnswer((_) async => big);
    when(() => api.progress('bud-1', date: any(named: 'date')))
        .thenAnswer((_) async => <ProgressDto>[progress(), progress()]);
    stubBudgetTransactions(api, 'bud-1', <TransactionDto>[transaction()]);
    when(() => api.alerts(status: any(named: 'status'))).thenAnswer(
      (_) async => <AlertDto>[
        budgetAlert(
          budgetName: 'A rather long household budget name for the month',
        ),
        budgetAlert(id: 'alert-2', kind: 'forecast_overspend'),
      ],
    );
  });

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('budget screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final ({Widget app, GoRouter router}) r = routedApp(
        '/budgets',
        overrides: <Override>[
          budgetsApiProvider.overrideWithValue(api),
          labelsApiProvider.overrideWithValue(labels),
          accountsApiProvider.overrideWithValue(accounts),
          peopleApiProvider.overrideWithValue(people),
        ],
        locale: locale,
      );
      await tester.pumpWidget(r.app);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final String location in <String>[
        '/budgets/bud-1',
        '/budgets/new',
        '/budgets/bud-1/edit',
        '/budget-alerts',
      ]) {
        unawaited(r.router.push<Object?>(location));
        await tester.pumpAndSettle();
        for (int i = 0; i < 10; i++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -600),
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: location);
        r.router.pop();
        await tester.pumpAndSettle();
      }
    });
  }
}
