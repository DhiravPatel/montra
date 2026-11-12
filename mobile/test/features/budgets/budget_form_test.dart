import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/budgets/data/budgets_api.dart';
import 'package:montra_mobile/features/budgets/presentation/allocation_editor.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/people/data/people_api.dart';

import '../../helpers/budgets_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/people_fakes.dart';
import '../../helpers/router_app.dart';

GroupDto tripGroup() => GroupDto.fromJson(<String, Object?>{
  'id': 'grp-trip',
  'name': 'Goa trip',
  'group_type': 'trip',
  'base_currency': 'USD',
  'default_split_method': 'equal',
  'allow_member_invites': true,
  'require_join_approval': false,
  'simplify_debts': true,
  'member_count': 2,
  'my_net': <String, Object?>{
    'amount_minor': 0,
    'amount': '0.00',
    'currency': 'USD',
  },
  'my_role': 'owner',
  'status': 'active',
  'timezone': 'Asia/Kolkata',
  'created_at': '2026-10-01T08:00:00Z',
  'version': 1,
});

MerchantDto merchant() => MerchantDto.fromJson(<String, Object?>{
  'id': 'mer-1',
  'name': 'Big Bazaar',
  'status': 'active',
  'transaction_count': 4,
  'aliases': <String>[],
  'version': 1,
});

void main() {
  late MockBudgetsApi api;
  late MockLabelsApi labels;
  late MockAccountsApi accounts;
  late MockPeopleApi people;
  late List<BudgetInput> created;

  setUpAll(registerBudgetFallbacks);

  setUp(() {
    api = MockBudgetsApi();
    labels = MockLabelsApi();
    accounts = MockAccountsApi();
    people = MockPeopleApi();
    created = <BudgetInput>[];
    stubLabels(labels, categories: <CategoryDto>[category()]);
    when(() => labels.searchMerchants(any(), limit: any(named: 'limit')))
        .thenAnswer((_) async => <MerchantDto>[merchant()]);
    stubPeople(people, groups: <GroupDto>[groupDto(), tripGroup()]);
    stubBudgetBasics(api);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    when(() => api.create(any())).thenAnswer((Invocation i) async {
      created.add(i.positionalArguments.first as BudgetInput);
      return budget(id: 'bud-new', name: 'Food');
    });
    for (final String id in <String>['bud-new', 'bud-1']) {
      when(() => api.progress(id, date: any(named: 'date')))
          .thenAnswer((_) async => <ProgressDto>[progress()]);
      stubBudgetTransactions(api, id, <TransactionDto>[]);
    }
    when(() => api.get('bud-new'))
        .thenAnswer((_) async => budget(id: 'bud-new', name: 'Food'));
  });

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: <Override>[
        budgetsApiProvider.overrideWithValue(api),
        labelsApiProvider.overrideWithValue(labels),
        accountsApiProvider.overrideWithValue(accounts),
        peopleApiProvider.overrideWithValue(people),
      ],
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    // A focused field would scroll itself back into view.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> chooseType(WidgetTester tester, String label) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Total spending'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Total spending'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('a category budget needs a category limit and sends the '
      'whole budget', (WidgetTester tester) async {
    final GoRouter router = await pump(tester, '/budgets/new');

    expect(find.text('New budget'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Budget name'),
      'Food',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Limit'),
      '10000',
    );
    await chooseType(tester, 'By category');
    expect(find.text('Limits for the categories you choose.'), findsWidgets);

    await tapVisible(tester, find.text('Create budget'));
    expect(find.text('Add at least one limit.'), findsOneWidget);
    verifyNever(() => api.create(any()));

    await tapVisible(tester, find.text('Add a limit'));
    expect(find.text('Applies to'), findsNothing);
    await tester.tap(find.widgetWithText(SelectorField, 'A category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Limit').last,
      '6000',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('₹6,000.00'), findsOneWidget);
    expect(find.byTooltip('Remove Groceries'), findsOneWidget);

    await tapVisible(tester, find.text('Create budget'));
    final BudgetInput input = created.single;
    expect(input.name, 'Food');
    expect(input.budgetType, BudgetInputBudgetType.category);
    expect(input.period, BudgetInputPeriod.monthly);
    expect(input.currency, 'INR');
    expect(input.limit, '10000.00');
    expect(input.version, isNull);
    expect(input.groupId, isNull);
    expect(input.allocations!.single.categoryId, 'cat-groceries');
    expect(input.allocations!.single.limit, '6000.00');
    expect(input.alertThresholds, <int>[50, 75, 90, 100]);
    expect(input.alertForecast, isTrue);
    expect(input.refundsRestore, isTrue);
    expect(input.includePending, isFalse);
    expect(input.rolloverPolicy, BudgetInputRolloverPolicy.none);
    expect(input.visibility, BudgetInputVisibility.private);
    expect(input.merchantIds, isEmpty);
    expect(locationOf(router), '/budgets/bud-new');
    expect(find.text('Budget created.'), findsOneWidget);
  });

  testWidgets('a merchant budget needs merchants chosen from search', (
    WidgetTester tester,
  ) async {
    await pump(tester, '/budgets/new');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Budget name'),
      'Shopping',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Limit'), '5000');
    await chooseType(tester, 'By merchant');

    await tapVisible(tester, find.text('Create budget'));
    expect(find.text('Choose at least one merchant.'), findsOneWidget);

    await tapVisible(tester, find.text('Add merchant'));
    await tester.enterText(find.byType(TextField).last, 'big');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Big Bazaar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove Big Bazaar'), findsOneWidget);

    await tapVisible(tester, find.text('Create budget'));
    expect(created.single.budgetType, BudgetInputBudgetType.merchant);
    expect(created.single.merchantIds, <String>['mer-1']);
  });

  testWidgets('a group budget uses the group currency and member shares', (
    WidgetTester tester,
  ) async {
    when(() => people.group('grp-trip')).thenAnswer(
      (_) async => groupDetail(
        id: 'grp-trip',
        name: 'Goa trip',
        members: <Map<String, Object?>>[
          groupMemberJson(id: testUserId, name: 'Me', role: 'owner'),
          groupMemberJson(id: 'u-ravi', name: 'Ravi'),
        ],
      ),
    );
    await pump(tester, '/budgets/new');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Budget name'),
      'Trip',
    );
    await tester.tap(find.widgetWithText(SelectorField, 'Group (optional)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goa trip'));
    await tester.pumpAndSettle();

    expect(find.text('USD'), findsWidgets);
    expect(
      find.text("Group budgets use the group's currency."),
      findsOneWidget,
    );
    expect(
      find.text(
        "Group budgets count all of the group's expenses: as one total, or "
        'split between members as envelopes or zero-based.',
      ),
      findsOneWidget,
    );
    expect(find.text('What counts'), findsNothing);
    await tester.enterText(find.widgetWithText(TextFormField, 'Limit'), '500');

    await tapVisible(tester, find.text('Add a limit'));
    // Group budgets are split between members only.
    expect(find.text('Applies to'), findsNothing);
    expect(find.text("A group member's share"), findsWidgets);
    await tester.tap(
      find.widgetWithText(SelectorField, "A group member's share"),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ravi'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Limit').last,
      '200',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text("Ravi's share"), findsOneWidget);

    await tapVisible(tester, find.text('Everyone in the group'));
    await tester.tap(find.text('Everyone in the group').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Create budget'));

    final BudgetInput input = created.single;
    expect(input.groupId, 'grp-trip');
    expect(input.currency, 'USD');
    expect(input.budgetType, BudgetInputBudgetType.total);
    expect(input.visibility, BudgetInputVisibility.members);
    expect(input.allocations!.single.memberUserId, 'u-ravi');
    expect(input.allocations!.single.limit, '200.00');
    expect(input.includedAccountIds, isEmpty);
  });

  testWidgets('server errors show next to the field or in words', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    when(() => api.create(any())).thenAnswer((_) async {
      calls++;
      throw calls == 1
          ? serverError(
              ErrorObjectCode.validationError,
              details: const <Detail>[
                Detail(field: 'body.name', message: 'Name is taken.'),
              ],
            )
          : serverError(
              ErrorObjectCode.domainRuleViolation,
              details: const <Detail>[
                Detail(
                  code: 'zero_based_unallocated',
                  message: 'Zero-based budgets must allocate exactly.',
                ),
              ],
            );
    });
    await pump(tester, '/budgets/new');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Budget name'),
      'Food',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Limit'), '100');

    await tapVisible(tester, find.text('Create budget'));
    await tester.scrollUntilVisible(
      find.text('Name is taken.'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Name is taken.'), findsOneWidget);

    await tapVisible(tester, find.text('Create budget'));
    await tester.scrollUntilVisible(
      find.textContaining("The envelopes don't add up"),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining("The envelopes don't add up"), findsOneWidget);
  });

  testWidgets('an edit sends only the changes with the version; a stale '
      'version reloads', (WidgetTester tester) async {
    Map<String, Object?> stored({String name = 'Monthly spending'}) =>
        budgetJson(
          name: name,
          type: 'category',
          notes: 'Keep it calm',
          rollover: 'carry_unused',
          rolloverCap: '500.00',
          thresholds: <int>[50, 90],
          allocations: <Map<String, Object?>>[
            allocationJson(categoryId: 'cat-groceries'),
          ],
        );
    final BudgetDto original = BudgetDto.fromJson(stored());
    final BudgetDto newer = BudgetDto.fromJson(<String, Object?>{
      ...stored(name: 'Renamed elsewhere'),
      'version': 4,
    });
    int loads = 0;
    when(() => api.get('bud-1')).thenAnswer((_) async {
      loads++;
      return loads <= 1 ? original : newer;
    });
    final List<BudgetPatch> updates = <BudgetPatch>[];
    when(() => api.update('bud-1', any())).thenAnswer((Invocation i) async {
      updates.add(i.positionalArguments[1] as BudgetPatch);
      if (updates.length == 1) {
        throw serverError(ErrorObjectCode.versionConflict, status: 409);
      }
      return newer;
    });
    final GoRouter router = await pump(tester, '/budgets/bud-1');
    unawaited(router.push<Object?>('/budgets/bud-1/edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit budget'), findsOneWidget);
    expect(
      find.textContaining('Changes apply from the current period'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Budget name'),
      'Food at home',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'Notes (optional)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Notes (optional)'),
      '',
    );
    await tapVisible(tester, find.text('Turn off threshold alerts'));
    expect(find.text('No threshold alerts'), findsOneWidget);
    await tapVisible(tester, find.text('Save'));

    expect(updates.first.toJson(), <String, Object?>{
      'alert_thresholds': <int>[],
      'name': 'Food at home',
      'notes': '',
      'version': 3,
    });

    await tester.scrollUntilVisible(
      find.textContaining('changed somewhere else'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('changed somewhere else'), findsOneWidget);
    expect(find.text('Renamed elsewhere'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Budget name'),
      'Food budget',
    );
    await tapVisible(tester, find.text('Save'));
    expect(updates.last.toJson(), <String, Object?>{
      'name': 'Food budget',
      'version': 4,
    });
    expect(locationOf(router), '/budgets/bud-1');
    expect(find.text('Budget saved.'), findsOneWidget);
  });

  testWidgets('saving an unchanged budget sends nothing', (
    WidgetTester tester,
  ) async {
    when(() => api.get('bud-1')).thenAnswer((_) async => budget());
    final GoRouter router = await pump(tester, '/budgets/bud-1');
    unawaited(router.push<Object?>('/budgets/bud-1/edit'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Save'));
    verifyNever(() => api.update(any(), any()));
    expect(locationOf(router), '/budgets/bud-1');
    expect(
      find.text('Nothing changed, so there was nothing to save.'),
      findsOneWidget,
    );
  });

  testWidgets('threshold alerts can be turned off when creating', (
    WidgetTester tester,
  ) async {
    await pump(tester, '/budgets/new');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Budget name'),
      'Quiet',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Limit'), '900');
    await tapVisible(tester, find.text('1%'));
    await tapVisible(tester, find.text('Turn off threshold alerts'));
    expect(find.text('No threshold alerts'), findsOneWidget);
    await tapVisible(tester, find.text('Create budget'));
    expect(created.single.alertThresholds, isEmpty);
    expect(created.single.toJson()['alert_thresholds'], <int>[]);
  });

  testWidgets('limits follow the budget type: merchants only in merchant '
      'budgets, accounts only in account budgets', (WidgetTester tester) async {
    await pump(tester, '/budgets/new');
    const List<String> all = <String>[
      'A category',
      'A merchant',
      'An account',
      "A group member's share",
      'Just a name',
    ];
    Future<List<String>> offered() async {
      await tapVisible(tester, find.text('Add a limit'));
      final Finder menu = find.byType(
        DropdownButtonFormField<AllocationTarget>,
      );
      if (menu.evaluate().isEmpty) {
        Navigator.of(tester.element(find.text('Add a limit').last)).pop();
        await tester.pumpAndSettle();
        return <String>[];
      }
      await tester.tap(menu);
      await tester.pumpAndSettle();
      final List<String> shown = <String>[
        for (final String t in all)
          if (find
              .descendant(
                of: find.byType(DropdownMenuItem<AllocationTarget>),
                matching: find.text(t),
              )
              .evaluate()
              .isNotEmpty)
            t,
      ];
      // Close the menu, then the sheet.
      await tester.tap(find.text('A category').last);
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Applies to'))).pop();
      await tester.pumpAndSettle();
      return shown;
    }

    expect(await offered(), <String>['A category', 'Just a name']);
    await chooseType(tester, 'By merchant');
    expect(await offered(), <String>[
      'A category',
      'A merchant',
      'Just a name',
    ]);
    await tester.ensureVisible(find.text('By merchant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('By merchant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('By account').last);
    await tester.pumpAndSettle();
    expect(await offered(), <String>[
      'A category',
      'An account',
      'Just a name',
    ]);
  });
}
