import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/charts.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/analytics/application/analytics_providers.dart';
import 'package:montra_mobile/features/analytics/domain/analytics_query.dart';
import 'package:montra_mobile/features/analytics/presentation/analytics_widgets.dart';
import 'package:montra_mobile/features/dashboard/presentation/dashboard_widgets.dart'
    show formatBasisPoints;
import 'package:montra_mobile/features/labels/domain/label_display.dart';

/// The comparison's notes in the user's language: by `note_codes` (in the
/// order of the English `notes`); a code this app does not know keeps the
/// English note.
List<String> comparisonNotes(AppLocalizations l10n, Comparison data) {
  final List<ComparisonNoteCodesItem> codes = data.noteCodes;
  if (codes.isEmpty) {
    return data.notes;
  }
  return <String>[
    for (int i = 0; i < codes.length; i++)
      switch (codes[i]) {
        ComparisonNoteCodesItem.sameFiltersAndRules =>
          l10n.analyticsCompareNoteSameRules,
        ComparisonNoteCodesItem.comparedAsTotals =>
          l10n.analyticsCompareNoteTotals,
        ComparisonNoteCodesItem.currenciesSeparate =>
          l10n.analyticsCompareNoteCurrencies,
        ComparisonNoteCodesItem.unrecognized =>
          i < data.notes.length ? data.notes[i] : '',
      },
  ].where((String n) => n.isNotEmpty).toList();
}

/// Compares a period with another one (`GET /analytics/compare`): totals
/// per currency side by side and the categories that changed most. The
/// comparison period defaults to the period of the same length just
/// before.
class AnalyticsCompareScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [query] carries the period (`range` or
  /// `from`/`to`), `currency`, and optionally `compare_from`/`compare_to`.
  const AnalyticsCompareScreen({
    this.query = const <String, String>{},
    super.key,
  });

  /// Route query string values.
  final Map<String, String> query;

  @override
  ConsumerState<AnalyticsCompareScreen> createState() =>
      _AnalyticsCompareScreenState();
}

class _AnalyticsCompareScreenState
    extends ConsumerState<AnalyticsCompareScreen> {
  late AnalyticsQuery _query = AnalyticsQuery.fromQuery(widget.query);
  late DateRangeChoice? _other = _initialOther();

  DateRangeChoice? _initialOther() {
    final DateTime? from = LocalDates.parse(widget.query['compare_from']);
    final DateTime? to = LocalDates.parse(widget.query['compare_to']);
    if (from == null || to == null || to.isBefore(from)) {
      return null;
    }
    return DateRangeChoice.custom(
      widget.query['compare_from']!,
      widget.query['compare_to']!,
    );
  }

  Future<void> _pickOther(DateRangeChoice? current) async {
    final DateTime today = LocalDates.today();
    final DateTime? from = LocalDates.parse(current?.from);
    final DateTime? to = LocalDates.parse(current?.to);
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 1, 12, 31),
      initialDateRange: from != null && to != null && !to.isBefore(from)
          ? DateTimeRange(start: from, end: to)
          : null,
      helpText: context.l10n.analyticsCompareWith,
    );
    if (picked != null && mounted) {
      setState(
        () => _other = DateRangeChoice.custom(
          LocalDates.format(picked.start),
          LocalDates.format(picked.end),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    // The current period's window (resolved by the server) sets the
    // default comparison: the same number of days just before it.
    final AsyncValue<CashFlowReport> current = ref.watch(
      analyticsOverviewProvider(_query.range),
    );
    final CashFlowReport? currentData = current.value;
    DateRangeChoice? other = _other;
    if (other == null && currentData != null) {
      // The server's previous period: as many days, just before.
      other = DateRangeChoice.custom(
        currentData.previousWindow.from,
        currentData.previousWindow.to,
      );
    }
    Widget body;
    if (other == null) {
      body = current.hasError && !current.isLoading
          ? ErrorStateView(
              error: current.error!,
              onRetry: () =>
                  ref.invalidate(analyticsOverviewProvider(_query.range)),
            )
          : LoadingStateView(label: l10n.analyticsLoading);
    } else {
      final CompareArgs args = (
        range: _query.range,
        compareFrom: other.from!,
        compareTo: other.to!,
      );
      final AsyncValue<Comparison> comparison = ref.watch(
        analyticsCompareProvider(args),
      );
      body = ListView(
        padding: const EdgeInsets.only(bottom: Insets.xl),
        children: <Widget>[
          ContentFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SelectorField(
                  label: l10n.analyticsCompareThisPeriod,
                  icon: Icons.date_range_outlined,
                  value: rangeChoiceLabel(l10n, _query.range, locale: locale),
                  onTap: () async {
                    final DateRangeChoice? next = await showRangePicker(
                      context,
                      current: _query.range,
                    );
                    if (next != null && mounted) {
                      setState(() {
                        _query = _query.copyWith(range: next);
                        _other = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: Insets.sm),
                SelectorField(
                  label: l10n.analyticsCompareWith,
                  icon: Icons.history,
                  value: rangeChoiceLabel(l10n, other, locale: locale),
                  helperText: _other == null
                      ? l10n.analyticsComparePreviousHelp
                      : null,
                  onTap: () => _pickOther(other),
                ),
                const SizedBox(height: Insets.md),
                _ComparisonBody(
                  value: comparison,
                  onRetry: () => ref.invalidate(analyticsCompareProvider(args)),
                  wanted: _query.currency,
                  onCurrency: (String c) =>
                      setState(() => _query = _query.copyWith(currency: c)),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.analyticsCompareTitle)),
      body: body,
    );
  }
}

class _ComparisonBody extends ConsumerWidget {
  const _ComparisonBody({
    required this.value,
    required this.onRetry,
    required this.wanted,
    required this.onCurrency,
  });

  final AsyncValue<Comparison> value;
  final VoidCallback onRetry;
  final String? wanted;
  final ValueChanged<String> onCurrency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final Comparison? data = value.value;
    if (value.hasError && !value.isLoading) {
      return SizedBox(
        height: 320,
        child: ErrorStateView(error: value.error!, onRetry: onRetry),
      );
    }
    if (data == null) {
      return const SizedBox(height: 200, child: LoadingStateView());
    }
    final String? base = ref.watch(analyticsBaseCurrencyProvider);
    final List<String> currencies = orderCurrencies(<String>[
      for (final CurrencyComparison c in data.currencies) c.currency,
    ], base);
    final String? currency = pickCurrency(currencies, wanted, base);
    CurrencyComparison? chosen;
    for (final CurrencyComparison c in data.currencies) {
      if (c.currency == currency) {
        chosen = c;
      }
    }
    final String nowText = windowText(data.window, locale);
    final String thenText = windowText(data.comparisonWindow, locale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CurrencyChips(
          currencies: currencies,
          selected: currency,
          onSelected: onCurrency,
        ),
        if (currencies.length > 1) const SizedBox(height: Insets.sm),
        if (chosen == null)
          MessageStateView(
            icon: Icons.compare_arrows,
            title: l10n.analyticsCompareEmpty(nowText, thenText),
          )
        else ...<Widget>[
          _TotalsCard(c: chosen, nowText: nowText, thenText: thenText),
          const SizedBox(height: Insets.md),
          _CategoryChanges(c: chosen),
        ],
        const SizedBox(height: Insets.md),
        for (final String note in comparisonNotes(l10n, data))
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.xs),
            child: Text(note, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}

class _TotalsCard extends ConsumerWidget {
  const _TotalsCard({
    required this.c,
    required this.nowText,
    required this.thenText,
  });

  final CurrencyComparison c;
  final String nowText;
  final String thenText;

  /// A change as "+₹1,500.00 (+12.5%)": the server's signed amount and,
  /// when the comparison amount is not zero, its `change_bp`.
  static String _changeText(
    AppLocalizations l10n,
    String amount,
    MetricChange change,
    String numberLocale,
  ) {
    final String signed = change.change.amountMinor > 0 ? '+$amount' : amount;
    final int? bp = change.changeBp;
    return l10n.analyticsCategoryChange(
      signed,
      bp == null ? l10n.analyticsChangeNew : signedPercent(bp, numberLocale),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String numberLocale = numberLocaleOf(context, ref);
    String money(Money m) => formatMoney(context, ref, m);
    final List<(String, Money, Money)> rows = <(String, Money, Money)>[
      (l10n.incomeLabel, c.current.income, c.comparison.income),
      (l10n.spendingLabel, c.current.netExpense, c.comparison.netExpense),
      (l10n.netCashFlowLabel, c.current.netCashFlow, c.comparison.netCashFlow),
    ];
    int max = 0;
    for (final (String _, Money a, Money b) in rows.take(2)) {
      if (a.amountMinor > max) {
        max = a.amountMinor;
      }
      if (b.amountMinor > max) {
        max = b.amountMinor;
      }
    }
    return SectionCard(
      title: l10n.currencyHeading(c.currency),
      children: <Widget>[
        AnalyticsNote(l10n.analyticsCompareWindows(nowText, thenText)),
        const SizedBox(height: Insets.sm),
        AccessibleChart(
          summary: l10n.analyticsCompareSummary(
            money(c.current.netExpense),
            money(c.comparison.netExpense),
            money(c.current.income),
            money(c.comparison.income),
          ),
          chart: GroupedColumns(
            styles: const <BarStyle>[BarStyle.filled, BarStyle.outlined],
            groups: <ColumnGroup>[
              for (final (String label, Money a, Money b) in rows.take(2))
                ColumnGroup(
                  label: label,
                  fractions: <double>[
                    barFraction(a.amountMinor, max),
                    barFraction(b.amountMinor, max),
                  ],
                ),
            ],
          ),
          legend: Wrap(
            spacing: Insets.md,
            runSpacing: Insets.xs,
            children: <Widget>[
              LegendItem(
                style: BarStyle.filled,
                label: l10n.analyticsCompareThisPeriod,
              ),
              LegendItem(
                style: BarStyle.outlined,
                label: l10n.analyticsCompareWith,
              ),
            ],
          ),
          table: Column(
            children: <Widget>[
              for (final (String label, Money a, Money b) in rows)
                DetailRow(
                  label: label,
                  value: l10n.analyticsCompareRow(money(a), money(b)),
                ),
            ],
          ),
        ),
        for (final (String label, Money a, Money b, MetricChange change)
            in <(String, Money, Money, MetricChange)>[
              (rows[0].$1, rows[0].$2, rows[0].$3, c.change.income),
              (rows[1].$1, rows[1].$2, rows[1].$3, c.change.netExpense),
              (rows[2].$1, rows[2].$2, rows[2].$3, c.change.netCashFlow),
            ])
          DetailRow(
            label: label,
            semanticsValue: l10n.analyticsCompareRowChange(
              money(a),
              money(b),
              _changeText(l10n, money(change.change), change, numberLocale),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                MoneyText(a, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  l10n.analyticsCompareThen(money(b)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  _changeText(l10n, money(change.change), change, numberLocale),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        if (c.change.refunds.change.amountMinor != 0)
          DetailRow(
            label: l10n.analyticsRefundsLabel,
            value: _changeText(
              l10n,
              money(c.change.refunds.change),
              c.change.refunds,
              numberLocale,
            ),
          ),
        DetailRow(
          label: l10n.analyticsCompareCountLabel,
          value: l10n.analyticsCompareCount(
            c.current.transactionCount,
            c.comparison.transactionCount,
          ),
        ),
        const SizedBox(height: Insets.sm),
      ],
    );
  }
}

/// A change in basis points as "+12.5%" / "−3.0%".
String signedPercent(int bp, String locale) {
  final String text = formatBasisPoints(bp.abs(), locale);
  if (bp > 0) {
    return '+$text';
  }
  if (bp < 0) {
    return '−$text';
  }
  return text;
}

class _CategoryChanges extends ConsumerWidget {
  const _CategoryChanges({required this.c});

  final CurrencyComparison c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String numberLocale = numberLocaleOf(context, ref);
    String money(Money m) => formatMoney(context, ref, m);
    String name(CategoryDelta d) => d.categoryId == null
        ? l10n.categoryUncategorized
        : categoryDisplayName(l10n, name: d.name, systemKey: d.systemKey);
    return SectionCard(
      title: l10n.analyticsCategoryChangesTitle,
      children: <Widget>[
        if (c.categories.isEmpty)
          AnalyticsEmpty(l10n.analyticsCategoryChangesEmpty)
        else
          for (final CategoryDelta d in c.categories)
            DetailRow(
              label: name(d),
              semanticsValue: l10n.analyticsCategoryChangeSpoken(
                money(d.current),
                money(d.comparison),
                d.changeBp == null
                    ? l10n.analyticsChangeNew
                    : signedPercent(d.changeBp!, numberLocale),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  MoneyText(d.current),
                  Text(
                    l10n.analyticsCompareThen(money(d.comparison)),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    l10n.analyticsCategoryChange(
                      _signedMoney(money(d.change), d.change.amountMinor),
                      d.changeBp == null
                          ? l10n.analyticsChangeNew
                          : signedPercent(d.changeBp!, numberLocale),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        const SizedBox(height: Insets.sm),
      ],
    );
  }

  /// Server amounts are signed; a "+" is added to increases for clarity.
  static String _signedMoney(String text, int minor) =>
      minor > 0 ? '+$text' : text;
}
