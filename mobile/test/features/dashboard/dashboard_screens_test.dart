import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/budgets/data/budgets_api.dart';
import 'package:montra_mobile/features/dashboard/data/dashboard_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/payment_methods/data/payment_methods_api.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';

import '../../helpers/budgets_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockDashboardApi api;
  late MockPreferencesApi prefs;
  late MockLabelsApi labels;
  late MockTransactionsApi transactions;
  late MockAccountsApi accounts;
  late MockPaymentMethodsApi methods;
  late MockBudgetsApi budgets;

  setUpAll(registerFinanceFallbacks);

  setUp(() {
    api = MockDashboardApi();
    prefs = MockPreferencesApi();
    labels = MockLabelsApi();
    transactions = MockTransactionsApi();
    accounts = MockAccountsApi();
    methods = MockPaymentMethodsApi();
    budgets = MockBudgetsApi();
    when(() => budgets.alerts(status: any(named: 'status')))
        .thenAnswer((_) async => <AlertDto>[]);
    stubLabels(labels, categories: <CategoryDto>[category()]);
    when(() => prefs.preferences()).thenAnswer((_) async => preferences());
    when(() => api.widgets()).thenAnswer((_) async => widgetLayout());
    when(
      () => transactions.list(
        any(),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => page(<TransactionDto>[transaction()]));
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    when(() => methods.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <PaymentMethodDto>[]);
  });

  List<Override> overrides() => <Override>[
    dashboardApiProvider.overrideWithValue(api),
    preferencesApiProvider.overrideWithValue(prefs),
    labelsApiProvider.overrideWithValue(labels),
    transactionsApiProvider.overrideWithValue(transactions),
    accountsApiProvider.overrideWithValue(accounts),
    paymentMethodsApiProvider.overrideWithValue(methods),
    budgetsApiProvider.overrideWithValue(budgets),
  ];

  Future<GoRouter> pump(
    WidgetTester tester, [
    String location = '/home',
  ]) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  group('dashboard', () {
    testWidgets('offers planning shortcuts and shows active budget alerts', (
      WidgetTester tester,
    ) async {
      when(() => api.summary(any())).thenAnswer((_) async => summary());
      when(() => budgets.alerts(status: any(named: 'status')))
          .thenAnswer((_) async => <AlertDto>[budgetAlert()]);
      final GoRouter router = await pump(tester);

      expect(find.text('1 budget alert'), findsOneWidget);
      expect(find.text('Plan ahead'), findsOneWidget);
      for (final String label in <String>[
        'Budgets',
        'Goals',
        'Bills',
        'Subscriptions',
      ]) {
        expect(find.widgetWithText(ActionChip, label), findsOneWidget);
      }
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/budget-alerts');
      router.pop();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(ActionChip, 'Calendar'));
      await tester.tap(find.widgetWithText(ActionChip, 'Calendar'));
      await tester.pumpAndSettle();
      expect(locationOf(router), startsWith('/calendar'));
    });

    testWidgets('draws the layout with chart summaries and list equivalents', (
      WidgetTester tester,
    ) async {
      when(() => api.summary(any())).thenAnswer((_) async => summary());
      when(() => api.widgets()).thenAnswer(
        (_) async =>
            widgetLayout(hidden: <WidgetDtoKey>{WidgetDtoKey.topMerchants}),
      );
      final GoRouter router = await pump(tester);

      verify(() => api.summary(const DateRangeChoice.named('this_month')))
          .called(1);
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('Balances'), findsOneWidget);
      expect(find.text('₹94,190.50'), findsOneWidget);
      expect(find.textContaining('Updated '), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('More came in than went out.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Savings rate'), findsOneWidget);
      expect(find.text('98.8%'), findsOneWidget);

      const String chart =
          'For Nov 1, 2026 – Nov 30, 2026, income was ₹85,000.00 and spending '
          'was ₹1,010.00.';
      await tester.scrollUntilVisible(
        find.text(chart),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(chart), findsOneWidget);
      // The chart drawing is replaced by the same figures as a list.
      await tester.tap(find.text('Show as a list').first);
      await tester.pumpAndSettle();
      expect(find.text('Show as a chart'), findsOneWidget);

      // Hidden widgets are not drawn.
      expect(find.text('Top merchants'), findsNothing);

      await tester.scrollUntilVisible(
        find.textContaining('Most spending went to Groceries'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Groceries').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Groceries').first);
      await tester.pumpAndSettle();
      expect(
        locationOf(router),
        '/transactions?from=2026-11-01&to=2026-11-30&category_id=cat-groceries',
      );
    });

    testWidgets('shows one currency at a time when several exist', (
      WidgetTester tester,
    ) async {
      when(() => api.summary(any()))
          .thenAnswer((_) async => summary(withUsd: true));
      await pump(tester);

      expect(find.widgetWithText(ChoiceChip, 'INR'), findsOneWidget);
      expect(
        find.text(
          'Amounts in different currencies are shown separately and never added together.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'USD'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('More went out than came in.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('More went out than came in.'), findsOneWidget);
      expect(find.text('-\$40.00'), findsOneWidget);
    });

    testWidgets('a new user sees how to get started', (
      WidgetTester tester,
    ) async {
      when(() => api.summary(any()))
          .thenAnswer((_) async => summary(empty: true));
      await pump(tester);

      expect(find.text("Let's start tracking"), findsOneWidget);
      expect(find.text('Add your first account'), findsOneWidget);
    });

    testWidgets(
      'errors offer a retry; a failed refresh keeps labelled figures',
      (WidgetTester tester) async {
        int calls = 0;
        when(() => api.summary(any())).thenAnswer((_) async {
          calls++;
          if (calls == 1 || calls == 3) {
            throw offline;
          }
          return summary();
        });
        await pump(tester);
        expect(find.text("You're offline"), findsOneWidget);

        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(find.text('Balances'), findsOneWidget);

        await tester.fling(
          find.byType(ListView).first,
          const Offset(0, 400),
          1000,
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining("We couldn't refresh. Showing figures from"),
          findsOneWidget,
        );
        expect(find.text('Balances'), findsOneWidget);
      },
    );

    testWidgets('changing the period reloads the summary for it', (
      WidgetTester tester,
    ) async {
      when(() => api.summary(any())).thenAnswer((_) async => summary());
      await pump(tester);

      await tester.tap(find.text('This month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last 30 days'));
      await tester.pumpAndSettle();

      expect(find.text('Last 30 days'), findsOneWidget);
      verify(() => api.summary(const DateRangeChoice.named('last_30_days')))
          .called(1);
    });
  });

  group('widget layout', () {
    testWidgets('hides and reorders widgets, then saves the layout', (
      WidgetTester tester,
    ) async {
      when(() => api.summary(any())).thenAnswer((_) async => summary());
      List<WidgetDto>? saved;
      when(() => api.saveWidgets(any())).thenAnswer((Invocation i) async {
        saved = i.positionalArguments.first as List<WidgetDto>;
        return saved!;
      });
      final GoRouter router = await pump(tester);
      unawaited(router.push<Object?>('/home/widgets'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SwitchListTile, 'Balances'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Move Cash flow down'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved!.map((WidgetDto w) => w.key.json).take(3).toList(), <String>[
        'balances',
        'income_vs_expense',
        'cash_flow',
      ]);
      expect(saved!.first.visible, isFalse);
      expect(find.text('Home layout saved.'), findsOneWidget);
    });

    testWidgets('resets the layout after confirming', (
      WidgetTester tester,
    ) async {
      when(() => api.summary(any())).thenAnswer((_) async => summary());
      when(() => api.resetWidgets()).thenAnswer((_) async => widgetLayout());
      final GoRouter router = await pump(tester);
      unawaited(router.push<Object?>('/home/widgets'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('Reset Home layout?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
      await tester.pumpAndSettle();

      verify(() => api.resetWidgets()).called(1);
      expect(find.text('Home layout reset.'), findsOneWidget);
    });

    testWidgets('shows an error when the layout cannot load', (
      WidgetTester tester,
    ) async {
      when(() => api.summary(any())).thenAnswer((_) async => summary());
      when(() => api.widgets()).thenThrow(offline);
      final GoRouter router = await pump(tester);
      // Home still works with the default layout.
      expect(
        find.textContaining("couldn't load your Home layout"),
        findsOneWidget,
      );
      unawaited(router.push<Object?>('/home/widgets'));
      await tester.pumpAndSettle();
      expect(find.text("You're offline"), findsOneWidget);
    });
  });
}
