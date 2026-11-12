import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/charts.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/features/dashboard/domain/widget_info.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_tile.dart';

/// Basis points (10000 = 100 %) as a percentage in [locale].
String formatBasisPoints(int bp, String locale) {
  try {
    return NumberFormat.decimalPercentPattern(
      locale: locale.replaceAll('-', '_'),
      decimalDigits: 1,
    ).format(bp / 10000);
  } on Object {
    return '${(bp / 100).toStringAsFixed(1)}%';
  }
}

/// Everything a widget card needs: the summary and the chosen currency.
@immutable
class DashboardContext {
  /// Creates the context.
  const DashboardContext({required this.summary, required this.currency});

  /// The computed dashboard.
  final DashboardSummary summary;

  /// The currency shown by per-currency widgets (never mixed).
  final String? currency;

  /// Cash flow totals in [currency].
  CashFlowTotals? get cashFlow => _inCurrency(summary.cashFlow);

  /// Previous-period totals in [currency].
  CashFlowTotals? get previous => _inCurrency(summary.previousCashFlow);

  CashFlowTotals? _inCurrency(List<CashFlowTotals>? list) {
    for (final CashFlowTotals c in list ?? const <CashFlowTotals>[]) {
      if (c.currency == currency) {
        return c;
      }
    }
    return null;
  }

  /// Trend points in [currency], oldest first.
  List<SeriesPoint> get trend => <SeriesPoint>[
    for (final SeriesPoint p in summary.trend)
      if (p.currency == currency) p,
  ]..sort((SeriesPoint a, SeriesPoint b) => a.bucket.compareTo(b.bucket));

  /// Category slices in [currency] (server order: largest first).
  List<CategorySlice> get categories => <CategorySlice>[
    for (final CategorySlice c in summary.topCategories)
      if (c.currency == currency) c,
  ];

  /// Merchant slices in [currency].
  List<MerchantSlice> get merchants => <MerchantSlice>[
    for (final MerchantSlice m in summary.topMerchants)
      if (m.currency == currency) m,
  ];

  /// The window as `from – to`.
  String windowLabel(String locale) => LocalDates.displayRange(
    summary.window.from,
    summary.window.to,
    locale: locale,
  );
}

/// Currencies that appear anywhere in [summary], base currency first.
List<String> dashboardCurrencies(DashboardSummary summary, String? base) {
  final List<String> found = <String>[];
  void add(String c) {
    if (!found.contains(c)) {
      found.add(c);
    }
  }

  for (final CashFlowTotals c in summary.cashFlow) {
    add(c.currency);
  }
  for (final BalanceTotals b in summary.balances) {
    add(b.currency);
  }
  found.sort();
  if (base != null && found.remove(base)) {
    found.insert(0, base);
  }
  return found;
}

/// The calculation notes in the user's language: each `note_codes` entry
/// is localized; an unknown code falls back to the server's English note at
/// the same position.
List<String> dashboardNotes(AppLocalizations l10n, DashboardSummary summary) {
  final List<DashboardSummaryNoteCodesItem> codes = summary.noteCodes;
  final List<String> english = summary.notes;
  final int count = codes.length > english.length
      ? codes.length
      : english.length;
  return <String>[
    for (int i = 0; i < count; i++)
      if (switch (i < codes.length
              ? codes[i]
              : DashboardSummaryNoteCodesItem.unrecognized) {
            DashboardSummaryNoteCodesItem.excludesTransfersAdjustments =>
              l10n.noteExcludesTransfers,
            DashboardSummaryNoteCodesItem.refundsReduceSpending =>
              l10n.noteRefundsReduceSpending,
            DashboardSummaryNoteCodesItem.currenciesSeparate =>
              l10n.noteCurrenciesSeparate,
            DashboardSummaryNoteCodesItem.balancesTrackedNotVerified =>
              l10n.noteBalancesTracked,
            DashboardSummaryNoteCodesItem.unrecognized =>
              i < english.length ? english[i] : null,
          }
          case final String note)
        note,
  ];
}

/// The card for widget [widgetKey].
class DashboardWidgetCard extends StatelessWidget {
  /// Creates the card.
  const DashboardWidgetCard({
    required this.widgetKey,
    required this.data,
    super.key,
  });

  /// Widget key.
  final WidgetDtoKey widgetKey;

  /// Dashboard data.
  final DashboardContext data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Widget body = switch (widgetKey) {
      WidgetDtoKey.balances => _Balances(data: data),
      WidgetDtoKey.cashFlow => _CashFlow(data: data),
      WidgetDtoKey.incomeVsExpense => _IncomeVsExpense(data: data),
      WidgetDtoKey.cashFlowTrend => _Trend(data: data),
      WidgetDtoKey.categoryBreakdown => _Categories(data: data),
      WidgetDtoKey.topMerchants => _Merchants(data: data),
      WidgetDtoKey.recentTransactions => _Recent(data: data),
      WidgetDtoKey.dataCoverage => _Coverage(data: data),
      WidgetDtoKey.unrecognized => const SizedBox.shrink(),
    };
    return SectionCard(
      title: widgetTitle(l10n, widgetKey),
      trailing: switch (widgetKey) {
        WidgetDtoKey.balances => TextButton(
          onPressed: () => context.push(AppRoutes.accounts),
          child: Text(l10n.dashboardViewAccounts),
        ),
        WidgetDtoKey.recentTransactions => TextButton(
          onPressed: () => context.go(AppRoutes.transactions),
          child: Text(
            l10n.actionSeeAll,
            semanticsLabel: l10n.dashboardSeeAllTransactions,
          ),
        ),
        _ => null,
      },
      children: <Widget>[body],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

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

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Insets.md,
      Insets.xs,
      Insets.md,
      Insets.sm,
    ),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _MoneyRow extends ConsumerWidget {
  const _MoneyRow({
    required this.label,
    required this.money,
    this.flow = MoneyFlow.none,
    this.previous,
  });

  final String label;
  final Money money;
  final MoneyFlow flow;
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

class _Balances extends ConsumerWidget {
  const _Balances({required this.data});

  final DashboardContext data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final List<BalanceTotals> totals = data.summary.balances;
    if (totals.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Empty(l10n.dashboardNoAccounts),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              0,
              Insets.md,
              Insets.md,
            ),
            child: OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.newAccount),
              icon: const Icon(Icons.add),
              label: Text(l10n.accountAdd),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final BalanceTotals t in totals) ...<Widget>[
          if (totals.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.sm,
                Insets.md,
                0,
              ),
              child: Text(
                l10n.currencyHeading(t.currency),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          _MoneyRow(label: l10n.netWorthLabel, money: t.netWorth),
          _MoneyRow(label: l10n.assetsLabel, money: t.assets),
          _MoneyRow(label: l10n.liabilitiesLabel, money: t.liabilities),
          _Note(l10n.dashboardAccountCount(t.accountCount)),
        ],
        _Note(
          data.summary.coverage.providerSynced
              ? l10n.providerBalanceNote
              : l10n.trackedBalanceNote,
        ),
      ],
    );
  }
}

class _CashFlow extends ConsumerWidget {
  const _CashFlow({required this.data});

  final DashboardContext data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final CashFlowTotals? c = data.cashFlow;
    if (c == null || c.transactionCount == 0) {
      return _Empty(l10n.dashboardNoActivity(data.windowLabel(locale)));
    }
    final CashFlowTotals? p = data.previous;
    final bool positive = c.netCashFlow.amountMinor >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Note(data.windowLabel(locale)),
        _MoneyRow(
          label: l10n.incomeLabel,
          money: c.income,
          flow: MoneyFlow.inflow,
          previous: p?.income,
        ),
        _MoneyRow(
          label: l10n.spendingLabel,
          money: c.netExpense,
          flow: MoneyFlow.outflow,
          previous: p?.netExpense,
        ),
        if (c.refunds.amountMinor > 0)
          _Note(
            l10n.dashboardSpendingDetail(
              formatMoney(context, ref, c.grossExpense),
              formatMoney(context, ref, c.refunds),
            ),
          ),
        _MoneyRow(
          label: l10n.netCashFlowLabel,
          money: c.netCashFlow,
          previous: p?.netCashFlow,
        ),
        _Note(positive ? l10n.netCashFlowPositive : l10n.netCashFlowNegative),
        if (c.savingsRateBp case final int bp)
          DetailRow(
            label: l10n.savingsRateLabel,
            value: formatBasisPoints(bp, numberLocaleOf(context, ref)),
          ),
        _Note(l10n.dashboardTransactionCount(c.transactionCount)),
        if (p != null) _Note(l10n.dashboardPreviousExplained),
      ],
    );
  }
}

class _IncomeVsExpense extends ConsumerWidget {
  const _IncomeVsExpense({required this.data});

  final DashboardContext data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final CashFlowTotals? c = data.cashFlow;
    if (c == null || c.transactionCount == 0) {
      return _Empty(l10n.dashboardNoActivity(data.windowLabel(locale)));
    }
    final String income = formatMoney(context, ref, c.income);
    final String spending = formatMoney(context, ref, c.netExpense);
    final int max = c.income.amountMinor > c.netExpense.amountMinor
        ? c.income.amountMinor
        : c.netExpense.amountMinor;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: AccessibleChart(
        summary: l10n.incomeVsExpenseSummary(
          data.windowLabel(locale),
          income,
          spending,
        ),
        chart: HorizontalBars(
          entries: <BarEntry>[
            BarEntry(
              label: l10n.incomeLabel,
              valueText: income,
              fraction: barFraction(c.income.amountMinor, max),
            ),
            BarEntry(
              label: l10n.spendingLabel,
              valueText: spending,
              fraction: barFraction(c.netExpense.amountMinor, max),
              style: BarStyle.outlined,
            ),
          ],
        ),
        legend: Wrap(
          spacing: Insets.md,
          runSpacing: Insets.xs,
          children: <Widget>[
            LegendItem(style: BarStyle.filled, label: l10n.incomeLabel),
            LegendItem(style: BarStyle.outlined, label: l10n.spendingLabel),
          ],
        ),
        table: Column(
          children: <Widget>[
            _MoneyRow(label: l10n.incomeLabel, money: c.income),
            _MoneyRow(label: l10n.spendingLabel, money: c.netExpense),
            _MoneyRow(label: l10n.netCashFlowLabel, money: c.netCashFlow),
          ],
        ),
      ),
    );
  }
}

class _Trend extends ConsumerWidget {
  const _Trend({required this.data});

  final DashboardContext data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final List<SeriesPoint> points = data.trend;
    final bool any = points.any(
      (SeriesPoint p) =>
          p.income.amountMinor != 0 || p.netExpense.amountMinor != 0,
    );
    if (!any) {
      return _Empty(l10n.dashboardNoActivity(data.windowLabel(locale)));
    }
    // The server reports the bucket size (weeks start on Monday).
    final DashboardSummaryTrendGranularity granularity =
        data.summary.trendGranularity;
    String label(String bucket) => switch (granularity) {
      DashboardSummaryTrendGranularity.month => LocalDates.displayMonth(
        bucket,
        locale: locale,
      ),
      DashboardSummaryTrendGranularity.year =>
        bucket.length >= 4 ? bucket.substring(0, 4) : bucket,
      DashboardSummaryTrendGranularity.day ||
      DashboardSummaryTrendGranularity.week ||
      DashboardSummaryTrendGranularity.unrecognized => LocalDates.displayShort(
        bucket,
        locale: locale,
      ),
    };
    final String unit = switch (granularity) {
      DashboardSummaryTrendGranularity.week => l10n.trendUnitWeek,
      DashboardSummaryTrendGranularity.month => l10n.trendUnitMonth,
      DashboardSummaryTrendGranularity.year => l10n.trendUnitYear,
      DashboardSummaryTrendGranularity.day ||
      DashboardSummaryTrendGranularity.unrecognized => l10n.trendUnitDay,
    };
    int max = 0;
    SeriesPoint top = points.first;
    for (final SeriesPoint p in points) {
      if (p.income.amountMinor > max) {
        max = p.income.amountMinor;
      }
      if (p.netExpense.amountMinor > max) {
        max = p.netExpense.amountMinor;
      }
      if (p.netExpense.amountMinor > top.netExpense.amountMinor) {
        top = p;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: AccessibleChart(
        summary: l10n.trendSummary(
          unit,
          data.windowLabel(locale),
          points.length,
          formatMoney(context, ref, top.netExpense),
          granularity == DashboardSummaryTrendGranularity.week
              ? l10n.trendBucketStarting(label(top.bucket))
              : label(top.bucket),
        ),
        chart: GroupedColumns(
          styles: const <BarStyle>[BarStyle.filled, BarStyle.outlined],
          groups: <ColumnGroup>[
            for (final SeriesPoint p in points)
              ColumnGroup(
                label: label(p.bucket),
                fractions: <double>[
                  barFraction(p.income.amountMinor, max),
                  barFraction(p.netExpense.amountMinor, max),
                ],
              ),
          ],
        ),
        legend: Wrap(
          spacing: Insets.md,
          runSpacing: Insets.xs,
          children: <Widget>[
            LegendItem(style: BarStyle.filled, label: l10n.incomeLabel),
            LegendItem(style: BarStyle.outlined, label: l10n.spendingLabel),
          ],
        ),
        table: Column(
          children: <Widget>[
            for (final SeriesPoint p in points)
              DetailRow(
                label: granularity == DashboardSummaryTrendGranularity.week
                    ? l10n.trendBucketStarting(label(p.bucket))
                    : label(p.bucket),
                value: l10n.trendRow(
                  formatMoney(context, ref, p.income),
                  formatMoney(context, ref, p.netExpense),
                  formatMoney(context, ref, p.net),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens a server drill-down path when it points at the transactions list
/// (the only target this app accepts from data).
void openDrillDown(BuildContext context, String path) {
  final Uri? uri = Uri.tryParse(path);
  if (uri == null || uri.path != AppRoutes.transactions || uri.hasScheme) {
    return;
  }
  context.go(TransactionFilter.fromQuery(uri.queryParameters).toLocation());
}

class _Categories extends ConsumerWidget {
  const _Categories({required this.data});

  final DashboardContext data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final String numberLocale = numberLocaleOf(context, ref);
    final List<CategorySlice> slices = data.categories;
    if (slices.isEmpty) {
      return _Empty(l10n.dashboardNoSpending(data.windowLabel(locale)));
    }
    String name(CategorySlice s) => categorySliceName(l10n, s);
    final CategorySlice top = slices.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: AccessibleChart(
        summary: l10n.categorySummary(
          name(top),
          formatMoney(context, ref, top.netExpense),
          formatBasisPoints(top.shareBp, numberLocale),
          slices.length,
        ),
        chart: HorizontalBars(
          entries: <BarEntry>[
            for (final CategorySlice s in slices)
              BarEntry(
                label: name(s),
                valueText: formatMoney(context, ref, s.netExpense),
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
                  formatMoney(context, ref, s.netExpense),
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

class _Merchants extends ConsumerWidget {
  const _Merchants({required this.data});

  final DashboardContext data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final List<MerchantSlice> merchants = data.merchants;
    if (merchants.isEmpty) {
      return _Empty(l10n.dashboardNoMerchants(data.windowLabel(locale)));
    }
    return Column(
      children: <Widget>[
        for (final MerchantSlice m in merchants)
          ListTile(
            leading: const ExcludeSemantics(
              child: Icon(Icons.storefront_outlined),
            ),
            title: Text(m.name),
            subtitle: Text(l10n.merchantTransactionCount(m.count)),
            trailing: MoneyText(
              m.netExpense,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            onTap: m.merchantId == null
                ? null
                : () => context.go(
                    TransactionFilter(
                      merchantId: m.merchantId,
                      from: data.summary.window.from,
                      to: data.summary.window.to,
                    ).toLocation(),
                  ),
          ),
      ],
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.data});

  final DashboardContext data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<TransactionDto> recent = data.summary.recentTransactions;
    if (recent.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Empty(l10n.dashboardNoRecent),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              0,
              Insets.md,
              Insets.md,
            ),
            child: OutlinedButton.icon(
              onPressed: () =>
                  context.push(AppRoutes.newTransactionOf('expense')),
              icon: const Icon(Icons.add),
              label: Text(l10n.transactionAddExpense),
            ),
          ),
        ],
      );
    }
    return Column(
      children: <Widget>[
        for (final TransactionDto t in recent)
          TransactionTile(
            transaction: t,
            onTap: () => context.push(AppRoutes.transactionDetail(t.id)),
          ),
      ],
    );
  }
}

class _Coverage extends StatelessWidget {
  const _Coverage({required this.data});

  final DashboardContext data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final Coverage c = data.summary.coverage;
    final List<String> notes = dashboardNotes(l10n, data.summary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DetailRow(
          label: l10n.coverageTransactions,
          value: l10n.coverageTransactionCount(c.transactionCount),
        ),
        if (c.earliestTransaction != null && c.latestTransaction != null)
          DetailRow(
            label: l10n.coverageSpan,
            value: LocalDates.displayRange(
              c.earliestTransaction!,
              c.latestTransaction!,
              locale: locale,
            ),
          ),
        DetailRow(
          label: l10n.coverageUncategorized,
          value: '${c.uncategorizedCount}',
        ),
        DetailRow(label: l10n.coveragePending, value: '${c.pendingCount}'),
        DetailRow(
          label: l10n.coverageLastImport,
          value: c.lastImportAt == null
              ? l10n.coverageNoImports
              : formatDateTime(c.lastImportAt!, locale: locale),
        ),
        _Note(
          c.providerSynced ? l10n.providerBalanceNote : l10n.trackedBalanceNote,
        ),
        if (notes.isNotEmpty)
          ExpansionTile(
            title: Text(l10n.dashboardHowCalculated),
            childrenPadding: const EdgeInsets.fromLTRB(
              Insets.md,
              0,
              Insets.md,
              Insets.md,
            ),
            children: <Widget>[
              for (final String note in notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: Insets.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const ExcludeSemantics(child: Text('•  ')),
                      Expanded(child: Text(note)),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
