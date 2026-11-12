import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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

void main() {
  late MockLabelsApi labels;
  late MockAccountsApi accounts;
  late MockPreferencesApi prefs;

  final List<CategoryDto> active = <CategoryDto>[
    managedCategory(),
    managedCategory(
      id: 'cat-delivery',
      name: 'Delivery',
      parentId: 'cat-food',
      transactions: 0,
      sortOrder: 1,
    ),
    managedCategory(
      id: 'cat-salary',
      name: 'Salary',
      kind: 'income',
      color: null,
      transactions: 2,
      sortOrder: 20,
    ),
  ];

  setUpAll(registerOrganizeFallbacks);

  setUp(() {
    labels = MockLabelsApi();
    accounts = MockAccountsApi();
    prefs = MockPreferencesApi();
    stubLabels(labels, categories: active);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    when(() => prefs.preferences()).thenAnswer((_) async => preferences());
  });

  List<Override> overrides() => <Override>[
    labelsApiProvider.overrideWithValue(labels),
    accountsApiProvider.overrideWithValue(accounts),
    preferencesApiProvider.overrideWithValue(prefs),
  ];

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  Future<void> unfocus(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Finder inSheet(String text) =>
      find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

  testWidgets('profile links to the organize screens', (
    WidgetTester tester,
  ) async {
    when(() => labels.listRules()).thenAnswer((_) async => <RuleDto>[]);
    when(
      () => labels.merchantsPage(
        query: any(named: 'query'),
        status: any(named: 'status'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async => merchantsPage(<MerchantDto>[]));
    final GoRouter router = await pump(tester, '/profile');
    await tester.scrollUntilVisible(
      find.text('Merchants'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Organize'), findsOneWidget);
    for (final (String label, String path) in <(String, String)>[
      ('Categories', '/categories'),
      ('Category rules', '/category-rules'),
      ('Tags', '/tags'),
      ('Merchants', '/merchants'),
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(locationOf(router), path);
      router.pop();
      await tester.pumpAndSettle();
    }
  });

  group('categories', () {
    testWidgets('lists the tree with counts and archives a category', (
      WidgetTester tester,
    ) async {
      when(() => labels.archiveCategory('cat-salary')).thenAnswer(
        (_) async => managedCategory(
          id: 'cat-salary',
          name: 'Salary',
          status: 'archived',
        ),
      );
      await pump(tester, '/categories');

      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Spending · 4 transactions'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Delivery, subcategory of Food')),
        findsOneWidget,
      );
      expect(find.text('Income · 2 transactions'), findsOneWidget);

      await tester.tap(find.byTooltip('More actions for Salary'));
      await tester.pumpAndSettle();
      // Used categories can't be deleted; merging or archiving is offered.
      expect(inSheet('Delete'), findsNothing);
      expect(inSheet('Merge into another category'), findsOneWidget);
      await tester.tap(inSheet('Archive'));
      await tester.pumpAndSettle();

      verify(() => labels.archiveCategory('cat-salary')).called(1);
      expect(
        find.text('“Salary” archived. Past transactions keep it.'),
        findsOneWidget,
      );
    });

    testWidgets('deletes an unused category after confirming', (
      WidgetTester tester,
    ) async {
      int attempts = 0;
      when(() => labels.deleteCategory('cat-delivery')).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) {
          throw serverError(
            ErrorObjectCode.conflict,
            status: 409,
            details: const <Detail>[
              Detail(message: 'in use', code: 'category_in_use'),
            ],
          );
        }
      });
      await pump(tester, '/categories');

      Future<void> delete() async {
        await tester.tap(find.byTooltip('More actions for Delivery'));
        await tester.pumpAndSettle();
        await tester.tap(inSheet('Delete'));
        await tester.pumpAndSettle();
        expect(find.text('Delete “Delivery”?'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();
      }

      await delete();
      expect(
        find.textContaining('Some records still use this category'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await delete();
      expect(find.text('“Delivery” deleted.'), findsOneWidget);
      verify(() => labels.deleteCategory('cat-delivery')).called(2);
    });

    testWidgets('merges into another category after a preview', (
      WidgetTester tester,
    ) async {
      when(
        () => labels.mergeCategories(
          targetId: 'cat-salary',
          sourceIds: <String>['cat-delivery'],
          preview: true,
        ),
      ).thenAnswer(
        (_) async => MergeResult(
          affected: mergeAffected(transactions: 12, rules: 1, budgetFilters: 2),
          preview: true,
        ),
      );
      when(
        () => labels.mergeCategories(
          targetId: 'cat-salary',
          sourceIds: <String>['cat-delivery'],
          preview: false,
        ),
      ).thenAnswer(
        (_) async => const MergeResult(
          affected: MergeAffected(
            bills: 0,
            budgetAllocations: 0,
            budgetFilters: 0,
            merchants: 0,
            recurringRules: 0,
            rules: 0,
            subcategories: 0,
            subscriptions: 0,
            transactions: 12,
          ),
          preview: false,
        ),
      );
      await pump(tester, '/categories');

      await tester.tap(find.byTooltip('More actions for Delivery'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Merge into another category'));
      await tester.pumpAndSettle();
      expect(find.text('Merge “Delivery” into…'), findsOneWidget);
      // The category itself is not offered as a target.
      expect(inSheet('Delivery'), findsNothing);
      await tester.tap(inSheet('Salary'));
      await tester.pumpAndSettle();

      expect(find.text('Merge “Delivery” into “Salary”?'), findsOneWidget);
      expect(find.textContaining('12 transactions'), findsOneWidget);
      expect(find.textContaining('1 category rule'), findsOneWidget);
      expect(
        find.textContaining('2 budgets will follow the merge'),
        findsOneWidget,
      );
      expect(find.textContaining('bill'), findsNothing);
      verifyNever(
        () => labels.mergeCategories(
          targetId: any(named: 'targetId'),
          sourceIds: any(named: 'sourceIds'),
          preview: false,
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();

      verify(
        () => labels.mergeCategories(
          targetId: 'cat-salary',
          sourceIds: <String>['cat-delivery'],
          preview: false,
        ),
      ).called(1);
      expect(find.text('“Delivery” merged into “Salary”.'), findsOneWidget);
    });

    testWidgets('shows archived categories on request and restores them', (
      WidgetTester tester,
    ) async {
      when(() => labels.listCategories(includeArchived: true)).thenAnswer(
        (_) async => <CategoryDto>[
          ...active,
          managedCategory(id: 'cat-old', name: 'Old hobby', status: 'archived'),
        ],
      );
      when(() => labels.restoreCategory('cat-old')).thenAnswer(
        (_) async => managedCategory(id: 'cat-old', name: 'Old hobby'),
      );
      await pump(tester, '/categories');
      expect(find.text('Old hobby'), findsNothing);

      await tester.tap(find.text('Show archived and merged'));
      await tester.pumpAndSettle();
      expect(find.text('Old hobby'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);

      await tester.tap(find.byTooltip('More actions for Old hobby'));
      await tester.pumpAndSettle();
      expect(inSheet('Archive'), findsNothing);
      await tester.tap(inSheet('Restore'));
      await tester.pumpAndSettle();
      verify(() => labels.restoreCategory('cat-old')).called(1);
      expect(find.text('“Old hobby” restored.'), findsOneWidget);
    });

    testWidgets('shows error and empty states', (WidgetTester tester) async {
      int calls = 0;
      when(
        () => labels.listCategories(
          includeArchived: any(named: 'includeArchived'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return <CategoryDto>[];
      });
      await pump(tester, '/categories');
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No categories yet'), findsOneWidget);
    });

    testWidgets('creates a subcategory with an icon and a named color', (
      WidgetTester tester,
    ) async {
      CategoryInput? sent;
      when(() => labels.createCategory(any())).thenAnswer((Invocation i) async {
        sent = i.positionalArguments.first as CategoryInput;
        return managedCategory(id: 'cat-new', name: 'Snacks');
      });
      final GoRouter router = await pump(tester, '/categories');
      unawaited(router.push<Object?>('/categories/new?parent=cat-food'));
      await tester.pumpAndSettle();

      expect(find.text('New category'), findsWidgets);
      expect(find.text('Food'), findsWidgets);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Snacks',
      );
      await unfocus(tester);
      await tester.tap(find.byTooltip('Food'));
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Green'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Green'));
      await tester.pump();
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(sent?.name, 'Snacks');
      expect(sent?.kind, CategoryInputKind.expense);
      expect(sent?.parentId, 'cat-food');
      expect(sent?.icon, 'restaurant');
      expect(sent?.color, '#43A047');
      expect(sent?.includeInBudgets, isTrue);
      expect(find.text('Category “Snacks” added.'), findsOneWidget);
      expect(locationOf(router), '/categories');
    });

    testWidgets('edits send only the change; a stale version reloads', (
      WidgetTester tester,
    ) async {
      int loads = 0;
      when(() => labels.getCategory('cat-food')).thenAnswer((_) async {
        loads++;
        return loads == 1
            ? managedCategory()
            : managedCategory(name: 'Eating out', version: 2);
      });
      when(() => labels.listCategories(includeArchived: true))
          .thenAnswer((_) async => active);
      final List<CategoryPatch> sent = <CategoryPatch>[];
      when(() => labels.updateCategory('cat-food', any()))
          .thenAnswer((Invocation i) async {
            sent.add(i.positionalArguments[1] as CategoryPatch);
            if (sent.length == 1) {
              throw serverError(ErrorObjectCode.versionConflict, status: 409);
            }
            return managedCategory(name: 'Food & dining', version: 3);
          });
      final GoRouter router = await pump(tester, '/categories');
      unawaited(router.push<Object?>('/categories/cat-food/edit'));
      await tester.pumpAndSettle();

      final Finder name = find.widgetWithText(TextFormField, 'Name');
      await tester.enterText(name, 'Food & dining');
      await unfocus(tester);
      await tester.ensureVisible(find.text('Count in budgets'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Count in budgets'));
      await tester.pump();
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(sent.first.version, 1);
      expect(sent.first.name, 'Food & dining');
      expect(sent.first.includeInBudgets, isFalse);
      expect(sent.first.kind, isNull);
      expect(sent.first.parentId, isNull);
      expect(sent.first.clearParent, isNull);
      expect(sent.first.color, isNull);
      expect(sent.first.clearColor, isNull);
      expect(find.textContaining('changed somewhere else'), findsOneWidget);
      expect(find.text('Eating out'), findsOneWidget);

      await tester.enterText(name, 'Food & dining');

      await unfocus(tester);
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(sent.last.version, 2);
      expect(sent.last.name, 'Food & dining');
      expect(sent.last.includeInBudgets, isNull);
      expect(find.text('Category saved.'), findsOneWidget);
    });

    testWidgets('a color can be removed (clear_color)', (
      WidgetTester tester,
    ) async {
      when(() => labels.getCategory('cat-food'))
          .thenAnswer((_) async => managedCategory());
      final List<CategoryPatch> sent = <CategoryPatch>[];
      when(() => labels.updateCategory('cat-food', any()))
          .thenAnswer((Invocation i) async {
            sent.add(i.positionalArguments[1] as CategoryPatch);
            return managedCategory(color: null, version: 2);
          });
      final GoRouter router = await pump(tester, '/categories');
      unawaited(router.push<Object?>('/categories/cat-food/edit'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'No color'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'No color'));
      await tester.pump();
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(sent.single.toJson(), <String, Object?>{
        'clear_color': true,
        'version': 1,
      });
      expect(find.text('Category saved.'), findsOneWidget);
    });
  });

  group('category rules', () {
    testWidgets('lists rules in running order with plain summaries', (
      WidgetTester tester,
    ) async {
      when(() => labels.listRules()).thenAnswer(
        (_) async => <RuleDto>[
          categoryRule(priority: 200),
          categoryRule(
            id: 'rule-2',
            name: 'Cabs',
            pattern: 'uber',
            priority: 50,
            enabled: false,
          ),
        ],
      );
      await pump(tester, '/category-rules');

      final double cabs = tester.getTopLeft(find.text('Cabs')).dy;
      final double food = tester.getTopLeft(find.text('Food delivery')).dy;
      expect(cabs, lessThan(food));
      expect(find.text('Merchant contains “uber” → Food'), findsOneWidget);
      expect(find.text('Turned off'), findsOneWidget);
      expect(find.text('Order 50 · Added by me and imported'), findsOneWidget);
    });

    testWidgets('shows the empty state and retries errors', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(() => labels.listRules()).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return <RuleDto>[];
      });
      await pump(tester, '/category-rules');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No rules yet'), findsOneWidget);
      expect(find.text('New rule'), findsOneWidget);
    });

    testWidgets('a new rule is previewed, applied and saved', (
      WidgetTester tester,
    ) async {
      when(() => labels.listRules()).thenAnswer((_) async => <RuleDto>[]);
      final List<(RuleInput, bool)> previews = <(RuleInput, bool)>[];
      when(
        () => labels.previewRule(
          any(),
          onlyUncategorized: any(named: 'onlyUncategorized'),
        ),
      ).thenAnswer((Invocation i) async {
        previews.add((
          i.positionalArguments.first as RuleInput,
          i.namedArguments[#onlyUncategorized] as bool,
        ));
        return rulePreview(3, sample: <TransactionDto>[transaction()]);
      });
      when(
        () => labels.applyRule(
          any(),
          onlyUncategorized: any(named: 'onlyUncategorized'),
        ),
      ).thenAnswer((_) async => rulePreview(3));
      RuleInput? saved;
      when(() => labels.createRule(any())).thenAnswer((Invocation i) async {
        saved = i.positionalArguments.first as RuleInput;
        return categoryRule();
      });
      final GoRouter router = await pump(tester, '/category-rules');
      unawaited(router.push<Object?>('/category-rules/new'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Rule name'),
        'Food delivery',
      );

      await unfocus(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Text to match'),
        'swiggy',
      );
      await unfocus(tester);
      // Nothing is sent until a category is chosen.
      await tester.ensureVisible(find.text('Preview matches'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview matches'));
      await tester.pumpAndSettle();
      expect(previews, isEmpty);
      await tester.ensureVisible(find.text('Choose a category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a category'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Food'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Preview matches'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview matches'));
      await tester.pumpAndSettle();
      expect(previews.single.$1.pattern, 'swiggy');
      expect(previews.single.$1.setCategoryId, 'cat-food');
      expect(previews.single.$1.matchField, RuleInputMatchField.any);
      expect(previews.single.$2, isTrue);
      expect(find.text('Matches 3 transactions (showing 1).'), findsOneWidget);
      expect(find.text('Big Bazaar'), findsOneWidget);

      await tester.ensureVisible(find.text('Apply to these 3 transactions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply to these 3 transactions'));
      await tester.pumpAndSettle();
      expect(find.text('Change 3 transactions?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Change'));
      await tester.pumpAndSettle();
      verify(() => labels.applyRule(any(), onlyUncategorized: true)).called(1);
      expect(find.text('Updated 3 transactions.'), findsOneWidget);
      // Let the snack bar time out so it doesn't cover the button.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved?.name, 'Food delivery');
      expect(saved?.priority, 100);
      expect(saved?.enabled, isTrue);
      expect(saved?.currency, isNull);
      expect(locationOf(router), '/category-rules');
    });

    testWidgets('edits replace the whole rule; delete asks first', (
      WidgetTester tester,
    ) async {
      when(() => labels.listRules()).thenAnswer(
        (_) async => <RuleDto>[
          categoryRule(amountMin: '100.00', currency: 'USD', version: 4),
        ],
      );
      when(() => labels.getRule('rule-1')).thenAnswer(
        (_) async =>
            categoryRule(amountMin: '100.00', currency: 'USD', version: 4),
      );
      final List<RuleUpdate> updates = <RuleUpdate>[];
      when(() => labels.updateRule('rule-1', any()))
          .thenAnswer((Invocation i) async {
            updates.add(i.positionalArguments[1] as RuleUpdate);
            return categoryRule();
          });
      when(() => labels.deleteRule('rule-1')).thenAnswer((_) async {});
      final GoRouter router = await pump(tester, '/category-rules');
      unawaited(router.push<Object?>('/category-rules/rule-1/edit'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Text to match'),
        'swiggy instamart',
      );

      await unfocus(tester);
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(updates.single.pattern, 'swiggy instamart');
      expect(updates.single.name, 'Food delivery');
      expect(updates.single.amountMin, '100.00');
      // The bounds keep the rule's own currency, and the version is sent.
      expect(updates.single.currency, 'USD');
      expect(updates.single.version, 4);
      expect(find.text('Rule saved.'), findsOneWidget);

      unawaited(router.push<Object?>('/category-rules/rule-1/edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete rule'));
      await tester.pumpAndSettle();
      expect(find.text('Delete the rule “Food delivery”?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete rule'));
      await tester.pumpAndSettle();
      verify(() => labels.deleteRule('rule-1')).called(1);
      expect(locationOf(router), '/category-rules');
    });

    testWidgets('a saved rule keeps its amount currency; an unchanged rule '
        'is applied as stored; problems show next to the field', (
      WidgetTester tester,
    ) async {
      when(() => labels.listRules()).thenAnswer(
        (_) async => <RuleDto>[
          categoryRule(amountMin: '20.00', currency: 'USD', version: 2),
        ],
      );
      when(() => labels.getRule('rule-1')).thenAnswer(
        (_) async =>
            categoryRule(amountMin: '20.00', currency: 'USD', version: 2),
      );
      int previews = 0;
      when(
        () => labels.previewRule(
          any(),
          onlyUncategorized: any(named: 'onlyUncategorized'),
        ),
      ).thenAnswer((_) async {
        previews++;
        if (previews == 1) {
          throw serverError(
            ErrorObjectCode.validationError,
            details: const <Detail>[
              Detail(
                field: 'body.rule.pattern',
                message: 'The pattern is not a valid regular expression.',
              ),
            ],
          );
        }
        return rulePreview(2);
      });
      when(
        () => labels.applySavedRule(
          'rule-1',
          onlyUncategorized: any(named: 'onlyUncategorized'),
        ),
      ).thenAnswer((_) async => rulePreview(2));
      final GoRouter router = await pump(tester, '/category-rules');
      unawaited(router.push<Object?>('/category-rules/rule-1/edit'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Currency of the amounts'));
      await tester.pumpAndSettle();
      expect(
        find.text('Amount limits match only transactions in USD.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Preview matches'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview matches'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('The pattern is not a valid regular expression.'),
      );
      expect(
        find.text('The pattern is not a valid regular expression.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Preview matches'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview matches'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Apply to these 2 transactions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply to these 2 transactions'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Change'));
      await tester.pumpAndSettle();
      verify(() => labels.applySavedRule('rule-1', onlyUncategorized: true))
          .called(1);
      verifyNever(
        () => labels.applyRule(
          any(),
          onlyUncategorized: any(named: 'onlyUncategorized'),
        ),
      );
    });

    testWidgets('a stale rule reloads and says so', (
      WidgetTester tester,
    ) async {
      int loads = 0;
      when(() => labels.listRules())
          .thenAnswer((_) async => <RuleDto>[categoryRule()]);
      // The form reloads only this rule (`GET /category-rules/{id}`).
      when(() => labels.getRule('rule-1')).thenAnswer((_) async {
        loads++;
        return loads == 1
            ? categoryRule()
            : categoryRule(name: 'Renamed elsewhere', version: 2);
      });
      final List<RuleUpdate> updates = <RuleUpdate>[];
      when(() => labels.updateRule('rule-1', any()))
          .thenAnswer((Invocation i) async {
            updates.add(i.positionalArguments[1] as RuleUpdate);
            throw serverError(ErrorObjectCode.versionConflict, status: 409);
          });
      final GoRouter router = await pump(tester, '/category-rules');
      unawaited(router.push<Object?>('/category-rules/rule-1/edit'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(updates.single.version, 1);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(find.textContaining('changed somewhere else'), findsOneWidget);
      expect(find.text('Renamed elsewhere'), findsWidgets);
      verify(() => labels.getRule('rule-1')).called(2);
    });

    testWidgets('the list shows amount limits with their currency', (
      WidgetTester tester,
    ) async {
      when(() => labels.listRules()).thenAnswer(
        (_) async => <RuleDto>[
          categoryRule(amountMin: '20.00', amountMax: '80.00', currency: 'USD'),
        ],
      );
      await pump(tester, '/category-rules');
      expect(find.text(r'Amounts from $20.00 to $80.00'), findsOneWidget);
    });
  });
}
