import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/features/recurring/domain/schedule.dart';
import 'package:montra_mobile/features/recurring/presentation/schedule_editor.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations hi;

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('hi');
    en = lookupAppLocalizations(const Locale('en'));
    hi = lookupAppLocalizations(const Locale('hi'));
  });

  String summary(ScheduleValue v, [String locale = 'en']) =>
      scheduleSummary(locale == 'hi' ? hi : en, v, locale: locale);

  test('summaries read naturally for each kind of schedule', () {
    const ScheduleValue start = ScheduleValue.monthly('2026-11-05');
    expect(summary(start), 'Monthly');
    expect(summary(start.copyWith(byMonthDay: 5)), 'Monthly · on day 5');
    expect(
      summary(start.copyWith(byMonthDay: -1)),
      'Monthly · on the last day',
    );
    expect(
      summary(start.copyWith(byWeekOfMonth: 2, byWeekday: 1)),
      'Monthly · on the second Monday',
    );
    expect(
      summary(start.copyWith(byWeekOfMonth: -1, byWeekday: 5)),
      'Monthly · on the last Friday',
    );
    expect(
      summary(
        const ScheduleValue(
          frequency: 'biweekly',
          startDate: '2026-11-05',
          byWeekday: 0,
        ),
      ),
      'Every 2 weeks · on Sunday',
    );
    expect(
      summary(
        const ScheduleValue(
          frequency: 'custom',
          startDate: '2026-11-05',
          intervalCount: 10,
          intervalUnit: 'day',
        ),
      ),
      'Every 10 days',
    );
    expect(
      summary(start.copyWith(byMonthDay: 5), 'hi'),
      'हर महीने · 5 तारीख़ को',
    );
    expect(
      summary(start.copyWith(byWeekOfMonth: 2, byWeekday: 1), 'hi'),
      contains('दूसरे'),
    );
  });

  test('ranges say when a schedule starts and stops', () {
    const ScheduleValue start = ScheduleValue.monthly('2026-11-05');
    expect(scheduleRange(en, start, locale: 'en'), 'From Nov 5, 2026');
    expect(
      scheduleRange(en, start.copyWith(endDate: '2027-11-05'), locale: 'en'),
      'From Nov 5, 2026 until Nov 5, 2027',
    );
    expect(
      scheduleRange(en, start.copyWith(maxOccurrences: 12), locale: 'en'),
      'From Nov 5, 2026, 12 times',
    );
    expect(
      scheduleRange(en, start.copyWith(maxOccurrences: 1), locale: 'en'),
      'From Nov 5, 2026, once',
    );
  });

  test('normalizing keeps only fields that apply to the frequency', () {
    const ScheduleValue mixed = ScheduleValue(
      frequency: 'weekly',
      startDate: '2026-11-05',
      intervalCount: 4,
      intervalUnit: 'month',
      byMonthDay: 9,
      byWeekday: 3,
      byWeekOfMonth: 2,
      endDate: '2027-01-01',
      maxOccurrences: 5,
    );
    final ScheduleValue n = mixed.normalized();
    expect(n.intervalCount, isNull);
    expect(n.intervalUnit, isNull);
    expect(n.byMonthDay, isNull);
    expect(n.byWeekOfMonth, isNull);
    expect(n.byWeekday, 3);
    expect(n.maxOccurrences, isNull, reason: 'an end date wins');

    final ScheduleValue monthly = mixed
        .copyWith(frequency: 'quarterly')
        .normalized();
    expect(monthly.anchor, ScheduleAnchor.nthWeekday);
    expect(monthly.byMonthDay, isNull);
    final ScheduleValue custom = mixed
        .copyWith(frequency: 'custom', clearAnchors: true, byMonthDay: 9)
        .normalized();
    expect(custom.intervalCount, 4);
    expect(custom.intervalUnit, 'month');
    expect(custom.byMonthDay, 9);
    expect(custom.isMonthBased, isTrue);
  });

  group('editor', () {
    Future<ValueNotifier<ScheduleValue>> pump(
      WidgetTester tester,
      ScheduleValue initial,
    ) async {
      final ValueNotifier<ScheduleValue> value = ValueNotifier<ScheduleValue>(
        initial,
      );
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder<ScheduleValue>(
                valueListenable: value,
                builder:
                    (BuildContext context, ScheduleValue v, Widget? child) =>
                        ScheduleEditor(
                          value: v,
                          onChanged: (ScheduleValue next) => value.value = next,
                        ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return value;
    }

    Future<void> choose(WidgetTester tester, String from, String to) async {
      await tester.tap(find.text(from).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(to).last);
      await tester.pumpAndSettle();
    }

    testWidgets('a custom interval and a day of the month', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<ScheduleValue> value = await pump(
        tester,
        const ScheduleValue.monthly('2026-11-05'),
      );
      expect(find.text('Monthly\nFrom Nov 5, 2026'), findsOneWidget);

      await choose(
        tester,
        'Same date as the start date',
        'A date of the month',
      );
      expect(value.value.byMonthDay, 5);
      await choose(tester, '5', '7');
      expect(value.value.byMonthDay, 7);
      expect(find.textContaining('Monthly · on day 7'), findsOneWidget);

      await choose(tester, 'Monthly', 'Custom');
      expect(value.value.frequency, 'custom');
      expect(value.value.intervalUnit, 'day');
      await tester.enterText(find.widgetWithText(TextFormField, 'Every'), '3');
      await choose(tester, 'Days', 'Weeks');
      expect(value.value.intervalCount, 3);
      expect(value.value.intervalUnit, 'week');
      expect(value.value.byMonthDay, isNull);
      expect(find.text('Day of the week'), findsOneWidget);
      await choose(tester, 'Same day as the start date', 'Wednesday');
      expect(value.value.byWeekday, 3);
      expect(
        find.textContaining('Every 3 weeks · on Wednesday'),
        findsOneWidget,
      );
    });

    testWidgets('a weekday of the month and an end after some times', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<ScheduleValue> value = await pump(
        tester,
        const ScheduleValue.monthly('2026-11-05'),
      );
      await choose(
        tester,
        'Same date as the start date',
        'A weekday of the month',
      );
      // Defaults to the start date's weekday in the first week.
      expect(value.value.byWeekOfMonth, 1);
      expect(value.value.byWeekday, 4);
      await choose(tester, 'First', 'Last');
      expect(value.value.byWeekOfMonth, -1);

      await tester.scrollUntilVisible(
        find.text('Never'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await choose(tester, 'Never', 'After a number of times');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Number of times'),
        '12',
      );
      await tester.pump();
      expect(value.value.maxOccurrences, 12);
      expect(value.value.endDate, isNull);
      expect(find.textContaining('12 times'), findsOneWidget);
    });
  });
}
