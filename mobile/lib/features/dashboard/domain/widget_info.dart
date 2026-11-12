import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';

/// Localized name of a dashboard widget. Keys added by a newer server
/// (`unrecognized`) are not drawn by this app version.
String widgetTitle(AppLocalizations l10n, WidgetDtoKey key) => switch (key) {
  WidgetDtoKey.balances => l10n.widgetBalances,
  WidgetDtoKey.cashFlow => l10n.widgetCashFlow,
  WidgetDtoKey.incomeVsExpense => l10n.widgetIncomeVsExpense,
  WidgetDtoKey.cashFlowTrend => l10n.widgetCashFlowTrend,
  WidgetDtoKey.categoryBreakdown => l10n.widgetCategoryBreakdown,
  WidgetDtoKey.topMerchants => l10n.widgetTopMerchants,
  WidgetDtoKey.recentTransactions => l10n.widgetRecentTransactions,
  WidgetDtoKey.dataCoverage => l10n.widgetDataCoverage,
  WidgetDtoKey.unrecognized => l10n.widgetUnknownTitle,
};

/// One-line description of a widget for the layout settings.
String widgetDescription(AppLocalizations l10n, WidgetDtoKey key) =>
    switch (key) {
      WidgetDtoKey.balances => l10n.widgetBalancesHelp,
      WidgetDtoKey.cashFlow => l10n.widgetCashFlowHelp,
      WidgetDtoKey.incomeVsExpense => l10n.widgetIncomeVsExpenseHelp,
      WidgetDtoKey.cashFlowTrend => l10n.widgetCashFlowTrendHelp,
      WidgetDtoKey.categoryBreakdown => l10n.widgetCategoryBreakdownHelp,
      WidgetDtoKey.topMerchants => l10n.widgetTopMerchantsHelp,
      WidgetDtoKey.recentTransactions => l10n.widgetRecentTransactionsHelp,
      WidgetDtoKey.dataCoverage => l10n.widgetDataCoverageHelp,
      WidgetDtoKey.unrecognized => l10n.widgetUnknownHelp,
    };

/// Icon of a widget.
IconData widgetIcon(WidgetDtoKey key) => switch (key) {
  WidgetDtoKey.balances => Icons.account_balance_wallet_outlined,
  WidgetDtoKey.cashFlow => Icons.swap_vert,
  WidgetDtoKey.incomeVsExpense => Icons.bar_chart,
  WidgetDtoKey.cashFlowTrend => Icons.show_chart,
  WidgetDtoKey.categoryBreakdown => Icons.donut_small_outlined,
  WidgetDtoKey.topMerchants => Icons.storefront_outlined,
  WidgetDtoKey.recentTransactions => Icons.receipt_long_outlined,
  WidgetDtoKey.dataCoverage => Icons.fact_check_outlined,
  WidgetDtoKey.unrecognized => Icons.widgets_outlined,
};

/// Whether this app version can draw [key].
bool isKnownWidget(WidgetDtoKey key) => key != WidgetDtoKey.unrecognized;
