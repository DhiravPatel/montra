import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/formatting/frequency.dart';
import 'package:montra_mobile/core/widgets/reminder_days_field.dart';

import '../helpers/test_app.dart';

void main() {
  test('frequencies read naturally in English and Hindi', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final AppLocalizations hi = lookupAppLocalizations(const Locale('hi'));
    expect(frequencyLabel(en, 'quarterly'), 'Every 3 months');
    expect(
      frequencyLabel(en, 'custom', intervalCount: 10, intervalUnit: 'day'),
      'Every 10 days',
    );
    expect(
      frequencyLabel(en, 'custom', intervalCount: 1, intervalUnit: 'week'),
      'Every week',
    );
    expect(frequencyLabel(en, 'custom'), 'Custom');
    expect(frequencyLabel(en, 'fortnightly-ish'), 'Custom');
    expect(frequencyLabel(hi, 'monthly'), 'हर महीने');
    expect(intervalLabel(hi, 2, 'year'), 'हर 2 साल');
    expect(reminderOffsetLabel(en, 0), 'On the day');
    expect(reminderOffsetLabel(en, 3), '3 days before');
    for (final String f in scheduleFrequencies) {
      expect(frequencyLabel(hi, f), isNotEmpty);
    }
  });

  testWidgets('reminder chips stay sorted, keep server values and cap at 5', (
    WidgetTester tester,
  ) async {
    List<int> value = <int>[2, 7];
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) =>
                ReminderDaysField(
                  value: value,
                  onChanged: (List<int> v) => setState(() => value = v),
                  maxSelected: 3,
                ),
          ),
        ),
      ),
    );

    expect(find.text('2 days before'), findsOneWidget);
    await tester.tap(find.text('On the day'));
    await tester.pump();
    expect(value, <int>[0, 2, 7]);
    // Full: other chips are disabled until one is removed.
    await tester.tap(find.text('1 day before'));
    await tester.pump();
    expect(value, <int>[0, 2, 7]);
    await tester.tap(find.text('2 days before'));
    await tester.pump();
    await tester.tap(find.text('1 day before'));
    await tester.pump();
    expect(value, <int>[0, 1, 7]);
    expect(find.text('Choose up to 3.'), findsOneWidget);
  });
}
