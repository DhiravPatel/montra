import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/analytics/application/analytics_providers.dart';
import 'package:montra_mobile/features/analytics/domain/analytics_query.dart';
import 'package:montra_mobile/features/analytics/presentation/analytics_widgets.dart';
import 'package:montra_mobile/features/dashboard/presentation/dashboard_widgets.dart'
    show formatBasisPoints;

/// Analytics overview: a period picker, one currency at a time, the
/// period's income, spending and net cash flow (from
/// `GET /analytics/cash-flow`), and links to every report. Amounts in
/// different currencies are never added together.
class AnalyticsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  AnalyticsQuery _query = const AnalyticsQuery();

  Future<void> _refresh() async {
    ref.invalidate(analyticsOverviewProvider(_query.range));
    try {
      await ref.read(analyticsOverviewProvider(_query.range).future);
    } on Object {
      // Shown by the screen state.
    }
  }

  void _open(AnalyticsReport report, String? currency) {
    context.push(
      AppRoutes.analyticsReport(
        report.slug,
        query: _query.copyWith(currency: currency).toQuery(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<CashFlowReport> overview = ref.watch(
      analyticsOverviewProvider(_query.range),
    );
    final String? base = ref.watch(analyticsBaseCurrencyProvider);
    final CashFlowReport? data = overview.value;
    final List<String> currencies = data == null
        ? const <String>[]
        : reportCurrencies(data, base);
    final String? currency = pickCurrency(currencies, _query.currency, base);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.analyticsTitle),
        bottom: overview.isLoading && overview.hasValue
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: <Widget>[
          IconButton(
            tooltip: l10n.analyticsCompareTitle,
            icon: const Icon(Icons.compare_arrows),
            onPressed: () => context.push(
              Uri(
                path: AppRoutes.analyticsCompare,
                queryParameters: _query.copyWith(currency: currency).toQuery(),
              ).toString(),
            ),
          ),
        ],
      ),
      body: data == null
          ? (overview.hasError && !overview.isLoading
                ? ErrorStateView(error: overview.error!, onRetry: _refresh)
                : LoadingStateView(label: l10n.analyticsLoading))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: Insets.xl),
                children: <Widget>[
                  ContentFrame(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.md,
                      Insets.sm,
                      Insets.md,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        PeriodChip(
                          range: _query.range,
                          onChanged: (DateRangeChoice r) => setState(
                            () => _query = _query.copyWith(range: r),
                          ),
                        ),
                        const SizedBox(height: Insets.sm),
                        CurrencyChips(
                          currencies: currencies,
                          selected: currency,
                          onSelected: (String c) => setState(
                            () => _query = _query.copyWith(currency: c),
                          ),
                        ),
                        if (currencies.length > 1)
                          const SizedBox(height: Insets.sm),
                        _Summary(report: data, currency: currency),
                      ],
                    ),
                  ),
                  ContentFrame(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.md,
                      Insets.md,
                      Insets.md,
                      0,
                    ),
                    child: SectionCard(
                      title: l10n.analyticsPeriodReportsTitle,
                      children: <Widget>[
                        for (final AnalyticsReport r in AnalyticsReport.values)
                          if (r.usesPeriod)
                            _ReportTile(
                              report: r,
                              onTap: () => _open(r, currency),
                            ),
                        ListTile(
                          leading: const ExcludeSemantics(
                            child: Icon(Icons.compare_arrows),
                          ),
                          title: Text(l10n.analyticsCompareTitle),
                          subtitle: Text(l10n.analyticsCompareSubtitle),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                            Uri(
                              path: AppRoutes.analyticsCompare,
                              queryParameters: _query
                                  .copyWith(currency: currency)
                                  .toQuery(),
                            ).toString(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ContentFrame(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.md,
                      Insets.md,
                      Insets.md,
                      0,
                    ),
                    child: SectionCard(
                      title: l10n.analyticsNowTitle,
                      children: <Widget>[
                        for (final AnalyticsReport r in AnalyticsReport.values)
                          if (!r.usesPeriod)
                            _ReportTile(report: r, onTap: () => _open(r, null)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report, required this.onTap});

  final AnalyticsReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ListTile(
      leading: ExcludeSemantics(child: Icon(analyticsReportIcon(report))),
      title: Text(analyticsReportTitle(l10n, report)),
      subtitle: Text(analyticsReportSubtitle(l10n, report)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// The period's totals in [currency]: income, spending, net cash flow and
/// savings rate, each with the previous period's value.
class _Summary extends ConsumerWidget {
  const _Summary({required this.report, required this.currency});

  final CashFlowReport report;
  final String? currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final String period = windowText(report.window, locale);
    final CashFlowTotals? now = totalsIn(report.totals, currency);
    if (now == null || now.transactionCount == 0) {
      return SectionCard(
        title: l10n.analyticsSummaryTitle,
        children: <Widget>[
          AnalyticsEmpty(l10n.dashboardNoActivity(period)),
          AnalyticsEmpty(l10n.analyticsNoActivityBody),
        ],
      );
    }
    final CashFlowTotals? before = totalsIn(report.previousPeriod, currency);
    return SectionCard(
      title: l10n.analyticsSummaryTitle,
      children: <Widget>[
        AnalyticsNote(period),
        CashFlowRows(totals: now, previous: before),
        if (before != null)
          AnalyticsNote(
            l10n.analyticsPreviousWindow(
              windowText(report.previousWindow, locale),
            ),
          ),
        const SizedBox(height: Insets.sm),
      ],
    );
  }
}

/// The totals in [currency] from a per-currency list, or null.
CashFlowTotals? totalsIn(List<CashFlowTotals> list, String? currency) {
  for (final CashFlowTotals t in list) {
    if (t.currency == currency) {
      return t;
    }
  }
  return null;
}

/// Income, spending (with refunds explained), net cash flow, savings rate
/// and the transaction count of one currency.
class CashFlowRows extends ConsumerWidget {
  /// Creates the rows.
  const CashFlowRows({required this.totals, this.previous, super.key});

  /// Totals of the period.
  final CashFlowTotals totals;

  /// Totals of the previous period of the same length.
  final CashFlowTotals? previous;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final CashFlowTotals c = totals;
    final CashFlowTotals? p = previous;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AnalyticsMoneyRow(
          label: l10n.incomeLabel,
          money: c.income,
          flow: MoneyFlow.inflow,
          previous: p?.income,
        ),
        AnalyticsMoneyRow(
          label: l10n.spendingLabel,
          money: c.netExpense,
          flow: MoneyFlow.outflow,
          previous: p?.netExpense,
        ),
        if (c.refunds.amountMinor > 0)
          AnalyticsNote(
            l10n.dashboardSpendingDetail(
              formatMoney(context, ref, c.grossExpense),
              formatMoney(context, ref, c.refunds),
            ),
          ),
        AnalyticsMoneyRow(
          label: l10n.netCashFlowLabel,
          money: c.netCashFlow,
          previous: p?.netCashFlow,
        ),
        AnalyticsNote(
          c.netCashFlow.amountMinor >= 0
              ? l10n.netCashFlowPositive
              : l10n.netCashFlowNegative,
        ),
        if (c.savingsRateBp case final int bp)
          DetailRow(
            label: l10n.savingsRateLabel,
            value: formatBasisPoints(bp, numberLocaleOf(context, ref)),
          ),
        AnalyticsNote(l10n.dashboardTransactionCount(c.transactionCount)),
      ],
    );
  }
}
