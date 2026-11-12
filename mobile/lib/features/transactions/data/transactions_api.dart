import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';

/// Typed calls for the `Transactions` tag of the contract (transactions,
/// refunds, bulk changes, transfers, attachments and audit history).
class TransactionsApi {
  /// Creates the API over [client].
  TransactionsApi(this._client);

  final ApiClient _client;

  /// One page of `GET /transactions` (or `/transactions/search` when the
  /// filter has a text query; both accept the same filters).
  Future<CursorPage<TransactionDto>> list(
    TransactionFilter filter, {
    String? cursor,
    int limit = 50,
  }) => _client.send(
    filter.hasQuery
        ? ApiEndpoints.searchTransactions
        : ApiEndpoints.listTransactions,
    query: <String, Object?>{
      ...filter.toQuery(),
      'cursor': cursor,
      'limit': limit,
    },
    decode: (Map<String, Object?> json) {
      final EnvelopeListTransactionDto envelope =
          decodeEnvelopeListTransactionDto(json);
      return CursorPage<TransactionDto>(
        envelope.data,
        envelope.meta.nextCursor,
      );
    },
  );

  /// `GET /transactions/{id}`.
  Future<TransactionDto> get(String id) => _client.send(
    ApiEndpoints.getTransaction,
    pathParameters: <String, String>{'id': id},
    decode: _decodeTransaction,
  );

  /// `POST /transactions` — idempotent; may report possible duplicates
  /// (never merged automatically).
  Future<CreateResult> create(TransactionInput input, {required String key}) =>
      _client.send(
        ApiEndpoints.createTransaction,
        body: input.toJson(),
        headers: <String, String>{Idempotency.header: key},
        decode: _decodeCreate,
      );

  /// `PATCH /transactions/{id}` — needs the current `version`.
  Future<TransactionDto> update(String id, TransactionPatch patch) =>
      _client.send(
        ApiEndpoints.updateTransaction,
        pathParameters: <String, String>{'id': id},
        body: patch.toJson(),
        decode: _decodeTransaction,
      );

  /// `DELETE /transactions/{id}` — voids (restorable). Voiding any leg of
  /// a transfer voids the whole transfer, fee included.
  Future<TransactionDto> delete(String id) => _client.send(
    ApiEndpoints.deleteTransaction,
    pathParameters: <String, String>{'id': id},
    decode: _decodeTransaction,
  );

  /// `POST /transactions/{id}/restore` — transfers are restored as a unit.
  Future<TransactionDto> restore(String id) => _client.send(
    ApiEndpoints.restoreTransaction,
    pathParameters: <String, String>{'id': id},
    decode: _decodeTransaction,
  );

  /// `POST /transactions/{id}/duplicate` — idempotent copy dated
  /// [localDate] (today when null).
  Future<CreateResult> duplicate(
    String id, {
    String? localDate,
    required String key,
  }) => _client.send(
    ApiEndpoints.duplicateTransaction,
    pathParameters: <String, String>{'id': id},
    body: TransactionsDuplicateRequest(localDate: localDate).toJson(),
    headers: <String, String>{Idempotency.header: key},
    decode: _decodeCreate,
  );

  /// `POST /transactions/{id}/refunds` — idempotent; capped by the server
  /// at the original amount unless `is_correction` is set.
  Future<CreateResult> refund(
    String id,
    RefundInput input, {
    required String key,
  }) => _client.send(
    ApiEndpoints.refundTransaction,
    pathParameters: <String, String>{'id': id},
    body: input.toJson(),
    headers: <String, String>{Idempotency.header: key},
    decode: _decodeCreate,
  );

  /// `GET /transactions/{id}/audit` (oldest first).
  Future<List<AuditEventDto>> audit(String id) => _client.send(
    ApiEndpoints.transactionAudit,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListAuditEventDto(json).data,
  );

  /// `GET /transactions/{id}/attachments`.
  Future<List<AttachmentDto>> attachments(String id) => _client.send(
    ApiEndpoints.transactionAttachments,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListAttachmentDto(json).data,
  );

  /// `POST /transactions/{id}/attachments` — attaches an uploaded file
  /// (`transaction_attachment` purpose, status ready).
  Future<TransactionDto> attach(String id, String fileId) => _client.send(
    ApiEndpoints.addAttachment,
    pathParameters: <String, String>{'id': id},
    body: TransactionsAttachmentsAddRequest(fileId: fileId).toJson(),
    decode: _decodeTransaction,
  );

  /// `DELETE /transactions/{id}/attachments/{fileId}` — detaches a file.
  Future<void> detach(String id, String fileId) => _client.send(
    ApiEndpoints.detachAttachment,
    pathParameters: <String, String>{'id': id, 'fileId': fileId},
    decode: decodeEnvelopeEmpty,
  );

  /// `POST /transactions/bulk-update` (all or nothing).
  Future<int> bulkUpdate(BulkUpdateInput input) => _client.send(
    ApiEndpoints.bulkUpdateTransactions,
    body: input.toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeBulkResult(json).data.updated,
  );

  /// `POST /transactions/bulk-delete` (restorable; `confirm` required).
  Future<int> bulkDelete(List<String> ids) => _client.send(
    ApiEndpoints.bulkDeleteTransactions,
    body: TransactionsBulkDeleteRequest(
      confirm: true,
      transactionIds: ids,
    ).toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeBulkResult(json).data.updated,
  );

  /// `POST /transactions/transfers` — idempotent; paired legs plus an
  /// optional fee expense, written atomically.
  Future<TransferDto> transfer(TransferInput input, {required String key}) =>
      _client.send(
        ApiEndpoints.createTransfer,
        body: input.toJson(),
        headers: <String, String>{Idempotency.header: key},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeTransferDto(json).data,
      );

  /// `DELETE /transactions/transfers/{id}` — voids both legs and the fee
  /// together (restorable).
  Future<TransferDto> deleteTransfer(String id) => _client.send(
    ApiEndpoints.deleteTransfer,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) => decodeEnvelopeTransferDto(json).data,
  );

  /// `POST /transactions/transfers/{id}/restore` — all legs together.
  Future<TransferDto> restoreTransfer(String id) => _client.send(
    ApiEndpoints.restoreTransfer,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) => decodeEnvelopeTransferDto(json).data,
  );

  /// `GET /transactions/transfers/{id}`.
  Future<TransferDto> getTransfer(String id) => _client.send(
    ApiEndpoints.getTransfer,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) => decodeEnvelopeTransferDto(json).data,
  );

  static TransactionDto _decodeTransaction(Map<String, Object?> json) =>
      decodeEnvelopeTransactionDto(json).data;

  static CreateResult _decodeCreate(Map<String, Object?> json) =>
      decodeEnvelopeCreateResult(json).data;
}

/// Transactions endpoints. Overridden in tests.
final Provider<TransactionsApi> transactionsApiProvider =
    Provider<TransactionsApi>(
      (Ref ref) => TransactionsApi(ref.watch(apiClientProvider)),
    );
