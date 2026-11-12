import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';

import 'finance_fakes.dart';

/// Registers fallback values for the organize screens' `any()` matchers.
void registerOrganizeFallbacks() {
  registerFinanceFallbacks();
  registerFallbackValue(
    const CategoryInput(kind: CategoryInputKind.expense, name: 'x'),
  );
  registerFallbackValue(const CategoryPatch(version: 1));
  registerFallbackValue(
    const RuleInput(
      matchField: RuleInputMatchField.any,
      matchType: RuleInputMatchType.contains,
      name: 'x',
      pattern: 'x',
      priority: 100,
      setCategoryId: 'x',
    ),
  );
  registerFallbackValue(
    const RuleUpdate(
      matchField: RuleUpdateMatchField.any,
      matchType: RuleUpdateMatchType.contains,
      name: 'x',
      pattern: 'x',
      setCategoryId: 'x',
    ),
  );
  registerFallbackValue(const TagBody());
  registerFallbackValue(const TagPatch());
  registerFallbackValue(const MerchantPatch());
}

/// A `CategoryDTO` with every management field.
CategoryDto managedCategory({
  String id = 'cat-food',
  String name = 'Food',
  String kind = 'expense',
  String status = 'active',
  String? parentId,
  String? systemKey,
  String? color = '#E53935',
  String? icon = 'restaurant',
  int transactions = 4,
  bool includeInBudgets = true,
  int sortOrder = 10,
  int version = 1,
}) => CategoryDto.fromJson(<String, Object?>{
  'id': id,
  'name': name,
  'kind': kind,
  'status': status,
  'parent_id': ?parentId,
  'system_key': ?systemKey,
  'color': ?color,
  'icon': ?icon,
  'include_in_budgets': includeInBudgets,
  'sort_order': sortOrder,
  'transaction_count': transactions,
  'version': version,
  'updated_at': '2026-11-01T08:00:00Z',
});

/// A `RuleDTO`.
RuleDto categoryRule({
  String id = 'rule-1',
  String name = 'Food delivery',
  String pattern = 'swiggy',
  String field = 'merchant',
  String type = 'contains',
  String categoryId = 'cat-food',
  int priority = 100,
  bool enabled = true,
  String applyTo = 'all',
  String? amountMin,
  String? amountMax,
  String? currency,
  int version = 1,
}) => RuleDto.fromJson(<String, Object?>{
  'id': id,
  'name': name,
  'pattern': pattern,
  'match_field': field,
  'match_type': type,
  'set_category_id': categoryId,
  'priority': priority,
  'enabled': enabled,
  'apply_to': applyTo,
  'amount_min': ?amountMin,
  'amount_max': ?amountMax,
  // The bounds' currency; null without an amount condition.
  'currency': amountMin != null || amountMax != null
      ? (currency ?? 'INR')
      : null,
  'version': version,
  'created_at': '2026-11-01T08:00:00Z',
});

/// A `RulePreview` with [count] matches and the given sample.
RulePreview rulePreview(int count, {List<TransactionDto>? sample}) =>
    RulePreview.fromJson(<String, Object?>{
      'match_count': count,
      'sample': <Object?>[
        for (final TransactionDto t in sample ?? <TransactionDto>[]) t.toJson(),
      ],
    });

/// A `TagDTO` with color and archive state.
TagDto managedTag({
  String id = 'tag-trip',
  String name = 'trip',
  int usage = 3,
  String? color = '#1E88E5',
  bool archived = false,
  int version = 1,
}) => TagDto.fromJson(<String, Object?>{
  'id': id,
  'name': name,
  'usage_count': usage,
  'color': ?color,
  if (archived) 'archived_at': '2026-10-01T08:00:00Z',
  'version': version,
});

Map<String, Object?> _merchantJson({
  required String id,
  required String name,
  required List<String> aliases,
  required String status,
  required int transactions,
  String? defaultCategoryId,
  String? website,
  String? notes,
  String? mergedIntoId,
  int version = 1,
}) => <String, Object?>{
  'id': id,
  'name': name,
  'aliases': aliases,
  'status': status,
  'transaction_count': transactions,
  'last_used_on': '2026-11-03',
  'default_category_id': ?defaultCategoryId,
  'website': ?website,
  'notes': ?notes,
  'merged_into_id': ?mergedIntoId,
  'version': version,
};

/// A `MerchantDTO`.
MerchantDto merchantDto({
  String id = 'mer-swiggy',
  String name = 'Swiggy',
  List<String> aliases = const <String>['SWIGGY BLR'],
  String status = 'active',
  int transactions = 6,
  int version = 1,
}) => MerchantDto.fromJson(
  _merchantJson(
    id: id,
    name: name,
    aliases: aliases,
    status: status,
    transactions: transactions,
    version: version,
  ),
);

/// One page of merchants (more after it when [next] is set).
CursorPage<MerchantDto> merchantsPage(
  List<MerchantDto> items, {
  String? next,
}) => CursorPage<MerchantDto>(items, next);

/// A `MergeAffected` (category merge preview) with the given counts.
MergeAffected mergeAffected({
  int transactions = 0,
  int subcategories = 0,
  int rules = 0,
  int budgetAllocations = 0,
  int budgetFilters = 0,
  int merchants = 0,
  int recurringRules = 0,
  int bills = 0,
  int subscriptions = 0,
}) => MergeAffected(
  transactions: transactions,
  subcategories: subcategories,
  rules: rules,
  budgetAllocations: budgetAllocations,
  budgetFilters: budgetFilters,
  merchants: merchants,
  recurringRules: recurringRules,
  bills: bills,
  subscriptions: subscriptions,
);

/// A merchant merge preview with the given counts.
MerchantMergeResult merchantMergePreview({
  int transactions = 0,
  int aliases = 0,
  int rules = 0,
  int budgetAllocations = 0,
  int budgetFilters = 0,
  int recurringRules = 0,
  int subscriptions = 0,
}) => MerchantMergeResult(
  preview: true,
  affected: MerchantMergeAffected(
    transactions: transactions,
    aliases: aliases,
    rules: rules,
    budgetAllocations: budgetAllocations,
    budgetFilters: budgetFilters,
    recurringRules: recurringRules,
    subscriptions: subscriptions,
  ),
);

/// A `MerchantDetail` with spending rows (`(month, amount, count)`).
MerchantDetail merchantDetail({
  String id = 'mer-swiggy',
  String name = 'Swiggy',
  List<String> aliases = const <String>['SWIGGY BLR'],
  String status = 'active',
  String? defaultCategoryId = 'cat-food',
  String? website = 'https://www.swiggy.com',
  String? notes,
  String? mergedIntoId,
  int version = 1,
  List<(String, String, int)> spending = const <(String, String, int)>[
    ('2026-09', '450.00', 2),
    ('2026-10', '1200.50', 3),
    ('2026-11', '300.00', 1),
  ],
}) => MerchantDetail.fromJson(<String, Object?>{
  ..._merchantJson(
    id: id,
    name: name,
    aliases: aliases,
    status: status,
    transactions: 6,
    defaultCategoryId: defaultCategoryId,
    website: website,
    notes: notes,
    mergedIntoId: mergedIntoId,
    version: version,
  ),
  'spending': <Object?>[
    for (final (String month, String amount, int count) in spending)
      <String, Object?>{
        'month': month,
        'total': moneyJson(amount),
        'count': count,
      },
  ],
});
