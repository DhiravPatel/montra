import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/features/analytics/data/analytics_api.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/insights_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockAnalyticsApi api;

  setUpAll(registerInsightsFallbacks);

  setUp(() {
    api = MockAnalyticsApi();
    when(
      () => api.cashFlow(
        any(),
        currency: any(named: 'currency'),
        granularity: any(named: 'granularity'),
      ),
    ).thenAnswer((_) async => cashFlowReport());
  });

  List<Override> overrides() => <Override>[
    analyticsApiProvider.overrideWithValue(api),
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

  group('overview', () {
    testWidgets('shows one currency at a time, the main currency first, and '
        'opens a report for the chosen period and currency', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pump(tester, '/analytics');

      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('+₹85,000.00'), findsOneWidget);
      expect(find.text('−₹4,609.50'), findsOneWidget);
      expect(find.text('₹80,390.50'), findsOneWidget);
      expect(find.text('Based on 5 transactions'), findsOneWidget);
      // USD figures are not shown, let alone added to INR.
      expect(find.textContaining(r'$'), findsNothing);
      expect(
        find.text(
          'Amounts in different currencies are shown separately and never '
          'added together.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'USD'));
      await tester.pumpAndSettle();
      expect(find.textContaining('300.00'), findsWidgets);
      expect(find.text('+₹85,000.00'), findsNothing);

      await tester.ensureVisible(find.text('Spending by category'));
      await tester.pumpAndSettle();
      when(
        () => api.categories(
          any(),
          currency: any(named: 'currency'),
          subcategories: any(named: 'subcategories'),
        ),
      ).thenAnswer(
        (_) async => categoryReport(slices: <Map<String, Object?>>[]),
      );
      await tester.tap(find.text('Spending by category'));
      await tester.pumpAndSettle();
      expect(
        locationOf(router),
        '/analytics/categories?range=this_month&currency=USD',
      );
      verify(
        () => api.categories(
          const DateRangeChoice.named('this_month'),
          currency: 'USD',
          subcategories: false,
        ),
      ).called(1);
    });

    testWidgets('a failed load can be retried', (WidgetTester tester) async {
      int calls = 0;
      when(
        () => api.cashFlow(
          any(),
          currency: any(named: 'currency'),
          granularity: any(named: 'granularity'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return cashFlowReport();
      });
      await pump(tester, '/analytics');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('+₹85,000.00'), findsOneWidget);
    });

    testWidgets('a period without activity says so and still offers the '
        'other reports', (WidgetTester tester) async {
      when(
        () => api.cashFlow(
          any(),
          currency: any(named: 'currency'),
          granularity: any(named: 'granularity'),
        ),
      ).thenAnswer((_) async => cashFlowReport(empty: true));
      await pump(tester, '/analytics');
      expect(find.textContaining('No income or spending for'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Net worth'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Net worth'), findsOneWidget);
    });
  });

  group('period reports', () {
    testWidgets('cash flow has a summary, a list alternative and a bucket '
        'size choice', (WidgetTester tester) async {
      await pump(tester, '/analytics/cash-flow?range=this_month&currency=INR');

      expect(find.text('Cash flow'), findsOneWidget);
      expect(
        find.textContaining('Income and spending per week'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Show as a list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show as a list'));
      await tester.pumpAndSettle();
      expect(
        find.text('In ₹85,000.00 · out ₹1,749.50 · net ₹83,250.50'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Month'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Month'));
      await tester.pumpAndSettle();
      verify(
        () => api.cashFlow(
          const DateRangeChoice.named('this_month'),
          currency: 'INR',
          granularity: 'month',
        ),
      ).called(1);
    });

    testWidgets('categories: bars with shares, subcategories on request and '
        'a drill-down into the transactions', (WidgetTester tester) async {
      when(
        () => api.categories(
          any(),
          currency: any(named: 'currency'),
          subcategories: any(named: 'subcategories'),
          income: any(named: 'income'),
        ),
      ).thenAnswer((_) async => categoryReport());
      final GoRouter router = await pump(
        tester,
        '/analytics/categories?range=this_month&currency=INR',
      );
      expect(find.textContaining('Most spending went to'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Uncategorized'), findsOneWidget);

      await tester.tap(find.text('Show subcategories separately'));
      await tester.pumpAndSettle();
      verify(
        () => api.categories(
          const DateRangeChoice.named('this_month'),
          currency: 'INR',
          subcategories: true,
          income: false,
        ),
      ).called(1);

      await tester.ensureVisible(find.text('Show as a list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show as a list'));
      await tester.pumpAndSettle();
      expect(find.text('₹1,250.50 (27.1%)'), findsOneWidget);
      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();
      expect(locationOf(router), startsWith('/transactions?'));
      expect(locationOf(router), contains('category_id=cat-groceries'));
    });

    testWidgets('categories: income per category (kind=income)', (
      WidgetTester tester,
    ) async {
      when(
        () => api.categories(
          any(),
          currency: any(named: 'currency'),
          subcategories: any(named: 'subcategories'),
          income: any(named: 'income'),
        ),
      ).thenAnswer((Invocation i) async {
        final bool income = i.namedArguments[#income] as bool;
        return income
            ? CategoryReport.fromJson(<String, Object?>{
                'window': windowJson(),
                'kind': 'income',
                'categories': <Object?>[
                  <String, Object?>{
                    ...categorySliceJson(name: 'Salary', id: 'cat-salary'),
                    'amount': moneyJson('60000.00'),
                    'net_expense': moneyJson('0.00'),
                    'share_bp': 10000,
                  },
                ],
              })
            : categoryReport();
      });
      await pump(tester, '/analytics/categories?range=this_month&currency=INR');
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      verify(
        () => api.categories(
          const DateRangeChoice.named('this_month'),
          currency: 'INR',
          subcategories: false,
          income: true,
        ),
      ).called(1);
      expect(find.textContaining('Most income came from Salary'), findsOne);
      expect(find.textContaining('60,000.00'), findsWidgets);
    });

    testWidgets('merchants: summary and an empty state', (
      WidgetTester tester,
    ) async {
      when(() => api.merchants(any(), currency: any(named: 'currency')))
          .thenAnswer((_) async => merchantReport());
      await pump(tester, '/analytics/merchants?currency=INR');
      expect(
        find.text('Croma had the most spending: ₹2,100.00. 2 merchants shown.'),
        findsOneWidget,
      );
      expect(find.text('Big Bazaar'), findsOneWidget);
    });

    testWidgets('merchants without spending say so', (
      WidgetTester tester,
    ) async {
      when(() => api.merchants(any(), currency: any(named: 'currency')))
          .thenAnswer((_) async => merchantReport(empty: true));
      await pump(tester, '/analytics/merchants?currency=INR');
      expect(
        find.textContaining('No spending with merchants for'),
        findsOneWidget,
      );
    });

    testWidgets('a report that fails to load offers a retry', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(
        () => api.expenses(
          any(),
          currency: any(named: 'currency'),
          granularity: any(named: 'granularity'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw serverError(ErrorObjectCode.internalError, status: 500);
        }
        return cashFlowReport(withUsd: false);
      });
      await pump(tester, '/analytics/expenses?currency=INR');
      expect(find.text('Something went wrong'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Spent before refunds'), findsOneWidget);
      expect(find.textContaining('Spending per week'), findsOneWidget);
    });
  });

  group('current state reports', () {
    testWidgets('net worth per currency, with the overview filter', (
      WidgetTester tester,
    ) async {
      when(() => api.accounts(overviewOnly: any(named: 'overviewOnly')))
          .thenAnswer((_) async => accountsReport());
      await pump(tester, '/analytics/accounts');
      expect(find.text('In INR'), findsOneWidget);
      expect(find.text('₹1,29,310.50'), findsOneWidget);
      expect(find.text('In USD'), findsOneWidget);
      await tester.tap(find.text('Only accounts in my overview'));
      await tester.pumpAndSettle();
      verify(() => api.accounts(overviewOnly: true)).called(1);
    });

    testWidgets('budgets, goals and subscriptions from the live server '
        'shapes', (WidgetTester tester) async {
      when(() => api.budgets()).thenAnswer((_) async => budgetPerformance());
      when(() => api.goals()).thenAnswer((_) async => goalReport());
      when(() => api.subscriptions())
          .thenAnswer((_) async => subscriptionSummary());
      final GoRouter router = await pump(tester, '/analytics/budgets');
      expect(find.text('1 budget is over its limit.'), findsOneWidget);
      expect(find.text('Monthly spending'), findsWidgets);

      router.go('/analytics/goals');
      await tester.pumpAndSettle();
      expect(find.text('Goa trip'), findsWidgets);
      expect(find.text('1 goal; achieved: 0'), findsOneWidget);

      router.go('/analytics/subscriptions');
      await tester.pumpAndSettle();
      expect(find.text('Music plan'), findsOneWidget);
      expect(find.text('₹119.00'), findsWidgets);
      expect(find.textContaining('Renews'), findsOneWidget);
    });

    testWidgets('empty budgets, goals and subscriptions offer to add one', (
      WidgetTester tester,
    ) async {
      when(() => api.budgets())
          .thenAnswer((_) async => budgetPerformance(empty: true));
      when(() => api.goals()).thenAnswer((_) async => goalReport(empty: true));
      when(() => api.subscriptions())
          .thenAnswer((_) async => subscriptionSummary(empty: true));
      final GoRouter router = await pump(tester, '/analytics/budgets');
      expect(find.text('No active budgets yet.'), findsOneWidget);
      expect(find.text('Create a budget'), findsOneWidget);
      router.go('/analytics/goals');
      await tester.pumpAndSettle();
      expect(find.text('No goals yet.'), findsOneWidget);
      router.go('/analytics/subscriptions');
      await tester.pumpAndSettle();
      expect(find.text('No subscriptions yet.'), findsOneWidget);
    });

    testWidgets('recurring commitments explain their note in the user '
        'language', (WidgetTester tester) async {
      when(() => api.recurring()).thenAnswer((_) async => recurringReport());
      await pump(tester, '/analytics/recurring');
      expect(
        find.text(
          'Monthly amounts use fixed amounts only. Bills and income are what '
          'you expect, not money already recorded.',
        ),
        findsOneWidget,
      );
      expect(
        find.text("1 with a varying amount isn't included."),
        findsOneWidget,
      );
      expect(find.textContaining('₹85,000.00 a month'), findsWidgets);
    });
  });

  group('compare', () {
    testWidgets('compares with the same number of days just before, per '
        'currency, with category changes', (WidgetTester tester) async {
      when(
        () => api.compare(
          any(),
          compareFrom: any(named: 'compareFrom'),
          compareTo: any(named: 'compareTo'),
          currency: any(named: 'currency'),
        ),
      ).thenAnswer((_) async => comparison());
      await pump(tester, '/analytics/compare?range=this_month&currency=INR');

      verify(
        () => api.compare(
          const DateRangeChoice.named('this_month'),
          compareFrom: '2026-10-02',
          compareTo: '2026-10-31',
        ),
      ).called(1);
      expect(find.text('Compare periods'), findsOneWidget);
      expect(find.text('The same number of days just before.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Changes by category'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Change: +₹4,289.50 (+1,340.5%)'), findsOneWidget);
      // Each total's change comes from the server (`change`, `change_bp`).
      expect(find.text('Change: +₹1,500.00 (+100.0%)'), findsOneWidget);
      expect(find.text('Change: -₹200.00 (−6.3%)'), findsOneWidget);
      expect(find.text('Change: +₹1,700.00 (+531.3%)'), findsOneWidget);
      expect(find.text('Change: +₹250.00 (new)'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(
          'Periods of different lengths are compared as totals, not per day.',
        ),
        200,
        scrollable: find.byType(Scrollable).first,
      );
    });
  });

  testWidgets('an unknown report says it is not available', (
    WidgetTester tester,
  ) async {
    await pump(tester, '/analytics/weather');
    expect(find.text("This report isn't available."), findsOneWidget);
  });
}
