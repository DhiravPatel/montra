import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/imports/data/imports_api.dart';

import 'finance_fakes.dart';

/// Mock of the statement imports API.
class MockImportsApi extends Mock implements ImportsApi {}

/// Registers fallback values for `any()` on [MockImportsApi].
void registerImportFallbacks() {
  registerFallbackValue(
    const ColumnMapping(headerRow: 0, dateColumn: 0, dateFormat: 'YYYY-MM-DD'),
  );
  registerFallbackValue(const ImportRowUpdate());
}

/// An `ImportBatchDTO` JSON object (a previewed CSV import by default).
Map<String, Object?> importBatchJson({
  String id = 'imp-1',
  String accountId = 'acc-1',
  String status = 'preview_ready',
  int version = 2,
  List<String> header = const <String>[
    'Txn Date',
    'Narration',
    'Withdrawal Amt',
    'Deposit Amt',
    'Closing Balance',
  ],
  Map<String, Object?>? mapping = const <String, Object?>{
    'header_row': 0,
    'date_column': 0,
    'date_format': 'DD/MM/YYYY',
    'debit_column': 2,
    'credit_column': 3,
    'description_columns': <int>[1],
    'balance_column': 4,
  },
  List<String> notes = const <String>[],
  int totalRows = 5,
  int validRows = 4,
  int invalidRows = 1,
  int duplicateRows = 1,
  int imported = 0,
  int skipped = 0,
  int failed = 0,
  String? errorCode,
  String? errorMessage,
  String? previous,
  bool cancelRequested = false,
  bool withTotals = true,
  List<String>? noteCodes,
  Map<String, String> noteParams = const <String, String>{},
  Map<String, String>? errorParams,
  int? toImport,
}) => <String, Object?>{
  'id': id,
  'account_id': accountId,
  'currency': 'INR',
  'file_id': 'file-1',
  'source_format': 'csv',
  'status': status,
  'header': header,
  'mapping': ?mapping,
  'mapping_notes': notes,
  'mapping_note_codes': noteCodes ?? <String>[for (final String _ in notes) ''],
  'mapping_note_params': noteParams,
  'to_import_rows': toImport ?? validRows,
  'error_params': ?errorParams,
  'total_rows': totalRows,
  'valid_rows': validRows,
  'invalid_rows': invalidRows,
  'duplicate_rows': duplicateRows,
  'imported_count': imported,
  'skipped_count': skipped,
  'failed_count': failed,
  'statement_start': '2026-10-26',
  'statement_end': '2026-11-03',
  'statement_opening_balance': moneyJson('50000.00'),
  'statement_closing_balance': moneyJson('106629.50'),
  if (withTotals)
    'totals': <String, Object?>{
      'valid_rows': validRows,
      'inflow': moneyJson('60000.00'),
      'outflow': moneyJson('3370.50'),
      'net': moneyJson('56629.50'),
      'opening_balance': moneyJson('50000.00'),
      'closing_balance': moneyJson('106629.50'),
      'inflow_minor': 6000000,
      'outflow_minor': 337050,
      'net_minor': 5662950,
      'balance_check': 'ok',
      'first_date': '2026-10-26',
      'last_date': '2026-11-03',
    },
  'error_code': ?errorCode,
  'error_message': ?errorMessage,
  'previous_import_of_file': ?previous,
  'cancel_requested': cancelRequested,
  'version': version,
  'created_at': '2026-11-05T09:27:21Z',
};

/// An import batch.
ImportBatchDto importBatch({
  String id = 'imp-1',
  String status = 'preview_ready',
  int version = 2,
  int imported = 0,
  int skipped = 0,
  int failed = 0,
  String? errorCode,
  String? errorMessage,
  Map<String, Object?>? mapping = const <String, Object?>{
    'header_row': 0,
    'date_column': 0,
    'date_format': 'DD/MM/YYYY',
    'debit_column': 2,
    'credit_column': 3,
    'description_columns': <int>[1],
    'balance_column': 4,
  },
  List<String> notes = const <String>[],
  String? previous,
  bool withTotals = true,
  List<String>? noteCodes,
  Map<String, String> noteParams = const <String, String>{},
  Map<String, String>? errorParams,
  int? toImport,
}) => ImportBatchDto.fromJson(
  importBatchJson(
    id: id,
    status: status,
    version: version,
    imported: imported,
    skipped: skipped,
    failed: failed,
    errorCode: errorCode,
    errorMessage: errorMessage,
    mapping: mapping,
    notes: notes,
    previous: previous,
    withTotals: withTotals,
    noteCodes: noteCodes,
    noteParams: noteParams,
    errorParams: errorParams,
    toImport: toImport,
  ),
);

/// An `ImportRowDTO`.
ImportRowDto importRow({
  String id = 'row-3',
  int number = 3,
  String status = 'ready',
  String? date = '2026-10-26',
  String? amount = '1250.50',
  String? direction = 'outflow',
  String? description = 'UPI-GROCER-WEEKLY SHOP',
  String? errorCode,
  String? errorMessage,
  String? decision,
  String? duplicateOf,
  String? errorField,
  Map<String, String>? errorParams,
  List<String>? duplicateCodes,
  List<String> raw = const <String>['26/10/2026', 'UPI-GROCER-WEEKLY SHOP'],
}) => ImportRowDto.fromJson(<String, Object?>{
  'id': id,
  'row_number': number,
  'raw': raw,
  'posted_date': ?date,
  if (amount != null) 'amount': moneyJson(amount),
  'direction': ?direction,
  'description': ?description,
  'status': status,
  'error_code': ?errorCode,
  'error_message': ?errorMessage,
  'user_decision': ?decision,
  'duplicate_of_transaction_id': ?duplicateOf,
  'error_field': ?errorField,
  'error_params': ?errorParams,
  'duplicate_reason_codes': ?duplicateCodes,
});

/// A page of the import history.
CursorPage<ImportBatchDto> importsPage(
  List<ImportBatchDto> items, {
  String? next,
}) => CursorPage<ImportBatchDto>(items, next);

/// A page of rows.
ImportRowPage rowPage(List<ImportRowDto> rows, {int? next}) =>
    ImportRowPage(rows: rows, nextCursor: next);
