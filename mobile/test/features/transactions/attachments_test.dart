import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/files/file_export.dart';
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:montra_mobile/core/files/file_source.dart';
import 'package:montra_mobile/core/files/file_uploader.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/payment_methods/data/payment_methods_api.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';

import '../../helpers/files_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/router_app.dart';

/// Attachments on the transaction page: add a photo or PDF (upload with the
/// `transaction_attachment` purpose, then attach), open one, and the link to
/// the receipt a transaction was recorded from.
void main() {
  late MockTransactionsApi api;
  late MockAccountsApi accounts;
  late MockLabelsApi labels;
  late MockPaymentMethodsApi methods;
  late MockFileUploader uploader;
  late MockFileDownloader downloader;
  late FakeFileSource source;
  late FakeFileExporter exporter;

  AttachmentDto attachment({
    String fileId = 'f1',
    String name = 'warranty.pdf',
    String type = 'application/pdf',
  }) => AttachmentDto.fromJson(<String, Object?>{
    'file_id': fileId,
    'filename': name,
    'content_type': type,
    'size_bytes': 15 << 20,
    'purpose': 'transaction_attachment',
    'attached_at': '2026-11-04T08:00:00Z',
  });

  setUpAll(() {
    registerFinanceFallbacks();
    registerFileFallbacks();
  });

  setUp(() {
    api = MockTransactionsApi();
    accounts = MockAccountsApi();
    labels = MockLabelsApi();
    methods = MockPaymentMethodsApi();
    uploader = MockFileUploader();
    downloader = MockFileDownloader();
    source = FakeFileSource();
    exporter = FakeFileExporter();
    stubLabels(labels, categories: <CategoryDto>[category()]);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    when(() => methods.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <PaymentMethodDto>[]);
    when(() => api.get('tx-1')).thenAnswer((_) async => transaction());
    when(() => api.audit('tx-1')).thenAnswer((_) async => <AuditEventDto>[]);
  });

  List<Override> overrides() => <Override>[
    transactionsApiProvider.overrideWithValue(api),
    accountsApiProvider.overrideWithValue(accounts),
    labelsApiProvider.overrideWithValue(labels),
    paymentMethodsApiProvider.overrideWithValue(methods),
    fileUploaderProvider.overrideWithValue(uploader),
    fileDownloaderProvider.overrideWithValue(downloader),
    fileSourceProvider.overrideWithValue(source),
    fileExporterProvider.overrideWithValue(exporter),
  ];

  Future<GoRouter> pump(WidgetTester tester) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      '/transactions',
      overrides: overrides(),
    );
    when(
      () => api.list(
        any(),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => page(<TransactionDto>[]));
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    unawaited(r.router.push<Object?>('/transactions/tx-1'));
    await tester.pumpAndSettle();
    return r.router;
  }

  testWidgets('a photo or PDF is uploaded and attached to the transaction', (
    WidgetTester tester,
  ) async {
    int lists = 0;
    when(() => api.attachments('tx-1')).thenAnswer((_) async {
      lists++;
      return lists == 1 ? <AttachmentDto>[] : <AttachmentDto>[attachment()];
    });
    source.enqueue(
      pickedFile(name: 'warranty.pdf', mimeType: 'application/pdf'),
    );
    when(
      () => uploader.upload(
        any(),
        any(),
        onStage: any(named: 'onStage'),
        onProgress: any(named: 'onProgress'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => fileDto(id: 'file-5', purpose: 'transaction_attachment'),
    );
    when(() => api.attach('tx-1', 'file-5'))
        .thenAnswer((_) async => transaction());
    await pump(tester);

    await tester.scrollUntilVisible(find.text('Add file'), 300);
    expect(find.textContaining('No files are attached'), findsOneWidget);
    await tester.tap(find.text('Add file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();

    expect(source.requests.single, (
      FileOrigin.files,
      UploadPurpose.transactionAttachment,
    ));
    final List<dynamic> upload = verify(
      () => uploader.upload(
        captureAny(),
        captureAny(),
        onStage: any(named: 'onStage'),
        onProgress: any(named: 'onProgress'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).captured;
    expect((upload[0] as PickedFile).name, 'warranty.pdf');
    expect(upload[1], UploadPurpose.transactionAttachment);
    verify(() => api.attach('tx-1', 'file-5')).called(1);
    expect(find.text('File attached.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('warranty.pdf'), 300);
    expect(find.textContaining('application/pdf · 15 MB'), findsOneWidget);
  });

  testWidgets('an attachment opens with share and save', (
    WidgetTester tester,
  ) async {
    when(() => api.attachments('tx-1'))
        .thenAnswer((_) async => <AttachmentDto>[attachment()]);
    when(() => downloader.download('f1')).thenAnswer(
      (_) async =>
          downloadedFile(name: 'warranty.pdf', mimeType: 'application/pdf'),
    );
    await pump(tester);
    await tester.scrollUntilVisible(find.text('warranty.pdf'), 300);
    await tester.tap(find.text('warranty.pdf'));
    await tester.pumpAndSettle();

    expect(find.textContaining('PDF files open in another app'), findsOne);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(exporter.shared.single.mimeType, 'application/pdf');
  });

  testWidgets('a transaction recorded from a receipt links to it', (
    WidgetTester tester,
  ) async {
    when(() => api.get('tx-1')).thenAnswer(
      (_) async => TransactionDto.fromJson(<String, Object?>{
        ...transactionJson(),
        'receipt_id': 'rc-1',
      }),
    );
    when(() => api.attachments('tx-1'))
        .thenAnswer((_) async => <AttachmentDto>[]);
    await pump(tester);
    expect(find.text('Receipt'), findsOneWidget);
    expect(
      find.text('This transaction was recorded from a receipt.'),
      findsOneWidget,
    );
  });
}
