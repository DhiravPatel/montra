import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/files/file_export.dart';
import 'package:montra_mobile/features/reports/data/reports_api.dart';

import '../../helpers/files_fakes.dart';
import '../../helpers/insights_fakes.dart';
import '../../helpers/router_app.dart';

/// Report screens at 200 % text in English and Hindi must lay out without
/// overflow.
void main() {
  late MockReportsApi api;

  setUpAll(registerInsightsFallbacks);

  setUp(() {
    api = MockReportsApi();
    when(() => api.list()).thenAnswer(
      (_) async => <ReportDto>[
        report(
          id: 'rep-2',
          type: 'transactions',
          title: 'A long title for the tax papers of the whole year 2026',
          format: 'xlsx',
          status: 'failed',
          errorCode: 'too_many_rows',
        ),
        report(),
        report(id: 'rep-3', status: 'expired'),
      ],
    );
    when(() => api.get('rep-1')).thenAnswer(
      (_) async => ReportDto.fromJson(<String, Object?>{
        ...reportJson(filters: <String, Object?>{'range': 'last_month'}),
        'window': windowJson(from: '2026-10-01', to: '2026-10-31', days: 31),
      }),
    );
    when(() => api.get('rep-2')).thenAnswer(
      (_) async =>
          report(id: 'rep-2', status: 'failed', errorCode: 'pdf_too_large'),
    );
    when(() => api.schedule('sch-1')).thenAnswer((_) async => schedule());
    when(() => api.schedules()).thenAnswer(
      (_) async => <ScheduleDto>[
        schedule(),
        schedule(
          id: 'sch-2',
          type: 'yearly_summary',
          title: 'Yearly summary (monthly)',
          cadence: 'monthly',
          enabled: false,
        ),
      ],
    );
  });

  List<Override> overrides() => <Override>[
    reportsApiProvider.overrideWithValue(api),
    fileDownloaderProvider.overrideWithValue(MockFileDownloader()),
    fileExporterProvider.overrideWithValue(FakeFileExporter()),
  ];

  /// Opens [start], then pushes each of [locations] at 200 % text in
  /// [locale], scrolling through it; any overflow fails the test.
  Future<void> walk(
    WidgetTester tester,
    Locale locale,
    String start,
    List<String> locations, {
    Future<void> Function(WidgetTester tester, String location)? extra,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final ({Widget app, GoRouter router}) r = routedApp(
      start,
      overrides: overrides(),
      locale: locale,
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: start);
    for (final String location in locations) {
      unawaited(r.router.push<Object?>(location));
      await tester.pumpAndSettle();
      for (int i = 0; i < 8; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: location);
      if (extra != null) {
        await extra(tester, location);
        expect(tester.takeException(), isNull, reason: '$location (more)');
      }
      r.router.pop();
      await tester.pumpAndSettle();
    }
  }

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('report screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      await walk(tester, locale, '/reports', <String>[
        '/reports/new',
        '/reports/rep-1',
        '/reports/rep-2',
        '/reports/schedules',
        '/reports/schedules/new',
        '/reports/schedules/sch-1/edit',
      ]);
    });
  }
}
