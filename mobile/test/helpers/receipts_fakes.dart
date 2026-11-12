import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/receipts/data/receipts_api.dart';
import 'package:montra_mobile/features/receipts/domain/receipt_codes.dart';

import 'finance_fakes.dart';

/// Mock of the receipts API.
class MockReceiptsApi extends Mock implements ReceiptsApi {}

/// Registers fallback values for `any()` on [MockReceiptsApi].
void registerReceiptFallbacks() {
  registerFallbackValue(
    const ReceiptReviewInput(receiptDate: '2026-11-01', total: '1', version: 1),
  );
  registerFallbackValue(
    const ReceiptCreateTransactionInput(accountId: 'acc-1'),
  );
}

/// A `ReceiptExtractionDTO` JSON object with the values a user typed.
Map<String, Object?> extractionJson({
  String? merchant = 'Fresh Mart',
  String? date = '2026-11-03',
  String? total = '1250.50',
  String currency = 'INR',
  String? subtotal,
  String? tax,
  List<String> warnings = const <String>[],
  List<String>? warningCodes,
  List<Map<String, String>>? warningParams,
  List<Map<String, Object?>> lineItems = const <Map<String, Object?>>[],
  int version = 1,
  String method = 'manual',
}) => <String, Object?>{
  'id': 'ext-$version',
  'version': version,
  'method': method,
  'extractor_version': 'user-review-1',
  'status': 'succeeded',
  'merchant_name': ?merchant,
  'receipt_date': ?date,
  'currency': currency,
  if (total != null) 'total': moneyJson(total, currency: currency),
  if (subtotal != null) 'subtotal': moneyJson(subtotal, currency: currency),
  if (tax != null) 'tax': moneyJson(tax, currency: currency),
  'field_confidence': <String, Object?>{'total': 1},
  'warnings': warnings,
  'warning_codes':
      warningCodes ?? <String>[for (final String _ in warnings) ''],
  'warning_params':
      warningParams ??
      <Map<String, String>>[
        for (final String _ in warnings) <String, String>{},
      ],
  'line_items': lineItems,
  'created_at': '2026-11-04T10:00:00Z',
};

/// A `ReceiptDTO` JSON object (also the base of a `ReceiptDetail`).
Map<String, Object?> receiptJson({
  String id = 'rc-1',
  String status = 'needs_review',
  Map<String, Object?>? current,
  String? transactionId,
  String? duplicateOfId,
  int version = 1,
  List<Map<String, Object?>>? files,
  String? notes,
}) => <String, Object?>{
  'id': id,
  'status': status,
  'files':
      files ??
      <Map<String, Object?>>[
        <String, Object?>{
          'file_id': 'file-$id',
          'page_no': 1,
          'content_type': 'image/png',
        },
      ],
  'current': ?current,
  'transaction_id': ?transactionId,
  'duplicate_of_id': ?duplicateOfId,
  'notes': ?notes,
  'version': version,
  'created_at': '2026-11-04T09:00:00Z',
};

/// A receipt in the inbox.
ReceiptDto receipt({
  String id = 'rc-1',
  String status = 'needs_review',
  Map<String, Object?>? current,
  String? transactionId,
  String? duplicateOfId,
  int version = 1,
}) => ReceiptDto.fromJson(
  receiptJson(
    id: id,
    status: status,
    current: current,
    transactionId: transactionId,
    duplicateOfId: duplicateOfId,
    version: version,
  ),
);

/// A receipt with its history.
ReceiptDetail receiptDetail({
  String id = 'rc-1',
  String status = 'needs_review',
  Map<String, Object?>? current,
  String? transactionId,
  String? duplicateOfId,
  int version = 1,
  List<Map<String, Object?>>? files,
  String? notes,
}) => ReceiptDetail.fromJson(<String, Object?>{
  ...receiptJson(
    id: id,
    status: status,
    current: current,
    transactionId: transactionId,
    duplicateOfId: duplicateOfId,
    version: version,
    files: files,
    notes: notes,
  ),
  'history': <Map<String, Object?>>[
    if (current != null)
      <String, Object?>{
        'id': 'ext-1',
        'version': 1,
        'method': 'manual',
        'status': 'succeeded',
        'created_at': '2026-11-04T10:00:00Z',
      },
  ],
});

/// A transaction that may be the receipt's purchase.
ReceiptMatchCandidate matchCandidate({
  List<String> codes = const <String>[],
  String transactionId = 'tx-9',
  String amount = '1250.50',
  String date = '2026-11-03',
  String? merchant = 'Fresh Mart',
  List<String> reasons = const <String>[
    'Same amount as the total',
    'Same date',
  ],
}) => ReceiptMatchCandidate.fromJson(<String, Object?>{
  'transaction_id': transactionId,
  'local_date': date,
  'amount': moneyJson(amount),
  'account_name': 'HDFC Savings',
  'merchant': ?merchant,
  'reasons': reasons,
  'reason_codes': codes,
});

/// One page of the inbox.
CursorPage<ReceiptDto> receiptPage(List<ReceiptDto> items, {String? next}) =>
    CursorPage<ReceiptDto>(items, next);

/// A receipt as the detail screens load it (warnings from its current
/// values' `warning_codes` / `warning_params`).
ReceiptView receiptView({
  String id = 'rc-1',
  String status = 'needs_review',
  Map<String, Object?>? current,
  String? transactionId,
  String? duplicateOfId,
  int version = 1,
  List<Map<String, Object?>>? files,
  String? notes,
}) {
  final ReceiptDetail detail = receiptDetail(
    id: id,
    status: status,
    current: current,
    transactionId: transactionId,
    duplicateOfId: duplicateOfId,
    version: version,
    files: files,
    notes: notes,
  );
  return ReceiptView(detail);
}

/// A suggested expense with reason codes.
ReceiptMatchCandidate suggestion({
  String transactionId = 'tx-9',
  List<String> reasons = const <String>[
    'Same amount as the total',
    'Same date',
  ],
  List<String> codes = const <String>[],
}) => matchCandidate(
  transactionId: transactionId,
  reasons: reasons,
  codes: codes,
);
