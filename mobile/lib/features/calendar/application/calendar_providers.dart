import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/features/calendar/data/calendar_api.dart';

/// First and last day (`YYYY-MM-DD`) of the month that contains [month].
({String from, String to}) monthRange(DateTime month) => (
  from: LocalDates.format(DateTime(month.year, month.month)),
  to: LocalDates.format(DateTime(month.year, month.month + 1, 0)),
);

/// `YYYY-MM` key of [month].
String monthKey(DateTime month) =>
    '${month.year.toString().padLeft(4, '0')}-'
    '${month.month.toString().padLeft(2, '0')}';

/// The month for a `YYYY-MM` key, or null when malformed.
DateTime? parseMonthKey(String? key) {
  final RegExpMatch? m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(key ?? '');
  if (m == null) {
    return null;
  }
  final int month = int.parse(m.group(2)!);
  if (month < 1 || month > 12) {
    return null;
  }
  return DateTime(int.parse(m.group(1)!), month);
}

/// Calendar items of one month (`YYYY-MM`), sorted by date. Re-read after
/// every finance write.
final FutureProviderFamily<List<CalendarItem>, String> calendarMonthProvider =
    FutureProvider.autoDispose.family<List<CalendarItem>, String>((
      Ref ref,
      String key,
    ) async {
      ref.watch(financeRevisionProvider);
      final DateTime month = parseMonthKey(key) ?? LocalDates.today();
      final ({String from, String to}) range = monthRange(month);
      final List<CalendarItem> items = await ref
          .read(calendarApiProvider)
          .items(from: range.from, to: range.to);
      return List<CalendarItem>.of(items)
        ..sort((CalendarItem a, CalendarItem b) => a.date.compareTo(b.date));
    });

/// [items] grouped by date, in date order.
List<(String, List<CalendarItem>)> groupByDate(List<CalendarItem> items) {
  final Map<String, List<CalendarItem>> byDate = <String, List<CalendarItem>>{};
  for (final CalendarItem item in items) {
    byDate.putIfAbsent(item.date, () => <CalendarItem>[]).add(item);
  }
  final List<String> dates = byDate.keys.toList()..sort();
  return <(String, List<CalendarItem>)>[
    for (final String d in dates) (d, byDate[d]!),
  ];
}
