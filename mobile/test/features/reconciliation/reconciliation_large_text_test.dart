import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/reconciliation/data/reconciliation_api.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/insights_fakes.dart';
import '../../helpers/router_app.dart';

/// Reconciliation screens at 200 % text in English and Hindi must lay out
/// without overflow, on every tab.
void main() {
  late MockReconciliationApi api;
  late MockAccountsApi accounts;

  setUpAll(() {
    registerInsightsFallbacks();
    registerFinanceFallbacks();
  });

  setUp(() {
    api = MockReconciliationApi();
    accounts = MockAccountsApi();
    when(() => accounts.get('acc-1')).thenAnswer(
      (_) async =>
          account(name: 'A very long savings account name at the bank'),
    );
    when(() => accounts.get('card')).thenAnswer(
      (_) async =>
          account(id: 'card', name: 'Rewards card', type: 'credit_card'),
    );
    when(() => api.balances(any(), cursor: any(named: 'cursor'))).thenAnswer(
      (_) async => CursorPage<ReconBalanceDto>(<ReconBalanceDto>[
        reconBalance(),
        reconBalance(
          id: 'rb-0',
          balanced: true,
          reconciled: 6,
          unreconciled: 0,
        ),
      ], null),
    );
    when(
      () => api.candidates(
        any(),
        kind: any(named: 'kind'),
        batchId: any(named: 'batchId'),
      ),
    ).thenAnswer(
      (_) async => <ReconCandidate>[
        reconCandidate(),
        reconCandidate(
          kind: 'statement_to_ledger',
          left: reconItemJson(
            side: 'statement',
            transactionId: null,
            importRowId: 'row-1',
            status: 'duplicate',
            description: 'UBER INDIA SYSTEMS PRIVATE LIMITED BANGALORE 7781',
          ),
        ),
      ],
    );
    when(() => api.matches(any(), cursor: any(named: 'cursor'))).thenAnswer(
      (_) async => CursorPage<ReconMatchDto>(<ReconMatchDto>[
        reconMatch(),
        reconMatch(status: 'unmatched'),
      ], null),
    );
  });

  List<Override> overrides() => <Override>[
    reconciliationApiProvider.overrideWithValue(api),
    accountsApiProvider.overrideWithValue(accounts),
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
    testWidgets('reconciliation screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      await walk(
        tester,
        locale,
        '/accounts/acc-1/reconcile',
        <String>[
          '/accounts/acc-1/reconcile',
          '/accounts/card/reconcile/new',
          '/accounts/acc-1/reconcile/new?import_batch_id=b-1',
        ],
        extra: (WidgetTester tester, String location) async {
          if (!location.endsWith('/reconcile')) {
            return;
          }
          for (final int tab in <int>[1, 2]) {
            await tester.tap(find.byType(Tab).at(tab));
            await tester.pumpAndSettle();
            for (int i = 0; i < 8; i++) {
              await tester.drag(
                find.byType(Scrollable).last,
                const Offset(0, -600),
              );
              await tester.pumpAndSettle();
            }
          }
        },
      );
    });
  }
}
