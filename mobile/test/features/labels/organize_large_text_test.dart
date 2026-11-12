import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/organize_fakes.dart';
import '../../helpers/router_app.dart';

/// The organize screens at 200 % text in English and Hindi must lay out
/// without overflow (overflow is reported as a test failure).
void main() {
  late MockLabelsApi labels;
  late MockAccountsApi accounts;
  late MockPreferencesApi prefs;

  setUpAll(registerOrganizeFallbacks);

  setUp(() {
    labels = MockLabelsApi();
    accounts = MockAccountsApi();
    prefs = MockPreferencesApi();
    stubLabels(
      labels,
      categories: <CategoryDto>[
        managedCategory(name: 'A rather long category name for food'),
        managedCategory(
          id: 'cat-sub',
          name: 'Subcategory with a long name',
          parentId: 'cat-food',
          status: 'archived',
          transactions: 1234,
          includeInBudgets: false,
        ),
      ],
      tags: <TagDto>[managedTag(name: 'a fairly long tag name', usage: 120)],
    );
    when(() => labels.listRules()).thenAnswer(
      (_) async => <RuleDto>[
        categoryRule(
          name: 'Rule with a long descriptive name',
          pattern: 'some long pattern text',
          enabled: false,
        ),
      ],
    );
    when(
      () => labels.merchantsPage(
        query: any(named: 'query'),
        status: any(named: 'status'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer(
      (_) async => merchantsPage(<MerchantDto>[
        merchantDto(
          name: 'A merchant with a very long display name',
          aliases: const <String>['ALIAS ONE', 'ALIAS TWO', 'ALIAS THREE'],
          status: 'archived',
        ),
      ], next: 'c2'),
    );
    when(() => labels.getMerchant('mer-swiggy')).thenAnswer(
      (_) async => merchantDetail(
        name: 'A merchant with a very long display name',
        notes: 'Some notes that go on for a while to test wrapping.',
        spending: const <(String, String, int)>[
          ('2026-10', '1234567.89', 12),
          ('2026-11', '300.00', 1),
        ],
      ),
    );
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    when(() => prefs.preferences()).thenAnswer((_) async => preferences());
  });

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('organize screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final ({Widget app, GoRouter router}) r = routedApp(
        '/profile',
        overrides: [
          labelsApiProvider.overrideWithValue(labels),
          accountsApiProvider.overrideWithValue(accounts),
          preferencesApiProvider.overrideWithValue(prefs),
        ],
        locale: locale,
      );
      await tester.pumpWidget(r.app);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final String location in <String>[
        '/categories',
        '/categories/new',
        '/categories/cat-food/edit',
        '/category-rules',
        '/category-rules/new',
        '/category-rules/rule-1/edit',
        '/tags',
        '/merchants',
        '/merchants/mer-swiggy',
        '/merchants/mer-swiggy/edit',
      ]) {
        unawaited(r.router.push<Object?>(location));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: location);
        for (int i = 0; i < 4; i++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -600),
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: location);
        r.router.pop();
        await tester.pumpAndSettle();
      }
    });
  }
}
