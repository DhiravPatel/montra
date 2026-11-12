import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';

/// A date range as the API takes it: a named range (resolved by the server
/// in the user's time zone and week/month settings) or custom dates.
@immutable
class DateRangeChoice {
  /// A range from raw values (a named [range] wins over dates).
  const DateRangeChoice({this.range, this.from, this.to});

  /// A named range such as `this_month`.
  const DateRangeChoice.named(String this.range) : from = null, to = null;

  /// Custom dates (`YYYY-MM-DD`, inclusive).
  const DateRangeChoice.custom(String this.from, String this.to) : range = null;

  /// No date limit.
  const DateRangeChoice.any() : range = null, from = null, to = null;

  /// Named range, if any.
  final String? range;

  /// Custom start.
  final String? from;

  /// Custom end.
  final String? to;

  /// Whether any limit applies.
  bool get isAny => range == null && from == null && to == null;

  @override
  bool operator ==(Object other) =>
      other is DateRangeChoice &&
      other.range == range &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(range, from, to);
}

/// Localized name of a named range.
String namedRangeLabel(AppLocalizations l10n, String range) => switch (range) {
  'today' => l10n.rangeToday,
  'yesterday' => l10n.rangeYesterday,
  'this_week' => l10n.rangeThisWeek,
  'last_week' => l10n.rangeLastWeek,
  'this_month' => l10n.rangeThisMonth,
  'last_month' => l10n.rangeLastMonth,
  'this_year' => l10n.rangeThisYear,
  'last_year' => l10n.rangeLastYear,
  'last_7_days' => l10n.rangeLast7Days,
  'last_30_days' => l10n.rangeLast30Days,
  'last_90_days' => l10n.rangeLast90Days,
  _ => range,
};

/// Text for [choice] ("This month", "1 Nov – 30 Nov 2026", "Any time").
String rangeChoiceLabel(
  AppLocalizations l10n,
  DateRangeChoice choice, {
  required String locale,
}) {
  final String? range = choice.range;
  if (range != null) {
    return namedRangeLabel(l10n, range);
  }
  final String? from = choice.from;
  final String? to = choice.to;
  if (from != null && to != null) {
    return LocalDates.displayRange(from, to, locale: locale);
  }
  if (from != null) {
    return l10n.rangeFrom(LocalDates.display(from, locale: locale));
  }
  if (to != null) {
    return l10n.rangeUntil(LocalDates.display(to, locale: locale));
  }
  return l10n.rangeAnyTime;
}

/// Named ranges offered by [showRangePicker].
const List<String> pickerRanges = <String>[
  'today',
  'yesterday',
  'this_week',
  'last_week',
  'this_month',
  'last_month',
  'last_7_days',
  'last_30_days',
  'last_90_days',
  'this_year',
  'last_year',
];

const String _custom = '__custom__';
const String _any = '__any__';

/// Lets the user choose a named range or custom dates. Returns null when
/// dismissed. [allowAny] adds "Any time".
Future<DateRangeChoice?> showRangePicker(
  BuildContext context, {
  required DateRangeChoice current,
  bool allowAny = false,
}) async {
  final AppLocalizations l10n = context.l10n;
  final String selected =
      current.range ?? (current.isAny ? (allowAny ? _any : '') : _custom);
  final String? picked = await showOptionSheet<String>(
    context,
    title: l10n.rangePickerTitle,
    selected: selected,
    options: <SheetOption<String>>[
      if (allowAny) SheetOption<String>(value: _any, label: l10n.rangeAnyTime),
      for (final String r in pickerRanges)
        SheetOption<String>(value: r, label: namedRangeLabel(l10n, r)),
      SheetOption<String>(
        value: _custom,
        label: l10n.rangeCustom,
        icon: Icons.date_range_outlined,
      ),
    ],
  );
  if (picked == null || !context.mounted) {
    return null;
  }
  if (picked == _any) {
    return const DateRangeChoice.any();
  }
  if (picked != _custom) {
    return DateRangeChoice.named(picked);
  }
  final DateTime today = LocalDates.today();
  final DateTime? from = LocalDates.parse(current.from);
  final DateTime? to = LocalDates.parse(current.to);
  final DateTimeRange? dates = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2000),
    lastDate: DateTime(today.year + 1, 12, 31),
    initialDateRange: from != null && to != null && !to.isBefore(from)
        ? DateTimeRange(start: from, end: to)
        : null,
    helpText: l10n.rangeCustom,
  );
  if (dates == null) {
    return null;
  }
  return DateRangeChoice.custom(
    LocalDates.format(dates.start),
    LocalDates.format(dates.end),
  );
}
