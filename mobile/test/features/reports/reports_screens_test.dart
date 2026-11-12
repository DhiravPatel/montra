import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/files/file_export.dart';
import 'package:montra_mobile/features/reports/data/reports_api.dart';

import '../../helpers/files_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/insights_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockReportsApi api;
  late MockFileDownloader downloader;
  late FakeFileExporter exporter;

  setUpAll(() {
    registerInsightsFallbacks();
    registerFileFallbacks();
    registerFallbackValue(access());
  });

  setUp(() {
    api = MockReportsApi();
    downloader = MockFileDownloader();
    exporter = FakeFileExporter();
  });

  List<Override> overrides() => <Override>[
    reportsApiProvider.overrideWithValue(api),
    fileDownloaderProvider.overrideWithValue(downloader),
    fileExporterProvider.overrideWithValue(exporter),
  ];

  /// Lets a page transition finish where a progress bar keeps animating
  /// (a report that is still being made), so pumpAndSettle cannot be used.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  group('reports list', () {
    testWidgets('re-reads itself while a report is being made and stops '
        'when it is ready', (WidgetTester tester) async {
      int calls = 0;
      when(() => api.list()).thenAnswer((_) async {
        calls++;
        return <ReportDto>[
          report(
            id: 'rep-2',
            type: 'transactions',
            title: 'Tax papers',
            format: 'pdf',
            status: calls == 1 ? 'running' : 'completed',
          ),
          report(),
        ];
      });
      await pump(tester, '/reports');

      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Tax papers'), findsOneWidget);
      expect(find.text('Transactions · PDF'), findsOneWidget);
      expect(find.text('Being made'), findsOneWidget);
      expect(
        find.text('Reports being made update here by themselves.'),
        findsOneWidget,
      );
      // The server's English default title is shown in the user's language.
      expect(find.text('Monthly summary'), findsOneWidget);
      expect(find.text('Ready to download'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Being made'), findsNothing);
      expect(find.text('Ready to download'), findsNWidgets(2));

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(calls, 2, reason: 'nothing is being made, so polling stopped');
    });

    testWidgets('gives up after a few minutes and asks to pull down', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(() => api.list()).thenAnswer((_) async {
        calls++;
        return <ReportDto>[report(status: 'queued')];
      });
      await pump(tester, '/reports');
      for (int i = 0; i < 61; i++) {
        await tester.pump(const Duration(seconds: 3));
      }
      await tester.pump();
      expect(calls, 61, reason: 'the first read and 60 polls');
      expect(
        find.text('Still being made. Pull down to check again.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 61);
    });

    testWidgets('empty and failed states', (WidgetTester tester) async {
      int calls = 0;
      when(() => api.list()).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return <ReportDto>[];
      });
      await pump(tester, '/reports');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No reports yet'), findsOneWidget);
      expect(find.text('New report'), findsWidgets);
    });
  });

  group('new report', () {
    testWidgets('sends the type, format and period, then opens the report', (
      WidgetTester tester,
    ) async {
      when(() => api.list()).thenAnswer((_) async => <ReportDto>[]);
      when(() => api.create(any())).thenAnswer(
        (_) async =>
            report(id: 'rep-9', type: 'transactions', status: 'queued'),
      );
      when(() => api.get('rep-9')).thenAnswer(
        (_) async =>
            report(id: 'rep-9', type: 'transactions', status: 'queued'),
      );
      final GoRouter router = await pump(tester, '/reports/new');
      expect(find.text('This month'), findsOneWidget);

      await tester.tap(find.text('Monthly summary'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Transactions').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transactions').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'PDF'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create report'));
      await tester.tap(find.text('Create report'));
      await settle(tester);

      final ReportInput sent =
          verify(() => api.create(captureAny())).captured.single as ReportInput;
      expect(sent.toJson(), <String, Object?>{
        'report_type': 'transactions',
        'format': 'pdf',
        'filters': <String, Object?>{'range': 'this_month'},
      });
      expect(locationOf(router), '/reports/rep-9');
      expect(
        find.text('Your report is being made. This page updates by itself.'),
        findsOneWidget,
      );
    });
  });

  group('report detail', () {
    testWidgets('a ready report is downloaded once, then shared or saved', (
      WidgetTester tester,
    ) async {
      when(() => api.get('rep-1')).thenAnswer((_) async => report());
      when(() => api.download('rep-1'))
          .thenAnswer((_) async => access(filename: 'monthly-summary.csv'));
      when(() => downloader.fetch(any(), onProgress: any(named: 'onProgress')))
          .thenAnswer(
            (_) async => downloadedFile(name: 'monthly-summary-20261105.csv'),
          );
      await pump(tester, '/reports/rep-1');

      expect(find.text('Ready to download'), findsOneWidget);
      expect(find.text('22 rows'), findsOneWidget);
      expect(find.byTooltip('Delete report'), findsOneWidget);
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(exporter.shared.single.name, 'monthly-summary-20261105.csv');

      await tester.tap(find.text('Save to device'));
      await tester.pumpAndSettle();
      expect(exporter.saved.single.name, 'monthly-summary-20261105.csv');
      expect(find.text('Saved.'), findsOneWidget);
      verify(() => api.download('rep-1')).called(1);
    });

    testWidgets('a report being made is re-read until it is ready', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(() => api.get('rep-1')).thenAnswer((_) async {
        calls++;
        return report(status: calls == 1 ? 'running' : 'completed');
      });
      final ({Widget app, GoRouter router}) r = routedApp(
        '/reports/rep-1',
        overrides: overrides(),
      );
      await tester.pumpWidget(r.app);
      await settle(tester);
      expect(
        find.text('Your report is being made. This page updates by itself.'),
        findsOneWidget,
      );
      expect(find.text('Share'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Ready to download'), findsOneWidget);
    });

    testWidgets('an expired report explains and can be made again', (
      WidgetTester tester,
    ) async {
      when(() => api.get('rep-1')).thenAnswer((_) async => report());
      when(() => api.download('rep-1'))
          .thenThrow(serverError(ErrorObjectCode.gone, status: 410));
      when(() => api.create(any()))
          .thenAnswer((_) async => report(id: 'rep-3', status: 'queued'));
      when(() => api.get('rep-3'))
          .thenAnswer((_) async => report(id: 'rep-3', status: 'queued'));
      when(() => api.list()).thenAnswer((_) async => <ReportDto>[]);
      final GoRouter router = await pump(tester, '/reports/rep-1');

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(exporter.shared, isEmpty);
      expect(
        find.text('This report has expired. Make it again to download it.'),
        findsWidgets,
      );
      await tester.ensureVisible(find.text('Make it again'));
      await tester.tap(find.text('Make it again'));
      await settle(tester);
      final ReportInput sent =
          verify(() => api.create(captureAny())).captured.single as ReportInput;
      expect(sent.reportType, ReportInputReportType.monthlySummary);
      expect(sent.format, ReportInputFormat.csv);
      expect(locationOf(router), '/reports/rep-3');
    });

    testWidgets('a failed report says why', (WidgetTester tester) async {
      when(() => api.get('rep-1')).thenAnswer(
        (_) async => report(status: 'failed', errorCode: 'pdf_too_large'),
      );
      await pump(tester, '/reports/rep-1');
      expect(
        find.text(
          'This report is too long for a PDF. Choose CSV or Excel, or a '
          'shorter period.',
        ),
        findsOneWidget,
      );
      expect(find.text('Make it again'), findsOneWidget);
      expect(find.text('Share'), findsNothing);
    });
  });

  group('schedules', () {
    testWidgets('lists schedules and deletes one after confirming', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(() => api.schedules()).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? <ScheduleDto>[
                schedule(),
                schedule(
                  id: 'sch-2',
                  type: 'goal',
                  title: 'Goals each month',
                  format: 'xlsx',
                  cadence: 'monthly',
                  enabled: false,
                ),
              ]
            : <ScheduleDto>[];
      });
      when(() => api.deleteSchedule(any())).thenAnswer((_) async {});
      await pump(tester, '/reports/schedules');

      expect(find.text('Cash flow (weekly)'), findsOneWidget);
      expect(find.text('Every week · CSV'), findsOneWidget);
      expect(find.text('Goals each month'), findsOneWidget);
      expect(find.text('Turned off'), findsOneWidget);

      await tester.tap(find.byTooltip('Options for Cash flow (weekly)'));
      await tester.pumpAndSettle();
      expect(find.text('Pause'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this schedule?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      verify(() => api.deleteSchedule('sch-1')).called(1);
      expect(find.text('No scheduled reports'), findsOneWidget);
    });

    testWidgets('a schedule is paused and resumed with its version', (
      WidgetTester tester,
    ) async {
      when(() => api.schedules()).thenAnswer(
        (_) async => <ScheduleDto>[
          schedule(),
          schedule(id: 'sch-2', title: 'Goals', type: 'goal', enabled: false),
        ],
      );
      when(() => api.updateSchedule(any(), any()))
          .thenAnswer((_) async => schedule());
      await pump(tester, '/reports/schedules');
      await tester.tap(find.byTooltip('Options for Cash flow (weekly)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Options for Goals'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      final List<Object?> sent = verify(
        () => api.updateSchedule(captureAny(), captureAny()),
      ).captured;
      expect(sent[0], 'sch-1');
      expect((sent[1]! as SchedulePatch).toJson(), <String, Object?>{
        'enabled': false,
        'version': 1,
      });
      expect(sent[2], 'sch-2');
      expect((sent[3]! as SchedulePatch).toJson(), <String, Object?>{
        'enabled': true,
        'version': 1,
      });
      expect(find.text('Schedule resumed.'), findsOneWidget);
    });

    testWidgets('editing sends only the changes; a stale schedule reloads', (
      WidgetTester tester,
    ) async {
      int loads = 0;
      when(() => api.schedules()).thenAnswer((_) async => <ScheduleDto>[]);
      when(() => api.schedule('sch-1')).thenAnswer((_) async {
        loads++;
        return loads == 1 ? schedule() : schedule(format: 'pdf', version: 2);
      });
      int saves = 0;
      when(() => api.updateSchedule(any(), any())).thenAnswer((_) async {
        saves++;
        if (saves == 1) {
          throw serverError(ErrorObjectCode.versionConflict, status: 409);
        }
        return schedule();
      });
      await pump(tester, '/reports/schedules/sch-1/edit');
      expect(find.text('Edit schedule'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Every month'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('changed somewhere else'), findsOneWidget);
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      // Nothing was changed on the reloaded version.
      expect(saves, 1);
      expect(
        find.text('Nothing changed, so there was nothing to save.'),
        findsOneWidget,
      );
      final List<Object?> sent = verify(
        () => api.updateSchedule(captureAny(), captureAny()),
      ).captured;
      expect((sent[1]! as SchedulePatch).toJson(), <String, Object?>{
        'cadence': 'monthly',
        'version': 1,
      });
    });

    testWidgets('editing reads the one schedule; a deleted one is explained', (
      WidgetTester tester,
    ) async {
      when(() => api.schedule('sch-gone'))
          .thenThrow(serverError(ErrorObjectCode.notFound, status: 404));
      await pump(tester, '/reports/schedules/sch-gone/edit');
      expect(find.text('Edit schedule'), findsOneWidget);
      expect(
        find.text("This schedule doesn't exist any more."),
        findsOneWidget,
      );
      verifyNever(() => api.schedules());
    });

    testWidgets('a schedule that fails to load can be retried', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(() => api.schedule('sch-1')).thenAnswer((_) async {
        if (calls++ == 0) {
          throw const ApiException(kind: ApiErrorKind.network);
        }
        return schedule();
      });
      await pump(tester, '/reports/schedules/sch-1/edit');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'Every month'), findsOneWidget);
    });

    testWidgets('a report is deleted after confirming', (
      WidgetTester tester,
    ) async {
      when(() => api.list()).thenAnswer((_) async => <ReportDto>[]);
      when(() => api.get('rep-1')).thenAnswer((_) async => report());
      when(() => api.delete('rep-1')).thenAnswer((_) async {});
      final GoRouter router = await pump(tester, '/reports');
      unawaited(router.push<Object?>('/reports/rep-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete report'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this report?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      verify(() => api.delete('rep-1')).called(1);
      expect(find.text('Report deleted.'), findsOneWidget);
      expect(locationOf(router), '/reports');
    });

    testWidgets('a report shows the dates it covers; a failure says why', (
      WidgetTester tester,
    ) async {
      when(() => api.get('rep-1')).thenAnswer(
        (_) async => ReportDto.fromJson(<String, Object?>{
          ...reportJson(
            status: 'failed',
            errorCode: 'generation_failed',
            filters: <String, Object?>{'range': 'last_month'},
          ),
          'window': windowJson(from: '2026-10-01', to: '2026-10-31', days: 31),
        }),
      );
      await pump(tester, '/reports/rep-1');
      expect(
        find.text(
          'Making the report failed every time it was tried. Make it again, '
          'or narrow the period.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('(31 days)'), findsOneWidget);
    });

    testWidgets('a new schedule sends the type, format and cadence', (
      WidgetTester tester,
    ) async {
      when(() => api.schedules()).thenAnswer((_) async => <ScheduleDto>[]);
      when(() => api.createSchedule(any())).thenAnswer((_) async => schedule());
      await pump(tester, '/reports/schedules');
      await tester.tap(find.text('Schedule a report').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Every week'));
      await tester.pumpAndSettle();
      expect(
        find.text('Each report covers the previous full week.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Schedule report'));
      await tester.tap(find.text('Schedule report'));
      await tester.pumpAndSettle();
      final ScheduleInput sent =
          verify(() => api.createSchedule(captureAny())).captured.single
              as ScheduleInput;
      expect(sent.toJson(), <String, Object?>{
        'report_type': 'monthly_summary',
        'format': 'csv',
        'cadence': 'weekly',
      });
      expect(find.text('Report scheduled.'), findsOneWidget);
    });
  });
}
