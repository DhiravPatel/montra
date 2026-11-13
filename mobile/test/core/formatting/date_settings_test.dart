import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:montra_mobile/app/l10n/date_localizations.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/settings/app_preferences.dart';
import 'package:montra_mobile/features/recurring/domain/schedule.dart';

import '../../helpers/finance_fakes.dart';

/// The account's `date_format` and `week_start` preferences, applied to
/// every date the app writes and to the date pickers.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('hi');
  });

  tearDown(() => LocalDates.settings = DateSettings.languageDefault);

  void use(String format, {int? weekStart}) => LocalDates.settings =
      DateSettings.fromWire(dateFormat: format, weekStart: weekStart);

  group('date format', () {
    test('locale follows the app language', () {
      use('locale');
      expect(LocalDates.display('2026-11-04', locale: 'en'), 'Nov 4, 2026');
      expect(
        LocalDates.displayLong('2026-11-04', locale: 'en'),
        'Wednesday, November 4, 2026',
      );
      expect(LocalDates.displayShort('2026-11-04', locale: 'en'), 'Nov 4');
    });

    test('dmy, mdy and ymd write full dates in that order, in both '
        'languages', () {
      for (final (String format, String en) in <(String, String)>[
        ('dmy', '04/11/2026'),
        ('mdy', '11/04/2026'),
        ('ymd', '2026-11-04'),
      ]) {
        use(format);
        expect(LocalDates.display('2026-11-04', locale: 'en'), en);
        expect(LocalDates.display('2026-11-04', locale: 'hi'), en);
      }
    });

    test('long, short, range and date-time forms follow the order', () {
      use('dmy');
      expect(
        LocalDates.displayLong('2026-11-04', locale: 'en'),
        'Wednesday, 04/11/2026',
      );
      expect(
        LocalDates.displayLong('2026-11-04', locale: 'hi'),
        'बुधवार, 04/11/2026',
      );
      expect(LocalDates.displayShort('2026-11-04', locale: 'en'), '04/11');
      expect(
        LocalDates.displayRange('2026-11-01', '2026-11-30', locale: 'en'),
        '01/11/2026 – 30/11/2026',
      );
      use('ymd');
      expect(LocalDates.displayShort('2026-11-04', locale: 'en'), '11-04');
      final DateTime local = DateTime(2026, 11, 4, 18, 45);
      expect(
        formatDateTime(local, locale: 'en').replaceAll('\u202f', ' '),
        '2026-11-04 6:45 PM',
      );
      expect(formatShortDate(local, locale: 'en'), '2026-11-04');
      use('mdy');
      expect(LocalDates.displayDay(local, locale: 'en'), '11/04/2026');
    });

    test('month labels keep month names; bad values stay as sent', () {
      use('ymd');
      expect(LocalDates.displayMonth('2026-11-01', locale: 'en'), 'Nov 2026');
      expect(LocalDates.display('not a date', locale: 'en'), 'not a date');
    });

    test('settings come from the preferences; unknown values fall back', () {
      expect(
        DateSettings.fromWire(dateFormat: 'dmy', weekStart: 6),
        const DateSettings(order: DateOrder.dmy, weekStart: 6),
      );
      expect(
        DateSettings.fromWire(dateFormat: 'something_new', weekStart: 9),
        DateSettings.languageDefault,
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[currentUserIdProvider.overrideWithValue('u1')],
      );
      addTearDown(container.dispose);
      expect(
        container.read(dateSettingsProvider),
        DateSettings.languageDefault,
      );
      container
          .read(preferencesSnapshotProvider.notifier)
          .update(preferences(dateFormat: 'mdy', weekStart: 0));
      expect(
        container.read(dateSettingsProvider),
        const DateSettings(order: DateOrder.mdy, weekStart: 0),
      );
    });
  });

  group('week start', () {
    test('weekdays are listed from the first day of the week', () {
      expect(weekdaysFrom(null), <int>[1, 2, 3, 4, 5, 6, 0]);
      expect(weekdaysFrom(0), <int>[0, 1, 2, 3, 4, 5, 6]);
      expect(weekdaysFrom(6), <int>[6, 0, 1, 2, 3, 4, 5]);
      use('locale', weekStart: 0);
      expect(weekdayOrder.first, 0);
      use('locale', weekStart: 6);
      expect(weekdayOrder, <int>[6, 0, 1, 2, 3, 4, 5]);
    });
  });

  group('in the app', () {
    /// A minimal app wired like `MontraApp`: settings from the preferences
    /// snapshot, applied to `LocalDates` and the localization delegates.
    Widget app(
      ProviderContainer container, {
      Locale locale = const Locale('en'),
    }) => UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) {
          final DateSettings dates = ref.watch(dateSettingsProvider);
          LocalDates.settings = dates;
          return MaterialApp(
            locale: locale,
            localizationsDelegates: appLocalizationsDelegates(dates),
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: _Dates()),
          );
        },
      ),
    );

    ProviderContainer signedIn() {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[currentUserIdProvider.overrideWithValue('u1')],
      );
      addTearDown(container.dispose);
      return container;
    }

    testWidgets('changing the date format redraws dates on screen', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = signedIn();
      await tester.pumpWidget(app(container));
      expect(find.text('Nov 4, 2026'), findsOneWidget);

      container
          .read(preferencesSnapshotProvider.notifier)
          .update(preferences(dateFormat: 'dmy'));
      await tester.pumpAndSettle();
      expect(find.text('04/11/2026'), findsOneWidget);

      container
          .read(preferencesSnapshotProvider.notifier)
          .update(preferences(dateFormat: 'ymd'));
      await tester.pumpAndSettle();
      expect(find.text('2026-11-04'), findsOneWidget);
    });

    /// The left-most weekday heading of the open date picker.
    String firstHeading(WidgetTester tester, List<String> names) {
      final List<Finder> found = <Finder>[
        for (final String n in names) find.text(n),
      ];
      String best = '';
      double left = double.infinity;
      for (int i = 0; i < names.length; i++) {
        for (final Element e in found[i].evaluate()) {
          final double x = tester.getTopLeft(find.byWidget(e.widget)).dx;
          if (x < left) {
            left = x;
            best = names[i];
          }
        }
      }
      return best;
    }

    for (final (int weekStart, String first) in <(int, String)>[
      (1, 'M'),
      (0, 'S'),
      (3, 'W'),
    ]) {
      testWidgets('the date picker starts weeks on the chosen day '
          '($weekStart)', (WidgetTester tester) async {
        final ProviderContainer container = signedIn();
        container
            .read(preferencesSnapshotProvider.notifier)
            .update(preferences(weekStart: weekStart));
        await tester.pumpWidget(app(container));
        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();
        expect(
          firstHeading(tester, const <String>['S', 'M', 'T', 'W', 'F']),
          first,
        );
      });
    }

    testWidgets('typed dates use the chosen order (Hindi too)', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = signedIn();
      container
          .read(preferencesSnapshotProvider.notifier)
          .update(preferences(dateFormat: 'dmy', weekStart: 0));
      await tester.pumpWidget(app(container, locale: const Locale('hi')));
      final BuildContext context = tester.element(find.byType(_Dates));
      final MaterialLocalizations m = MaterialLocalizations.of(context);
      expect(m.firstDayOfWeekIndex, 0);
      expect(m.dateHelpText, 'dd/mm/yyyy');
      expect(m.formatCompactDate(DateTime(2026, 11, 4)), '04/11/2026');
      expect(m.parseCompactDate('04/11/2026'), DateTime(2026, 11, 4));
      // Everything else stays Hindi.
      expect(m.okButtonLabel, isNot('OK'));
      expect(find.text('04/11/2026'), findsOneWidget);
    });
  });
}

class _Dates extends StatelessWidget {
  const _Dates();

  @override
  Widget build(BuildContext context) {
    final String locale = Localizations.localeOf(context).toString();
    return Column(
      children: <Widget>[
        Text(LocalDates.display('2026-11-04', locale: locale)),
        TextButton(
          onPressed: () => showDatePicker(
            context: context,
            firstDate: DateTime(2026),
            lastDate: DateTime(2027),
            initialDate: DateTime(2026, 11, 4),
          ),
          child: const Text('Pick'),
        ),
      ],
    );
  }
}
