import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';

/// Report types offered when requesting or scheduling a report, in the
/// order shown.
const List<ReportInputReportType> reportTypes = <ReportInputReportType>[
  ReportInputReportType.monthlySummary,
  ReportInputReportType.yearlySummary,
  ReportInputReportType.cashFlow,
  ReportInputReportType.income,
  ReportInputReportType.expense,
  ReportInputReportType.category,
  ReportInputReportType.merchant,
  ReportInputReportType.account,
  ReportInputReportType.budget,
  ReportInputReportType.subscription,
  ReportInputReportType.recurring,
  ReportInputReportType.goal,
  ReportInputReportType.transactions,
];

/// File formats offered, in the order shown.
const List<ReportInputFormat> reportFormats = <ReportInputFormat>[
  ReportInputFormat.csv,
  ReportInputFormat.xlsx,
  ReportInputFormat.pdf,
  ReportInputFormat.jsonValue,
];

/// Name of a report type (wire value; `ReportDTO.report_type` is a plain
/// string), or a generic name for types this app does not know.
String reportTypeLabel(AppLocalizations l10n, String type) => switch (type) {
  'monthly_summary' => l10n.reportTypeMonthlySummary,
  'yearly_summary' => l10n.reportTypeYearlySummary,
  'income' => l10n.reportTypeIncome,
  'expense' => l10n.reportTypeExpense,
  'cash_flow' => l10n.reportTypeCashFlow,
  'category' => l10n.reportTypeCategory,
  'merchant' => l10n.reportTypeMerchant,
  'account' => l10n.reportTypeAccount,
  'budget' => l10n.reportTypeBudget,
  'subscription' => l10n.reportTypeSubscription,
  'recurring' => l10n.reportTypeRecurring,
  'goal' => l10n.reportTypeGoal,
  'transactions' => l10n.reportTypeTransactions,
  _ => l10n.reportTypeOther,
};

/// What a report type contains.
String reportTypeHelp(AppLocalizations l10n, String type) => switch (type) {
  'monthly_summary' => l10n.reportTypeMonthlySummaryHelp,
  'yearly_summary' => l10n.reportTypeYearlySummaryHelp,
  'income' => l10n.reportTypeIncomeHelp,
  'expense' => l10n.reportTypeExpenseHelp,
  'cash_flow' => l10n.reportTypeCashFlowHelp,
  'category' => l10n.reportTypeCategoryHelp,
  'merchant' => l10n.reportTypeMerchantHelp,
  'account' => l10n.reportTypeAccountHelp,
  'budget' => l10n.reportTypeBudgetHelp,
  'subscription' => l10n.reportTypeSubscriptionHelp,
  'recurring' => l10n.reportTypeRecurringHelp,
  'goal' => l10n.reportTypeGoalHelp,
  'transactions' => l10n.reportTypeTransactionsHelp,
  _ => '',
};

/// Name of a file format (wire value).
String reportFormatLabel(AppLocalizations l10n, String format) =>
    switch (format) {
      'csv' => l10n.reportFormatCsv,
      'xlsx' => l10n.reportFormatXlsx,
      'pdf' => l10n.reportFormatPdf,
      'json' => l10n.reportFormatJson,
      _ => format.toUpperCase(),
    };

/// The titles the server gives reports requested without one
/// (`titles` in `backend/internal/reports/reports.go`), so that default
/// titles can be shown in the user's language.
const Map<String, String> serverDefaultReportTitles = <String, String>{
  'monthly_summary': 'Monthly summary',
  'yearly_summary': 'Yearly summary',
  'income': 'Income',
  'expense': 'Expenses',
  'cash_flow': 'Cash flow',
  'category': 'Spending by category',
  'merchant': 'Spending by merchant',
  'account': 'Accounts',
  'budget': 'Budgets',
  'subscription': 'Subscriptions',
  'recurring': 'Recurring commitments',
  'goal': 'Goals',
  'transactions': 'Transactions',
};

/// The title to show for a report or schedule: the user's own title, or
/// the localized type name when the server's English default was kept
/// (schedules add " (weekly)" / " (monthly)").
String reportTitle(
  AppLocalizations l10n, {
  required String title,
  required String type,
  String? cadence,
}) {
  final String? english = serverDefaultReportTitles[type];
  final String typeName = reportTypeLabel(l10n, type);
  if (english == null) {
    return title.isEmpty ? typeName : title;
  }
  if (title.isEmpty || title == english) {
    return typeName;
  }
  if (cadence != null && title == '$english ($cadence)') {
    return switch (cadence) {
      'weekly' => l10n.scheduleTitleWeekly(typeName),
      'monthly' => l10n.scheduleTitleMonthly(typeName),
      _ => typeName,
    };
  }
  return title;
}

/// Text, tone and icon of a report's status.
(String, StatusTone, IconData) reportStatusLabel(
  AppLocalizations l10n,
  ReportDtoStatus status,
) => switch (status) {
  ReportDtoStatus.queued => (
    l10n.reportStatusQueued,
    StatusTone.neutral,
    Icons.schedule,
  ),
  ReportDtoStatus.running => (
    l10n.reportStatusRunning,
    StatusTone.neutral,
    Icons.hourglass_top,
  ),
  ReportDtoStatus.completed => (
    l10n.reportStatusReady,
    StatusTone.positive,
    Icons.check_circle,
  ),
  ReportDtoStatus.failed => (
    l10n.reportStatusFailed,
    StatusTone.caution,
    Icons.error_outline,
  ),
  ReportDtoStatus.expired => (
    l10n.reportStatusExpired,
    StatusTone.neutral,
    Icons.history_toggle_off,
  ),
  ReportDtoStatus.unrecognized => (
    l10n.reportStatusOther,
    StatusTone.neutral,
    Icons.help_outline,
  ),
};

/// Why a report failed (`ReportDTO.error_code`).
String reportFailureText(AppLocalizations l10n, ReportDtoErrorCode? code) =>
    switch (code) {
      ReportDtoErrorCode.tooManyRows => l10n.reportFailedTooManyRows,
      ReportDtoErrorCode.pdfTooLarge => l10n.reportFailedPdfTooLarge,
      ReportDtoErrorCode.reportInvalid => l10n.reportFailedInvalid,
      ReportDtoErrorCode.reportsUnavailable => l10n.reportFailedUnavailable,
      ReportDtoErrorCode.storageUnavailable =>
        l10n.reportFailedStorageUnavailable,
      ReportDtoErrorCode.generationFailed => l10n.reportFailedGeneration,
      ReportDtoErrorCode.unrecognized || null => l10n.reportFailedOther,
    };

/// The filters to make [report] again for the same dates: a report with a
/// resolved `window` asks for exactly those dates (a named range would be
/// resolved again from today); current-state reports keep their filters.
Filters againFilters(ReportDto report) {
  final Filters f = report.filters;
  final Window? w = report.window;
  if (w == null) {
    return f;
  }
  return Filters(
    accountIds: f.accountIds,
    categoryIds: f.categoryIds,
    currency: f.currency,
    displayCurrency: f.displayCurrency,
    includePending: f.includePending,
    merchantIds: f.merchantIds,
    tags: f.tags,
    types: f.types,
    from: w.from,
    to: w.to,
  );
}

/// Whether [report] can no longer be downloaded (expired, or past its
/// expiry time).
bool isExpired(ReportDto report, DateTime now) =>
    report.status == ReportDtoStatus.expired ||
    (report.expiresAt != null && report.expiresAt!.isBefore(now));

/// Name of a schedule's cadence.
String cadenceLabel(AppLocalizations l10n, String cadence) => switch (cadence) {
  'weekly' => l10n.scheduleCadenceWeekly,
  'monthly' => l10n.scheduleCadenceMonthly,
  _ => cadence,
};
