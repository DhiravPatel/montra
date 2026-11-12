import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/features/accounts/domain/account_types.dart';
import 'package:montra_mobile/features/budgets/domain/budget_display.dart';
import 'package:montra_mobile/features/goals/domain/goal_display.dart';
import 'package:montra_mobile/features/labels/domain/organize_display.dart';

/// A section of the search results (also a `scope` value).
enum SearchSection {
  /// Transactions.
  transactions('transactions', Icons.receipt_long_outlined),

  /// Merchants.
  merchants('merchants', Icons.storefront_outlined),

  /// Accounts.
  accounts('accounts', Icons.account_balance_wallet_outlined),

  /// Categories.
  categories('categories', Icons.category_outlined),

  /// Budgets.
  budgets('budgets', Icons.pie_chart_outline),

  /// Goals.
  goals('goals', Icons.flag_outlined),

  /// Bills.
  bills('bills', Icons.receipt_outlined),

  /// Subscriptions.
  subscriptions('subscriptions', Icons.autorenew),

  /// Recurring payments.
  recurringRules('recurring_rules', Icons.event_repeat),

  /// Groups.
  groups('groups', Icons.group_outlined),

  /// Community posts.
  posts('posts', Icons.forum_outlined),

  /// People (exact usernames only).
  users('users', Icons.person_search_outlined);

  const SearchSection(this.wire, this.icon);

  /// The `scope` value.
  final String wire;

  /// Decorative icon.
  final IconData icon;
}

/// Name of a section.
String searchSectionLabel(AppLocalizations l10n, SearchSection s) =>
    switch (s) {
      SearchSection.transactions => l10n.searchSectionTransactions,
      SearchSection.merchants => l10n.searchSectionMerchants,
      SearchSection.accounts => l10n.searchSectionAccounts,
      SearchSection.categories => l10n.searchSectionCategories,
      SearchSection.budgets => l10n.searchSectionBudgets,
      SearchSection.goals => l10n.searchSectionGoals,
      SearchSection.bills => l10n.searchSectionBills,
      SearchSection.subscriptions => l10n.searchSectionSubscriptions,
      SearchSection.recurringRules => l10n.searchSectionRecurring,
      SearchSection.groups => l10n.searchSectionGroups,
      SearchSection.posts => l10n.searchSectionPosts,
      SearchSection.users => l10n.searchSectionPeople,
    };

/// Name of a scope value (`all` or a section), for recent searches.
String searchScopeLabel(AppLocalizations l10n, String scope) {
  for (final SearchSection s in SearchSection.values) {
    if (s.wire == scope) {
      return searchSectionLabel(l10n, s);
    }
  }
  return l10n.searchScopeAll;
}

/// Name of a sort order.
String searchSortLabel(AppLocalizations l10n, String sort) => switch (sort) {
  'name' => l10n.searchSortName,
  'recent' => l10n.searchSortRecent,
  _ => l10n.searchSortRelevance,
};

/// The named hits of [section] in [results] (empty for transactions,
/// posts and people, which have their own shapes).
List<NamedHit> namedHits(Results results, SearchSection section) =>
    switch (section) {
      SearchSection.merchants => results.merchants,
      SearchSection.accounts => results.accounts,
      SearchSection.categories => results.categories,
      SearchSection.budgets => results.budgets,
      SearchSection.goals => results.goals,
      SearchSection.bills => results.bills,
      SearchSection.subscriptions => results.subscriptions,
      SearchSection.recurringRules => results.recurringRules,
      SearchSection.groups => results.groups,
      _ => const <NamedHit>[],
    };

/// How many hits [section] has.
int hitCount(Results results, SearchSection section) => switch (section) {
  SearchSection.transactions => results.transactions.length,
  SearchSection.posts => results.posts.length,
  SearchSection.users => results.users.length,
  _ => namedHits(results, section).length,
};

/// Whether nothing was found.
bool isEmptyResult(Results results) =>
    SearchSection.values.every((SearchSection s) => hitCount(results, s) == 0);

/// The `kind` of a named hit in words (account type, category kind, goal
/// status, budget type, bill/subscription status, recurring kind or group
/// type), or null when there is none.
String? namedHitKind(AppLocalizations l10n, SearchSection s, String? kind) {
  if (kind == null || kind.isEmpty) {
    return null;
  }
  return switch (s) {
    SearchSection.accounts => accountTypeLabel(
      l10n,
      AccountInputAccountType.fromJson(kind),
    ),
    SearchSection.categories => categoryKindLabel(
      l10n,
      CategoryDtoKind.fromJson(kind),
    ),
    SearchSection.goals => goalStatusLabel(l10n, GoalDtoStatus.fromJson(kind)),
    SearchSection.budgets => budgetTypeLabel(
      l10n,
      BudgetInputBudgetType.fromJson(kind),
    ),
    SearchSection.bills ||
    SearchSection.subscriptions => statusWord(l10n, kind),
    SearchSection.recurringRules => switch (kind) {
      'expense' => l10n.searchKindExpense,
      'income' => l10n.searchKindIncome,
      'transfer' => l10n.searchKindTransfer,
      _ => kind.replaceAll('_', ' '),
    },
    SearchSection.groups => switch (kind) {
      'household' => l10n.searchGroupHousehold,
      'roommates' => l10n.searchGroupRoommates,
      'trip' => l10n.searchGroupTrip,
      'event' => l10n.searchGroupEvent,
      'friends' => l10n.searchGroupFriends,
      'custom' => l10n.searchGroupCustom,
      _ => kind.replaceAll('_', ' '),
    },
    _ => kind.replaceAll('_', ' '),
  };
}

/// Where a named hit opens.
String namedHitRoute(SearchSection s, NamedHit hit) => switch (s) {
  SearchSection.merchants => AppRoutes.merchantDetail(hit.id),
  SearchSection.accounts => AppRoutes.accountDetail(hit.id),
  SearchSection.categories => Uri(
    path: AppRoutes.transactions,
    queryParameters: <String, String>{'category_id': hit.id},
  ).toString(),
  SearchSection.budgets => AppRoutes.budgetDetail(hit.id),
  SearchSection.goals => AppRoutes.goalDetail(hit.id),
  SearchSection.bills => AppRoutes.billDetail(hit.id),
  SearchSection.subscriptions => AppRoutes.subscriptionDetail(hit.id),
  SearchSection.recurringRules => AppRoutes.recurringDetail(hit.id),
  SearchSection.groups => AppRoutes.groupDetail(hit.id),
  _ => AppRoutes.search,
};
