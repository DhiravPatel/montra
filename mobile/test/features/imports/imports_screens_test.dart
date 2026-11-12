import 'dart:async';

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
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/imports/data/imports_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';

import '../../helpers/files_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/imports_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockImportsApi api;
  late MockAccountsApi accounts;
  late MockLabelsApi labels;
  late MockTransactionsApi transactions;
  late MockFileUploader uploader;
  late FakeFileSource source;

  setUpAll(() {
    registerFinanceFallbacks();
    registerImportFallbacks();
    registerFileFallbacks();
  });

  setUp(() {
    api = MockImportsApi();
    accounts = MockAccountsApi();
    labels = MockLabelsApi();
    transactions = MockTransactionsApi();
    uploader = MockFileUploader();
    source = FakeFileSource();
    stubLabels(labels, categories: <CategoryDto>[category()]);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
  });

  List<Override> overrides() => <Override>[
    importsApiProvider.overrideWithValue(api),
    accountsApiProvider.overrideWithValue(accounts),
    labelsApiProvider.overrideWithValue(labels),
    transactionsApiProvider.overrideWithValue(transactions),
    fileUploaderProvider.overrideWithValue(uploader),
    fileSourceProvider.overrideWithValue(source),
    fileExporterProvider.overrideWithValue(FakeFileExporter()),
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

  void stubRows(List<ImportRowDto> rows, {int? next}) {
    when(
      () => api.rows(
        any(),
        status: any(named: 'status'),
        afterRow: any(named: 'afterRow'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => rowPage(rows, next: next));
  }

  void stubUpload(String fileId) {
    when(
      () => uploader.upload(
        any(),
        any(),
        onStage: any(named: 'onStage'),
        onProgress: any(named: 'onProgress'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => fileDto(
        id: fileId,
        purpose: 'statement_import',
        name: 'statement.csv',
        contentType: 'text/csv',
      ),
    );
  }

  group('history', () {
    testWidgets('lists imports with status, counts and account; opens one', (
      WidgetTester tester,
    ) async {
      when(
        () => api.list(
          accountId: any(named: 'accountId'),
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer(
        (_) async => importsPage(<ImportBatchDto>[
          importBatch(status: 'completed', imported: 3, skipped: 1),
          importBatch(id: 'imp-2'),
        ]),
      );
      when(
        () => api.get('imp-1'),
      ).thenAnswer((_) async => importBatch(status: 'completed', imported: 3));
      final GoRouter router = await pump(tester, '/imports');

      expect(find.text('Statement imports'), findsOneWidget);
      expect(find.text('HDFC Savings'), findsNWidgets(2));
      expect(find.text('Imported'), findsOneWidget);
      expect(find.text('3 imported · 1 skipped · 0 failed'), findsOneWidget);
      expect(find.text('Ready to review'), findsOneWidget);

      await tester.tap(find.text('Imported'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/imports/imp-1');
    });

    testWidgets('an empty history explains what can be imported', (
      WidgetTester tester,
    ) async {
      when(
        () => api.list(
          accountId: any(named: 'accountId'),
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer((_) async => importsPage(<ImportBatchDto>[]));
      await pump(tester, '/imports?account_id=acc-1');
      expect(find.text('No imports yet'), findsOneWidget);
      expect(find.text('Imports into HDFC Savings'), findsOneWidget);
      verify(
        () => api.list(
          accountId: 'acc-1',
          cursor: any(named: 'cursor'),
        ),
      ).called(1);
    });

    testWidgets('a failed load can be retried', (WidgetTester tester) async {
      int calls = 0;
      when(
        () => api.list(
          accountId: any(named: 'accountId'),
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return importsPage(<ImportBatchDto>[]);
      });
      await pump(tester, '/imports');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No imports yet'), findsOneWidget);
    });
  });

  group('wizard', () {
    testWidgets('uploads a CSV for the chosen account and opens the import', (
      WidgetTester tester,
    ) async {
      source.enqueue(pickedFile(name: 'statement.csv', mimeType: 'text/csv'));
      stubUpload('file-9');
      when(
        () => api.create(
          accountId: 'acc-1',
          fileId: 'file-9',
          key: any(named: 'key'),
        ),
      ).thenAnswer((_) async => importBatch(id: 'imp-9', status: 'uploaded'));
      when(() => api.get('imp-9'))
          .thenAnswer((_) async => importBatch(id: 'imp-9'));
      final GoRouter router = await pump(
        tester,
        '/imports/new?account_id=acc-1',
      );

      expect(find.textContaining("PDF statements aren't supported"), findsOne);
      expect(find.text('HDFC Savings · INR'), findsOneWidget);
      await tester.tap(find.text('Choose a file'));
      await tester.pumpAndSettle();
      expect(source.requests.single, (
        FileOrigin.files,
        UploadPurpose.statementImport,
      ));
      expect(find.text('statement.csv'), findsOneWidget);

      await tapVisible(tester, find.text('Upload and read'));
      verify(
        () => api.create(
          accountId: 'acc-1',
          fileId: 'file-9',
          key: any(named: 'key'),
        ),
      ).called(1);
      expect(locationOf(router), '/imports/imp-9');
      expect(find.text('Ready to review'), findsOneWidget);
    });

    testWidgets('asks for the account and the file first', (
      WidgetTester tester,
    ) async {
      await pump(tester, '/imports/new');
      await tapVisible(tester, find.text('Upload and read'));
      expect(
        find.text('Choose the account the statement belongs to.'),
        findsOneWidget,
      );
      expect(find.text('Choose the statement file.'), findsOneWidget);
      verifyNever(
        () => api.create(
          accountId: any(named: 'accountId'),
          fileId: any(named: 'fileId'),
          key: any(named: 'key'),
        ),
      );
    });
  });

  group('detail', () {
    testWidgets('re-reads the import while the file is read, then stops', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(() => api.get('imp-1')).thenAnswer((_) async {
        calls++;
        return calls == 1 ? importBatch(status: 'parsing') : importBatch();
      });
      final ({Widget app, GoRouter router}) r = routedApp(
        '/imports/imp-1',
        overrides: overrides(),
      );
      await tester.pumpWidget(r.app);
      await tester.pump();
      await tester.pump();
      expect(calls, 1);
      expect(find.text('Reading the file'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await tester.pump();
      expect(calls, 2);
      expect(find.text('Ready to review'), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(calls, 2, reason: 'no polling once previewed');
    });

    testWidgets('confirming sends the version with an idempotency key', (
      WidgetTester tester,
    ) async {
      int gets = 0;
      when(() => api.get('imp-1')).thenAnswer((_) async {
        gets++;
        return gets == 1
            ? importBatch()
            : importBatch(status: 'completed', imported: 3, skipped: 1);
      });
      when(
        () => api.confirm('imp-1', version: 2, key: any(named: 'key')),
      ).thenAnswer((_) async => importBatch(status: 'confirmed', version: 3));
      await pump(tester, '/imports/imp-1');

      await tester.tap(find.widgetWithText(FilledButton, 'Import 4 rows'));
      await tester.pumpAndSettle();
      expect(find.text('Import these rows?'), findsOneWidget);
      expect(
        find.textContaining('4 rows will be added to HDFC Savings.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Import rows').last);
      await tester.pumpAndSettle();

      final String key =
          verify(
                () => api.confirm(
                  'imp-1',
                  version: 2,
                  key: captureAny(named: 'key'),
                ),
              ).captured.single
              as String;
      expect(key.length, greaterThanOrEqualTo(8));
      expect(find.text('The rows were added to the account.'), findsOneWidget);
      expect(find.text('Check against the statement'), findsOneWidget);
    });

    testWidgets('an import with errors offers fixing, retrying and rolling '
        'back (confirmed)', (WidgetTester tester) async {
      when(() => api.get('imp-1')).thenAnswer(
        (_) async => importBatch(
          status: 'completed_with_errors',
          imported: 3,
          failed: 1,
        ),
      );
      when(() => api.retryFailed('imp-1'))
          .thenAnswer((_) async => importBatch(status: 'confirmed'));
      when(() => api.rollback('imp-1'))
          .thenAnswer((_) async => importBatch(status: 'processing'));
      await pump(tester, '/imports/imp-1');
      expect(find.text('Imported with problems'), findsOneWidget);

      await tester.tap(find.text('Try failed rows again'));
      await tester.pumpAndSettle();
      verify(() => api.retryFailed('imp-1')).called(1);

      await tester.tap(find.widgetWithText(TextButton, 'Roll back'));
      await tester.pumpAndSettle();
      expect(find.text('Roll back this import?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Roll back'));
      await tester.pumpAndSettle();
      verify(() => api.rollback('imp-1')).called(1);
    });

    testWidgets('a failed import explains why and offers another file', (
      WidgetTester tester,
    ) async {
      when(() => api.get('imp-1')).thenAnswer(
        (_) async => importBatch(
          status: 'failed',
          errorCode: 'unsupported_format',
          errorMessage: 'This file type cannot be imported.',
          withTotals: false,
        ),
      );
      await pump(tester, '/imports/imp-1');
      expect(find.text("Couldn't import"), findsOneWidget);
      expect(
        find.textContaining("This file type can't be imported"),
        findsOneWidget,
      );
      expect(find.text('Try another file'), findsOneWidget);
    });

    testWidgets('a rolled-back import gives the counts', (
      WidgetTester tester,
    ) async {
      when(() => api.get('imp-1')).thenAnswer(
        (_) async => importBatch(
          status: 'cancelled',
          errorCode: 'rolled_back',
          errorMessage: 'Rolled back.',
          errorParams: const <String, String>{'voided': '3', 'kept': '1'},
          imported: 1,
        ),
      );
      await pump(tester, '/imports/imp-1');
      expect(
        find.textContaining('3 transactions removed, 1 kept'),
        findsOneWidget,
      );
    });
  });

  group('round 4 codes', () {
    testWidgets('column notes are shown in words with the date formats; '
        'nothing to import disables importing', (WidgetTester tester) async {
      when(() => api.get('imp-1')).thenAnswer(
        (_) async => importBatch(
          notes: const <String>['Dates could be day-first or month-first.'],
          noteCodes: const <String>['ambiguous_date_order'],
          noteParams: const <String, String>{
            'assumed_date_format': 'DD/MM/YYYY',
            'alternative_date_format': 'MM/DD/YYYY',
          },
          toImport: 0,
        ),
      );
      await pump(tester, '/imports/imp-1');
      expect(
        find.text(
          'Dates could be day-first or month-first; DD/MM/YYYY was assumed. '
          "Choose MM/DD/YYYY if that's wrong.",
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'No rows are marked to import. Mark the rows you want, or cancel '
          'the import.',
        ),
        findsOneWidget,
      );
      final FilledButton button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Import 0 rows'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('a statement in another currency names both currencies', (
      WidgetTester tester,
    ) async {
      when(() => api.get('imp-1')).thenAnswer(
        (_) async => importBatch(
          status: 'failed',
          errorCode: 'currency_mismatch',
          errorMessage: 'Currency mismatch.',
          errorParams: const <String, String>{
            'statement_currency': 'USD',
            'account_currency': 'INR',
          },
        ),
      );
      await pump(tester, '/imports/imp-1');
      expect(
        find.text(
          'The statement is in USD, but the account is in INR. Import it '
          'into an account in USD.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('row reasons use their values; the correction points at '
        'the value the server named', (WidgetTester tester) async {
      when(() => api.get('imp-1')).thenAnswer((_) async => importBatch());
      when(
        () => api.rows(
          'imp-1',
          status: any(named: 'status'),
          afterRow: any(named: 'afterRow'),
        ),
      ).thenAnswer(
        (_) async => rowPage(<ImportRowDto>[
          importRow(
            id: 'row-4',
            number: 4,
            status: 'invalid',
            date: null,
            errorCode: 'bad_date',
            errorField: 'posted_date',
            errorParams: const <String, String>{'format': 'DD/MM/YYYY'},
          ),
          importRow(
            id: 'row-5',
            number: 5,
            status: 'duplicate',
            errorCode: 'possible_duplicate',
            errorParams: const <String, String>{'days_apart': '0'},
            duplicateCodes: const <String>[
              'same_amount_direction',
              'same_date',
            ],
          ),
        ]),
      );
      await pump(tester, '/imports/imp-1/rows');
      expect(find.text("The date doesn't match DD/MM/YYYY."), findsOneWidget);
      expect(
        find.text(
          'Looks like a transaction already in the account: Same amount and '
          'direction, Same date.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text("The date doesn't match DD/MM/YYYY."));
      await tester.pumpAndSettle();
      expect(find.text('Correct the date'), findsOneWidget);
      await tester.tap(find.text('Correct the date'));
      await tester.pumpAndSettle();
      // The problem is shown under the date, the value to correct.
      expect(find.text("The date doesn't match DD/MM/YYYY."), findsWidgets);
    });

    testWidgets('statement totals are the server\'s Money values', (
      WidgetTester tester,
    ) async {
      when(() => api.get('imp-1')).thenAnswer((_) async => importBatch());
      await pump(tester, '/imports/imp-1');
      await tester.scrollUntilVisible(find.text('Money in'), 200);
      expect(find.textContaining('60,000.00'), findsWidgets);
      expect(find.textContaining('3,370.50'), findsWidgets);
    });
  });

  group('columns and rows', () {
    testWidgets('columns are chosen by name and saved with the version', (
      WidgetTester tester,
    ) async {
      when(() => api.get('imp-1')).thenAnswer(
        (_) async => importBatch(
          status: 'needs_mapping',
          // The server's suggestion when nothing was recognized.
          mapping: <String, Object?>{
            'header_row': -1,
            'date_column': -1,
            'date_format': '',
            'sign_convention': 'negative_is_outflow',
            'decimal_separator': '.',
          },
          notes: <String>['No header row was found; map the columns manually.'],
        ),
      );
      stubRows(<ImportRowDto>[
        importRow(
          id: 'r1',
          number: 1,
          status: 'parsed',
          raw: <String>['When', 'What', 'How much'],
        ),
        importRow(
          id: 'r2',
          number: 2,
          status: 'parsed',
          raw: <String>['2026-11-01', 'Lunch', '-250.00'],
        ),
      ]);
      when(() => api.setMapping('imp-1', any(), version: 2))
          .thenAnswer((_) async => importBatch(status: 'parsing', version: 3));
      final GoRouter router = await pump(tester, '/imports/imp-1');
      expect(find.text('Columns needed'), findsOneWidget);
      expect(
        find.text('No header row was found; map the columns manually.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Choose columns'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/imports/imp-1/mapping');
      expect(find.text('Row 2: 2026-11-01 · Lunch · -250.00'), findsOneWidget);

      await tapVisible(tester, find.text('Save and read again'));
      expect(find.text('Choose the date column.'), findsOneWidget);

      await tapVisible(tester, find.text('No header row'));
      await tester.tap(find.text('Row 1: When · What · How much').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Date column'));
      await tester.tap(find.text('When (e.g. 2026-11-01)').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Date format'));
      await tester.tap(find.text('YYYY-MM-DD').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Amount column'));
      await tester.tap(find.text('How much (e.g. -250.00)').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(FilterChip, 'What'));
      await tapVisible(tester, find.text('Save and read again'));

      final ColumnMapping mapping =
          verify(() => api.setMapping('imp-1', captureAny(), version: 2))
                  .captured
                  .single
              as ColumnMapping;
      expect(mapping.headerRow, 0);
      expect(mapping.dateColumn, 0);
      expect(mapping.dateFormat, 'YYYY-MM-DD');
      expect(mapping.amountColumn, 2);
      expect(
        mapping.signConvention,
        ColumnMappingSignConvention.negativeIsOutflow,
      );
      expect(mapping.debitColumn, isNull);
      expect(mapping.descriptionColumns, <int>[1]);
      expect(find.textContaining('Columns saved'), findsOneWidget);
      expect(locationOf(router), '/imports/imp-1');
    });

    testWidgets('rows show their reason; a row is skipped or corrected; more '
        'rows load on request', (WidgetTester tester) async {
      when(() => api.get('imp-1')).thenAnswer((_) async => importBatch());
      when(
        () => api.rows(
          any(),
          status: any(named: 'status'),
          afterRow: any(named: 'afterRow'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((Invocation i) async {
        final int? after = i.namedArguments[#afterRow] as int?;
        if (after != null) {
          return rowPage(<ImportRowDto>[
            importRow(id: 'row-9', number: 9, description: 'ELECTRICITY BILL'),
          ]);
        }
        return rowPage(<ImportRowDto>[
          importRow(),
          importRow(
            id: 'row-6',
            number: 6,
            status: 'invalid',
            amount: null,
            direction: null,
            date: null,
            description: 'BOOKSTORE',
            errorCode: 'bad_amount',
            raw: <String>['28/10/2026', 'BOOKSTORE', 'abc'],
          ),
          importRow(
            id: 'row-7',
            number: 7,
            status: 'duplicate',
            errorCode: 'possible_duplicate',
            duplicateOf: 'tx-1',
          ),
        ], next: 7);
      });
      when(() => api.updateRow('imp-1', 'row-3', any()))
          .thenAnswer((_) async => importRow(decision: 'skip'));
      when(() => api.updateRow('imp-1', 'row-6', any())).thenAnswer(
        (_) async => importRow(
          id: 'row-6',
          number: 6,
          description: 'BOOKSTORE',
          amount: '120.00',
        ),
      );
      await pump(tester, '/imports/imp-1/rows');

      expect(find.text('Will be imported'), findsOneWidget);
      expect(
        find.text("The amount isn't a number in this currency."),
        findsOneWidget,
      );
      expect(
        find.text('Looks like a transaction already in the account.'),
        findsOneWidget,
      );

      await tester.tap(find.text('UPI-GROCER-WEEKLY SHOP').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip this row'));
      await tester.pumpAndSettle();
      final ImportRowUpdate skip =
          verify(() => api.updateRow('imp-1', 'row-3', captureAny()))
                  .captured
                  .single
              as ImportRowUpdate;
      expect(skip.decision, ImportRowUpdateDecision.skip);
      expect(find.text('Left out'), findsWidgets);

      await tester.tap(find.text('BOOKSTORE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Correct this row'));
      await tester.pumpAndSettle();
      expect(find.textContaining('As read from the file'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '120',
      );
      await tester.tap(find.text('Money out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save correction'));
      await tester.pumpAndSettle();
      final ImportRowUpdate fix =
          verify(() => api.updateRow('imp-1', 'row-6', captureAny()))
                  .captured
                  .single
              as ImportRowUpdate;
      expect(fix.amount, '120.00');
      expect(fix.direction, ImportRowUpdateDirection.outflow);
      expect(fix.postedDate, isNotNull);
      expect(fix.description, 'BOOKSTORE');

      await tapVisible(tester, find.text('Load more'));
      expect(find.text('ELECTRICITY BILL'), findsOneWidget);
    });

    testWidgets('an empty filter says so', (WidgetTester tester) async {
      when(() => api.get('imp-1')).thenAnswer((_) async => importBatch());
      stubRows(<ImportRowDto>[]);
      await pump(tester, '/imports/imp-1/rows?status=failed');
      expect(find.text('No rows here.'), findsOneWidget);
    });
  });

  group('error states', () {
    testWidgets('a refused import is explained on the wizard', (
      WidgetTester tester,
    ) async {
      source.enqueue(pickedFile(name: 'statement.csv', mimeType: 'text/csv'));
      stubUpload('file-9');
      when(
        () => api.create(
          accountId: 'acc-1',
          fileId: 'file-9',
          key: any(named: 'key'),
        ),
      ).thenThrow(
        const ApiException(
          kind: ApiErrorKind.server,
          code: ErrorObjectCode.domainRuleViolation,
          statusCode: 422,
          details: <Detail>[
            Detail(
              code: 'account_inactive',
              message: 'Imports need an active account.',
            ),
          ],
        ),
      );
      await pump(tester, '/imports/new?account_id=acc-1');
      await tester.tap(find.text('Choose a file'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Upload and read'));
      await tester.scrollUntilVisible(
        find.textContaining('archived or closed'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('archived or closed'), findsOneWidget);
    });

    testWidgets('an import that fails to load offers a retry', (
      WidgetTester tester,
    ) async {
      when(() => api.get('imp-1')).thenThrow(offline);
      await pump(tester, '/imports/imp-1');
      expect(find.text("You're offline"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a mapping the server refuses shows its reason', (
      WidgetTester tester,
    ) async {
      when(() => api.get('imp-1')).thenAnswer((_) async => importBatch());
      stubRows(<ImportRowDto>[
        importRow(
          id: 'r1',
          number: 1,
          status: 'skipped',
          errorCode: 'header',
          raw: <String>[
            'Txn Date',
            'Narration',
            'Withdrawal Amt',
            'Deposit Amt',
          ],
        ),
      ]);
      when(() => api.setMapping('imp-1', any(), version: 2)).thenThrow(
        const ApiException(
          kind: ApiErrorKind.server,
          code: ErrorObjectCode.validationError,
          statusCode: 422,
          details: <Detail>[
            Detail(
              field: 'body.mapping',
              message: 'A mapped column does not exist in the file.',
            ),
          ],
        ),
      );
      await pump(tester, '/imports/imp-1/mapping');
      await tapVisible(tester, find.text('Save and read again'));
      await tester.scrollUntilVisible(
        find.text('A mapped column does not exist in the file.'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('A mapped column does not exist in the file.'),
        findsOneWidget,
      );
    });

    testWidgets('rows that fail to load can be retried', (
      WidgetTester tester,
    ) async {
      when(() => api.get('imp-1')).thenAnswer((_) async => importBatch());
      int calls = 0;
      when(
        () => api.rows(
          any(),
          status: any(named: 'status'),
          afterRow: any(named: 'afterRow'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return rowPage(<ImportRowDto>[importRow()]);
      });
      await pump(tester, '/imports/imp-1/rows');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('UPI-GROCER-WEEKLY SHOP'), findsOneWidget);
    });
  });

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('import screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      when(
        () => api.list(
          accountId: any(named: 'accountId'),
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer(
        (_) async => importsPage(<ImportBatchDto>[
          importBatch(status: 'completed_with_errors', imported: 3, failed: 1),
          importBatch(id: 'imp-2', status: 'needs_mapping'),
        ]),
      );
      when(() => api.get('imp-1')).thenAnswer(
        (_) async => importBatch(
          status: 'completed_with_errors',
          imported: 3,
          failed: 1,
          previous: 'imp-0',
          errorCode: 'currency_mismatch',
          errorParams: const <String, String>{
            'statement_currency': 'USD',
            'account_currency': 'INR',
          },
        ),
      );
      when(() => api.get('imp-2')).thenAnswer(
        (_) async => importBatch(
          id: 'imp-2',
          status: 'needs_mapping',
          notes: <String>[
            'The amount column could not be recognized.',
            'Dates could be day-first or month-first.',
          ],
          noteCodes: const <String>[
            'mapping_incomplete',
            'ambiguous_date_order',
          ],
          noteParams: const <String, String>{
            'assumed_date_format': 'DD/MM/YYYY',
            'alternative_date_format': 'MM/DD/YYYY',
          },
        ),
      );
      stubRows(<ImportRowDto>[
        importRow(
          id: 'r1',
          number: 1,
          status: 'skipped',
          errorCode: 'header',
          raw: <String>['Txn Date', 'Narration', 'Withdrawal Amt'],
        ),
        importRow(),
        importRow(
          id: 'row-6',
          number: 6,
          status: 'failed',
          errorCode: 'invalid_date',
          errorField: 'posted_date',
          errorMessage: 'The date cannot be in the future.',
        ),
        importRow(
          id: 'row-7',
          number: 7,
          status: 'duplicate',
          errorCode: 'possible_duplicate',
          duplicateCodes: const <String>[
            'same_amount_direction',
            'within_3_days',
            'similar_description',
          ],
        ),
      ], next: 6);
      final ({Widget app, GoRouter router}) r = routedApp(
        '/imports',
        overrides: overrides(),
        locale: locale,
      );
      await tester.pumpWidget(r.app);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final String location in <String>[
        '/imports/new?account_id=acc-1',
        '/imports/imp-1',
        '/imports/imp-2/mapping',
        '/imports/imp-1/rows',
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
