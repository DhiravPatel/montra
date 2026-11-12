import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/analytics/data/analytics_api.dart';
import 'package:montra_mobile/features/dashboard/data/dashboard_api.dart';
import 'package:montra_mobile/features/fx/data/fx_api.dart';
import 'package:montra_mobile/features/imports/data/imports_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/receipts/data/receipts_api.dart';
import 'package:montra_mobile/features/reconciliation/data/reconciliation_api.dart';
import 'package:montra_mobile/features/reports/data/reports_api.dart';
import 'package:montra_mobile/features/settings/data/limits_api.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';

import '../helpers/finance_fakes.dart';
import '../helpers/imports_fakes.dart';
import '../helpers/insights_fakes.dart';
import '../helpers/receipts_fakes.dart';
import '../helpers/router_app.dart';

class MockLimitsApi extends Mock implements LimitsApi {}

Limits limits({int used = 1536 * 1024}) => Limits.fromJson(<String, Object?>{
  'storage_quota_bytes': 2147483648,
  'storage_used_bytes': used,
  'max_upload_bytes': 20971520,
  'import_max_rows': 20000,
  'max_open_recurring_rules': 500,
  'max_open_bills': 200,
  'max_open_subscriptions': 500,
  'max_open_goals': 200,
  'support_requests_per_day': 10,
  'rate_limits': <Object?>[],
  'deletion_grace_days': 7,
  'export_download_days': 7,
  'ai_requests_per_day': 0,
  'note': 'Every feature is free for everyone.',
  'note_code': 'fair_use_same_for_everyone',
});

/// Round-3 entry points: Profile "Records and insights" (with file storage
/// from GET /limits), the Home "Review your money" row and the account
/// detail actions open the new screens.
void main() {
  late MockLimitsApi limitsApi;
  late MockReceiptsApi receipts;
  late MockImportsApi imports;
  late MockReportsApi reports;
  late MockFxApi fx;
  late MockAnalyticsApi analytics;
  late MockReconciliationApi reconciliation;
  late MockAccountsApi accounts;
  late MockLabelsApi labels;
  late MockDashboardApi dashboard;
  late MockPreferencesApi prefs;

  setUpAll(() {
    registerFinanceFallbacks();
    registerInsightsFallbacks();
    registerReceiptFallbacks();
    registerImportFallbacks();
  });

  setUp(() {
    limitsApi = MockLimitsApi();
    receipts = MockReceiptsApi();
    imports = MockImportsApi();
    reports = MockReportsApi();
    fx = MockFxApi();
    analytics = MockAnalyticsApi();
    reconciliation = MockReconciliationApi();
    accounts = MockAccountsApi();
    labels = MockLabelsApi();
    dashboard = MockDashboardApi();
    prefs = MockPreferencesApi();
    stubLabels(labels);
    when(() => limitsApi.get()).thenAnswer((_) async => limits());
    // The opened screens get empty answers.
    when(() => receipts.list(status: any(named: 'status')))
        .thenAnswer((_) async => receiptPage(<ReceiptDto>[]));
    when(
      () => imports.list(
        accountId: any(named: 'accountId'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer(
      (_) async => const CursorPage<ImportBatchDto>(<ImportBatchDto>[], null),
    );
    when(() => reports.list()).thenAnswer((_) async => <ReportDto>[]);
    when(
      () => fx.rates(
        base: any(named: 'base'),
        quote: any(named: 'quote'),
      ),
    ).thenAnswer((_) async => <RateDto>[]);
    when(
      () => analytics.cashFlow(
        any(),
        currency: any(named: 'currency'),
        granularity: any(named: 'granularity'),
      ),
    ).thenAnswer((_) async => cashFlowReport(empty: true));
    when(() => reconciliation.balances(any(), cursor: any(named: 'cursor')))
        .thenAnswer(
          (_) async =>
              const CursorPage<ReconBalanceDto>(<ReconBalanceDto>[], null),
        );
    when(
      () => reconciliation.candidates(
        any(),
        kind: any(named: 'kind'),
        batchId: any(named: 'batchId'),
      ),
    ).thenAnswer((_) async => <ReconCandidate>[]);
    when(() => reconciliation.matches(any(), cursor: any(named: 'cursor')))
        .thenAnswer(
          (_) async => const CursorPage<ReconMatchDto>(<ReconMatchDto>[], null),
        );
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    when(() => accounts.list())
        .thenAnswer((_) async => <AccountDto>[account()]);
    when(() => accounts.totals()).thenAnswer((_) async => <BalanceTotals>[]);
    when(() => prefs.preferences()).thenAnswer((_) async => preferences());
    when(() => dashboard.summary(any())).thenAnswer((_) async => summary());
    when(() => dashboard.widgets()).thenAnswer((_) async => widgetLayout());
  });

  List<Override> overrides() => <Override>[
    limitsApiProvider.overrideWithValue(limitsApi),
    receiptsApiProvider.overrideWithValue(receipts),
    importsApiProvider.overrideWithValue(imports),
    reportsApiProvider.overrideWithValue(reports),
    fxApiProvider.overrideWithValue(fx),
    analyticsApiProvider.overrideWithValue(analytics),
    reconciliationApiProvider.overrideWithValue(reconciliation),
    accountsApiProvider.overrideWithValue(accounts),
    labelsApiProvider.overrideWithValue(labels),
    dashboardApiProvider.overrideWithValue(dashboard),
    preferencesApiProvider.overrideWithValue(prefs),
  ];

  Future<GoRouter> pump(
    WidgetTester tester,
    String location, {
    Locale locale = const Locale('en'),
  }) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(),
      locale: locale,
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  testWidgets('profile lists the round-3 screens and opens each one', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pump(tester, '/profile');
    await tester.scrollUntilVisible(
      find.text('Records and insights'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    for (final (String label, String path) in <(String, String)>[
      ('Receipts', '/receipts'),
      ('Statement imports', '/imports'),
      ('Analytics', '/analytics'),
      ('Reports', '/reports'),
      ('Exchange rates', '/exchange-rates'),
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(locationOf(router), path, reason: label);
      router.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('profile shows file storage and the fair-use limits', (
    WidgetTester tester,
  ) async {
    await pump(tester, '/profile');
    await tester.scrollUntilVisible(
      find.text('File storage'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1.5 MB of 2048 MB used'), findsOneWidget);
    await tester.ensureVisible(find.text('File storage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('File storage'));
    await tester.pumpAndSettle();
    // The row opens the limits screen (rounds 4–5).
    expect(find.text('Fair-use limits'), findsOneWidget);
    expect(find.text('Open bills'), findsOneWidget);
    expect(find.text('200'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Rows per statement import'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('20,000'), findsOneWidget);
  });

  testWidgets('the storage row is left out when the limits cannot load', (
    WidgetTester tester,
  ) async {
    when(() => limitsApi.get())
        .thenThrow(const ApiException(kind: ApiErrorKind.network));
    await pump(tester, '/profile');
    await tester.scrollUntilVisible(
      find.text('Exchange rates'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('File storage'), findsNothing);
  });

  testWidgets('home has a review row that opens receipts, imports, '
      'analytics and reports', (WidgetTester tester) async {
    final GoRouter router = await pump(tester, '/home');
    expect(find.text('Review your money'), findsOneWidget);
    for (final (String label, String path) in <(String, String)>[
      ('Receipts', '/receipts'),
      ('Import a statement', '/imports/new'),
      ('Analytics', '/analytics'),
      ('Reports', '/reports'),
    ]) {
      final Finder chip = find.widgetWithText(ActionChip, label);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(locationOf(router), path, reason: label);
      router.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('an account offers reconciling and importing a statement', (
    WidgetTester tester,
  ) async {
    final AccountDto a = account();
    when(() => accounts.get(a.id)).thenAnswer((_) async => a);
    when(() => accounts.balance(a.id, from: any(named: 'from'))).thenAnswer(
      (_) async => BalanceReport.fromJson(<String, Object?>{
        'account_id': a.id,
        'as_of': '2026-11-04',
        'balance': moneyJson('25000.50'),
        'balance_source': 'calculated',
        'verified': false,
        'history': <Object?>[],
      }),
    );
    when(() => accounts.transactions(a.id, limit: any(named: 'limit')))
        .thenAnswer(
          (_) async =>
              const CursorPage<TransactionDto>(<TransactionDto>[], null),
        );
    final GoRouter router = await pump(tester, '/accounts');
    unawaited(router.push<Object?>('/accounts/${a.id}'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Reconcile'));
    await tester.tap(find.text('Reconcile'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/accounts/${a.id}/reconcile');
    router.pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Import a statement'));
    await tester.tap(find.text('Import a statement'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/imports/new?account_id=${a.id}');
  });

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('profile with the new section fits at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, '/profile', locale: locale);
      for (int i = 0; i < 12; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
