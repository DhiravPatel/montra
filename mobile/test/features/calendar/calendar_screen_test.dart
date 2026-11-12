import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/bills/data/bills_api.dart';
import 'package:montra_mobile/features/calendar/application/calendar_providers.dart';
import 'package:montra_mobile/features/calendar/data/calendar_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/recurring/data/recurring_api.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/planning_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockCalendarApi api;
  late MockRecurringApi recurring;
  late MockBillsApi bills;
  late MockAccountsApi accounts;
  late MockLabelsApi labels;

  setUpAll(registerPlanningFallbacks);

  setUp(() {
    api = MockCalendarApi();
    recurring = MockRecurringApi();
    bills = MockBillsApi();
    accounts = MockAccountsApi();
    labels = MockLabelsApi();
    stubLabels(labels);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
  });

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: [
        calendarApiProvider.overrideWithValue(api),
        recurringApiProvider.overrideWithValue(recurring),
        billsApiProvider.overrideWithValue(bills),
        accountsApiProvider.overrideWithValue(accounts),
        labelsApiProvider.overrideWithValue(labels),
      ],
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  test('a month spans its first to last day', () {
    expect(monthRange(DateTime(2026, 2)), (
      from: '2026-02-01',
      to: '2026-02-28',
    ));
    expect(monthRange(DateTime(2028, 2)), (
      from: '2028-02-01',
      to: '2028-02-29',
    ));
    expect(monthRange(DateTime(2026, 12)), (
      from: '2026-12-01',
      to: '2026-12-31',
    ));
    expect(monthKey(DateTime(2026, 3)), '2026-03');
    expect(parseMonthKey('2026-13'), isNull);
    expect(parseMonthKey('2026-11'), DateTime(2026, 11));
    expect(
      groupByDate(<CalendarItem>[
        calendarItem(date: '2026-11-12'),
        calendarItem(date: '2026-11-10'),
        calendarItem(date: '2026-11-12', title: 'Rent'),
      ]).map(((String, List<CalendarItem>) d) => (d.$1, d.$2.length)).toList(),
      <(String, int)>[('2026-11-10', 1), ('2026-11-12', 2)],
    );
  });

  testWidgets('a moved occurrence says where it was moved from', (
    WidgetTester tester,
  ) async {
    when(() => api.items(from: '2026-11-01', to: '2026-11-30')).thenAnswer(
      (_) async => <CalendarItem>[
        calendarItem(date: '2026-11-14', scheduledOn: '2026-11-10'),
      ],
    );
    await pump(tester, '/calendar?month=2026-11');
    expect(find.text('Moved from Nov 10, 2026'), findsOneWidget);
  });

  testWidgets('groups a month by day with kinds, statuses and amounts, and '
      'opens each item', (WidgetTester tester) async {
    when(() => api.items(from: '2026-11-01', to: '2026-11-30')).thenAnswer(
      (_) async => <CalendarItem>[
        calendarItem(
          date: '2026-11-05',
          kind: 'recurring',
          entityType: 'recurring_rule',
          entityId: 'rule-1',
          title: 'Rent',
          status: 'posted',
          amount: '15000.00',
        ),
        calendarItem(status: 'overdue'),
        calendarItem(
          date: '2026-11-10',
          kind: 'trial_end',
          entityType: 'subscription',
          entityId: 'sub-1',
          title: 'Music app',
          status: 'expected',
          amount: null,
        ),
        calendarItem(
          date: '2026-11-20',
          kind: 'group_expense',
          entityType: 'group_recurring_expense',
          entityId: 'g-1',
          title: 'Flat rent share',
          status: 'projected',
        ),
      ],
    );
    when(() => recurring.get('rule-1')).thenAnswer((_) async => ruleDetail());
    when(() => bills.get('bill-1')).thenAnswer((_) async => billDetail());
    final GoRouter router = await pump(tester, '/calendar?month=2026-11');

    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('4 items this month'), findsOneWidget);
    // Today's heading also says "Today".
    expect(find.textContaining('Thursday, November 5, 2026'), findsOneWidget);
    expect(find.textContaining('Tuesday, November 10, 2026'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Recorded'), findsOneWidget);
    expect(find.text('₹15,000.00'), findsOneWidget);
    expect(find.text('Electricity'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Trial ends'), findsOneWidget);
    expect(find.text('Expected'), findsOneWidget);
    expect(find.text('Group expense'), findsOneWidget);
    expect(find.text('Planned'), findsOneWidget);

    // Shared group expenses have no screen yet: not tappable.
    final ListTile group = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Flat rent share'),
        matching: find.byType(ListTile),
      ),
    );
    expect(group.onTap, isNull);

    await tester.tap(find.text('Rent'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/recurring/rule-1');
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Electricity'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/bills/bill-1');
  });

  testWidgets('a goal target date reads as a target, not a payment', (
    WidgetTester tester,
  ) async {
    when(() => api.items(from: '2026-11-01', to: '2026-11-30')).thenAnswer(
      (_) async => <CalendarItem>[
        calendarItem(
          date: '2026-11-28',
          kind: 'goal_target',
          entityType: 'goal',
          entityId: 'goal-1',
          title: 'Emergency fund',
          status: 'target',
          amount: '50000.00',
        ),
      ],
    );
    await pump(tester, '/calendar?month=2026-11');
    expect(find.text('Emergency fund'), findsOneWidget);
    expect(find.text('Goal target date'), findsOneWidget);
    expect(find.text('Target date'), findsOneWidget);
  });

  testWidgets('moves between months and back to this month', (
    WidgetTester tester,
  ) async {
    final List<String> asked = <String>[];
    when(
      () => api.items(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((Invocation i) async {
      asked.add('${i.namedArguments[#from]}..${i.namedArguments[#to]}');
      return <CalendarItem>[];
    });
    await pump(tester, '/calendar');

    final DateTime today = LocalDates.today();
    final DateTime month = DateTime(today.year, today.month);
    final ({String from, String to}) current = monthRange(month);
    expect(asked.single, '${current.from}..${current.to}');
    expect(find.text('Go to this month'), findsNothing);
    final String name = DateFormat.yMMMM('en').format(month);
    expect(find.text('Nothing planned in $name'), findsOneWidget);

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    final ({String from, String to}) next = monthRange(
      DateTime(month.year, month.month + 1),
    );
    expect(asked.last, '${next.from}..${next.to}');
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('Go to this month'), findsOneWidget);
    await tester.tap(find.text('Go to this month'));
    await tester.pumpAndSettle();
    expect(find.text(name), findsOneWidget);
  });

  testWidgets('shows an error state with retry', (WidgetTester tester) async {
    int calls = 0;
    when(
      () => api.items(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw offline;
      }
      return <CalendarItem>[calendarItem()];
    });
    await pump(tester, '/calendar?month=2026-11');
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Electricity'), findsOneWidget);
    expect(find.text('1 item this month'), findsOneWidget);
  });
}
