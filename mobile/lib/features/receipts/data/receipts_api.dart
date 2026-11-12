import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/features/receipts/domain/receipt_codes.dart';

/// Typed calls for the `Receipts` tag of the contract.
///
/// Receipts are always entered by hand: they are created without
/// `read_automatically` (manual entry is the server default), and
/// `POST /receipts/{id}/process` (automatic reading) is never called.
class ReceiptsApi {
  /// Creates the API over [client].
  ReceiptsApi(this._client);

  final ApiClient _client;

  /// Receipts fetched per page of the inbox.
  static const int pageSize = 50;

  /// `GET /receipts`: one page of the inbox, newest first. [status] is one
  /// receipt status; null lists every receipt except discarded ones. Pass
  /// the page's `nextCursor` as [cursor] for the next one.
  Future<CursorPage<ReceiptDto>> list({
    String? status,
    String? cursor,
    int limit = pageSize,
  }) => _client.send(
    ApiEndpoints.listReceipts,
    query: <String, Object?>{
      'status': status,
      'cursor': cursor,
      'limit': limit,
    },
    decode: (Map<String, Object?> json) {
      final EnvelopeListReceiptDto envelope = decodeEnvelopeListReceiptDto(
        json,
      );
      final bool more = envelope.meta.hasMore ?? true;
      return CursorPage<ReceiptDto>(
        envelope.data,
        more ? envelope.meta.nextCursor : null,
      );
    },
  );

  /// `POST /receipts` for uploaded pages ([fileIds], in page order), for
  /// manual entry. Idempotent with [key]: a retry with the same key and
  /// pages returns the receipt created the first time.
  Future<ReceiptDto> create(
    List<String> fileIds, {
    String? notes,
    required String key,
  }) => _client.send(
    ApiEndpoints.createReceipt,
    body: ReceiptCreateInput(fileIds: fileIds, notes: notes).toJson(),
    headers: <String, String>{Idempotency.header: key},
    decode: _decodeReceipt,
  );

  /// `GET /receipts/{id}` with its pages, history and coded warnings.
  Future<ReceiptView> get(String id) => _client.send(
    ApiEndpoints.getReceipt,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) =>
        ReceiptView(decodeEnvelopeReceiptDetail(json).data),
  );

  /// `PATCH /receipts/{id}/review`: the values the user confirmed (stored
  /// as a new version; needs the receipt's `version`).
  Future<ReceiptDto> review(String id, ReceiptReviewInput input) =>
      _client.send(
        ApiEndpoints.reviewReceipt,
        pathParameters: <String, String>{'id': id},
        body: input.toJson(),
        decode: _decodeReceipt,
      );

  /// `GET /receipts/{id}/match-candidates`: existing expenses that may be
  /// this purchase, with their reason codes (`reason_codes`).
  Future<List<ReceiptMatchCandidate>> matchCandidates(String id) =>
      _client.send(
        ApiEndpoints.receiptMatchCandidates,
        pathParameters: <String, String>{'id': id},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeListReceiptMatchCandidate(json).data,
      );

  /// `POST /receipts/{id}/match-transaction`: links an existing
  /// transaction (no new money is recorded).
  Future<ReceiptDto> match(String id, String transactionId) => _client.send(
    ApiEndpoints.matchReceipt,
    pathParameters: <String, String>{'id': id},
    body: ReceiptMatchInput(transactionId: transactionId).toJson(),
    decode: _decodeReceipt,
  );

  /// `POST /receipts/{id}/create-transaction` (idempotent with [key]):
  /// records the purchase from values the user reviewed by hand.
  Future<ReceiptDto> createTransaction(
    String id,
    ReceiptCreateTransactionInput input, {
    required String key,
  }) => _client.send(
    ApiEndpoints.receiptCreateTransaction,
    pathParameters: <String, String>{'id': id},
    body: input.toJson(),
    headers: <String, String>{Idempotency.header: key},
    decode: _decodeReceipt,
  );

  /// `POST /receipts/{id}/unlink`: removes the transaction link (the
  /// transaction itself is kept).
  Future<ReceiptDto> unlink(String id) => _client.send(
    ApiEndpoints.unlinkReceipt,
    pathParameters: <String, String>{'id': id},
    decode: _decodeReceipt,
  );

  /// `POST /receipts/{id}/discard?version=`: removes the receipt from the
  /// inbox (its files are kept; [restore] brings it back). [version] is the
  /// version the user saw; a stale one answers `VERSION_CONFLICT`.
  Future<ReceiptDto> discard(String id, {int? version}) => _client.send(
    ApiEndpoints.discardReceipt,
    pathParameters: <String, String>{'id': id},
    query: <String, Object?>{'version': version},
    decode: _decodeReceipt,
  );

  /// `POST /receipts/{id}/restore?version=`: brings a discarded receipt
  /// back (to reviewed when its values were reviewed, else to
  /// needs_review).
  Future<ReceiptDto> restore(String id, {int? version}) => _client.send(
    ApiEndpoints.restoreReceipt,
    pathParameters: <String, String>{'id': id},
    query: <String, Object?>{'version': version},
    decode: _decodeReceipt,
  );

  /// `DELETE /files/{fileId}`: deletes an uploaded page that never became
  /// part of a receipt (the user removed it or left before adding the
  /// receipt), so it does not use storage.
  Future<void> deleteUpload(String fileId) => _client.send(
    ApiEndpoints.deleteFile,
    pathParameters: <String, String>{'fileId': fileId},
    decode: decodeEnvelopeEmpty,
  );

  static ReceiptDto _decodeReceipt(Map<String, Object?> json) =>
      decodeEnvelopeReceiptDto(json).data;
}

/// The [ReceiptsApi] over the shared client. Overridden in tests.
final Provider<ReceiptsApi> receiptsApiProvider = Provider<ReceiptsApi>(
  (Ref ref) => ReceiptsApi(ref.watch(apiClientProvider)),
);
