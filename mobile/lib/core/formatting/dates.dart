import 'package:intl/intl.dart';

/// Calendar dates (`YYYY-MM-DD`) as the API uses them: a day in the user's
/// (or the record's) time zone, never an instant. They are kept as plain
/// year/month/day values so no time-zone conversion can shift them.
abstract final class LocalDates {
  static final RegExp _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

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

  /// A readable date such as `4 Nov 2026` for [value] (`YYYY-MM-DD`);
  /// returns [value] unchanged when it cannot be parsed.
  static String display(String value, {required String locale}) {
    final DateTime? date = parse(value);
    return date == null ? value : DateFormat.yMMMd(locale).format(date);
  }

  /// A long readable date such as `Wednesday, 4 November 2026`.
  static String displayLong(String value, {required String locale}) {
    final DateTime? date = parse(value);
    return date == null ? value : DateFormat.yMMMMEEEEd(locale).format(date);
  }

  /// `4 Nov – 30 Nov 2026` style range text.
  static String displayRange(String from, String to, {required String locale}) {
    if (from == to) {
      return display(from, locale: locale);
    }
    return '${display(from, locale: locale)} – ${display(to, locale: locale)}';
  }

  /// A month label such as `Nov 2026` for a bucket start date.
  static String displayMonth(String value, {required String locale}) {
    final DateTime? date = parse(value);
    return date == null ? value : DateFormat.yMMM(locale).format(date);
  }

  /// A short day label such as `4 Nov` for chart axes.
  static String displayShort(String value, {required String locale}) {
    final DateTime? date = parse(value);
    return date == null ? value : DateFormat.MMMd(locale).format(date);
  }
}

/// Date and time of an instant in the device's time zone, e.g.
/// `4 Nov 2026, 6:45 pm`.
String formatDateTime(DateTime instant, {required String locale}) =>
    DateFormat.yMMMd(locale).add_jm().format(instant.toLocal());
