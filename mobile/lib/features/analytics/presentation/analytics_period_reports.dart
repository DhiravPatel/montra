import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/widgets/charts.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/analytics/application/analytics_providers.dart';
import 'package:montra_mobile/features/analytics/domain/analytics_query.dart';
import 'package:montra_mobile/features/analytics/presentation/analytics_screen.dart';
import 'package:montra_mobile/features/analytics/presentation/analytics_widgets.dart';
import 'package:montra_mobile/features/dashboard/presentation/dashboard_widgets.dart'
    show formatBasisPoints, openDrillDown;
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';

/// The body of a period report for one currency ([query] has it).
class PeriodReportBody extends ConsumerWidget {
  /// Creates the body.
  const PeriodReportBody({
    required this.report,
    required this.query,
    required this.onQuery,
    super.key,
  });

  /// The report.
  final AnalyticsReport report;

  /// Period, currency (set) and bucket size.
  final AnalyticsQuery query;

  /// Changes the query (bucket size, subcategories).
  final ValueChanged<AnalyticsQuery> onQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (report) {
    AnalyticsReport.categories => _CategoriesReport(query: query),
    AnalyticsReport.merchants => _MerchantsReport(query: query),
    _ => _SeriesReport(report: report, query: query, onQuery: onQuery),
  };
}

/// Shows [value] in a card-sized area: the data, or loading / error with a
/// retry.
class _Loaded<T> extends StatelessWidget {
  const _Loaded({
    required this.value,
    required this.onRetry,
    required this.builder,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    final T? data = value.value;
    if (value.hasError && !value.isLoading) {
      return SizedBox(
        height: 320,
        child: ErrorStateView(error: value.error!, onRetry: onRetry),
      );
    }
    if (data == null) {
      return const SizedBox(height: 200, child: LoadingStateView());
    }
    return builder(data);
  }
}

/// Cash flow, expenses or income over time.
class _SeriesReport extends ConsumerWidget {
  const _SeriesReport({
    required this.report,
    required this.query,
    required this.onQuery,
  });

  final AnalyticsReport report;
  final AnalyticsQuery query;
  final ValueChanged<AnalyticsQuery> onQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final SeriesArgs args = (
      report: report,
      range: query.range,
      currency: query.currency!,
      granularity: query.granularity,
    );
    return _Loaded<CashFlowReport>(
      value: ref.watch(analyticsSeriesProvider(args)),
      onRetry: () => ref.invalidate(analyticsSeriesProvider(args)),
      builder: (CashFlowReport data) {
        final String currency = query.currency!;
        final CashFlowTotals? now = totalsIn(data.totals, currency);
        final CashFlowTotals? before = totalsIn(data.previousPeriod, currency);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionCard(
              title: l10n.currencyHeading(currency),
              children: <Widget>[
                if (now == null || now.transactionCount == 0)
                  AnalyticsEmpty(
                    l10n.dashboardNoActivity(
                      windowText(
                        data.window,
                        Localizations.localeOf(context).toString(),
                      ),
                    ),
                  )
                else
                  _SeriesTotals(report: report, now: now, before: before),
                const SizedBox(height: Insets.sm),
              ],
            ),
            const SizedBox(height: Insets.md),
            _GranularityChips(
              selected: query.granularity,
              onSelected: (String? g) => onQuery(
                g == null
                    ? query.copyWith(clearGranularity: true)
                    : query.copyWith(granularity: g),
              ),
            ),
            const SizedBox(height: Insets.sm),
            SectionCard(
              title: l10n.analyticsOverTimeTitle,
              children: <Widget>[
                _SeriesChart(report: report, data: data, currency: currency),
              ],
            ),
            if (report == AnalyticsReport.cashFlow) ...<Widget>[
              const SizedBox(height: Insets.md),
              _CoverageCard(coverage: data.coverage),
            ],
          ],
        );
      },
    );
  }
}

/// The totals a series report highlights.
class _SeriesTotals extends ConsumerWidget {
  const _SeriesTotals({
    required this.report,
    required this.now,
    required this.before,
  });

  final AnalyticsReport report;
  final CashFlowTotals now;
  final CashFlowTotals? before;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return switch (report) {
      AnalyticsReport.expenses => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AnalyticsMoneyRow(
            label: l10n.spendingLabel,
            money: now.netExpense,
            flow: MoneyFlow.outflow,
            previous: before?.netExpense,
          ),
          AnalyticsMoneyRow(
            label: l10n.analyticsGrossSpendingLabel,
            money: now.grossExpense,
            previous: before?.grossExpense,
          ),
          AnalyticsMoneyRow(
            label: l10n.analyticsRefundsLabel,
            money: now.refunds,
            flow: MoneyFlow.inflow,
            previous: before?.refunds,
          ),
          AnalyticsNote(l10n.dashboardTransactionCount(now.transactionCount)),
        ],
      ),
      AnalyticsReport.income => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AnalyticsMoneyRow(
            label: l10n.incomeLabel,
            money: now.income,
            flow: MoneyFlow.inflow,
            previous: before?.income,
          ),
          AnalyticsNote(l10n.dashboardTransactionCount(now.transactionCount)),
        ],
      ),
      _ => CashFlowRows(totals: now, previous: before),
    };
  }
}

class _GranularityChips extends StatelessWidget {
  const _GranularityChips({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            l10n.analyticsGranularityLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: Insets.xs),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final String? g in <String?>[null, ...analyticsGranularities])
              ChoiceChip(
                label: Text(granularityChoiceLabel(l10n, g)),
                selected: g == selected,
                onSelected: (_) => onSelected(g),
              ),
          ],
        ),
      ],
    );
  }
}

/// Income and spending per bucket (cash flow), or one series (expenses,
/// income), with a summary and a list of every value.
class _SeriesChart extends ConsumerWidget {
  const _SeriesChart({
    required this.report,
    required this.data,
    required this.currency,
  });

  final AnalyticsReport report;
  final CashFlowReport data;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final String period = windowText(data.window, locale);
    final List<SeriesPoint> points = <SeriesPoint>[
      for (final SeriesPoint p in data.series)
        if (p.currency == currency) p,
    ]..sort((SeriesPoint a, SeriesPoint b) => a.bucket.compareTo(b.bucket));
    final bool showIncome = report != AnalyticsReport.expenses;
    final bool showSpending = report != AnalyticsReport.income;
    final bool any = points.any(
      (SeriesPoint p) =>
          (showIncome && p.income.amountMinor != 0) ||
          (showSpending && p.netExpense.amountMinor != 0),
    );
    if (!any) {
      return AnalyticsEmpty(l10n.dashboardNoActivity(period));
    }
    final CashFlowReportSeriesGranularity g = data.seriesGranularity;
    final String unit = seriesUnit(l10n, g);
    String axis(SeriesPoint p) =>
        bucketLabel(l10n, p.bucket, g, locale: locale);
    String spelled(SeriesPoint p) =>
        bucketLabel(l10n, p.bucket, g, locale: locale, spelled: true);
    int max = 0;
    SeriesPoint topSpending = points.first;
    SeriesPoint topIncome = points.first;
    for (final SeriesPoint p in points) {
      if (showIncome && p.income.amountMinor > max) {
        max = p.income.amountMinor;
      }
      if (showSpending && p.netExpense.amountMinor > max) {
        max = p.netExpense.amountMinor;
      }
      if (p.netExpense.amountMinor > topSpending.netExpense.amountMinor) {
        topSpending = p;
      }
      if (p.income.amountMinor > topIncome.income.amountMinor) {
        topIncome = p;
      }
    }
    final String summary = switch (report) {
      AnalyticsReport.expenses => l10n.analyticsExpensesSummary(
        unit,
        period,
        formatMoney(context, ref, topSpending.netExpense),
        spelled(topSpending),
      ),
      AnalyticsReport.income => l10n.analyticsIncomeSummary(
        unit,
        period,
        formatMoney(context, ref, topIncome.income),
        spelled(topIncome),
      ),
      _ => l10n.trendSummary(
        unit,
        period,
        points.length,
        formatMoney(context, ref, topSpending.netExpense),
        spelled(topSpending),
      ),
    };
    final List<BarStyle> styles = <BarStyle>[
      if (showIncome) BarStyle.filled,
      if (showSpending) BarStyle.outlined,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: AccessibleChart(
        summary: summary,
        chart: GroupedColumns(
          styles: styles,
          groups: <ColumnGroup>[
            for (final SeriesPoint p in points)
              ColumnGroup(
                label: axis(p),
                fractions: <double>[
                  if (showIncome) barFraction(p.income.amountMinor, max),
                  if (showSpending) barFraction(p.netExpense.amountMinor, max),
                ],
              ),
          ],
        ),
        legend: Wrap(
          spacing: Insets.md,
          runSpacing: Insets.xs,
          children: <Widget>[
            if (showIncome)
              LegendItem(style: BarStyle.filled, label: l10n.incomeLabel),
            if (showSpending)
              LegendItem(style: BarStyle.outlined, label: l10n.spendingLabel),
          ],
        ),
        table: Column(
          children: <Widget>[
            for (final SeriesPoint p in points)
              DetailRow(
                label: spelled(p),
                value: switch (report) {
                  AnalyticsReport.expenses => formatMoney(
                    context,
                    ref,
                    p.netExpense,
                  ),
                  AnalyticsReport.income => formatMoney(context, ref, p.income),
                  _ => l10n.trendRow(
                    formatMoney(context, ref, p.income),
                    formatMoney(context, ref, p.netExpense),
                    formatMoney(context, ref, p.net),
                  ),
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// What the figures are based on.
class _CoverageCard extends StatelessWidget {
  const _CoverageCard({required this.coverage});

  final Coverage coverage;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SectionCard(
      title: l10n.dashboardHowCalculated,
      children: <Widget>[
        DetailRow(
          label: l10n.coverageUncategorized,
          value: '${coverage.uncategorizedCount}',
        ),
        DetailRow(
          label: l10n.coveragePending,
          value: '${coverage.pendingCount}',
        ),
        AnalyticsNote(l10n.noteExcludesTransfers),
        AnalyticsNote(l10n.noteRefundsReduceSpending),
        AnalyticsNote(
          coverage.providerSynced
              ? l10n.providerBalanceNote
              : l10n.trackedBalanceNote,
        ),
        const SizedBox(height: Insets.sm),
      ],
    );
  }
}

/// Spending or income by category, with an option to keep subcategories
/// separate.
class _CategoriesReport extends ConsumerStatefulWidget {
  const _CategoriesReport({required this.query});

  final AnalyticsQuery query;

  @override
  ConsumerState<_CategoriesReport> createState() => _CategoriesReportState();
}

class _CategoriesReportState extends ConsumerState<_CategoriesReport> {
  bool _subcategories = false;
  bool _income = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CategoryArgs args = (
      range: widget.query.range,
      currency: widget.query.currency!,
      subcategories: _subcategories,
      income: _income,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentedButton<bool>(
          segments: <ButtonSegment<bool>>[
            ButtonSegment<bool>(
              value: false,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(l10n.analyticsCategoriesSpending),
            ),
            ButtonSegment<bool>(
              value: true,
              icon: const Icon(Icons.savings_outlined),
              label: Text(l10n.analyticsCategoriesIncome),
            ),
          ],
          selected: <bool>{_income},
          onSelectionChanged: (Set<bool> s) =>
              setState(() => _income = s.first),
        ),
        SwitchListTile(
          value: _subcategories,
          title: Text(l10n.analyticsShowSubcategories),
          subtitle: Text(l10n.analyticsShowSubcategoriesHelp),
          onChanged: (bool v) => setState(() => _subcategories = v),
        ),
        _Loaded<CategoryReport>(
          value: ref.watch(analyticsCategoriesProvider(args)),
          onRetry: () => ref.invalidate(analyticsCategoriesProvider(args)),
          builder: (CategoryReport data) => SectionCard(
            title: l10n.currencyHeading(args.currency),
            children: <Widget>[
              _CategoryChart(
                slices: <CategorySlice>[
                  for (final CategorySlice s in data.categories)
                    if (s.currency == args.currency) s,
                ],
                window: data.window,
                income: data.kind == CategoryReportKind.income,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryChart extends ConsumerWidget {
  const _CategoryChart({
    required this.slices,
    required this.window,
    this.income = false,
  });

  final List<CategorySlice> slices;
  final Window window;

  /// Whether the slices are income (`kind=income`) rather than spending.
  final bool income;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final String numberLocale = numberLocaleOf(context, ref);
    if (slices.isEmpty) {
      return AnalyticsEmpty(
        income
            ? l10n.analyticsNoIncome(windowText(window, locale))
            : l10n.dashboardNoSpending(windowText(window, locale)),
      );
    }
    String name(CategorySlice s) => categorySliceName(l10n, s);
    final CategorySlice top = slices.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: AccessibleChart(
        summary: (income ? l10n.categoryIncomeSummary : l10n.categorySummary)(
          name(top),
          formatMoney(context, ref, top.amount),
          formatBasisPoints(top.shareBp, numberLocale),
          slices.length,
        ),
        chart: HorizontalBars(
          entries: <BarEntry>[
            for (final CategorySlice s in slices)
              BarEntry(
                label: name(s),
                valueText: formatMoney(context, ref, s.amount),
                detail: l10n.categoryShareDetail(
                  formatBasisPoints(s.shareBp, numberLocale),
                  s.count,
                ),
                fraction: s.shareBp / 10000,
                onTap: () => openDrillDown(context, s.drillDownPath),
              ),
          ],
        ),
        table: Column(
          children: <Widget>[
            for (final CategorySlice s in slices)
              DetailRow(
                label: name(s),
                value: l10n.categoryTableValue(
                  formatMoney(context, ref, s.amount),
                  formatBasisPoints(s.shareBp, numberLocale),
                ),
                onTap: () => openDrillDown(context, s.drillDownPath),
              ),
          ],
        ),
      ),
    );
  }
}

/// Top merchants by net spending in one currency.
class _MerchantsReport extends ConsumerWidget {
  const _MerchantsReport({required this.query});

  final AnalyticsQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final MerchantArgs args = (range: query.range, currency: query.currency!);
    return _Loaded<MerchantReport>(
      value: ref.watch(analyticsMerchantsProvider(args)),
      onRetry: () => ref.invalidate(analyticsMerchantsProvider(args)),
      builder: (MerchantReport data) {
        final List<MerchantSlice> merchants = <MerchantSlice>[
          for (final MerchantSlice m in data.merchants)
            if (m.currency == args.currency) m,
        ];
        void open(MerchantSlice m) {
          final String? id = m.merchantId;
          if (id == null) {
            return;
          }
          context.go(
            TransactionFilter(
              merchantId: id,
              from: data.window.from,
              to: data.window.to,
            ).toLocation(),
          );
        }

        if (merchants.isEmpty) {
          return SectionCard(
            title: l10n.currencyHeading(args.currency),
            children: <Widget>[
              AnalyticsEmpty(
                l10n.dashboardNoMerchants(windowText(data.window, locale)),
              ),
            ],
          );
        }
        final int max = merchants.first.netExpense.amountMinor;
        final MerchantSlice top = merchants.first;
        return SectionCard(
          title: l10n.currencyHeading(args.currency),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: AccessibleChart(
                summary: l10n.analyticsMerchantsSummary(
                  top.name,
                  formatMoney(context, ref, top.netExpense),
                  merchants.length,
                ),
                chart: HorizontalBars(
                  entries: <BarEntry>[
                    for (final MerchantSlice m in merchants)
                      BarEntry(
                        label: m.name,
                        valueText: formatMoney(context, ref, m.netExpense),
                        detail: l10n.merchantTransactionCount(m.count),
                        fraction: barFraction(m.netExpense.amountMinor, max),
                        onTap: m.merchantId == null ? null : () => open(m),
                      ),
                  ],
                ),
                table: Column(
                  children: <Widget>[
                    for (final MerchantSlice m in merchants)
                      DetailRow(
                        label: m.name,
                        value: l10n.analyticsMerchantRow(
                          formatMoney(context, ref, m.netExpense),
                          m.count,
                        ),
                        onTap: m.merchantId == null ? null : () => open(m),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
