import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/dashboard/data/dashboard_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/payment_methods/data/payment_methods_api.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';

import '../helpers/finance_fakes.dart';
import '../helpers/router_app.dart';

/// Phone-sized screens at 200 % text in English and Hindi must lay out
/// without overflow (overflow is reported as a test failure).
void main() {
  late MockDashboardApi dashboard;
  late MockPreferencesApi prefs;
  late MockLabelsApi labels;
  late MockTransactionsApi transactions;
  late MockAccountsApi accounts;
  late MockPaymentMethodsApi methods;

  setUpAll(registerFinanceFallbacks);

  setUp(() {
    dashboard = MockDashboardApi();
    prefs = MockPreferencesApi();
    labels = MockLabelsApi();
    transactions = MockTransactionsApi();
    accounts = MockAccountsApi();
    methods = MockPaymentMethodsApi();
    stubLabels(labels, categories: <CategoryDto>[category()]);
    when(() => prefs.preferences()).thenAnswer((_) async => preferences());
    when(() => dashboard.summary(any()))
        .thenAnswer((_) async => summary(withUsd: true));
    when(() => dashboard.widgets()).thenAnswer((_) async => widgetLayout());
    when(
      () => transactions.list(
        any(),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => page(<TransactionDto>[
        transaction(refunded: '250.75', status: 'pending'),
        transaction(
          id: 'tx-2',
          type: 'income',
          direction: 'inflow',
          amount: '1234567.89',
          merchant: null,
          description: 'A rather long salary description for the month',
        ),
      ], next: 'c2'),
    );
    final AccountDto card = account(
      id: 'card',
      name: 'Very long credit card account name',
      type: 'credit_card',
      balance: '-123456.78',
      creditLimit: '500000.00',
      availableCredit: '376543.22',
    );
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account(), card]);
    when(() => accounts.totals()).thenAnswer((_) async => <BalanceTotals>[]);
    when(() => accounts.get('card')).thenAnswer((_) async => card);
    when(() => accounts.balance('card', from: any(named: 'from'))).thenAnswer(
      (_) async => BalanceReport.fromJson(<String, Object?>{
        'account_id': 'card',
        'as_of': '2026-11-04',
        'balance': moneyJson('-123456.78'),
        'balance_source': 'calculated',
        'verified': false,
        'history': <Object?>[
          <String, Object?>{
            'date': '2026-11-04',
            'balance': moneyJson('-123456.78'),
          },
        ],
      }),
    );
    when(() => accounts.transactions('card', limit: 10)).thenAnswer(
      (_) async =>
          CursorPage<TransactionDto>(<TransactionDto>[transaction()], null),
    );
    when(() => methods.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <PaymentMethodDto>[paymentMethod()]);
  });

  List<Override> overrides() => <Override>[
    dashboardApiProvider.overrideWithValue(dashboard),
    preferencesApiProvider.overrideWithValue(prefs),
    labelsApiProvider.overrideWithValue(labels),
    transactionsApiProvider.overrideWithValue(transactions),
    accountsApiProvider.overrideWithValue(accounts),
    paymentMethodsApiProvider.overrideWithValue(methods),
  ];

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('main screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final ({Widget app, GoRouter router}) r = routedApp(
        '/home',
        overrides: overrides(),
        locale: locale,
      );
      await tester.pumpWidget(r.app);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Scroll through the whole dashboard.
      for (int i = 0; i < 12; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);

      r.router.go('/transactions');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final String location in <String>[
        '/accounts',
        '/accounts/card',
        '/transactions/new?type=expense',
        '/transactions/transfer',
        '/payment-methods',
        '/home/widgets',
        '/onboarding',
      ]) {
        unawaited(r.router.push<Object?>(location));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: location);
        r.router.pop();
        await tester.pumpAndSettle();
      }
    });
  }
}
