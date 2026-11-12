import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';

/// Localized category kind.
String categoryKindLabel(AppLocalizations l10n, CategoryDtoKind kind) =>
    switch (kind) {
      CategoryDtoKind.expense => l10n.categoryKindExpense,
      CategoryDtoKind.income => l10n.categoryKindIncome,
      CategoryDtoKind.both => l10n.categoryKindBoth,
      CategoryDtoKind.unrecognized => l10n.categoryKindOther,
    };

/// The input kind matching a category's kind (unknown kinds become
/// "both", the least restrictive choice; the user sees it before saving).
CategoryInputKind categoryInputKindOf(CategoryDtoKind kind) => switch (kind) {
  CategoryDtoKind.expense => CategoryInputKind.expense,
  CategoryDtoKind.income => CategoryInputKind.income,
  CategoryDtoKind.both ||
  CategoryDtoKind.unrecognized => CategoryInputKind.both,
};

/// Localized kind for the form's choices.
String categoryInputKindLabel(AppLocalizations l10n, CategoryInputKind kind) =>
    categoryKindLabel(l10n, CategoryDtoKind.fromJson(kind.json));

/// What a rule looks at.
String ruleFieldLabel(AppLocalizations l10n, RuleInputMatchField field) =>
    switch (field) {
      RuleInputMatchField.description => l10n.ruleFieldDescription,
      RuleInputMatchField.merchant => l10n.ruleFieldMerchant,
      RuleInputMatchField.any => l10n.ruleFieldAny,
      RuleInputMatchField.unrecognized => l10n.ruleFieldAny,
    };

/// How a rule compares.
String ruleMatchTypeLabel(AppLocalizations l10n, RuleInputMatchType type) =>
    switch (type) {
      RuleInputMatchType.contains => l10n.ruleMatchContains,
      RuleInputMatchType.equals => l10n.ruleMatchEquals,
      RuleInputMatchType.startsWith => l10n.ruleMatchStartsWith,
      RuleInputMatchType.regex => l10n.ruleMatchRegex,
      RuleInputMatchType.unrecognized => l10n.ruleMatchContains,
    };

/// Which new transactions a rule runs on.
String ruleApplyToLabel(AppLocalizations l10n, RuleInputApplyTo applyTo) =>
    switch (applyTo) {
      RuleInputApplyTo.manual => l10n.ruleApplyManual,
      RuleInputApplyTo.imports => l10n.ruleApplyImports,
      RuleInputApplyTo.all ||
      RuleInputApplyTo.unrecognized => l10n.ruleApplyAll,
    };

/// The saved rule as the form's input (rules are replaced whole on save).
/// The amount bounds keep the rule's own `currency` ([fallbackCurrency],
/// normally the base currency, only when the rule has none).
RuleInput ruleInputOf(RuleDto rule, {String? fallbackCurrency}) => RuleInput(
  name: rule.name,
  pattern: rule.pattern,
  matchField: RuleInputMatchField.fromJson(rule.matchField.json),
  matchType: RuleInputMatchType.fromJson(rule.matchType.json),
  setCategoryId: rule.setCategoryId,
  priority: rule.priority,
  enabled: rule.enabled,
  applyTo: RuleInputApplyTo.fromJson(rule.applyTo.json),
  transactionType: rule.transactionType == null
      ? null
      : RuleInputTransactionType.fromJson(rule.transactionType!.json),
  accountId: rule.accountId,
  amountMin: rule.amountMin,
  amountMax: rule.amountMax,
  currency: rule.amountMin != null || rule.amountMax != null
      ? rule.currency ?? fallbackCurrency
      : null,
);

/// [input] as the `PUT /category-rules/{id}` body with the loaded
/// [version].
RuleUpdate ruleUpdateOf(RuleInput input, int version) => RuleUpdate.fromJson(
  <String, Object?>{...input.toJson(), 'version': version},
);

/// The rule's amount limits in words ("Amounts from ₹100.00 to ₹500.00"),
/// or null when it has none. [money] formats an exact amount in the rule's
/// currency.
String? ruleAmountsText(
  AppLocalizations l10n,
  RuleDto rule, {
  required String Function(String amount, String? currency) money,
}) {
  final String? min = rule.amountMin;
  final String? max = rule.amountMax;
  return switch ((min, max)) {
    (final String a, final String b) => l10n.ruleAmountsBetween(
      money(a, rule.currency),
      money(b, rule.currency),
    ),
    (final String a, null) => l10n.ruleAmountsAtLeast(money(a, rule.currency)),
    (null, final String b) => l10n.ruleAmountsAtMost(money(b, rule.currency)),
    (null, null) => null,
  };
}

/// One line describing a rule: "Merchant contains “swiggy” → Food".
String ruleSummary(
  AppLocalizations l10n,
  RuleDto rule, {
  required String categoryName,
}) => l10n.ruleSummary(
  ruleFieldLabel(l10n, RuleInputMatchField.fromJson(rule.matchField.json)),
  ruleMatchTypeLabel(l10n, RuleInputMatchType.fromJson(rule.matchType.json)),
  rule.pattern,
  categoryName,
);

/// What a category merge moves, as lines like "12 transactions" (only the
/// kinds with something to move), from the preview's typed counts.
List<String> mergeAffectedLines(
  AppLocalizations l10n,
  MergeAffected a,
) => <String>[
  if (a.transactions > 0) l10n.mergeAffectedTransactions(a.transactions),
  if (a.subcategories > 0) l10n.mergeAffectedSubcategories(a.subcategories),
  if (a.rules > 0) l10n.mergeAffectedRules(a.rules),
  if (a.budgetAllocations > 0) l10n.mergeAffectedBudgets(a.budgetAllocations),
  if (a.budgetFilters > 0) l10n.mergeAffectedBudgetFilters(a.budgetFilters),
  if (a.merchants > 0) l10n.mergeAffectedMerchants(a.merchants),
  if (a.recurringRules > 0) l10n.mergeAffectedRecurring(a.recurringRules),
  if (a.bills > 0) l10n.mergeAffectedBills(a.bills),
  if (a.subscriptions > 0) l10n.mergeAffectedSubscriptions(a.subscriptions),
];

/// What a merchant merge moves, as lines like "12 transactions" (only the
/// kinds with something to move).
List<String> merchantMergeAffectedLines(
  AppLocalizations l10n,
  MerchantMergeAffected a,
) => <String>[
  if (a.transactions > 0) l10n.mergeAffectedTransactions(a.transactions),
  if (a.aliases > 0) l10n.mergeAffectedAliases(a.aliases),
  if (a.rules > 0) l10n.mergeAffectedRules(a.rules),
  if (a.budgetAllocations > 0) l10n.mergeAffectedBudgets(a.budgetAllocations),
  if (a.budgetFilters > 0) l10n.mergeAffectedBudgetFilters(a.budgetFilters),
  if (a.recurringRules > 0) l10n.mergeAffectedRecurring(a.recurringRules),
  if (a.subscriptions > 0) l10n.mergeAffectedSubscriptions(a.subscriptions),
];

/// A color offered for categories and tags, with a name for screen
/// readers (colors are never the only cue: names are always shown).
typedef LabelColor = ({String hex, String Function(AppLocalizations) name});

/// Colors offered for categories and tags.
final List<LabelColor> labelColors = <LabelColor>[
  (hex: '#E53935', name: (AppLocalizations l) => l.labelColorRed),
  (hex: '#FB8C00', name: (AppLocalizations l) => l.labelColorOrange),
  (hex: '#FDD835', name: (AppLocalizations l) => l.labelColorYellow),
  (hex: '#43A047', name: (AppLocalizations l) => l.labelColorGreen),
  (hex: '#00897B', name: (AppLocalizations l) => l.labelColorTeal),
  (hex: '#1E88E5', name: (AppLocalizations l) => l.labelColorBlue),
  (hex: '#5E35B1', name: (AppLocalizations l) => l.labelColorPurple),
  (hex: '#D81B60', name: (AppLocalizations l) => l.labelColorPink),
  (hex: '#6D4C41', name: (AppLocalizations l) => l.labelColorBrown),
  (hex: '#546E7A', name: (AppLocalizations l) => l.labelColorGrey),
];

/// Spoken name of [hex] ("Blue"), or "Custom color" for others.
String labelColorName(AppLocalizations l10n, String hex) {
  for (final LabelColor c in labelColors) {
    if (c.hex.toUpperCase() == hex.toUpperCase()) {
      return c.name(l10n);
    }
  }
  return l10n.labelColorCustom;
}

/// Icon names offered for categories (Material Symbols names, as the
/// starter categories use).
const List<String> categoryIconNames = <String>[
  'shopping_cart',
  'restaurant',
  'directions_bus',
  'local_gas_station',
  'home',
  'bolt',
  'shopping_bag',
  'medical_services',
  'school',
  'movie',
  'flight',
  'spa',
  'verified_user',
  'receipt_long',
  'redeem',
  'family_restroom',
  'work',
  'payments',
  'laptop',
  'savings',
];

/// Spoken name of a category icon.
String categoryIconLabel(AppLocalizations l10n, String name) => switch (name) {
  'shopping_cart' => l10n.categoryIconCart,
  'restaurant' => l10n.categoryIconFood,
  'directions_bus' => l10n.categoryIconTransport,
  'local_gas_station' => l10n.categoryIconFuel,
  'home' => l10n.categoryIconHome,
  'bolt' => l10n.categoryIconUtilities,
  'shopping_bag' => l10n.categoryIconShopping,
  'medical_services' => l10n.categoryIconHealth,
  'school' => l10n.categoryIconEducation,
  'movie' => l10n.categoryIconEntertainment,
  'flight' => l10n.categoryIconTravel,
  'spa' => l10n.categoryIconPersonalCare,
  'verified_user' => l10n.categoryIconInsurance,
  'receipt_long' => l10n.categoryIconBills,
  'redeem' => l10n.categoryIconGifts,
  'family_restroom' => l10n.categoryIconFamily,
  'work' => l10n.categoryIconWork,
  'payments' => l10n.categoryIconMoney,
  'laptop' => l10n.categoryIconTech,
  'savings' => l10n.categoryIconSavings,
  _ => l10n.categoryIconOther,
};
