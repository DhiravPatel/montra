import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for the `Reconciliation` tag: statement balance checks
/// (the server computes the difference), suggested matches with reasons,
/// and user-confirmed matches that can be undone. Nothing is matched or
/// removed without the user confirming it.
class ReconciliationApi {
  /// Creates the API over [client].
  ReconciliationApi(this._client);

  final ApiClient _client;

  /// Items fetched per page of the lists below.
  static const int pageSize = 50;

  /// `GET /accounts/{id}/reconciliations`: one page of statement balance
  /// checks, latest statement first.
  Future<CursorPage<ReconBalanceDto>> balances(
    String accountId, {
    String? cursor,
    int limit = pageSize,
  }) => _client.send(
    ApiEndpoints.listReconciliations,
    pathParameters: <String, String>{'id': accountId},
    query: <String, Object?>{'cursor': cursor, 'limit': limit},
    decode: (Map<String, Object?> json) {
      final EnvelopeListReconBalanceDto e = decodeEnvelopeListReconBalanceDto(
        json,
      );
      return CursorPage<ReconBalanceDto>(e.data, _next(e.meta));
    },
  );

  /// `POST /accounts/{id}/reconciliations`: compares a statement balance
  /// with Montra's balance on the statement date. When they match, the
  /// posted transactions up to that date are marked reconciled.
  Future<ReconBalanceDto> reconcile(
    String accountId,
    ReconBalanceInput input,
  ) => _client.send(
    ApiEndpoints.createReconciliation,
    pathParameters: <String, String>{'id': accountId},
    body: input.toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeReconBalanceDto(json).data,
  );

  /// `GET /reconciliation/candidates`: suggested matches, optionally of one
  /// [kind] or for one import ([batchId]).
  Future<List<ReconCandidate>> candidates(
    String accountId, {
    String? kind,
    String? batchId,
  }) => _client.send(
    ApiEndpoints.reconciliationCandidates,
    query: <String, Object?>{
      'account_id': accountId,
      'kind': kind,
      'batch_id': batchId,
    },
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListReconCandidate(json).data,
  );

  /// `GET /reconciliation/matches`: one page of an account's matches,
  /// newest first.
  Future<CursorPage<ReconMatchDto>> matches(
    String accountId, {
    String? cursor,
    int limit = pageSize,
  }) => _client.send(
    ApiEndpoints.listReconciliationMatches,
    query: <String, Object?>{
      'account_id': accountId,
      'cursor': cursor,
      'limit': limit,
    },
    decode: (Map<String, Object?> json) {
      final EnvelopeListReconMatchDto e = decodeEnvelopeListReconMatchDto(json);
      return CursorPage<ReconMatchDto>(e.data, _next(e.meta));
    },
  );

  /// `GET /accounts/{id}/statement-lines`: one page of statement lines
  /// (oldest first) that were neither imported nor matched
  /// ([matched] false), or the ones matched by hand ([matched] true, with
  /// `match_id`), optionally of one import ([batchId]).
  Future<CursorPage<StatementLineDto>> statementLines(
    String accountId, {
    bool matched = false,
    String? batchId,
    String? cursor,
    int limit = pageSize,
  }) => _client.send(
    ApiEndpoints.accountStatementLines,
    pathParameters: <String, String>{'id': accountId},
    query: <String, Object?>{
      'status': matched ? 'matched' : 'unmatched',
      'batch_id': batchId,
      'cursor': cursor,
      'limit': limit,
    },
    decode: (Map<String, Object?> json) {
      final EnvelopeListStatementLineDto e = decodeEnvelopeListStatementLineDto(
        json,
      );
      return CursorPage<StatementLineDto>(e.data, _next(e.meta));
    },
  );

  /// `POST /reconciliation/matches`: confirms a match (a suggestion, or a
  /// statement line matched by hand with transactions of the account:
  /// [manualMatchInput]).
  Future<ReconMatchDto> confirm(ReconMatchInput input) => _client.send(
    ApiEndpoints.createReconciliationMatch,
    body: input.toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeReconMatchDto(json).data,
  );

  /// `DELETE /reconciliation/matches/{id}`: undoes a match (removed
  /// transactions come back, statement rows return to their import).
  Future<ReconMatchDto> unmatch(String matchId) => _client.send(
    ApiEndpoints.deleteReconciliationMatch,
    pathParameters: <String, String>{'id': matchId},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeReconMatchDto(json).data,
  );

  static String? _next(Meta meta) =>
      (meta.hasMore ?? false) ? meta.nextCursor : null;
}

/// Reconciliation endpoints. Overridden in tests.
final Provider<ReconciliationApi> reconciliationApiProvider =
    Provider<ReconciliationApi>(
      (Ref ref) => ReconciliationApi(ref.watch(apiClientProvider)),
    );
