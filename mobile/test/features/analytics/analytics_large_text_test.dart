import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/features/analytics/data/analytics_api.dart';

import '../../helpers/insights_fakes.dart';
import '../../helpers/router_app.dart';

/// Analytics screens at 200 % text in English and Hindi must lay out without
/// overflow (overflow is reported as a test failure).
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
    when(
      () => api.expenses(
        any(),
        currency: any(named: 'currency'),
        granularity: any(named: 'granularity'),
      ),
    ).thenAnswer((_) async => cashFlowReport());
    when(
      () => api.income(
        any(),
        currency: any(named: 'currency'),
        granularity: any(named: 'granularity'),
      ),
    ).thenAnswer((_) async => cashFlowReport());
    when(
      () => api.categories(
        any(),
        currency: any(named: 'currency'),
        subcategories: any(named: 'subcategories'),
        income: any(named: 'income'),
      ),
    ).thenAnswer((_) async => categoryReport());
    when(() => api.merchants(any(), currency: any(named: 'currency')))
        .thenAnswer((_) async => merchantReport());
    when(() => api.paymentMethods(any(), currency: any(named: 'currency')))
        .thenAnswer((_) async => paymentMethodReport());
    when(() => api.accounts(overviewOnly: any(named: 'overviewOnly')))
        .thenAnswer((_) async => accountsReport());
    when(() => api.budgets()).thenAnswer((_) async => budgetPerformance());
    when(() => api.goals()).thenAnswer((_) async => goalReport());
    when(() => api.subscriptions())
        .thenAnswer((_) async => subscriptionSummary());
    when(() => api.recurring()).thenAnswer((_) async => recurringReport());
    when(
      () => api.compare(
        any(),
        compareFrom: any(named: 'compareFrom'),
        compareTo: any(named: 'compareTo'),
        currency: any(named: 'currency'),
      ),
    ).thenAnswer((_) async => comparison());
  });

  List<Override> overrides() => <Override>[
    analyticsApiProvider.overrideWithValue(api),
  ];

  /// Opens [start], then pushes each of [locations] at 200 % text in
  /// [locale], scrolling through it; any overflow fails the test.
  Future<void> walk(
    WidgetTester tester,
    Locale locale,
    String start,
    List<String> locations, {
    Future<void> Function(WidgetTester tester, String location)? extra,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final ({Widget app, GoRouter router}) r = routedApp(
      start,
      overrides: overrides(),
      locale: locale,
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: start);
    for (final String location in locations) {
      unawaited(r.router.push<Object?>(location));
      await tester.pumpAndSettle();
      for (int i = 0; i < 8; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: location);
      if (extra != null) {
        await extra(tester, location);
        expect(tester.takeException(), isNull, reason: '$location (more)');
      }
      r.router.pop();
      await tester.pumpAndSettle();
    }
  }

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('analytics screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      await walk(
        tester,
        locale,
        '/analytics',
        <String>[
          '/analytics/cash-flow?currency=INR',
          '/analytics/expenses?currency=INR',
          '/analytics/income?currency=USD',
          '/analytics/categories?currency=INR',
          '/analytics/merchants?currency=INR',
          '/analytics/payment-methods?currency=INR',
          '/analytics/accounts',
          '/analytics/budgets',
          '/analytics/goals',
          '/analytics/subscriptions',
          '/analytics/recurring',
          '/analytics/compare?currency=INR',
        ],
        extra: (WidgetTester tester, String location) async {
          final Finder list = find.text(
            locale.languageCode == 'hi'
                ? 'सूची के रूप में दिखाएँ'
                : 'Show as a list',
          );
          if (list.evaluate().isNotEmpty) {
            await tester.ensureVisible(list.first);
            await tester.pumpAndSettle();
            await tester.tap(list.first);
            await tester.pumpAndSettle();
          }
          // Income by category.
          final Finder income = find.text(
            locale.languageCode == 'hi' ? 'आय' : 'Income',
          );
          if (location.startsWith('/analytics/categories') &&
              income.evaluate().isNotEmpty) {
            await tester.ensureVisible(income.first);
            await tester.pumpAndSettle();
            await tester.tap(income.first);
            await tester.pumpAndSettle();
          }
        },
      );
    });
  }
}
