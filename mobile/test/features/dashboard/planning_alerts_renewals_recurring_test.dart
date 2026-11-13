import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
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
import '../../helpers/planning_fakes.dart';
import '../../helpers/router_app.dart';

/// The Home cards for budget alerts, renewals and recurring commitments:
/// all three read the same `GET /dashboard/planning` answer as the other
/// planning cards.
void main() {
  late MockDashboardApi api;
  late MockPreferencesApi prefs;
  late MockLabelsApi labels;
  late MockTransactionsApi transactions;
  late MockAccountsApi accounts;
  late MockPaymentMethodsApi methods;
  late MockBudgetsApi budgets;
  late List<(String, BudgetAlertsUpdateRequest)> sent;

  setUpAll(() {
    registerFinanceFallbacks();
    registerBudgetFallbacks();
  });

  /// Only the three new cards, so each is on screen.
  List<DashboardWidget> newCards() =>
      widgetLayout(keys: const <String>['alerts', 'renewals', 'recurring']);

  setUp(() {
    api = MockDashboardApi();
    prefs = MockPreferencesApi();
    labels = MockLabelsApi();
    transactions = MockTransactionsApi();
    accounts = MockAccountsApi();
    methods = MockPaymentMethodsApi();
    budgets = MockBudgetsApi();
    sent = <(String, BudgetAlertsUpdateRequest)>[];
    when(() => budgets.alerts(status: any(named: 'status')))
        .thenAnswer((_) async => <AlertDto>[]);
    when(() => budgets.updateAlert(any(), any()))
        .thenAnswer((Invocation i) async {
          sent.add((
            i.positionalArguments[0] as String,
            i.positionalArguments[1] as BudgetAlertsUpdateRequest,
          ));
        });
    stubLabels(labels, categories: <CategoryDto>[category()]);
    when(() => prefs.preferences()).thenAnswer((_) async => preferences());
    when(() => api.summary(any())).thenAnswer((_) async => summary());
    when(() => api.widgets()).thenAnswer((_) async => newCards());
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

  /// A phone-sized screen (360 × 780).
  void phone(WidgetTester tester, {bool tall = false}) {
    tester.view.physicalSize = Size(1080, tall ? 4200 : 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<GoRouter> pump(WidgetTester tester, {Locale? locale}) async {
    phone(tester);
    final ({Widget app, GoRouter router}) r = routedApp(
      '/home',
      overrides: overrides(),
      locale: locale ?? const Locale('en'),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  /// Drags Home (down, then back up) until [finder] can be tapped.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    final Finder list = find.byType(Scrollable).first;
    for (final double dy in <double>[-120, 120]) {
      for (int i = 0; i < 25 && finder.hitTestable().evaluate().isEmpty; i++) {
        await tester.drag(list, Offset(0, dy));
        await tester.pumpAndSettle();
      }
    }
    expect(finder.hitTestable(), findsWidgets);
  }

  /// Scrolls [finder] out from under the add button, then taps it.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await scrollTo(tester, finder);
    await tester.tap(finder.hitTestable().first);
    await tester.pumpAndSettle();
  }

  group('budget alerts card', () {
    testWidgets('says each active alert in words and opens its budget', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pump(tester);

      verify(() => api.planning()).called(1);
      expect(find.text('Budget alerts'), findsOneWidget);
      expect(find.text('2 active alerts'), findsOneWidget);
      expect(find.text('Food budget: the whole limit is used'), findsOneWidget);
      expect(
        find.text('Monthly spending may go over its limit'),
        findsOneWidget,
      );
      expect(find.textContaining('Noticed '), findsNWidgets(2));
      expect(
        find.bySemanticsLabel('Snooze the alert for Food budget'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Dismiss the alert for Monthly spending'),
        findsOneWidget,
      );

      await tester.tap(find.text('Food budget: the whole limit is used'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/budgets/bud-1');
      router.pop();
      await tester.pumpAndSettle();

      await tapVisible(tester, find.bySemanticsLabel('See all budget alerts'));
      expect(locationOf(router), '/budget-alerts');
    });

    testWidgets('dismisses an alert and reads planning again', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(() => api.planning()).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? dashboardPlanning()
            : dashboardPlanning(
                alerts: <AlertDto>[
                  budgetAlert(
                    id: 'alert-2',
                    budgetId: 'bud-2',
                    kind: 'forecast_overspend',
                  ),
                ],
              );
      });
      await pump(tester);

      await tapVisible(
        tester,
        find.bySemanticsLabel('Dismiss the alert for Food budget'),
      );

      expect(sent, hasLength(1));
      expect(sent.single.$1, 'alert-1');
      expect(sent.single.$2.status, BudgetAlertsUpdateRequestStatus.dismissed);
      expect(sent.single.$2.snoozedUntil, isNull);
      expect(find.text('Alert dismissed.'), findsOneWidget);
      expect(calls, 2);
      expect(find.text('Food budget: the whole limit is used'), findsNothing);
      expect(find.text('1 active alert'), findsOneWidget);
    });

    testWidgets('snoozes an alert for a day', (WidgetTester tester) async {
      await pump(tester);
      final DateTime before = DateTime.now();

      await tapVisible(
        tester,
        find.bySemanticsLabel('Snooze the alert for Monthly spending'),
      );
      await tester.tap(find.text('For 1 day'));
      await tester.pumpAndSettle();

      expect(sent.single.$1, 'alert-2');
      expect(sent.single.$2.status, BudgetAlertsUpdateRequestStatus.snoozed);
      final DateTime until = sent.single.$2.snoozedUntil!;
      expect(until.isUtc, isTrue);
      expect(
        until.difference(before.toUtc()).inHours,
        inInclusiveRange(23, 24),
      );
      expect(find.textContaining('Alert snoozed until'), findsOneWidget);
      verify(() => api.planning()).called(2);
    });

    testWidgets('a failed change says why and keeps the alert', (
      WidgetTester tester,
    ) async {
      when(() => budgets.updateAlert(any(), any())).thenThrow(offline);
      await pump(tester);

      await tapVisible(
        tester,
        find.bySemanticsLabel('Dismiss the alert for Food budget'),
      );

      expect(
        find.text('Check your internet connection and try again.'),
        findsOneWidget,
      );
      expect(find.text('Food budget: the whole limit is used'), findsOneWidget);
      verify(() => api.planning()).called(1);
    });
  });

  group('renewals card', () {
    testWidgets('lists renewals and trial ends soonest first with amounts', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pump(tester);
      await scrollTo(tester, find.text('Music Plus'));

      expect(
        find.text('2 renewals and trial ends through Dec 12, 2026'),
        findsOneWidget,
      );
      final Offset netflix = tester.getTopLeft(find.text('Netflix'));
      final Offset music = tester.getTopLeft(find.text('Music Plus'));
      expect(netflix.dy, lessThan(music.dy));
      expect(find.text('Subscription renewal · Today'), findsOneWidget);
      expect(find.text('Trial ends · On Nov 30, 2026'), findsOneWidget);
      expect(find.text('₹649.00'), findsOneWidget);
      expect(find.text('₹119.00'), findsOneWidget);
      expect(find.text('Expected'), findsNWidgets(2));

      await tester.tap(find.text('Netflix'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/subscriptions/sub-1');
      router.pop();
      await tester.pumpAndSettle();

      await tapVisible(tester, find.bySemanticsLabel('See all subscriptions'));
      expect(locationOf(router), '/subscriptions');
    });

    testWidgets('says when more renewals are coming than shown', (
      WidgetTester tester,
    ) async {
      when(() => api.planning())
          .thenAnswer((_) async => dashboardPlanning(renewalCount: 9));
      await pump(tester);
      await scrollTo(tester, find.text('Showing 2 of 9'));
      expect(find.text('Showing 2 of 9'), findsOneWidget);
    });
  });

  group('recurring card', () {
    testWidgets('shows monthly amounts per kind and currency, exactly as '
        'sent, with the note in words', (WidgetTester tester) async {
      final GoRouter router = await pump(tester);
      await scrollTo(tester, find.text('\$19.99 a month'));

      expect(find.text('Recurring commitments'), findsOneWidget);
      expect(find.text('In INR'), findsOneWidget);
      expect(find.text('In USD'), findsOneWidget);
      expect(find.text('₹12,499.50 a month'), findsOneWidget);
      expect(find.text('₹85,000.00 a month'), findsOneWidget);
      expect(find.text('\$19.99 a month'), findsOneWidget);
      expect(find.text('2 active'), findsOneWidget);
      expect(
        find.text("1 with a varying amount isn't included."),
        findsOneWidget,
      );
      expect(
        find.text(
          'Monthly amounts use fixed amounts only. Bills and income are '
          'what you expect, not money already recorded.',
        ),
        findsOneWidget,
      );
      // INR (the base currency) comes before USD.
      expect(
        tester.getTopLeft(find.text('In INR')).dy,
        lessThan(tester.getTopLeft(find.text('In USD')).dy),
      );

      await scrollTo(
        tester,
        find.bySemanticsLabel('Open recurring commitments'),
      );
      await tapVisible(
        tester,
        find.bySemanticsLabel('Open recurring commitments'),
      );
      expect(locationOf(router), '/analytics/recurring');
    });

    testWidgets('an unknown note code shows the figures without a note', (
      WidgetTester tester,
    ) async {
      when(() => api.planning()).thenAnswer(
        (_) async => dashboardPlanning(recurringNoteCode: 'something_new'),
      );
      await pump(tester);
      await scrollTo(tester, find.text('₹12,499.50 a month'));
      expect(find.textContaining('Monthly amounts use'), findsNothing);
      expect(find.text('₹12,499.50 a month'), findsOneWidget);
    });
  });

  group('all three cards', () {
    testWidgets('empty cards say what is missing and offer the next step', (
      WidgetTester tester,
    ) async {
      when(() => api.planning())
          .thenAnswer((_) async => dashboardPlanning(empty: true));
      final GoRouter router = await pump(tester);

      expect(
        find.text(
          'No active budget alerts. One appears here when a budget reaches '
          'a limit you set.',
        ),
        findsOneWidget,
      );
      await scrollTo(tester, find.text('Add a recurring payment'));
      expect(
        find.text(
          'No subscription renewals or trial ends in the next 30 days.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('No active recurring payments or income.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Add a recurring payment'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/recurring/new');
      router.pop();
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Add a subscription'));
      await tester.tap(find.text('Add a subscription'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/subscriptions/new');
    });

    testWidgets('each card is loading until the one planning answer '
        'arrives', (WidgetTester tester) async {
      phone(tester);
      final Completer<DashboardPlanning> answer =
          Completer<DashboardPlanning>();
      when(() => api.planning()).thenAnswer((_) => answer.future);
      final ({Widget app, GoRouter router}) r = routedApp(
        '/home',
        overrides: overrides(),
      );
      await tester.pumpWidget(r.app);
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Loading…'), findsNWidgets(3));
      answer.complete(dashboardPlanning());
      await tester.pumpAndSettle();
      expect(find.text('Loading…'), findsNothing);
      expect(find.text('2 active alerts'), findsOneWidget);
      verify(() => api.planning()).called(1);
    });

    testWidgets('a failed request shows an error on each card and one '
        'retry reloads all of them', (WidgetTester tester) async {
      int calls = 0;
      when(() => api.planning()).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return dashboardPlanning();
      });
      await pump(tester);
      phone(tester, tall: true);
      await tester.pumpAndSettle();

      expect(
        find.textContaining("This card couldn't be loaded."),
        findsNWidgets(3),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Try again').first);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(
        find.textContaining("This card couldn't be loaded."),
        findsNothing,
      );
      expect(find.text('2 active alerts'), findsOneWidget);
    });

    testWidgets('a new user sees the cards that have something in them', (
      WidgetTester tester,
    ) async {
      when(() => api.summary(any()))
          .thenAnswer((_) async => summary(empty: true));
      when(() => api.planning()).thenAnswer(
        (_) async => dashboardPlanning(
          empty: true,
          renewals: <CalendarItem>[
            calendarItem(
              date: '2026-11-20',
              kind: 'trial_end',
              entityType: 'subscription',
              entityId: 'sub-2',
              title: 'Music Plus',
              status: 'expected',
              amount: '119.00',
            ),
          ],
        ),
      );
      await pump(tester);
      await scrollTo(tester, find.text('Music Plus'));
      expect(find.text('Renewals'), findsOneWidget);
      expect(find.text('Budget alerts'), findsNothing);
      expect(find.text('Recurring commitments'), findsNothing);
    });

    testWidgets('the layout settings list, hide and reset the new cards', (
      WidgetTester tester,
    ) async {
      when(() => api.widgets()).thenAnswer((_) async => widgetLayout());
      when(() => api.resetWidgets()).thenAnswer((_) async => widgetLayout());
      List<DashboardWidget>? saved;
      when(() => api.saveWidgets(any())).thenAnswer((Invocation i) async {
        saved = i.positionalArguments.first as List<DashboardWidget>;
        return saved!;
      });
      final GoRouter router = await pump(tester);
      unawaited(router.push<Object?>('/home/widgets'));
      await tester.pumpAndSettle();

      for (final String title in <String>[
        'Budget alerts',
        'Renewals',
        'Recurring commitments',
      ]) {
        await scrollTo(tester, find.widgetWithText(SwitchListTile, title));
        expect(find.widgetWithText(SwitchListTile, title), findsOneWidget);
      }
      await scrollTo(tester, find.byTooltip('Move Renewals up'));
      await tester.tap(find.byTooltip('Move Renewals up'));
      await tester.pumpAndSettle();
      await scrollTo(
        tester,
        find.widgetWithText(SwitchListTile, 'Recurring commitments'),
      );
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Recurring commitments'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final List<String> keys = saved!
          .map((DashboardWidget w) => w.key)
          .toList();
      expect(keys, hasLength(15));
      expect(keys.indexOf('renewals'), keys.indexOf('upcoming') - 1);
      expect(
        saved!.firstWhere((DashboardWidget w) => w.key == 'recurring').visible,
        isFalse,
      );
      expect(
        saved!.firstWhere((DashboardWidget w) => w.key == 'alerts').visible,
        isTrue,
      );

      unawaited(router.push<Object?>('/home/widgets'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
      await tester.pumpAndSettle();
      verify(() => api.resetWidgets()).called(1);
    });
  });

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('alerts, renewals and recurring cards fit at 200% text '
        '($locale)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, locale: locale);
      final Finder list = find.byType(Scrollable).first;
      for (int i = 0; i < 12; i++) {
        await tester.drag(list, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty alerts, renewals and recurring cards fit at 200% '
        'text ($locale)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      when(() => api.planning())
          .thenAnswer((_) async => dashboardPlanning(empty: true));
      await pump(tester, locale: locale);
      final Finder list = find.byType(Scrollable).first;
      for (int i = 0; i < 8; i++) {
        await tester.drag(list, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
