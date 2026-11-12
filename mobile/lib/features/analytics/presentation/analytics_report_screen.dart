import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/analytics/application/analytics_providers.dart';
import 'package:montra_mobile/features/analytics/domain/analytics_query.dart';
import 'package:montra_mobile/features/analytics/presentation/analytics_period_reports.dart';
import 'package:montra_mobile/features/analytics/presentation/analytics_state_reports.dart';
import 'package:montra_mobile/features/analytics/presentation/analytics_widgets.dart';

/// One analytics report (`/analytics/<report>`). Period reports (cash
/// flow, categories, expenses, income, merchants) take the period and
/// currency from the route's query string and show one currency at a
/// time; the others (accounts, budgets, goals, subscriptions, recurring)
/// describe the current state, each currency separately. Every chart has a
/// text summary and a "Show as a list" alternative.
class AnalyticsReportScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [report] (a route segment) with [query].
  const AnalyticsReportScreen({
    required this.report,
    this.query = const <String, String>{},
    super.key,
  });

  /// Route segment, e.g. `cash-flow`.
  final String report;

  /// Route query string values.
  final Map<String, String> query;

  @override
  ConsumerState<AnalyticsReportScreen> createState() =>
      _AnalyticsReportScreenState();
}

class _AnalyticsReportScreenState extends ConsumerState<AnalyticsReportScreen> {
  late AnalyticsQuery _query = AnalyticsQuery.fromQuery(widget.query);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AnalyticsReport? report = AnalyticsReport.fromSlug(widget.report);
    if (report == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.analyticsTitle)),
        body: MessageStateView(
          icon: Icons.insights_outlined,
          title: l10n.analyticsUnknownReport,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(analyticsReportTitle(l10n, report))),
      body: report.usesPeriod
          ? _PeriodReport(
              report: report,
              query: _query,
              onQuery: (AnalyticsQuery q) => setState(() => _query = q),
            )
          : StateReportBody(report: report),
    );
  }
}

/// A period report: period and currency on top, then the report in the
/// chosen currency.
class _PeriodReport extends ConsumerWidget {
  const _PeriodReport({
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
    final String locale = Localizations.localeOf(context).toString();
    final AsyncValue<CashFlowReport> overview = ref.watch(
      analyticsOverviewProvider(query.range),
    );
    final String? base = ref.watch(analyticsBaseCurrencyProvider);
    final CashFlowReport? data = overview.value;
    Future<void> retry() async {
      ref.invalidate(analyticsOverviewProvider(query.range));
    }

    if (data == null) {
      return overview.hasError && !overview.isLoading
          ? ErrorStateView(error: overview.error!, onRetry: retry)
          : LoadingStateView(label: l10n.analyticsLoading);
    }
    final List<String> currencies = reportCurrencies(data, base);
    final String? currency = pickCurrency(currencies, query.currency, base);
    final String period = windowText(data.window, locale);
    return ListView(
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
                range: query.range,
                onChanged: (DateRangeChoice r) =>
                    onQuery(query.copyWith(range: r)),
              ),
              const SizedBox(height: Insets.sm),
              CurrencyChips(
                currencies: currencies,
                selected: currency,
                onSelected: (String c) => onQuery(query.copyWith(currency: c)),
              ),
            ],
          ),
        ),
        ContentFrame(
          child: currency == null
              ? MessageStateView(
                  icon: Icons.insights_outlined,
                  title: l10n.dashboardNoActivity(period),
                  body: l10n.analyticsNoActivityBody,
                )
              : PeriodReportBody(
                  report: report,
                  query: query.copyWith(currency: currency),
                  onQuery: onQuery,
                ),
        ),
      ],
    );
  }
}
