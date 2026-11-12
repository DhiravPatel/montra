import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for budgets, their members and budget alerts.
///
/// None of these operations takes an `Idempotency-Key` (the contract
/// requires one only for money-moving creates). `PATCH /budgets/{id}`
/// changes only the fields sent ([BudgetPatch], built by the form from
/// what the user changed) and needs the `version` that was loaded.
/// Lifecycle actions take the displayed `version` too, so a change made
/// elsewhere answers `VERSION_CONFLICT` instead of being overwritten.
class BudgetsApi {
  /// Creates the API over [client].
  BudgetsApi(this._client);

  final ApiClient _client;

  /// Page size of counted transactions and of the alerts screen.
  static const int pageSize = 50;

  /// Most alerts one request returns (`GET /budget-alerts` `limit` maximum).
  static const int maxPageSize = 200;

  /// `GET /budgets` with current progress (archived ones only with
  /// [includeArchived]).
  Future<List<BudgetDto>> list({bool includeArchived = false}) => _client.send(
    ApiEndpoints.listBudgets,
    query: <String, Object?>{if (includeArchived) 'include_archived': true},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListBudgetDto(json).data,
  );

  /// `GET /budgets/{id}` with progress and allocations.
  Future<BudgetDto> get(String id) => _client.send(
    ApiEndpoints.getBudget,
    pathParameters: <String, String>{'id': id},
    decode: _decodeBudget,
  );

  /// `POST /budgets`.
  Future<BudgetDto> create(BudgetInput input) => _client.send(
    ApiEndpoints.createBudget,
    body: input.toJson(),
    decode: _decodeBudget,
  );

  /// `PATCH /budgets/{id}`: only the fields in [patch] change (lists
  /// replace the stored list, `[]` empties it, `""` clears text fields);
  /// applies from the current period onward.
  Future<BudgetDto> update(String id, BudgetPatch patch) => _client.send(
    ApiEndpoints.updateBudget,
    pathParameters: <String, String>{'id': id},
    body: patch.toJson(),
    decode: _decodeBudget,
  );

  /// `DELETE /budgets/{id}`: archives the budget (history is kept;
  /// archiving twice changes nothing).
  Future<BudgetDto> archive(String id, {int? version}) =>
      _action(ApiEndpoints.deleteBudget, id, version);

  /// `POST /budgets/{id}/pause` (active budgets only).
  Future<BudgetDto> pause(String id, {int? version}) =>
      _action(ApiEndpoints.pauseBudget, id, version);

  /// `POST /budgets/{id}/resume` (paused budgets only).
  Future<BudgetDto> resume(String id, {int? version}) =>
      _action(ApiEndpoints.resumeBudget, id, version);

  /// `POST /budgets/{id}/restore`: an archived budget becomes active again.
  Future<BudgetDto> restore(String id, {int? version}) =>
      _action(ApiEndpoints.restoreBudget, id, version);

  /// `GET /budgets/{id}/progress`: the period containing [date] (default
  /// today) followed by the period before it (not for custom dates).
  Future<List<ProgressDto>> progress(String id, {String? date}) => _client.send(
    ApiEndpoints.budgetProgress,
    pathParameters: <String, String>{'id': id},
    query: <String, Object?>{'date': date},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListProgressDto(json).data,
  );

  /// `GET /budgets/{id}/transactions`: one page of exactly the transactions
  /// counted in the period containing [date] (owner only; collaborators get
  /// `FORBIDDEN` and see the totals only).
  Future<CursorPage<TransactionDto>> transactions(
    String id, {
    String? date,
    String? cursor,
    int limit = pageSize,
  }) => _client.send(
    ApiEndpoints.budgetTransactions,
    pathParameters: <String, String>{'id': id},
    query: <String, Object?>{'date': date, 'cursor': cursor, 'limit': limit},
    decode: (Map<String, Object?> json) {
      final EnvelopeListTransactionDto envelope =
          decodeEnvelopeListTransactionDto(json);
      return CursorPage<TransactionDto>(
        envelope.data,
        envelope.meta.nextCursor,
      );
    },
  );

  /// `POST /budgets/{id}/members`: shares the budget with a connection or
  /// group member.
  Future<BudgetDto> addMember(String id, MemberInput input) => _client.send(
    ApiEndpoints.addBudgetMember,
    pathParameters: <String, String>{'id': id},
    body: input.toJson(),
    decode: _decodeBudget,
  );

  /// `PATCH /budgets/{id}/members/{userId}`: role and allocation.
  Future<BudgetDto> updateMember(
    String id,
    String userId,
    BudgetsMembersUpdateRequest change,
  ) => _client.send(
    ApiEndpoints.updateBudgetMember,
    pathParameters: <String, String>{'id': id, 'userId': userId},
    body: change.toJson(),
    decode: _decodeBudget,
  );

  /// `DELETE /budgets/{id}/members/{userId}`: the owner removes a member,
  /// or a member leaves.
  Future<void> removeMember(String id, String userId) => _client.send(
    ApiEndpoints.removeBudgetMember,
    pathParameters: <String, String>{'id': id, 'userId': userId},
    decode: decodeEnvelopeEmpty,
  );

  /// `GET /budget-alerts` with [status] (all statuses when null): the first
  /// [maxPageSize] alerts, enough for counts such as the Home banner. The
  /// alerts screen pages with [alertsPage].
  Future<List<AlertDto>> alerts({String? status, String? budgetId}) async =>
      (await alertsPage(
        status: status,
        budgetId: budgetId,
        limit: maxPageSize,
      )).items;

  /// One page of `GET /budget-alerts` (newest first), optionally of one
  /// budget ([budgetId], `?budget_id=`).
  Future<CursorPage<AlertDto>> alertsPage({
    String? status,
    String? budgetId,
    String? cursor,
    int limit = pageSize,
  }) => _client.send(
    ApiEndpoints.listBudgetAlerts,
    query: <String, Object?>{
      'status': status,
      'budget_id': budgetId,
      'cursor': cursor,
      'limit': limit,
    },
    decode: (Map<String, Object?> json) {
      final EnvelopeListAlertDto envelope = decodeEnvelopeListAlertDto(json);
      return CursorPage<AlertDto>(envelope.data, envelope.meta.nextCursor);
    },
  );

  /// `PATCH /budget-alerts/{id}`: dismiss, snooze or reactivate.
  Future<void> updateAlert(String id, BudgetAlertsUpdateRequest change) =>
      _client.send(
        ApiEndpoints.updateBudgetAlert,
        pathParameters: <String, String>{'id': id},
        body: change.toJson(),
        decode: decodeEnvelopeEmpty,
      );

  /// `GET /merchants/{id}`, for the names of merchants a budget counts.
  Future<MerchantDetail> merchant(String id) => _client.send(
    ApiEndpoints.getMerchant,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeMerchantDetail(json).data,
  );

  Future<BudgetDto> _action(ApiEndpoint endpoint, String id, int? version) =>
      _client.send(
        endpoint,
        pathParameters: <String, String>{'id': id},
        query: <String, Object?>{'version': version},
        decode: _decodeBudget,
      );

  static BudgetDto _decodeBudget(Map<String, Object?> json) =>
      decodeEnvelopeBudgetDto(json).data;
}

/// The [BudgetsApi] over the shared client.
final Provider<BudgetsApi> budgetsApiProvider = Provider<BudgetsApi>(
  (Ref ref) => BudgetsApi(ref.watch(apiClientProvider)),
);
