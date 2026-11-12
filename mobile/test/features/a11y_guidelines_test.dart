import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/files/file_source.dart';
import 'package:montra_mobile/core/formatting/currency_catalog.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/budgets/data/budgets_api.dart';
import 'package:montra_mobile/features/dashboard/data/dashboard_api.dart';
import 'package:montra_mobile/features/groups/data/groups_api.dart';
import 'package:montra_mobile/features/insights/data/insights_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/notifications/application/unread_count.dart';
import 'package:montra_mobile/features/payment_methods/data/payment_methods_api.dart';
import 'package:montra_mobile/features/settings/data/limits_api.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';
import 'package:montra_mobile/features/social/data/social_api.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';

import '../helpers/budgets_fakes.dart';
import '../helpers/dashboard_fakes.dart';
import '../helpers/files_fakes.dart';
import '../helpers/finance_fakes.dart';
import '../helpers/insights_feature_fakes.dart';
import '../helpers/router_app.dart';
import '../helpers/social_fakes.dart';
import '../helpers/support_fakes.dart';

/// Automated accessibility checks (Flutter's `meetsGuideline`) on the main
/// screens: touch targets of at least 48×48 (Android) and 44×44 (iOS),
/// every tappable element labelled for screen readers, and text contrast
/// (WCAG AA) in the light theme. Assistive-technology review on devices is
/// still needed (README "Limitations").
void main() {
  late MockDashboardApi dashboard;
  late MockPreferencesApi prefs;
  late MockLabelsApi labels;
  late MockTransactionsApi transactions;
  late MockAccountsApi accounts;
  late MockPaymentMethodsApi methods;
  late MockBudgetsApi budgets;
  late MockInsightsApi insights;
  late MockSocialApi social;
  late MockGroupsApi groups;
  late MockLimitsApi limits;

  setUpAll(() {
    registerFinanceFallbacks();
    registerSocialFallbacks();
    registerFileFallbacks();
  });

  setUp(() {
    dashboard = MockDashboardApi();
    prefs = MockPreferencesApi();
    labels = MockLabelsApi();
    transactions = MockTransactionsApi();
    accounts = MockAccountsApi();
    methods = MockPaymentMethodsApi();
    budgets = MockBudgetsApi();
    insights = MockInsightsApi();
    social = MockSocialApi();
    groups = MockGroupsApi();
    limits = MockLimitsApi();
    when(() => dashboard.summary(any())).thenAnswer((_) async => summary());
    when(() => dashboard.widgets()).thenAnswer((_) async => widgetLayout());
    when(() => dashboard.planning())
        .thenAnswer((_) async => dashboardPlanning());
    when(() => prefs.preferences()).thenAnswer((_) async => preferences());
    stubLabels(labels, categories: <CategoryDto>[category()]);
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
    when(() => budgets.alerts(status: any(named: 'status')))
        .thenAnswer((_) async => <AlertDto>[budgetAlert()]);
    when(
      () => insights.list(
        all: any(named: 'all'),
        kind: any(named: 'kind'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => insightPage(<InsightDto>[insight()]));
    stubSocialReads(social);
    when(() => social.me()).thenAnswer((_) async => meDto());
    stubGroupReads(groups);
    when(() => limits.get()).thenAnswer((_) async => limitsDto());
  });

  List<Override> overrides() => <Override>[
    dashboardApiProvider.overrideWithValue(dashboard),
    preferencesApiProvider.overrideWithValue(prefs),
    labelsApiProvider.overrideWithValue(labels),
    transactionsApiProvider.overrideWithValue(transactions),
    accountsApiProvider.overrideWithValue(accounts),
    paymentMethodsApiProvider.overrideWithValue(methods),
    budgetsApiProvider.overrideWithValue(budgets),
    insightsApiProvider.overrideWithValue(insights),
    socialApiProvider.overrideWithValue(social),
    groupsApiProvider.overrideWithValue(groups),
    limitsApiProvider.overrideWithValue(limits),
    fileSourceProvider.overrideWithValue(FakeFileSource()),
    unreadNotificationCountProvider.overrideWith((Ref ref) async => 2),
    currencyCatalogProvider.overrideWith(
      (_) async => CurrencyCatalog(const <CurrencyDto>[
        CurrencyDto(
          code: 'INR',
          name: 'Indian Rupee',
          exponent: 2,
          selectable: true,
        ),
      ]),
    ),
  ];

  /// Main screens, opened directly (the auth redirect is not installed).
  const List<String> screens = <String>[
    '/welcome',
    '/sign-in',
    '/sign-up',
    '/home',
    '/transactions',
    '/insights',
    '/together',
    '/profile',
    '/profile/edit',
    '/profile/preferences',
    '/receipts/new',
  ];

  for (final String location in screens) {
    testWidgets('$location meets the tap-target, label and contrast '
        'guidelines', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      // A phone-wide but very tall window, so every part of the screen is
      // laid out at once: elements half-hidden by scrolling would fail the
      // size checks only because they are clipped.
      tester.view
        ..physicalSize = const Size(1080, 30000)
        ..devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final ({Widget app, GoRouter router}) r = routedApp(
        location,
        overrides: overrides(),
      );
      await tester.pumpWidget(r.app);
      await tester.pumpAndSettle();
      expect(locationOf(r.router), location);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }
}
