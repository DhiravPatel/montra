import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for the `Imports` tag of the contract (statement imports).
///
/// Only CSV, XLSX and OFX statements are offered: PDF statements need AI
/// reading, which Montra does not use, so `allow_ai_extraction` is never
/// sent.
class ImportsApi {
  /// Creates the API over [client].
  ImportsApi(this._client);

  final ApiClient _client;

  /// Rows fetched per page of the preview.
  static const int rowPageSize = 100;

  /// Imports fetched per page of the history.
  static const int pageSize = 50;

  /// `GET /imports`: one page of the history, newest first, optionally for
  /// one account. Pass the page's `nextCursor` as [cursor] for the next.
  Future<CursorPage<ImportBatchDto>> list({
    String? accountId,
    String? cursor,
    int limit = pageSize,
  }) => _client.send(
    ApiEndpoints.listImports,
    query: <String, Object?>{
      'account_id': accountId,
      'cursor': cursor,
      'limit': limit,
    },
    decode: (Map<String, Object?> json) {
      final EnvelopeListImportBatchDto envelope =
          decodeEnvelopeListImportBatchDto(json);
      final bool more = envelope.meta.hasMore ?? false;
      return CursorPage<ImportBatchDto>(
        envelope.data,
        more ? envelope.meta.nextCursor : null,
      );
    },
  );

  /// `POST /imports` (idempotent with [key]): starts importing an uploaded
  /// statement into [accountId] (parsing runs in the background). A retry
  /// with the same key returns the batch created the first time.
  Future<ImportBatchDto> create({
    required String accountId,
    required String fileId,
    required String key,
  }) => _client.send(
    ApiEndpoints.createImport,
    body: ImportCreateInput(accountId: accountId, fileId: fileId).toJson(),
    headers: <String, String>{Idempotency.header: key},
    decode: _decodeBatch,
  );

  /// `GET /imports/{id}` with counts, mapping and totals.
  Future<ImportBatchDto> get(String id) => _client.send(
    ApiEndpoints.getImport,
    pathParameters: <String, String>{'id': id},
    decode: _decodeBatch,
  );

  /// `PATCH /imports/{id}/mapping`: which columns hold which values (rows
  /// are re-derived and earlier decisions reset).
  Future<ImportBatchDto> setMapping(
    String id,
    ColumnMapping mapping, {
    required int version,
  }) => _client.send(
    ApiEndpoints.updateImportMapping,
    pathParameters: <String, String>{'id': id},
    body: ImportMappingInput(mapping: mapping, version: version).toJson(),
    decode: _decodeBatch,
  );

  /// `GET /imports/{id}/rows`: rows after [afterRow] (the page's
  /// `next_cursor`), optionally only those with [status].
  Future<ImportRowPage> rows(
    String id, {
    String? status,
    int? afterRow,
    int limit = rowPageSize,
  }) => _client.send(
    ApiEndpoints.importRows,
    pathParameters: <String, String>{'id': id},
    query: <String, Object?>{
      'status': status,
      'after_row': afterRow,
      'limit': limit,
    },
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeImportRowPage(json).data,
  );

  /// `PATCH /imports/{id}/rows/{rowId}`: import or skip a row, set its
  /// category or correct its date, amount, direction or description.
  Future<ImportRowDto> updateRow(
    String id,
    String rowId,
    ImportRowUpdate update,
  ) => _client.send(
    ApiEndpoints.updateImportRow,
    pathParameters: <String, String>{'id': id, 'rowId': rowId},
    body: update.toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeImportRowDto(json).data,
  );

  /// `POST /imports/{id}/confirm` (idempotent with [key]): imports the
  /// ready rows in the background.
  Future<ImportBatchDto> confirm(
    String id, {
    required int version,
    required String key,
  }) => _client.send(
    ApiEndpoints.confirmImport,
    pathParameters: <String, String>{'id': id},
    body: ImportConfirmInput(version: version).toJson(),
    headers: <String, String>{Idempotency.header: key},
    decode: _decodeBatch,
  );

  /// `POST /imports/{id}/cancel` (processing stops between rows).
  Future<ImportBatchDto> cancel(String id) =>
      _action(ApiEndpoints.cancelImport, id);

  /// `POST /imports/{id}/retry-failed`.
  Future<ImportBatchDto> retryFailed(String id) =>
      _action(ApiEndpoints.retryFailedImport, id);

  /// `POST /imports/{id}/rollback`: voids this import's transactions that
  /// were not changed since (runs in the background).
  Future<ImportBatchDto> rollback(String id) =>
      _action(ApiEndpoints.rollbackImport, id);

  Future<ImportBatchDto> _action(ApiEndpoint endpoint, String id) =>
      _client.send(
        endpoint,
        pathParameters: <String, String>{'id': id},
        decode: _decodeBatch,
      );

  static ImportBatchDto _decodeBatch(Map<String, Object?> json) =>
      decodeEnvelopeImportBatchDto(json).data;
}

/// The [ImportsApi] over the shared client. Overridden in tests.
final Provider<ImportsApi> importsApiProvider = Provider<ImportsApi>(
  (Ref ref) => ImportsApi(ref.watch(apiClientProvider)),
);
