import 'package:montra_mobile/app/l10n/l10n.dart';

/// Schedule frequencies offered by recurring rules and bills, in the order
/// forms show them (contract `frequency`).
const List<String> scheduleFrequencies = <String>[
  'daily',
  'weekly',
  'biweekly',
  'monthly',
  'bimonthly',
  'quarterly',
  'semiannual',
  'yearly',
  'custom',
];

/// Units of a custom interval (contract `interval_unit`).
const List<String> intervalUnits = <String>['day', 'week', 'month', 'year'];

/// Localized text for a contract frequency (`frequency` of recurring rules
/// and bills, `billing_frequency` of subscriptions): "Monthly", "Every 3
/// months", or for `custom` "Every 10 days" from [intervalCount] and
/// [intervalUnit]. Unknown values read as "Custom".
String frequencyLabel(
  AppLocalizations l10n,
  String frequency, {
  int? intervalCount,
  String? intervalUnit,
}) => switch (frequency) {
  'daily' => l10n.frequencyDaily,
  'weekly' => l10n.frequencyWeekly,
  'biweekly' => l10n.frequencyBiweekly,
  'monthly' => l10n.frequencyMonthly,
  'bimonthly' => l10n.frequencyBimonthly,
  'quarterly' => l10n.frequencyQuarterly,
  'semiannual' => l10n.frequencySemiannual,
  'yearly' => l10n.frequencyYearly,
  'custom' when intervalCount != null && intervalUnit != null => intervalLabel(
    l10n,
    intervalCount,
    intervalUnit,
  ),
  _ => l10n.frequencyCustom,
};

/// "Every 2 weeks" for an interval of [count] [unit]s.
String intervalLabel(AppLocalizations l10n, int count, String unit) =>
    switch (unit) {
      'day' => l10n.frequencyEveryDays(count),
      'week' => l10n.frequencyEveryWeeks(count),
      'month' => l10n.frequencyEveryMonths(count),
      'year' => l10n.frequencyEveryYears(count),
      _ => l10n.frequencyCustom,
    };

/// Name of an interval unit for pickers ("Days").
String intervalUnitLabel(AppLocalizations l10n, String unit) => switch (unit) {
  'day' => l10n.intervalUnitDays,
  'week' => l10n.intervalUnitWeeks,
  'month' => l10n.intervalUnitMonths,
  'year' => l10n.intervalUnitYears,
  _ => unit,
};

/// "1 day before" / "On the day" for a reminder offset.
String reminderOffsetLabel(AppLocalizations l10n, int days) =>
    days == 0 ? l10n.reminderOnTheDay : l10n.reminderDaysBefore(days);
