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
import 'package:montra_mobile/features/dashboard/domain/widget_info.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/payment_methods/data/payment_methods_api.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';

import '../../helpers/budgets_fakes.dart';
import '../../helpers/dashboard_fakes.dart';
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
    when(() => api.planning()).thenAnswer((_) async => dashboardPlanning());
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
        (_) async => widgetLayout(hidden: <String>{'top_merchants'}),
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
      List<DashboardWidget>? saved;
      when(() => api.saveWidgets(any())).thenAnswer((Invocation i) async {
        saved = i.positionalArguments.first as List<DashboardWidget>;
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

      expect(
        saved!.map((DashboardWidget w) => w.key).take(3).toList(),
        <String>['balances', 'budgets', 'cash_flow'],
      );
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

  group('planning cards', () {
    /// Only the four planning widgets, so every card is on screen.
    List<DashboardWidget> planningOnly() => widgetLayout(
      keys: const <String>['budgets', 'upcoming', 'goals', 'group_balances'],
    );

    Future<void> scrollTo(WidgetTester tester, Finder finder) =>
        tester.scrollUntilVisible(
          finder,
          200,
          scrollable: find.byType(Scrollable).first,
        );

    testWidgets('one request draws budgets, coming up, goals and group '
        'balances with every status in words', (WidgetTester tester) async {
      when(() => api.summary(any())).thenAnswer((_) async => summary());
      when(() => api.widgets()).thenAnswer((_) async => planningOnly());
      final GoRouter router = await pump(tester);

      verify(() => api.planning()).called(1);
      expect(find.text('2 active budgets · 1 is over budget'), findsOneWidget);
      expect(find.text('Food budget'), findsOneWidget);
      expect(find.text('₹12,500.50 spent of ₹10,000.00'), findsOneWidget);
      expect(find.text('Over the limit'), findsOneWidget);

      await scrollTo(tester, find.text('Bill · Was due Nov 8, 2026'));
      expect(
        find.text('2 items through Nov 26, 2026 · 1 is overdue'),
        findsOneWidget,
      );
      expect(find.text('Bill · Was due Nov 8, 2026'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Bill · Due Nov 20, 2026'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);

      await scrollTo(tester, find.text('1 active goal'));
      expect(find.text('Emergency fund'), findsOneWidget);
      expect(find.textContaining('saved ·'), findsOneWidget);

      await scrollTo(tester, find.text('You owe ₹450.25'));
      expect(find.text('Open balances in 2 groups'), findsOneWidget);
      expect(find.text('You are owed ₹1,000.00'), findsOneWidget);
      expect(find.text('Goa trip'), findsOneWidget);
      verifyNever(() => api.planning());

      await tester.tap(find.text('Goa trip'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/groups/g2/balances');
    });

    testWidgets('rows and "See all" open the full screens', (
      WidgetTester tester,
    ) async {
      when(() => api.summary(any())).thenAnswer((_) async => summary());
      when(() => api.widgets()).thenAnswer((_) async => planningOnly());
      final GoRouter router = await pump(tester);

      expect(find.bySemanticsLabel('See all budgets'), findsOneWidget);
      await scrollTo(tester, find.bySemanticsLabel('Open the calendar'));
      expect(find.bySemanticsLabel('Open the calendar'), findsOneWidget);
      await tester.ensureVisible(find.text('Food budget'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food budget'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/budgets/bud-1');
      router.pop();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.bySemanticsLabel('See all budgets'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('See all budgets'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/budgets');
    });

    testWidgets('empty cards say what is missing and offer the next step', (
      WidgetTester tester,
    ) async {
      when(() => api.summary(any())).thenAnswer((_) async => summary());
      when(() => api.widgets()).thenAnswer((_) async => planningOnly());
      when(() => api.planning())
          .thenAnswer((_) async => dashboardPlanning(empty: true));
      final GoRouter router = await pump(tester);

      expect(find.textContaining('No active budgets.'), findsOneWidget);
      await scrollTo(tester, find.text("You're settled up in every group."));
      expect(
        find.text(
          'Nothing is due in the next 14 days, and nothing is overdue.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('No active goals.'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Create a budget'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Create a budget'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/budgets/new');
    });

    testWidgets('a card is loading until the planning answer arrives', (
      WidgetTester tester,
    ) async {
      final Completer<DashboardPlanning> answer =
          Completer<DashboardPlanning>();
      when(() => api.summary(any())).thenAnswer((_) async => summary());
      when(() => api.widgets()).thenAnswer((_) async => planningOnly());
      when(() => api.planning()).thenAnswer((_) => answer.future);
      final ({Widget app, GoRouter router}) r = routedApp(
        '/home',
        overrides: overrides(),
      );
      await tester.pumpWidget(r.app);
      // The progress indicator keeps animating, so pump a few frames.
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Loading…'), findsWidgets);
      answer.complete(dashboardPlanning());
      await tester.pumpAndSettle();
      expect(find.text('Loading…'), findsNothing);
      expect(find.text('Food budget'), findsOneWidget);
    });

    testWidgets('a failed request is shown on the cards and retried once '
        'for all of them', (WidgetTester tester) async {
      int calls = 0;
      when(() => api.summary(any())).thenAnswer((_) async => summary());
      when(() => api.widgets()).thenAnswer((_) async => planningOnly());
      when(() => api.planning()).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return dashboardPlanning();
      });
      await pump(tester);

      expect(
        find.textContaining("This card couldn't be loaded."),
        findsWidgets,
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Try again').first);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Food budget'), findsOneWidget);
      expect(
        find.textContaining("This card couldn't be loaded."),
        findsNothing,
      );
    });

    testWidgets('hidden planning widgets are neither drawn nor requested', (
      WidgetTester tester,
    ) async {
      when(() => api.summary(any())).thenAnswer((_) async => summary());
      when(() => api.widgets()).thenAnswer(
        (_) async => widgetLayout(
          hidden: <String>{'budgets', 'upcoming', 'goals', 'group_balances'},
        ),
      );
      await pump(tester);
      expect(find.text('Coming up'), findsNothing);
      verifyNever(() => api.planning());
    });

    testWidgets('the layout settings list the planning widgets and keep '
        'widgets from a newer server when saving', (WidgetTester tester) async {
      when(() => api.summary(any())).thenAnswer((_) async => summary());
      when(() => api.widgets()).thenAnswer(
        (_) async => widgetLayout(
          keys: <String>[...defaultWidgetKeys, 'net_worth_forecast'],
        ),
      );
      List<DashboardWidget>? saved;
      when(() => api.saveWidgets(any())).thenAnswer((Invocation i) async {
        saved = i.positionalArguments.first as List<DashboardWidget>;
        return saved!;
      });
      final GoRouter router = await pump(tester);
      unawaited(router.push<Object?>('/home/widgets'));
      await tester.pumpAndSettle();

      for (final String title in <String>[
        'Budgets',
        'Coming up',
        'Goals',
        'Group balances',
      ]) {
        await scrollTo(tester, find.widgetWithText(SwitchListTile, title));
        expect(find.widgetWithText(SwitchListTile, title), findsOneWidget);
      }
      await tester.tap(find.widgetWithText(SwitchListTile, 'Group balances'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved!.map((DashboardWidget w) => w.key).toList(), <String>[
        ...defaultWidgetKeys,
        'net_worth_forecast',
      ]);
      expect(
        saved!
            .firstWhere((DashboardWidget w) => w.key == 'group_balances')
            .visible,
        isFalse,
      );
    });

    for (final Locale locale in <Locale>[
      const Locale('en'),
      const Locale('hi'),
    ]) {
      testWidgets('planning cards fit at 200% text ($locale)', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        when(() => api.summary(any())).thenAnswer((_) async => summary());
        when(() => api.widgets()).thenAnswer((_) async => planningOnly());
        final ({Widget app, GoRouter router}) r = routedApp(
          '/home',
          overrides: overrides(),
          locale: locale,
        );
        await tester.pumpWidget(r.app);
        await tester.pumpAndSettle();
        final Finder list = find.byType(Scrollable).first;
        for (int i = 0; i < 12; i++) {
          await tester.drag(list, const Offset(0, -500));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}
