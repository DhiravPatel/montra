import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/features/analytics/domain/analytics_query.dart';

/// Title of an analytics report.
String analyticsReportTitle(AppLocalizations l10n, AnalyticsReport report) =>
    switch (report) {
      AnalyticsReport.cashFlow => l10n.analyticsCashFlowTitle,
      AnalyticsReport.categories => l10n.analyticsCategoriesTitle,
      AnalyticsReport.expenses => l10n.analyticsExpensesTitle,
      AnalyticsReport.income => l10n.analyticsIncomeTitle,
      AnalyticsReport.merchants => l10n.analyticsMerchantsTitle,
      AnalyticsReport.accounts => l10n.analyticsAccountsTitle,
      AnalyticsReport.budgets => l10n.analyticsBudgetsTitle,
      AnalyticsReport.goals => l10n.analyticsGoalsTitle,
      AnalyticsReport.subscriptions => l10n.analyticsSubscriptionsTitle,
      AnalyticsReport.recurring => l10n.analyticsRecurringTitle,
    };

/// One-line description of an analytics report.
String analyticsReportSubtitle(AppLocalizations l10n, AnalyticsReport report) =>
    switch (report) {
      AnalyticsReport.cashFlow => l10n.analyticsCashFlowSubtitle,
      AnalyticsReport.categories => l10n.analyticsCategoriesSubtitle,
      AnalyticsReport.expenses => l10n.analyticsExpensesSubtitle,
      AnalyticsReport.income => l10n.analyticsIncomeSubtitle,
      AnalyticsReport.merchants => l10n.analyticsMerchantsSubtitle,
      AnalyticsReport.accounts => l10n.analyticsAccountsSubtitle,
      AnalyticsReport.budgets => l10n.analyticsBudgetsSubtitle,
      AnalyticsReport.goals => l10n.analyticsGoalsSubtitle,
      AnalyticsReport.subscriptions => l10n.analyticsSubscriptionsSubtitle,
      AnalyticsReport.recurring => l10n.analyticsRecurringSubtitle,
    };

/// Icon of an analytics report (decorative).
IconData analyticsReportIcon(AnalyticsReport report) => switch (report) {
  AnalyticsReport.cashFlow => Icons.swap_vert,
  AnalyticsReport.categories => Icons.donut_large_outlined,
  AnalyticsReport.expenses => Icons.trending_down,
  AnalyticsReport.income => Icons.trending_up,
  AnalyticsReport.merchants => Icons.storefront_outlined,
  AnalyticsReport.accounts => Icons.account_balance_outlined,
  AnalyticsReport.budgets => Icons.savings_outlined,
  AnalyticsReport.goals => Icons.flag_outlined,
  AnalyticsReport.subscriptions => Icons.subscriptions_outlined,
  AnalyticsReport.recurring => Icons.event_repeat_outlined,
};

/// The name of a series bucket size ("week").
String granularityUnit(AppLocalizations l10n, String? granularity) =>
    switch (granularity) {
      'week' => l10n.trendUnitWeek,
      'month' => l10n.trendUnitMonth,
      'year' => l10n.trendUnitYear,
      _ => l10n.trendUnitDay,
    };

/// The label of a granularity choice ("Automatic", "Week").
String granularityChoiceLabel(AppLocalizations l10n, String? granularity) =>
    switch (granularity) {
      'day' => l10n.analyticsGranularityDay,
      'week' => l10n.analyticsGranularityWeek,
      'month' => l10n.analyticsGranularityMonth,
      'year' => l10n.analyticsGranularityYear,
      _ => l10n.analyticsGranularityAuto,
    };

/// A bucket's label on the axis and in the table: a date, "Starting
/// 3 Nov" for weeks, a month or a year.
String bucketLabel(
  AppLocalizations l10n,
  String bucket,
  CashFlowReportSeriesGranularity granularity, {
  required String locale,
  bool spelled = false,
}) => switch (granularity) {
  CashFlowReportSeriesGranularity.month => LocalDates.displayMonth(
    bucket,
    locale: locale,
  ),
  CashFlowReportSeriesGranularity.year =>
    bucket.length >= 4 ? bucket.substring(0, 4) : bucket,
  CashFlowReportSeriesGranularity.week =>
    spelled
        ? l10n.trendBucketStarting(
            LocalDates.displayShort(bucket, locale: locale),
          )
        : LocalDates.displayShort(bucket, locale: locale),
  CashFlowReportSeriesGranularity.day ||
  CashFlowReportSeriesGranularity.unrecognized => LocalDates.displayShort(
    bucket,
    locale: locale,
  ),
};

/// The unit word of a server-chosen bucket size.
String seriesUnit(
  AppLocalizations l10n,
  CashFlowReportSeriesGranularity granularity,
) => switch (granularity) {
  CashFlowReportSeriesGranularity.week => l10n.trendUnitWeek,
  CashFlowReportSeriesGranularity.month => l10n.trendUnitMonth,
  CashFlowReportSeriesGranularity.year => l10n.trendUnitYear,
  CashFlowReportSeriesGranularity.day ||
  CashFlowReportSeriesGranularity.unrecognized => l10n.trendUnitDay,
};

/// A chip that shows the period and opens the period picker.
class PeriodChip extends StatelessWidget {
  /// Creates the chip.
  const PeriodChip({required this.range, required this.onChanged, super.key});

  /// The period shown.
  final DateRangeChoice range;

  /// Called with the newly chosen period.
  final ValueChanged<DateRangeChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ActionChip(
        avatar: const Icon(Icons.date_range_outlined, size: 18),
        label: Text(rangeChoiceLabel(l10n, range, locale: locale)),
        tooltip: l10n.dashboardChangePeriod,
        onPressed: () async {
          final DateRangeChoice? next = await showRangePicker(
            context,
            current: range,
          );
          if (next != null) {
            onChanged(next);
          }
        },
      ),
    );
  }
}

/// One chip per currency, with a note that currencies are never added
/// together. Shown only when there is more than one currency.
class CurrencyChips extends StatelessWidget {
  /// Creates the chips.
  const CurrencyChips({
    required this.currencies,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// Currencies with activity.
  final List<String> currencies;

  /// The currency shown.
  final String? selected;

  /// Called with the chosen currency.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (currencies.length < 2) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            l10n.dashboardCurrencyTitle,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: Insets.xs),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final String c in currencies)
              ChoiceChip(
                label: Text(c),
                selected: c == selected,
                tooltip: l10n.dashboardCurrencyChip(c),
                onSelected: (_) => onSelected(c),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: Insets.xs),
          child: Text(
            l10n.dashboardCurrencyNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// A label with an exact server amount and, optionally, the previous
/// period's amount.
class AnalyticsMoneyRow extends ConsumerWidget {
  /// Creates the row.
  const AnalyticsMoneyRow({
    required this.label,
    required this.money,
    this.flow = MoneyFlow.none,
    this.previous,
    super.key,
  });

  /// Label.
  final String label;

  /// Amount.
  final Money money;

  /// Direction shown with the amount.
  final MoneyFlow flow;

  /// The previous period's amount.
  final Money? previous;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String now = formatMoney(context, ref, money);
    final Money? before = previous;
    return DetailRow(
      label: label,
      semanticsValue: before == null
          ? now
          : l10n.dashboardWithPrevious(now, formatMoney(context, ref, before)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          MoneyText(
            money,
            flow: flow,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (before != null)
            Text(
              l10n.dashboardPreviousValue(formatMoney(context, ref, before)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// A short explanatory line inside a card.
class AnalyticsNote extends StatelessWidget {
  /// Creates the note.
  const AnalyticsNote(this.text, {super.key});

  /// Text.
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Insets.md, Insets.xs, Insets.md, 0),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

/// An empty card body.
class AnalyticsEmpty extends StatelessWidget {
  /// Creates the message.
  const AnalyticsEmpty(this.text, {super.key});

  /// Text.
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Insets.md,
      Insets.xs,
      Insets.md,
      Insets.md,
    ),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

/// The window of a report as `from – to`.
String windowText(Window window, String locale) =>
    LocalDates.displayRange(window.from, window.to, locale: locale);
