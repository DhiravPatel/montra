import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// The order the account writes dates in (`PreferencesDTO.date_format`).
enum DateOrder {
  /// The app language decides (`4 Nov 2026` in English).
  locale('locale'),

  /// Day, month, year: `31/12/2026`.
  dmy('dmy'),

  /// Month, day, year: `12/31/2026`.
  mdy('mdy'),

  /// Year, month, day: `2026-12-31`.
  ymd('ymd');

  const DateOrder(this.wire);

  /// The wire value.
  final String wire;

  /// The order for wire [value]; unknown or missing values follow the
  /// language.
  static DateOrder fromWire(String? value) {
    for (final DateOrder order in values) {
      if (order.wire == value) {
        return order;
      }
    }
    return DateOrder.locale;
  }

  /// Pattern of a full date (null: the language's medium date).
  String? get datePattern => switch (this) {
    DateOrder.locale => null,
    DateOrder.dmy => 'dd/MM/yyyy',
    DateOrder.mdy => 'MM/dd/yyyy',
    DateOrder.ymd => 'yyyy-MM-dd',
  };

  /// Pattern of a day and month without the year (chart axes).
  String? get dayMonthPattern => switch (this) {
    DateOrder.locale => null,
    DateOrder.dmy => 'dd/MM',
    DateOrder.mdy => 'MM/dd',
    DateOrder.ymd => 'MM-dd',
  };

  /// What a typed date looks like (the date picker's hint).
  String? get inputHint => switch (this) {
    DateOrder.locale => null,
    DateOrder.dmy => 'dd/mm/yyyy',
    DateOrder.mdy => 'mm/dd/yyyy',
    DateOrder.ymd => 'yyyy-mm-dd',
  };
}

/// The account's date preferences applied app wide: how dates are written
/// ([order]) and the first day of the week ([weekStart], 0 = Sunday … 6 =
/// Saturday, as the API counts; null follows the app language).
@immutable
class DateSettings {
  /// Creates the settings.
  const DateSettings({this.order = DateOrder.locale, this.weekStart});

  /// From the preference wire values (`date_format`, `week_start`).
  factory DateSettings.fromWire({String? dateFormat, int? weekStart}) =>
      DateSettings(
        order: DateOrder.fromWire(dateFormat),
        weekStart: weekStart == null || weekStart < 0 || weekStart > 6
            ? null
            : weekStart,
      );

  /// Before the preferences are known: everything follows the language.
  static const DateSettings languageDefault = DateSettings();

  /// How dates are written.
  final DateOrder order;

  /// First day of the week (0 = Sunday), or null for the language's.
  final int? weekStart;

  @override
  bool operator ==(Object other) =>
      other is DateSettings &&
      other.order == order &&
      other.weekStart == weekStart;

  @override
  int get hashCode => Object.hash(order, weekStart);

  @override
  String toString() => 'DateSettings(${order.wire}, $weekStart)';
}

/// Weekdays (0 = Sunday … 6 = Saturday) in week order, starting on
/// [start] (Monday when unknown).
List<int> weekdaysFrom(int? start) {
  final int first = start ?? DateTime.monday % 7;
  return <int>[for (int i = 0; i < 7; i++) (first + i) % 7];
}

/// Calendar dates (`YYYY-MM-DD`) as the API uses them: a day in the user's
/// (or the record's) time zone, never an instant. They are kept as plain
/// year/month/day values so no time-zone conversion can shift them.
///
/// Every date the app shows is written here, following the account's
/// [settings] (applied by the app once the preferences load; changing them
/// reloads the app's localizations, so every screen redraws its dates).
abstract final class LocalDates {
  static final RegExp _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// The account's date settings in effect: applied app wide by
  /// `MontraApp`; tests set them directly and restore
  /// [DateSettings.languageDefault].
  static DateSettings settings = DateSettings.languageDefault;

  /// The first day of the week (0 = Sunday), or null for the language's.
  static int? get weekStart => settings.weekStart;

  /// [date] written as a full date (`4 Nov 2026`, `04/11/2026` …).
  static String displayDay(DateTime date, {required String locale}) {
    final String? pattern = settings.order.datePattern;
    return pattern == null
        ? DateFormat.yMMMd(locale).format(date)
        : DateFormat(pattern, locale).format(date);
  }

  /// Parses `YYYY-MM-DD` into a local midnight [DateTime], or null.
  static DateTime? parse(String? value) {
    if (value == null) {
      return null;
    }
    final Match? match = _pattern.firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    final DateTime date = DateTime(year, month, day);
    // Reject overflow such as 2026-02-31.
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  /// Formats the calendar day of [date] as `YYYY-MM-DD`.
  static String format(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// The device's calendar day today.
  static DateTime today([DateTime? now]) {
    final DateTime n = now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// A readable date such as `4 Nov 2026` (or `04/11/2026` with the
  /// `dmy` setting) for [value] (`YYYY-MM-DD`); returns [value] unchanged
  /// when it cannot be parsed.
  static String display(String value, {required String locale}) {
    final DateTime? date = parse(value);
    return date == null ? value : displayDay(date, locale: locale);
  }

  /// A long readable date such as `Wednesday, 4 November 2026` (or
  /// `Wednesday, 04/11/2026` with the `dmy` setting).
  static String displayLong(String value, {required String locale}) {
    final DateTime? date = parse(value);
    if (date == null) {
      return value;
    }
    final String? pattern = settings.order.datePattern;
    return pattern == null
        ? DateFormat.yMMMMEEEEd(locale).format(date)
        : DateFormat('EEEE, $pattern', locale).format(date);
  }

  /// `4 Nov – 30 Nov 2026` style range text.
  static String displayRange(String from, String to, {required String locale}) {
    if (from == to) {
      return display(from, locale: locale);
    }
    return '${display(from, locale: locale)} – ${display(to, locale: locale)}';
  }

  /// A month label such as `Nov 2026` for a bucket start date (month
  /// names in the app language; there is no day to order).
  static String displayMonth(String value, {required String locale}) {
    final DateTime? date = parse(value);
    return date == null ? value : DateFormat.yMMM(locale).format(date);
  }

  /// A short day label such as `4 Nov` (or `04/11` with the `dmy`
  /// setting) for chart axes.
  static String displayShort(String value, {required String locale}) {
    final DateTime? date = parse(value);
    if (date == null) {
      return value;
    }
    final String? pattern = settings.order.dayMonthPattern;
    return pattern == null
        ? DateFormat.MMMd(locale).format(date)
        : DateFormat(pattern, locale).format(date);
  }
}

/// Date and time of an instant in the device's time zone, e.g.
/// `4 Nov 2026, 6:45 pm` (the date follows the account's date format).
String formatDateTime(DateTime instant, {required String locale}) {
  final String? pattern = LocalDates.settings.order.datePattern;
  return (pattern == null
          ? DateFormat.yMMMd(locale)
          : DateFormat(pattern, locale))
      .add_jm()
      .format(instant.toLocal());
}
