import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/files/file_export.dart';
import 'package:montra_mobile/features/privacy/data/privacy_api.dart';
import 'package:montra_mobile/features/settings/data/limits_api.dart';

import '../../helpers/files_fakes.dart';
import '../../helpers/router_app.dart';
import '../../helpers/support_fakes.dart';

void main() {
  late MockPrivacyApi api;
  late MockLimitsApi limitsApi;
  late MockFileDownloader downloader;
  late FakeFileExporter exporter;

  setUpAll(() {
    registerSupportFallbacks();
    registerFileFallbacks();
  });

  setUp(() {
    api = MockPrivacyApi();
    limitsApi = MockLimitsApi();
    downloader = MockFileDownloader();
    exporter = FakeFileExporter();
    when(() => api.legal()).thenAnswer((_) async => legalDto());
    when(() => api.consents()).thenAnswer(
      (_) async => <ConsentDto>[
        consentDto('terms'),
        consentDto('privacy_policy'),
        consentDto('marketing_email'),
      ],
    );
    when(() => api.exports()).thenAnswer((_) async => <ExportDto>[exportDto()]);
    when(() => api.deletion()).thenAnswer((_) async => deletionDto());
    when(() => limitsApi.get()).thenAnswer((_) async => limitsDto());
  });

  List<Override> overrides() => <Override>[
    privacyApiProvider.overrideWithValue(api),
    limitsApiProvider.overrideWithValue(limitsApi),
    fileDownloaderProvider.overrideWithValue(downloader),
    fileExporterProvider.overrideWithValue(exporter),
  ];

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  group('privacy & data', () {
    testWidgets('consents: required ones, optional switches with the legal '
        'version; AI consents only when given', (WidgetTester tester) async {
      when(() => api.grant(any(), any()))
          .thenAnswer((_) async => consentDto('location'));
      when(() => api.revoke(any())).thenAnswer((_) async {});
      await pump(tester, '/privacy');
      expect(find.text('Terms of use'), findsOneWidget);
      expect(
        find.textContaining('Accepted (version 2026-11-01)'),
        findsNWidgets(2),
      );
      expect(find.text('AI features'), findsNothing);
      final Finder location = find.widgetWithText(
        SwitchListTile,
        'Location on transactions',
      );
      expect(tester.widget<SwitchListTile>(location).value, isFalse);
      await tester.tap(location);
      await tester.pumpAndSettle();
      verify(
        () =>
            api.grant(MeConsentsGrantRequestConsentType.location, '2026-11-01'),
      ).called(1);
      expect(find.text('Consent given.'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Product news by email'),
      );
      await tester.pumpAndSettle();
      verify(() => api.revoke('marketing_email')).called(1);
    });

    testWidgets('an AI consent given elsewhere can only be withdrawn', (
      WidgetTester tester,
    ) async {
      when(() => api.consents())
          .thenAnswer((_) async => <ConsentDto>[consentDto('ai_processing')]);
      await pump(tester, '/privacy');
      final Finder ai = find.widgetWithText(SwitchListTile, 'AI features');
      expect(tester.widget<SwitchListTile>(ai).value, isTrue);
      expect(tester.widget<SwitchListTile>(ai).onChanged, isNotNull);
    });

    testWidgets('exports: request, poll until ready, download and share', (
      WidgetTester tester,
    ) async {
      int reads = 0;
      when(() => api.exports()).thenAnswer((_) async {
        reads++;
        return <ExportDto>[
          exportDto(id: 'exp-2', status: reads < 2 ? 'running' : 'completed'),
        ];
      });
      when(() => api.requestExport())
          .thenAnswer((_) async => exportDto(id: 'exp-2', status: 'queued'));
      when(() => downloader.download('file-exp')).thenAnswer(
        (_) async => DownloadedFile(
          name: 'montra-export-20261112.zip',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          mimeType: 'application/zip',
        ),
      );
      await pump(tester, '/privacy?export=exp-2');
      expect(find.text('Being made'), findsOneWidget);
      await tester.tap(find.text('Request a copy'));
      await tester.pump();
      expect(find.text('Waiting to start'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Ready to download'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      final int settled = reads;
      await tester.pump(const Duration(seconds: 10));
      expect(reads, settled, reason: 'polling stops once ready');
      await tester.tap(find.byTooltip('Download your data'));
      await tester.pumpAndSettle();
      expect(find.text('Your data is ready'), findsOneWidget);
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(exporter.shared.single.name, 'montra-export-20261112.zip');
    });

    testWidgets('a failed or expired export says what to do', (
      WidgetTester tester,
    ) async {
      when(() => api.exports()).thenAnswer(
        (_) async => <ExportDto>[
          exportDto(status: 'failed'),
          exportDto(id: 'exp-0', status: 'expired'),
        ],
      );
      await pump(tester, '/privacy');
      expect(find.text("Couldn't be made"), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      expect(find.byTooltip('Download your data'), findsNothing);
    });

    testWidgets('no exports, and a failed load offers a retry', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(() => api.exports()).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw const ApiException(kind: ApiErrorKind.network);
        }
        return <ExportDto>[];
      });
      await pump(tester, '/privacy');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text("You haven't requested a copy yet."), findsOneWidget);
    });
  });

  group('closing the account', () {
    testWidgets('deactivate asks first, then ends the session', (
      WidgetTester tester,
    ) async {
      when(() => api.deactivate()).thenAnswer((_) async {});
      await pump(tester, '/privacy/deactivate');
      expect(find.text('Close your account for now'), findsOneWidget);
      await tester.tap(find.text('Close my account'));
      // The button shows progress while the dialog is open.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Close your account?'), findsOneWidget);
      await tester.tap(find.text('Close my account').last);
      // The session ends here; the router (not installed in this test)
      // would take the user to the welcome screen.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      verify(() => api.deactivate()).called(1);
    });

    testWidgets('deletion: consequences by code, group impact, typed '
        'confirmation, then cancel', (WidgetTester tester) async {
      DeletionDto current = deletionDto();
      when(() => api.deletion()).thenAnswer((_) async => current);
      when(() => api.requestDeletion(reason: any(named: 'reason')))
          .thenAnswer((_) async {
            current = deletionDto(status: 'scheduled');
            return current;
          });
      when(() => api.cancelDeletion()).thenAnswer((_) async {
        current = deletionDto(status: 'cancelled');
        return current;
      });
      await pump(tester, '/privacy/delete');
      expect(
        find.text(
          "You'll be signed out of every device and connected services will "
          'be disconnected.',
        ),
        findsOneWidget,
      );
      // An unknown retained code keeps the server's English text.
      expect(find.text('New rule'), findsOneWidget);
      expect(
        find.text(
          'Flat 4B: ownership will pass to its longest-standing admin or '
          'member.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      expect(find.text('Type DELETE exactly to confirm.'), findsOneWidget);
      verifyNever(() => api.requestDeletion(reason: any(named: 'reason')));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Type DELETE to confirm'),
        'DELETE',
      );
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      verify(() => api.requestDeletion(reason: '')).called(1);
      expect(find.text('Account deletion scheduled'), findsOneWidget);
      await tester.tap(find.text('Keep my account'));
      await tester.pumpAndSettle();
      verify(() => api.cancelDeletion()).called(1);
      expect(
        find.text('Deletion cancelled. Your account stays.'),
        findsOneWidget,
      );
    });
  });

  group('limits', () {
    testWidgets('every limit, the storage meter and the fair-use note', (
      WidgetTester tester,
    ) async {
      await pump(tester, '/limits');
      expect(
        find.textContaining('Every feature is free for everyone.'),
        findsOneWidget,
      );
      expect(find.text('512 MB of 2048 MB used'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Open bills'), findsOneWidget);
      expect(find.text('Recurring payments'), findsOneWidget);
      expect(find.text('Rows per statement import'), findsOneWidget);
      expect(find.text('7 days'), findsNWidgets(2));
      expect(find.text('Friends and community'), findsOneWidget);
      // The app has no AI, so the AI rate is not listed.
      expect(find.text('AI'), findsNothing);
    });

    testWidgets('a failed load offers a retry', (WidgetTester tester) async {
      when(() => limitsApi.get())
          .thenThrow(const ApiException(kind: ApiErrorKind.network));
      await pump(tester, '/limits');
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('privacy screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      when(() => api.exports()).thenAnswer(
        (_) async => <ExportDto>[
          exportDto(),
          exportDto(id: 'e2', status: 'failed'),
        ],
      );
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final ({Widget app, GoRouter router}) r = routedApp(
        '/privacy',
        overrides: overrides(),
        locale: locale,
      );
      await tester.pumpWidget(r.app);
      await tester.pumpAndSettle();
      for (int i = 0; i < 8; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      for (final String location in <String>[
        '/privacy/deactivate',
        '/privacy/delete',
        '/limits',
      ]) {
        unawaited(r.router.push<Object?>(location));
        await tester.pumpAndSettle();
        for (int i = 0; i < 8; i++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -600),
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: location);
        r.router.pop();
        await tester.pumpAndSettle();
      }
    });
  }
}
