import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/bills/data/bills_api.dart';
import 'package:montra_mobile/features/calendar/data/calendar_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/recurring/data/recurring_api.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/planning_fakes.dart';
import '../../helpers/router_app.dart';

/// Recurring, bill and calendar screens at 200 % text in English and Hindi
/// must lay out without overflow (overflow fails the test).
void main() {
  late MockRecurringApi recurring;
  late MockBillsApi bills;
  late MockCalendarApi calendar;
  late MockAccountsApi accounts;
  late MockLabelsApi labels;

  setUpAll(registerPlanningFallbacks);

  setUp(() {
    recurring = MockRecurringApi();
    bills = MockBillsApi();
    calendar = MockCalendarApi();
    accounts = MockAccountsApi();
    labels = MockLabelsApi();
    stubLabels(labels, categories: <CategoryDto>[category()]);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer(
          (_) async => <AccountDto>[
            account(),
            account(id: 'acc-2', name: 'A very long savings account name'),
          ],
        );
    final Map<String, Object?> due = billOccurrenceJson();
    when(
      () => recurring.list(
        kind: any(named: 'kind'),
        status: any(named: 'status'),
      ),
    ).thenAnswer(
      (_) async => <RecurringRuleDto>[
        rule(
          name: 'Rent for the flat on the second floor',
          amount: '123456.78',
        ),
        rule(id: 'rule-2', name: 'Gym', status: 'paused'),
      ],
    );
    when(() => recurring.get('rule-1')).thenAnswer(
      (_) async => ruleDetail(
        name: 'Rent for the flat on the second floor',
        amount: '123456.78',
        autoPost: true,
        merchantId: 'm-1',
        merchantName: 'A landlord with a rather long business name',
        description: 'Paid to the landlord every month',
        occurrences: <Map<String, Object?>>[
          occurrenceJson(id: 'occ-2', effectiveDate: '2026-12-08'),
          occurrenceJson(
            id: 'occ-1',
            date: '2026-11-05',
            status: 'posted',
            transactionId: 'tx-1',
          ),
        ],
      ),
    );
    when(() => bills.list(status: any(named: 'status'))).thenAnswer(
      (_) async => <BillDto>[
        bill(state: 'due_today', nextDue: due),
        bill(id: 'b-2', name: 'Broadband and phone', state: 'overdue'),
      ],
    );
    when(() => bills.get('bill-1')).thenAnswer(
      (_) async => billDetail(
        state: 'due_soon',
        nextDue: due,
        occurrences: <Map<String, Object?>>[due],
      ),
    );
    when(
      () => bills.paymentCandidates(
        any(),
        occurrenceId: any(named: 'occurrenceId'),
      ),
    ).thenAnswer(
      (_) async => <BillPaymentCandidate>[
        candidate(
          reasonCodes: <String>[
            'same_provider',
            'amount_close',
            'near_due_date',
          ],
          reasons: <String>['a', 'b', 'c'],
          daysFromDue: 9,
        ),
      ],
    );
    when(
      () => calendar.items(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer(
      (_) async => <CalendarItem>[
        calendarItem(status: 'overdue', amount: '123456.78'),
        calendarItem(
          kind: 'subscription_renewal',
          entityType: 'subscription',
          entityId: 'sub-1',
          title: 'A streaming service with a long name',
          status: 'expected',
        ),
        calendarItem(
          kind: 'goal_target',
          entityType: 'goal',
          entityId: 'goal-1',
          title: 'Emergency fund for the whole family',
          status: 'target',
          amount: '500000.00',
        ),
      ],
    );
  });

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('planning screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final ({Widget app, GoRouter router}) r = routedApp(
        '/recurring',
        locale: locale,
        overrides: [
          recurringApiProvider.overrideWithValue(recurring),
          billsApiProvider.overrideWithValue(bills),
          calendarApiProvider.overrideWithValue(calendar),
          accountsApiProvider.overrideWithValue(accounts),
          labelsApiProvider.overrideWithValue(labels),
        ],
      );
      await tester.pumpWidget(r.app);
      await tester.pumpAndSettle();

      for (final String location in <String>[
        '/recurring/rule-1',
        '/recurring/new',
        '/recurring/rule-1/edit',
        '/bills',
        '/bills/bill-1',
        '/bills/bill-1/edit',
        '/bills/bill-1/pay',
        '/calendar?month=2026-11',
      ]) {
        unawaited(r.router.push<Object?>(location));
        await tester.pumpAndSettle();
        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, -3000),
          4000,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: location);
      }
    });
  }
}
