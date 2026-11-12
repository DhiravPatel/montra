import 'package:flutter/foundation.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';

/// The analytics reports the app shows, with their route segment
/// (`/analytics/<slug>`).
enum AnalyticsReport {
  /// Income, spending and net cash flow over time.
  cashFlow('cash-flow'),

  /// Spending by category.
  categories('categories'),

  /// Spending over time.
  expenses('expenses'),

  /// Income over time.
  income('income'),

  /// Top merchants by spending.
  merchants('merchants'),

  /// Assets, liabilities and net worth.
  accounts('accounts'),

  /// Budget performance in the current periods.
  budgets('budgets'),

  /// Goal progress.
  goals('goals'),

  /// Subscription costs.
  subscriptions('subscriptions'),

  /// Recurring commitments per month.
  recurring('recurring');

  const AnalyticsReport(this.slug);

  /// Route segment.
  final String slug;

  /// The report for a route segment, or null.
  static AnalyticsReport? fromSlug(String slug) {
    for (final AnalyticsReport r in values) {
      if (r.slug == slug) {
        return r;
      }
    }
    return null;
  }

  /// Whether the report covers a chosen period (and one currency at a
  /// time); the others describe the current state.
  bool get usesPeriod => switch (this) {
    cashFlow || categories || expenses || income || merchants => true,
    accounts || budgets || goals || subscriptions || recurring => false,
  };

  /// Whether the report has a time series (and a bucket size).
  bool get hasSeries => this == cashFlow || this == expenses || this == income;
}

/// Bucket sizes for a series; null lets the server choose.
const List<String> analyticsGranularities = <String>[
  'day',
  'week',
  'month',
  'year',
];

final RegExp _currencyPattern = RegExp(r'^[A-Z]{3}$');

/// The period, currency and bucket size of an analytics screen as kept in
/// the route's query string: `range=this_month` or `from=…&to=…`,
/// `currency=INR`, `granularity=week`.
@immutable
class AnalyticsQuery {
  /// Creates the query.
  const AnalyticsQuery({
    this.range = const DateRangeChoice.named('this_month'),
    this.currency,
    this.granularity,
  });

  /// Reads a route query; unknown or malformed values fall back to this
  /// month, any currency and the server's bucket size.
  factory AnalyticsQuery.fromQuery(Map<String, String> query) {
    final String? from = _date(query['from']);
    final String? to = _date(query['to']);
    final String? named = query['range'];
    final DateRangeChoice range;
    if (from != null && to != null && from.compareTo(to) <= 0) {
      range = DateRangeChoice.custom(from, to);
    } else if (named != null && pickerRanges.contains(named)) {
      range = DateRangeChoice.named(named);
    } else {
      range = const DateRangeChoice.named('this_month');
    }
    final String? currency = query['currency'];
    final String? granularity = query['granularity'];
    return AnalyticsQuery(
      range: range,
      currency: currency != null && _currencyPattern.hasMatch(currency)
          ? currency
          : null,
      granularity: analyticsGranularities.contains(granularity)
          ? granularity
          : null,
    );
  }

  /// The period: a named range or custom dates.
  final DateRangeChoice range;

  /// The one currency shown, or null for "choose for me".
  final String? currency;

  /// Series bucket size, or null for the server's choice.
  final String? granularity;

  /// A copy with other values; [clearCurrency] / [clearGranularity] remove
  /// them.
  AnalyticsQuery copyWith({
    DateRangeChoice? range,
    String? currency,
    String? granularity,
    bool clearCurrency = false,
    bool clearGranularity = false,
  }) => AnalyticsQuery(
    range: range ?? this.range,
    currency: clearCurrency ? null : currency ?? this.currency,
    granularity: clearGranularity ? null : granularity ?? this.granularity,
  );

  /// The route query string values.
  Map<String, String> toQuery() => <String, String>{
    if (range.range != null) 'range': range.range!,
    if (range.range == null && range.from != null) 'from': range.from!,
    if (range.range == null && range.to != null) 'to': range.to!,
    'currency': ?currency,
    'granularity': ?granularity,
  };

  static String? _date(String? value) =>
      LocalDates.parse(value) == null ? null : value;

  @override
  bool operator ==(Object other) =>
      other is AnalyticsQuery &&
      other.range == range &&
      other.currency == currency &&
      other.granularity == granularity;

  @override
  int get hashCode => Object.hash(range, currency, granularity);
}

/// The API query for [range]: a named `range`, or `from`/`to` for custom
/// dates (the server resolves named ranges in the user's time zone).
Map<String, Object?> rangeQuery(DateRangeChoice range) => <String, Object?>{
  'range': range.range,
  if (range.range == null) 'from': range.from,
  if (range.range == null) 'to': range.to,
};

/// The period just before [from] … [to] with the same number of days
/// ([days], as the server counted them): calendar arithmetic only.
({String from, String to})? previousPeriod(String from, int days) {
  final DateTime? start = LocalDates.parse(from);
  if (start == null || days <= 0) {
    return null;
  }
  final DateTime end = DateTime(start.year, start.month, start.day - 1);
  final DateTime begin = DateTime(start.year, start.month, start.day - days);
  return (from: LocalDates.format(begin), to: LocalDates.format(end));
}

/// Currencies to offer as chips: [found] sorted, with [base] first.
List<String> orderCurrencies(Iterable<String> found, String? base) {
  final List<String> list = found.toSet().toList()..sort();
  if (base != null && list.remove(base)) {
    list.insert(0, base);
  }
  return list;
}

/// The currency to show: [wanted] when present in [available], else
/// [base] when present, else the first one; null when there is none.
String? pickCurrency(List<String> available, String? wanted, String? base) {
  if (available.isEmpty) {
    return null;
  }
  if (wanted != null && available.contains(wanted)) {
    return wanted;
  }
  if (base != null && available.contains(base)) {
    return base;
  }
  return available.first;
}
