import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/formatting/frequency.dart';

/// How a month-based schedule picks its day.
enum ScheduleAnchor {
  /// The same day as the start date.
  startDate,

  /// A day of the month (`by_month_day`, -1 = last day).
  monthDay,

  /// The nth weekday of the month (`by_week_of_month` + `by_weekday`).
  nthWeekday,
}

const Set<String> _monthFamily = <String>{
  'monthly',
  'bimonthly',
  'quarterly',
  'semiannual',
  'yearly',
};

/// The schedule fields shared by recurring rules and bills
/// (`RecurringRuleInput` / `BillInput`), as wire values.
@immutable
class ScheduleValue {
  /// Creates a schedule.
  const ScheduleValue({
    required this.frequency,
    required this.startDate,
    this.intervalCount,
    this.intervalUnit,
    this.byMonthDay,
    this.byWeekday,
    this.byWeekOfMonth,
    this.endDate,
    this.maxOccurrences,
    this.localTime,
  });

  /// A monthly schedule starting [startDate].
  const ScheduleValue.monthly(this.startDate)
    : frequency = 'monthly',
      intervalCount = null,
      intervalUnit = null,
      byMonthDay = null,
      byWeekday = null,
      byWeekOfMonth = null,
      endDate = null,
      maxOccurrences = null,
      localTime = null;

  /// The schedule of [rule] (also a bill's `schedule`).
  factory ScheduleValue.fromRule(RecurringRuleDto rule) => ScheduleValue(
    frequency: rule.frequency.json,
    startDate: rule.startDate,
    intervalCount: rule.intervalCount,
    intervalUnit: rule.intervalUnit?.json,
    byMonthDay: rule.byMonthDay,
    byWeekday: rule.byWeekday,
    byWeekOfMonth: rule.byWeekOfMonth,
    endDate: rule.endDate,
    maxOccurrences: rule.maxOccurrences,
    localTime: rule.localTime,
  );

  /// The schedule of a rule loaded with its occurrences.
  factory ScheduleValue.fromDetail(RecurringRuleDetail rule) => ScheduleValue(
    frequency: rule.frequency.json,
    startDate: rule.startDate,
    intervalCount: rule.intervalCount,
    intervalUnit: rule.intervalUnit?.json,
    byMonthDay: rule.byMonthDay,
    byWeekday: rule.byWeekday,
    byWeekOfMonth: rule.byWeekOfMonth,
    endDate: rule.endDate,
    maxOccurrences: rule.maxOccurrences,
    localTime: rule.localTime,
  );

  /// `frequency` wire value (see [scheduleFrequencies]).
  final String frequency;

  /// First eligible date (`YYYY-MM-DD`).
  final String startDate;

  /// Custom frequency: every N [intervalUnit]s.
  final int? intervalCount;

  /// Custom frequency unit (see [intervalUnits]).
  final String? intervalUnit;

  /// Day of the month (-1 = last day).
  final int? byMonthDay;

  /// Weekday, 0 = Sunday.
  final int? byWeekday;

  /// With [byWeekday]: nth week of the month (-1 = last).
  final int? byWeekOfMonth;

  /// Last date, if any.
  final String? endDate;

  /// Most occurrences, if any.
  final int? maxOccurrences;

  /// Local due time (`HH:MM`); the server default is 09:00.
  final String? localTime;

  /// Whether this app knows the schedule's frequency (and, for custom
  /// schedules, its unit). A newer server may send values this version
  /// decodes as `unrecognized` (wire value `''`); such schedules are shown
  /// as "Custom" and never edited, so they are never sent back changed.
  bool get isKnown =>
      scheduleFrequencies.contains(frequency) &&
      (frequency != 'custom' || intervalUnits.contains(intervalUnit));

  /// Whether occurrences fall on a weekday (weekly family).
  bool get isWeekBased =>
      frequency == 'weekly' ||
      frequency == 'biweekly' ||
      (frequency == 'custom' && intervalUnit == 'week');

  /// Whether occurrences fall on a day of the month (monthly family and
  /// yearly).
  bool get isMonthBased =>
      _monthFamily.contains(frequency) ||
      (frequency == 'custom' &&
          (intervalUnit == 'month' || intervalUnit == 'year'));

  /// How the day is picked for month-based schedules.
  ScheduleAnchor get anchor => byWeekOfMonth != null && byWeekday != null
      ? ScheduleAnchor.nthWeekday
      : byMonthDay != null
      ? ScheduleAnchor.monthDay
      : ScheduleAnchor.startDate;

  /// A copy with the given fields replaced; `clear*` flags set a field to
  /// null.
  ScheduleValue copyWith({
    String? frequency,
    String? startDate,
    int? intervalCount,
    String? intervalUnit,
    int? byMonthDay,
    int? byWeekday,
    int? byWeekOfMonth,
    String? endDate,
    int? maxOccurrences,
    String? localTime,
    bool clearAnchors = false,
    bool clearEnd = false,
  }) => ScheduleValue(
    frequency: frequency ?? this.frequency,
    startDate: startDate ?? this.startDate,
    intervalCount: intervalCount ?? this.intervalCount,
    intervalUnit: intervalUnit ?? this.intervalUnit,
    byMonthDay: clearAnchors ? byMonthDay : (byMonthDay ?? this.byMonthDay),
    byWeekday: clearAnchors ? byWeekday : (byWeekday ?? this.byWeekday),
    byWeekOfMonth: clearAnchors
        ? byWeekOfMonth
        : (byWeekOfMonth ?? this.byWeekOfMonth),
    endDate: clearEnd ? endDate : (endDate ?? this.endDate),
    maxOccurrences: clearEnd
        ? maxOccurrences
        : (maxOccurrences ?? this.maxOccurrences),
    localTime: localTime ?? this.localTime,
  );

  /// Only the fields that apply to [frequency]: interval fields for custom
  /// schedules, a weekday for week-based ones, a day or nth weekday for
  /// month-based ones, and at most one way of ending.
  ScheduleValue normalized() {
    final bool custom = frequency == 'custom';
    final bool week = isWeekBased;
    final bool month = isMonthBased;
    final ScheduleAnchor a = anchor;
    return ScheduleValue(
      frequency: frequency,
      startDate: startDate,
      intervalCount: custom ? (intervalCount ?? 1) : null,
      intervalUnit: custom ? (intervalUnit ?? 'day') : null,
      byMonthDay: month && a == ScheduleAnchor.monthDay ? byMonthDay : null,
      byWeekday: week || (month && a == ScheduleAnchor.nthWeekday)
          ? byWeekday
          : null,
      byWeekOfMonth: month && a == ScheduleAnchor.nthWeekday
          ? byWeekOfMonth
          : null,
      endDate: endDate,
      maxOccurrences: endDate == null ? maxOccurrences : null,
      localTime: localTime,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ScheduleValue &&
      other.frequency == frequency &&
      other.startDate == startDate &&
      other.intervalCount == intervalCount &&
      other.intervalUnit == intervalUnit &&
      other.byMonthDay == byMonthDay &&
      other.byWeekday == byWeekday &&
      other.byWeekOfMonth == byWeekOfMonth &&
      other.endDate == endDate &&
      other.maxOccurrences == maxOccurrences &&
      other.localTime == localTime;

  @override
  int get hashCode => Object.hash(
    frequency,
    startDate,
    intervalCount,
    intervalUnit,
    byMonthDay,
    byWeekday,
    byWeekOfMonth,
    endDate,
    maxOccurrences,
    localTime,
  );
}

/// Schedule fields that a new `frequency` resets on the server (bills and
/// recurring rules): a partial `PATCH` sends them together.
const Set<String> scheduleGroupKeys = <String>{
  'frequency',
  'interval_count',
  'interval_unit',
  'by_month_day',
  'by_weekday',
  'by_week_of_month',
};

/// Weekdays in the order pickers show them (Monday first), 0 = Sunday.
const List<int> weekdayOrder = <int>[1, 2, 3, 4, 5, 6, 0];

/// The weekday's name in [locale] (0 = Sunday).
String weekdayName(int weekday, String locale) =>
    // 1 November 2026 is a Sunday.
    DateFormat.EEEE(locale).format(DateTime(2026, 11, 1 + weekday % 7));

/// "first" … "fifth", or "last" for -1.
String weekOfMonthLabel(AppLocalizations l10n, int week) =>
    l10n.scheduleOrdinal(week < 1 || week > 5 ? 'last' : '$week');

/// A readable summary such as "Monthly · on day 5" or "Every 2 weeks · on
/// Monday".
String scheduleSummary(
  AppLocalizations l10n,
  ScheduleValue value, {
  required String locale,
}) {
  final String base = frequencyLabel(
    l10n,
    value.frequency,
    intervalCount: value.intervalCount,
    intervalUnit: value.intervalUnit,
  );
  final int? weekday = value.byWeekday;
  final int? week = value.byWeekOfMonth;
  final int? day = value.byMonthDay;
  final String? detail = value.isWeekBased && weekday != null
      ? l10n.scheduleOnWeekday(weekdayName(weekday, locale))
      : !value.isMonthBased
      ? null
      : week != null && weekday != null
      ? l10n.scheduleOnNthWeekday(
          week < 1 || week > 5 ? 'last' : '$week',
          weekdayName(weekday, locale),
        )
      : day == -1
      ? l10n.scheduleOnLastDay
      : day != null
      ? l10n.scheduleOnMonthDay(day)
      : null;
  return <String>[base, ?detail].join(' · ');
}

/// When the schedule starts and stops, e.g. "From 5 Nov 2026 until 5 Nov
/// 2027" or "From 5 Nov 2026, 12 times".
String scheduleRange(
  AppLocalizations l10n,
  ScheduleValue value, {
  required String locale,
}) {
  final String start = LocalDates.display(value.startDate, locale: locale);
  final String? end = value.endDate;
  final int? count = value.maxOccurrences;
  if (end != null) {
    return l10n.scheduleFromUntil(
      start,
      LocalDates.display(end, locale: locale),
    );
  }
  if (count != null) {
    return l10n.scheduleFromTimes(start, count);
  }
  return l10n.scheduleFrom(start);
}

/// Typed `frequency` for a recurring rule input; unknown values fall back
/// to monthly (never sent as `unrecognized`).
RecurringRuleInputFrequency recurringFrequencyOf(String wire) {
  final RecurringRuleInputFrequency f = RecurringRuleInputFrequency.fromJson(
    wire,
  );
  return f == RecurringRuleInputFrequency.unrecognized
      ? RecurringRuleInputFrequency.monthly
      : f;
}

/// Typed `interval_unit` for a recurring rule input.
RecurringRuleInputIntervalUnit? recurringIntervalUnitOf(String? wire) {
  if (wire == null) {
    return null;
  }
  final RecurringRuleInputIntervalUnit u =
      RecurringRuleInputIntervalUnit.fromJson(wire);
  return u == RecurringRuleInputIntervalUnit.unrecognized ? null : u;
}

/// Typed `frequency` for a bill input; unknown values fall back to monthly.
BillInputFrequency billFrequencyOf(String wire) {
  final BillInputFrequency f = BillInputFrequency.fromJson(wire);
  return f == BillInputFrequency.unrecognized ? BillInputFrequency.monthly : f;
}

/// Typed `interval_unit` for a bill input.
BillInputIntervalUnit? billIntervalUnitOf(String? wire) {
  if (wire == null) {
    return null;
  }
  final BillInputIntervalUnit u = BillInputIntervalUnit.fromJson(wire);
  return u == BillInputIntervalUnit.unrecognized ? null : u;
}
