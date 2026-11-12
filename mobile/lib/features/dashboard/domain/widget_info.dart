import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';

/// The Home widgets this app version can draw, by their wire key, in the
/// server's default order (`backend/internal/analytics/dashboard.go`).
///
/// The same twelve keys as the generated `WidgetDtoKey` (a test keeps them
/// in step). The layout is kept as wire keys ([DashboardWidget.key]) rather
/// than that enum: a key from a newer server would decode as
/// `unrecognized` and lose its name, so saving the layout could not send it
/// back. Such keys are not drawn, and are saved back unchanged.
enum DashboardWidgetKind {
  /// Tracked balances per currency.
  balances('balances'),

  /// Income, spending and net cash flow.
  cashFlow('cash_flow'),

  /// Fullest budgets (`GET /dashboard/planning`).
  budgets('budgets'),

  /// Overdue and upcoming bills, recurring payments, renewals and goal
  /// dates (`GET /dashboard/planning`).
  upcoming('upcoming'),

  /// Income vs spending chart.
  incomeVsExpense('income_vs_expense'),

  /// Cash-flow trend chart.
  cashFlowTrend('cash_flow_trend'),

  /// Spending by category.
  categoryBreakdown('category_breakdown'),

  /// Top merchants.
  topMerchants('top_merchants'),

  /// Nearest goals (`GET /dashboard/planning`).
  goals('goals'),

  /// Groups with an open balance (`GET /dashboard/planning`).
  groupBalances('group_balances'),

  /// Latest transactions.
  recentTransactions('recent_transactions'),

  /// What the figures are based on.
  dataCoverage('data_coverage');

  const DashboardWidgetKind(this.key);

  /// The wire key.
  final String key;

  /// The kind for wire [key], or null when this version does not know it.
  static DashboardWidgetKind? of(String key) {
    for (final DashboardWidgetKind kind in values) {
      if (kind.key == key) {
        return kind;
      }
    }
    return null;
  }

  /// Whether the widget reads `GET /dashboard/planning` (one request feeds
  /// all of them) instead of the period summary.
  bool get isPlanning =>
      this == budgets ||
      this == upcoming ||
      this == goals ||
      this == groupBalances;
}

/// One entry of the Home layout (`WidgetDTO`), keeping the wire key.
@immutable
class DashboardWidget {
  /// Creates the entry.
  const DashboardWidget({
    required this.key,
    required this.position,
    required this.visible,
    this.settings = const <String, Object?>{},
  });

  /// Decodes one `WidgetDTO`. Throws [FormatException] when a member has
  /// the wrong type (the API client reports it as an invalid response).
  factory DashboardWidget.fromJson(Map<String, Object?> json) {
    final Object? key = json['key'];
    final Object? position = json['position'];
    final Object? visible = json['visible'];
    if (key is! String || position is! int || visible is! bool) {
      throw const FormatException('WidgetDTO has an unexpected shape');
    }
    return DashboardWidget(
      key: key,
      position: position,
      visible: visible,
      settings: json['settings'] ?? const <String, Object?>{},
    );
  }

  /// The wire key (also for widgets this version does not know).
  final String key;

  /// Position saved by the server (0 first).
  final int position;

  /// Whether Home shows it.
  final bool visible;

  /// Widget-specific settings, sent back unchanged.
  final Object? settings;

  /// The kind, or null for a widget from a newer server.
  DashboardWidgetKind? get kind => DashboardWidgetKind.of(key);

  /// A copy with another visibility or position.
  DashboardWidget copyWith({bool? visible, int? position}) => DashboardWidget(
    key: key,
    position: position ?? this.position,
    visible: visible ?? this.visible,
    settings: settings,
  );

  @override
  bool operator ==(Object other) =>
      other is DashboardWidget &&
      other.key == key &&
      other.position == position &&
      other.visible == visible;

  @override
  int get hashCode => Object.hash(key, position, visible);

  @override
  String toString() => 'DashboardWidget($key, $position, $visible)';
}

/// Localized name of a dashboard widget; [kind] is null for keys added by
/// a newer server (not drawn by this app version).
String widgetTitle(AppLocalizations l10n, DashboardWidgetKind? kind) =>
    switch (kind) {
      DashboardWidgetKind.balances => l10n.widgetBalances,
      DashboardWidgetKind.cashFlow => l10n.widgetCashFlow,
      DashboardWidgetKind.budgets => l10n.widgetBudgets,
      DashboardWidgetKind.upcoming => l10n.widgetUpcoming,
      DashboardWidgetKind.incomeVsExpense => l10n.widgetIncomeVsExpense,
      DashboardWidgetKind.cashFlowTrend => l10n.widgetCashFlowTrend,
      DashboardWidgetKind.categoryBreakdown => l10n.widgetCategoryBreakdown,
      DashboardWidgetKind.topMerchants => l10n.widgetTopMerchants,
      DashboardWidgetKind.goals => l10n.widgetGoals,
      DashboardWidgetKind.groupBalances => l10n.widgetGroupBalances,
      DashboardWidgetKind.recentTransactions => l10n.widgetRecentTransactions,
      DashboardWidgetKind.dataCoverage => l10n.widgetDataCoverage,
      null => l10n.widgetUnknownTitle,
    };

/// One-line description of a widget for the layout settings.
String widgetDescription(AppLocalizations l10n, DashboardWidgetKind? kind) =>
    switch (kind) {
      DashboardWidgetKind.balances => l10n.widgetBalancesHelp,
      DashboardWidgetKind.cashFlow => l10n.widgetCashFlowHelp,
      DashboardWidgetKind.budgets => l10n.widgetBudgetsHelp,
      DashboardWidgetKind.upcoming => l10n.widgetUpcomingHelp,
      DashboardWidgetKind.incomeVsExpense => l10n.widgetIncomeVsExpenseHelp,
      DashboardWidgetKind.cashFlowTrend => l10n.widgetCashFlowTrendHelp,
      DashboardWidgetKind.categoryBreakdown => l10n.widgetCategoryBreakdownHelp,
      DashboardWidgetKind.topMerchants => l10n.widgetTopMerchantsHelp,
      DashboardWidgetKind.goals => l10n.widgetGoalsHelp,
      DashboardWidgetKind.groupBalances => l10n.widgetGroupBalancesHelp,
      DashboardWidgetKind.recentTransactions =>
        l10n.widgetRecentTransactionsHelp,
      DashboardWidgetKind.dataCoverage => l10n.widgetDataCoverageHelp,
      null => l10n.widgetUnknownHelp,
    };

/// Icon of a widget.
IconData widgetIcon(DashboardWidgetKind? kind) => switch (kind) {
  DashboardWidgetKind.balances => Icons.account_balance_wallet_outlined,
  DashboardWidgetKind.cashFlow => Icons.swap_vert,
  DashboardWidgetKind.budgets => Icons.savings_outlined,
  DashboardWidgetKind.upcoming => Icons.event_outlined,
  DashboardWidgetKind.incomeVsExpense => Icons.bar_chart,
  DashboardWidgetKind.cashFlowTrend => Icons.show_chart,
  DashboardWidgetKind.categoryBreakdown => Icons.donut_small_outlined,
  DashboardWidgetKind.topMerchants => Icons.storefront_outlined,
  DashboardWidgetKind.goals => Icons.flag_outlined,
  DashboardWidgetKind.groupBalances => Icons.groups_outlined,
  DashboardWidgetKind.recentTransactions => Icons.receipt_long_outlined,
  DashboardWidgetKind.dataCoverage => Icons.fact_check_outlined,
  null => Icons.widgets_outlined,
};
