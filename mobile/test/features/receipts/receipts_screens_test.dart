import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/files/file_export.dart';
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:montra_mobile/core/files/file_source.dart';
import 'package:montra_mobile/core/files/file_uploader.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/receipts/data/receipts_api.dart';
import 'package:montra_mobile/features/receipts/domain/receipt_codes.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';

import '../../helpers/files_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/receipts_fakes.dart';
import '../../helpers/router_app.dart';

/// A 409 answer with a coded detail, as the live receipts API sends them.
ApiException conflict(String code, {bool duplicate = false}) => ApiException(
  kind: ApiErrorKind.server,
  code: duplicate ? ErrorObjectCode.duplicate : ErrorObjectCode.conflict,
  statusCode: 409,
  message: 'English server text',
  details: <Detail>[Detail(code: code, message: 'English detail')],
);

void main() {
  late MockReceiptsApi api;
  late MockAccountsApi accounts;
  late MockLabelsApi labels;
  late MockTransactionsApi transactions;
  late MockFileUploader uploader;
  late MockFileDownloader downloader;
  late FakeFileSource source;
  late FakeFileExporter exporter;

  setUpAll(() {
    registerFinanceFallbacks();
    registerReceiptFallbacks();
    registerFileFallbacks();
  });

  setUp(() {
    api = MockReceiptsApi();
    accounts = MockAccountsApi();
    labels = MockLabelsApi();
    transactions = MockTransactionsApi();
    uploader = MockFileUploader();
    downloader = MockFileDownloader();
    source = FakeFileSource();
    exporter = FakeFileExporter();
    stubLabels(labels, categories: <CategoryDto>[category()]);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    when(() => downloader.download(any())).thenAnswer(
      (_) async => downloadedFile(name: 'r.png', mimeType: 'image/png'),
    );
  });

  List<Override> overrides() => <Override>[
    receiptsApiProvider.overrideWithValue(api),
    accountsApiProvider.overrideWithValue(accounts),
    labelsApiProvider.overrideWithValue(labels),
    transactionsApiProvider.overrideWithValue(transactions),
    fileUploaderProvider.overrideWithValue(uploader),
    fileDownloaderProvider.overrideWithValue(downloader),
    fileSourceProvider.overrideWithValue(source),
    fileExporterProvider.overrideWithValue(exporter),
  ];

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    // Let a focused field finish scrolling itself into view first.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  ReceiptView reviewed({String? transactionId, String method = 'manual'}) =>
      receiptView(
        status: transactionId == null ? 'reviewed' : 'matched',
        current: extractionJson(method: method),
        transactionId: transactionId,
      );

  void stubInbox(List<ReceiptDto> items) {
    when(
      () => api.list(
        status: any(named: 'status'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => receiptPage(items));
  }

  group('inbox', () {
    testWidgets('lists receipts with their details and status in words; '
        'filters by status', (WidgetTester tester) async {
      stubInbox(<ReceiptDto>[
        receipt(),
        receipt(
          id: 'rc-2',
          status: 'reviewed',
          current: extractionJson(),
          duplicateOfId: 'rc-1',
        ),
      ]);
      await pump(tester, '/receipts');

      expect(find.text('Receipts'), findsWidgets);
      expect(find.textContaining('never reads receipts'), findsOneWidget);
      expect(find.text('Details not entered yet'), findsOneWidget);
      expect(find.text('Details needed'), findsOneWidget);
      expect(find.text('Fresh Mart'), findsOneWidget);
      expect(find.text('₹1,250.50'), findsOneWidget);
      expect(find.text('Ready to record'), findsOneWidget);
      expect(find.text('Possible duplicate'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);

      await tester.tap(find.text('To fill in'));
      await tester.pumpAndSettle();
      verify(
        () => api.list(
          status: 'needs_review',
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).called(1);
    });

    testWidgets('more receipts load on request with the cursor', (
      WidgetTester tester,
    ) async {
      when(
        () => api.list(
          status: any(named: 'status'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((Invocation i) async {
        final String? cursor = i.namedArguments[#cursor] as String?;
        return cursor == null
            ? receiptPage(<ReceiptDto>[receipt()], next: 'c2')
            : receiptPage(<ReceiptDto>[
                receipt(
                  id: 'rc-2',
                  status: 'reviewed',
                  current: extractionJson(merchant: 'Corner Bakery'),
                ),
              ]);
      });
      await pump(tester, '/receipts');
      expect(find.text('Corner Bakery'), findsNothing);

      await tapVisible(tester, find.text('Load more'));
      verify(
        () => api.list(
          status: any(named: 'status'),
          cursor: 'c2',
          limit: any(named: 'limit'),
        ),
      ).called(1);
      expect(find.text('Corner Bakery'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('an empty inbox explains how receipts work', (
      WidgetTester tester,
    ) async {
      stubInbox(<ReceiptDto>[]);
      await pump(tester, '/receipts');
      expect(find.text('No receipts yet'), findsOneWidget);
      expect(find.textContaining('You enter the details'), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (WidgetTester tester) async {
      int calls = 0;
      when(
        () => api.list(
          status: any(named: 'status'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return receiptPage(<ReceiptDto>[receipt()]);
      });
      await pump(tester, '/receipts');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Details needed'), findsOneWidget);
    });
  });

  group('adding receipts', () {
    /// Uploads answer with `f-<file name without extension>`.
    void stubUploads({Set<String> failing = const <String>{}}) {
      when(
        () => uploader.upload(
          any(),
          any(),
          onStage: any(named: 'onStage'),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((Invocation i) async {
        final PickedFile file = i.positionalArguments.first as PickedFile;
        final void Function(UploadStage)? onStage =
            i.namedArguments[#onStage] as void Function(UploadStage)?;
        onStage?.call(UploadStage.sending);
        if (failing.contains(file.name)) {
          throw offline;
        }
        return fileDto(id: 'f-${file.name.split('.').first}', name: file.name);
      });
    }

    void stubCreate(ReceiptDto Function(List<String> ids) answer) {
      when(
        () => api.create(
          any(),
          notes: any(named: 'notes'),
          key: any(named: 'key'),
        ),
      ).thenAnswer(
        (Invocation i) async =>
            answer(i.positionalArguments.first as List<String>),
      );
    }

    Finder saveButton(String label) => find.widgetWithText(FilledButton, label);

    /// A tall phone, so every page of the list is laid out.
    void tall(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(1080, 4200)
        ..devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
    }

    testWidgets('Add receipt opens an empty list; one photo becomes a '
        'receipt for manual entry with an idempotency key', (
      WidgetTester tester,
    ) async {
      tall(tester);
      stubInbox(<ReceiptDto>[]);
      source.enqueue(pickedFile());
      stubUploads();
      stubCreate((List<String> ids) => receipt(id: 'rc-9'));
      when(() => api.get('rc-9'))
          .thenAnswer((_) async => receiptView(id: 'rc-9'));
      final GoRouter router = await pump(tester, '/receipts');

      await tester.tap(find.text('Add receipt'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/receipts/new');
      expect(find.text('No pages yet'), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose photos'), findsOneWidget);

      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      expect(source.manyRequests.single, (
        FileOrigin.files,
        UploadPurpose.receipt,
        20,
      ));
      expect(find.text('Page 1 of 1'), findsOneWidget);
      expect(find.text('Ready to upload'), findsOneWidget);

      await tester.tap(saveButton('Add receipt'));
      await tester.pumpAndSettle();
      final String key =
          verify(
                () => api.create(<String>[
                  'f-receipt',
                ], key: captureAny(named: 'key')),
              ).captured.single
              as String;
      expect(key.length, greaterThanOrEqualTo(8));
      expect(locationOf(router), '/receipts/rc-9');
      expect(find.text('Enter details'), findsWidgets);
    });

    testWidgets('several files are pages of one receipt in the order shown, '
        'with a note', (WidgetTester tester) async {
      tall(tester);
      source.enqueue(<PickedFile>[
        pickedFile(name: 'top.jpg', text: 'a'),
        pickedFile(name: 'bottom.pdf', text: 'b', mimeType: 'application/pdf'),
        pickedFile(name: 'middle.png', text: 'c', mimeType: 'image/png'),
      ]);
      stubUploads();
      stubCreate((List<String> ids) => receipt(id: 'rc-9'));
      when(() => api.get('rc-9'))
          .thenAnswer((_) async => receiptView(id: 'rc-9'));
      final GoRouter router = await pump(tester, '/receipts/new');

      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      expect(find.text('Page 3 of 3'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Move middle.png up'));
      expect(find.text('Pages of one receipt'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Note (optional)'),
        'Team lunch',
      );
      await tapVisible(tester, saveButton('Add receipt with 3 pages'));

      final List<Object?> captured = verify(
        () => api.create(
          captureAny(),
          notes: captureAny(named: 'notes'),
          key: any(named: 'key'),
        ),
      ).captured;
      expect(captured, <Object?>[
        <String>['f-top', 'f-middle', 'f-bottom'],
        'Team lunch',
      ]);
      expect(locationOf(router), '/receipts/rc-9');
      verifyNever(() => api.deleteUpload(any()));
    });

    testWidgets('separate receipts: each file becomes its own receipt', (
      WidgetTester tester,
    ) async {
      tall(tester);
      stubInbox(<ReceiptDto>[]);
      source.enqueue(<PickedFile>[
        pickedFile(name: 'a.jpg', text: 'a'),
        pickedFile(name: 'b.jpg', text: 'b'),
      ]);
      stubUploads();
      final List<List<String>> creates = <List<String>>[];
      stubCreate((List<String> ids) {
        creates.add(ids);
        return receipt(id: 'rc-${creates.length}');
      });
      final GoRouter router = await pump(tester, '/receipts');
      await tester.tap(find.text('Add receipt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose photos'));
      await tester.pumpAndSettle();
      expect(source.manyRequests.single.$1, FileOrigin.photos);
      await tapVisible(tester, find.text('Separate receipts'));
      expect(find.text('File 1 of 2'), findsOneWidget);
      await tapVisible(tester, saveButton('Add 2 receipts'));

      expect(creates, <List<String>>[
        <String>['f-a'],
        <String>['f-b'],
      ]);
      expect(locationOf(router), '/receipts');
      expect(
        find.text('2 receipts added. Enter their details next.'),
        findsOneWidget,
      );
    });

    testWidgets('a receipt that could not be created is retried with the '
        'same pages and key, without uploading again', (
      WidgetTester tester,
    ) async {
      tall(tester);
      source.enqueue(pickedFile());
      stubUploads();
      final List<String> keys = <String>[];
      when(
        () => api.create(
          <String>['f-receipt'],
          notes: any(named: 'notes'),
          key: any(named: 'key'),
        ),
      ).thenAnswer((Invocation i) async {
        keys.add(i.namedArguments[#key]! as String);
        if (keys.length == 1) {
          throw offline;
        }
        return receipt(id: 'rc-9');
      });
      when(() => api.get('rc-9'))
          .thenAnswer((_) async => receiptView(id: 'rc-9'));
      final GoRouter router = await pump(tester, '/receipts/new');
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      await tester.tap(saveButton('Add receipt'));
      await tester.pumpAndSettle();
      expect(find.text("The receipt wasn't added"), findsOneWidget);
      expect(
        find.textContaining('Check your internet connection'),
        findsWidgets,
      );
      expect(find.textContaining('Not added:'), findsOneWidget);

      await tester.tap(saveButton('Add receipt'));
      await tester.pumpAndSettle();
      expect(keys, hasLength(2));
      expect(keys.first, keys.last);
      verify(
        () => uploader.upload(
          any(),
          any(),
          onStage: any(named: 'onStage'),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
      expect(locationOf(router), '/receipts/rc-9');
    });

    testWidgets('a failed upload is shown on its page; trying again uploads '
        'only what is missing', (WidgetTester tester) async {
      tall(tester);
      source.enqueue(<PickedFile>[
        pickedFile(name: 'one.jpg', text: '1'),
        pickedFile(name: 'two.jpg', text: '2'),
      ]);
      stubUploads(failing: <String>{'two.jpg'});
      stubCreate((List<String> ids) => receipt(id: 'rc-9'));
      when(() => api.get('rc-9'))
          .thenAnswer((_) async => receiptView(id: 'rc-9'));
      await pump(tester, '/receipts/new');
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      await tapVisible(tester, saveButton('Add receipt with 2 pages'));
      expect(find.text('Uploaded'), findsOneWidget);
      expect(find.textContaining('Not added:'), findsOneWidget);
      expect(find.textContaining('Some pages couldn'), findsOneWidget);
      verifyNever(
        () => api.create(
          any(),
          notes: any(named: 'notes'),
          key: any(named: 'key'),
        ),
      );

      stubUploads();
      await tapVisible(tester, saveButton('Add receipt with 2 pages'));
      final List<String> names = <String>[
        for (final Object? f in verify(
          () => uploader.upload(
            captureAny(),
            any(),
            onStage: any(named: 'onStage'),
            onProgress: any(named: 'onProgress'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).captured)
          (f! as PickedFile).name,
      ];
      // one.jpg was uploaded once; only two.jpg was sent again.
      expect(names, <String>['one.jpg', 'two.jpg', 'two.jpg']);
      verify(
        () => api.create(
          <String>['f-one', 'f-two'],
          notes: any(named: 'notes'),
          key: any(named: 'key'),
        ),
      ).called(1);
    });

    testWidgets('files of the wrong type or already in the list are refused '
        'before uploading', (WidgetTester tester) async {
      tall(tester);
      source
        ..enqueue(<PickedFile>[
          pickedFile(name: 'notes.txt', mimeType: 'text/plain'),
          pickedFile(),
        ])
        ..enqueue(pickedFile());
      await pump(tester, '/receipts/new');
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          "notes.txt wasn't added: This file type isn't "
          'accepted',
        ),
        findsOneWidget,
      );
      expect(find.text('Page 1 of 1'), findsOneWidget);
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();
      expect(find.text('receipt.jpg is already in the list.'), findsOneWidget);
      verifyNever(
        () => uploader.upload(
          any(),
          any(),
          onStage: any(named: 'onStage'),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    testWidgets('stopping an upload creates nothing; leaving deletes the '
        'pages already uploaded', (WidgetTester tester) async {
      tall(tester);
      stubInbox(<ReceiptDto>[]);
      source.enqueue(<PickedFile>[
        pickedFile(name: 'one.jpg', text: '1'),
        pickedFile(name: 'two.jpg', text: '2'),
      ]);
      when(() => api.deleteUpload(any())).thenAnswer((_) async {});
      when(
        () => uploader.upload(
          any(),
          any(),
          onStage: any(named: 'onStage'),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((Invocation i) async {
        final PickedFile file = i.positionalArguments.first as PickedFile;
        if (file.name == 'one.jpg') {
          return fileDto(id: 'f-one');
        }
        final CancelToken token =
            i.namedArguments[#cancelToken]! as CancelToken;
        await token.whenCancel;
        throw const ApiException(kind: ApiErrorKind.cancelled);
      });
      final GoRouter router = await pump(tester, '/receipts');
      await tester.tap(find.text('Add receipt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      await tester.tap(saveButton('Add receipt with 2 pages'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Stop uploading'), findsOneWidget);
      await tester.tap(find.text('Stop uploading'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Stopped. Nothing was added'), findsOneWidget);
      verifyNever(
        () => api.create(
          any(),
          notes: any(named: 'notes'),
          key: any(named: 'key'),
        ),
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Leave without adding?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/receipts');
      verify(() => api.deleteUpload('f-one')).called(1);
    });

    for (final Locale locale in <Locale>[
      const Locale('en'),
      const Locale('hi'),
    ]) {
      testWidgets('the add screen fits at 200% text ($locale)', (
        WidgetTester tester,
      ) async {
        tester.view
          ..physicalSize = const Size(1080, 2340)
          ..devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        source.enqueue(<PickedFile>[
          pickedFile(name: 'a-rather-long-receipt-photo-name.jpg', text: 'a'),
          pickedFile(name: 'b.pdf', text: 'b', mimeType: 'application/pdf'),
        ]);
        final ({Widget app, GoRouter router}) r = routedApp(
          '/receipts/new',
          overrides: overrides(),
          locale: locale,
        );
        await tester.pumpWidget(r.app);
        await tester.pumpAndSettle();
        final Finder list = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(
          find.byIcon(Icons.upload_file_outlined),
          200,
          scrollable: list,
        );
        await tester.ensureVisible(find.byIcon(Icons.upload_file_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.upload_file_outlined));
        await tester.pumpAndSettle();
        expect(source.manyRequests, hasLength(1));
        for (int i = 0; i < 10; i++) {
          await tester.drag(list, const Offset(0, -400));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('detail and review', () {
    testWidgets('the details are typed by hand and saved with the version', (
      WidgetTester tester,
    ) async {
      when(() => api.get('rc-1')).thenAnswer((_) async => receiptView());
      when(() => api.review('rc-1', any()))
          .thenAnswer((_) async => receipt(status: 'reviewed'));
      final GoRouter router = await pump(tester, '/receipts/rc-1');
      expect(find.text('Details needed'), findsOneWidget);
      verify(() => downloader.download('file-rc-1')).called(1);

      await tester.tap(find.widgetWithText(FilledButton, 'Enter details'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/receipts/rc-1/review');
      await tester.scrollUntilVisible(
        find.textContaining("Don't enter card or account numbers"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          "For example cash, UPI or card. Don't enter card or account "
          'numbers.',
        ),
        findsOneWidget,
      );

      await tapVisible(tester, find.text('Save details'));
      await tester.scrollUntilVisible(
        find.text('Choose the date on the receipt.'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Choose the date on the receipt.'), findsOneWidget);
      verifyNever(() => api.review(any(), any()));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Shop or merchant'),
        'Fresh Mart',
      );
      await tapVisible(tester, find.text('Choose a date'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Total'),
        '1250.50',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Tax'), '50');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'How you paid'),
        'UPI',
      );
      await tapVisible(tester, find.text('Save details'));

      final ReceiptReviewInput input =
          verify(() => api.review('rc-1', captureAny())).captured.single
              as ReceiptReviewInput;
      expect(input.merchantName, 'Fresh Mart');
      expect(input.total, '1250.50');
      expect(input.tax, '50.00');
      expect(input.currency, 'INR');
      expect(input.paymentHint, 'UPI');
      expect(input.version, 1);
      expect(input.receiptDate, LocalDates.format(LocalDates.today()));
      expect(find.text('Receipt details saved.'), findsOneWidget);
      expect(locationOf(router), '/receipts/rc-1');
    });

    testWidgets('a change made elsewhere reloads the receipt', (
      WidgetTester tester,
    ) async {
      when(() => api.get('rc-1'))
          .thenAnswer((_) async => receiptView(current: extractionJson()));
      when(() => api.review('rc-1', any())).thenThrow(
        const ApiException(
          kind: ApiErrorKind.server,
          code: ErrorObjectCode.versionConflict,
          statusCode: 409,
        ),
      );
      await pump(tester, '/receipts/rc-1/review');
      await tapVisible(tester, find.text('Save details'));
      verify(() => api.get('rc-1')).called(2);
      await tester.scrollUntilVisible(
        find.textContaining('changed somewhere else'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('changed somewhere else'), findsOneWidget);
    });

    testWidgets('a reviewed receipt is linked to a suggested expense; reason '
        'codes are shown in words', (WidgetTester tester) async {
      when(() => api.get('rc-1')).thenAnswer((_) async => reviewed());
      when(() => api.matchCandidates('rc-1')).thenAnswer(
        (_) async => <ReceiptMatchCandidate>[
          suggestion(
            reasons: <String>['English reason one', 'English reason two'],
            codes: <String>['amount_close', 'near_date'],
          ),
        ],
      );
      when(() => api.match('rc-1', 'tx-9'))
          .thenAnswer((_) async => receipt(status: 'matched'));
      final GoRouter router = await pump(tester, '/receipts/rc-1');
      expect(find.text('Ready to record'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Find the expense'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/receipts/rc-1/match');
      expect(
        find.text(
          'amount within 20% of the total (tip or fees) · within 3 days',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Link'));
      await tester.pumpAndSettle();
      verify(() => api.match('rc-1', 'tx-9')).called(1);
      expect(find.text('Receipt linked to the expense.'), findsOneWidget);
      expect(locationOf(router), '/receipts/rc-1');
    });

    testWidgets('a suggestion that already has a receipt is explained', (
      WidgetTester tester,
    ) async {
      when(() => api.get('rc-1')).thenAnswer((_) async => reviewed());
      when(() => api.matchCandidates('rc-1'))
          .thenAnswer((_) async => <ReceiptMatchCandidate>[suggestion()]);
      when(() => api.match('rc-1', 'tx-9'))
          .thenThrow(conflict('transaction_has_receipt', duplicate: true));
      await pump(tester, '/receipts/rc-1/match');
      expect(find.text('same amount as the total · same date'), findsOneWidget);
      await tester.tap(find.text('Link'));
      await tester.pumpAndSettle();
      expect(find.text('That transaction already has a receipt.'), findsOne);
    });

    testWidgets('recording the purchase needs an account and reuses the '
        'idempotency key after a lost connection', (WidgetTester tester) async {
      when(() => api.get('rc-1')).thenAnswer((_) async => reviewed());
      final List<String> keys = <String>[];
      when(() => api.createTransaction('rc-1', any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            keys.add(i.namedArguments[#key]! as String);
            if (keys.length == 1) {
              throw offline;
            }
            return receipt(status: 'matched', transactionId: 'tx-new');
          });
      final GoRouter router = await pump(tester, '/receipts/rc-1/record');
      expect(find.text('Fresh Mart'), findsOneWidget);
      expect(find.text('−₹1,250.50'), findsOneWidget);

      await tapVisible(tester, find.text('Record expense'));
      await tester.scrollUntilVisible(
        find.text('Choose the account you paid from.'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Choose the account you paid from.'), findsOneWidget);

      await tapVisible(tester, find.text('Choose an account'));
      await tester.tap(find.text('HDFC Savings').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Record expense'));
      await tester.scrollUntilVisible(
        find.textContaining('Check your internet connection'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Check your internet connection'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Record expense'));

      expect(keys, hasLength(2));
      expect(keys.first, keys.last);
      final ReceiptCreateTransactionInput input =
          verify(
                () => api.createTransaction(
                  'rc-1',
                  captureAny(),
                  key: any(named: 'key'),
                ),
              ).captured.last
              as ReceiptCreateTransactionInput;
      expect(input.accountId, 'acc-1');
      expect(find.text('Expense recorded from the receipt.'), findsOneWidget);
      expect(locationOf(router), isNot(contains('/record')));
    });

    testWidgets('a receipt linked elsewhere meanwhile is explained and '
        'reloaded', (WidgetTester tester) async {
      int gets = 0;
      when(() => api.get('rc-1')).thenAnswer((_) async {
        gets++;
        return gets == 1 ? reviewed() : reviewed(transactionId: 'tx-7');
      });
      when(() => api.createTransaction('rc-1', any(), key: any(named: 'key')))
          .thenThrow(conflict('receipt_linked'));
      await pump(tester, '/receipts/rc-1/record');
      await tapVisible(tester, find.text('Choose an account'));
      await tester.tap(find.text('HDFC Savings').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Record expense'));

      expect(gets, 2);
      expect(find.text("This receipt can't be recorded yet"), findsOneWidget);
    });

    testWidgets('values that were not reviewed by hand are checked before '
        'recording', (WidgetTester tester) async {
      when(() => api.get('rc-1'))
          .thenAnswer((_) async => reviewed(method: 'deterministic_text'));
      final GoRouter router = await pump(tester, '/receipts/rc-1');
      expect(find.textContaining("weren't entered by you"), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Check the details'),
        findsOneWidget,
      );
      expect(find.text('Record as a new expense'), findsNothing);

      unawaited(router.push<Object?>('/receipts/rc-1/record'));
      await tester.pumpAndSettle();
      expect(find.text("This receipt can't be recorded yet"), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Check the details'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/receipts/rc-1/review');
    });

    testWidgets('unlinking and discarding ask first; discard sends the '
        'version', (WidgetTester tester) async {
      when(() => api.get('rc-1'))
          .thenAnswer((_) async => reviewed(transactionId: 'tx-9'));
      when(() => api.unlink('rc-1'))
          .thenAnswer((_) async => receipt(status: 'reviewed'));
      when(() => api.discard('rc-1', version: any(named: 'version')))
          .thenAnswer((_) async => receipt(status: 'discarded'));
      await pump(tester, '/receipts/rc-1');
      expect(find.text('Linked to a transaction'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Unlink'));
      await tester.pumpAndSettle();
      expect(find.text('Unlink this receipt?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Unlink'));
      await tester.pumpAndSettle();
      verify(() => api.unlink('rc-1')).called(1);
      expect(find.text('Receipt unlinked.'), findsOneWidget);

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this receipt?'), findsOneWidget);
      expect(find.textContaining('If you restore the receipt later'), findsOne);
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();
      verify(() => api.discard('rc-1', version: 1)).called(1);
      expect(find.text('Receipt discarded.'), findsOneWidget);
    });

    testWidgets('a discarded receipt can be restored with its version', (
      WidgetTester tester,
    ) async {
      when(() => api.get('rc-1')).thenAnswer(
        (_) async => receiptView(
          status: 'discarded',
          current: extractionJson(),
          version: 4,
        ),
      );
      when(() => api.restore('rc-1', version: any(named: 'version')))
          .thenAnswer((_) async => receipt(status: 'reviewed', version: 5));
      await pump(tester, '/receipts/rc-1');
      expect(find.text('Discarded'), findsOneWidget);
      expect(find.text('Find the expense'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
      await tester.pumpAndSettle();
      verify(() => api.restore('rc-1', version: 4)).called(1);
      expect(find.text('Receipt restored.'), findsOneWidget);
    });

    testWidgets('discarding a receipt discarded elsewhere is explained and '
        'reloads it', (WidgetTester tester) async {
      int gets = 0;
      when(() => api.get('rc-1')).thenAnswer((_) async {
        gets++;
        return receiptView(status: gets == 1 ? 'needs_review' : 'discarded');
      });
      when(() => api.discard('rc-1', version: any(named: 'version')))
          .thenThrow(conflict('receipt_discarded'));
      await pump(tester, '/receipts/rc-1');
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();

      expect(
        find.text('This receipt was discarded. Restore it first.'),
        findsOneWidget,
      );
      expect(gets, 2);
      expect(find.widgetWithText(FilledButton, 'Restore'), findsOneWidget);
    });

    testWidgets('coded remarks about the values are shown in words', (
      WidgetTester tester,
    ) async {
      when(() => api.get('rc-1')).thenAnswer(
        (_) async => receiptView(
          status: 'reviewed',
          current: extractionJson(
            warnings: <String>[
              'Line items add up to 1100.00, not the subtotal.',
              'An amount could not be read: 12,3O',
              'The date could not be read; check it.',
              'Faded print near the bottom.',
            ],
            warningCodes: <String>[
              'line_items_mismatch',
              'amount_unreadable',
              'date_unreadable',
              'reader_note',
            ],
            warningParams: <Map<String, String>>[
              <String, String>{
                'line_items_total': '1100.00',
                'subtotal': '1200.50',
                'currency': 'INR',
              },
              <String, String>{'value': '12,3O'},
              <String, String>{},
              <String, String>{},
            ],
          ),
        ),
      );
      await pump(tester, '/receipts/rc-1');
      expect(
        find.text(
          'The items add up to ₹1,100.00, not the subtotal of ₹1,200.50. '
          'Check the numbers.',
        ),
        findsOneWidget,
      );
      expect(
        find.text("An amount couldn't be read (“12,3O”). Check it."),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Faded print near the bottom.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text("The date couldn't be read. Check it."), findsOneWidget);
      expect(find.text('Faded print near the bottom.'), findsOneWidget);
    });

    testWidgets('a page opens full screen with share and save', (
      WidgetTester tester,
    ) async {
      when(() => api.get('rc-1')).thenAnswer((_) async => reviewed());
      await pump(tester, '/receipts/rc-1');
      await tapVisible(tester, find.text('Open page 1'));
      expect(find.text('Save to device'), findsOneWidget);
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(exporter.shared.single.name, 'r.png');
      await tester.tap(find.text('Save to device'));
      await tester.pumpAndSettle();
      expect(exporter.saved, hasLength(1));
      expect(find.text('Saved.'), findsWidgets);
    });

    testWidgets('a receipt that fails to load offers a retry', (
      WidgetTester tester,
    ) async {
      when(() => api.get('rc-1')).thenThrow(offline);
      await pump(tester, '/receipts/rc-1');
      expect(find.text("You're offline"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('no matching expense offers other ways', (
      WidgetTester tester,
    ) async {
      when(() => api.get('rc-1')).thenAnswer((_) async => reviewed());
      when(() => api.matchCandidates('rc-1'))
          .thenAnswer((_) async => <ReceiptMatchCandidate>[]);
      await pump(tester, '/receipts/rc-1/match');
      expect(find.textContaining('No recorded expense'), findsOneWidget);
      expect(find.text('Choose another expense'), findsOneWidget);
      expect(find.text('Record as a new expense'), findsOneWidget);
    });
  });

  group('other states', () {
    testWidgets('suggestions that fail to load can be retried', (
      WidgetTester tester,
    ) async {
      when(() => api.get('rc-1')).thenAnswer((_) async => reviewed());
      int calls = 0;
      when(() => api.matchCandidates('rc-1')).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return <ReceiptMatchCandidate>[suggestion()];
      });
      await pump(tester, '/receipts/rc-1/match');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Link'), findsOneWidget);
    });

    testWidgets('a receipt without details cannot be recorded yet', (
      WidgetTester tester,
    ) async {
      when(() => api.get('rc-1')).thenAnswer((_) async => receiptView());
      await pump(tester, '/receipts/rc-1/record');
      expect(find.text("This receipt can't be recorded yet"), findsOneWidget);
      expect(
        find.textContaining('Enter the details from the receipt'),
        findsOneWidget,
      );
    });

    testWidgets('a linked receipt cannot be reviewed until unlinked', (
      WidgetTester tester,
    ) async {
      when(() => api.get('rc-1'))
          .thenAnswer((_) async => reviewed(transactionId: 'tx-9'));
      await pump(tester, '/receipts/rc-1/review');
      expect(find.text("These details can't be changed now"), findsOneWidget);
    });
  });

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('receipt screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      when(
        () => api.list(
          status: any(named: 'status'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => receiptPage(<ReceiptDto>[
          receipt(),
          receipt(
            id: 'rc-2',
            status: 'reviewed',
            current: extractionJson(
              merchant: 'A rather long shop name for the receipt',
            ),
            duplicateOfId: 'rc-1',
          ),
        ], next: 'c2'),
      );
      when(() => api.get('rc-1')).thenAnswer(
        (_) async => receiptView(
          status: 'reviewed',
          duplicateOfId: 'rc-2',
          notes: 'Lunch with the team',
          current: extractionJson(
            subtotal: '1200.50',
            tax: '50.00',
            warnings: <String>[
              'Line items add up to 1100.00, not the subtotal.',
              'An amount could not be read: 12,3O',
            ],
            warningCodes: <String>['line_items_mismatch', 'amount_unreadable'],
            warningParams: <Map<String, String>>[
              <String, String>{
                'line_items_total': '1100.00',
                'subtotal': '1200.50',
                'currency': 'INR',
              },
              <String, String>{'value': '12,3O'},
            ],
            lineItems: <Map<String, Object?>>[
              <String, Object?>{
                'position': 1,
                'description': 'Basmati rice 5 kg bag',
                'quantity': '2',
                'unit_price': moneyJson('600.25'),
                'amount': moneyJson('1200.50'),
              },
            ],
          ),
        ),
      );
      when(() => api.get('rc-3')).thenAnswer(
        (_) async => receiptView(
          id: 'rc-3',
          status: 'discarded',
          current: extractionJson(method: 'deterministic_text'),
        ),
      );
      when(() => api.matchCandidates('rc-1')).thenAnswer(
        (_) async => <ReceiptMatchCandidate>[
          suggestion(codes: <String>['same_amount', 'same_date']),
        ],
      );
      final ({Widget app, GoRouter router}) r = routedApp(
        '/receipts',
        overrides: overrides(),
        locale: locale,
      );
      await tester.pumpWidget(r.app);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (int i = 0; i < 4; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: 'inbox');

      for (final String location in <String>[
        '/receipts/rc-1',
        '/receipts/rc-3',
        '/receipts/rc-1/review',
        '/receipts/rc-1/match',
        '/receipts/rc-1/record',
      ]) {
        unawaited(r.router.push<Object?>(location));
        await tester.pumpAndSettle();
        for (int i = 0; i < 12; i++) {
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
