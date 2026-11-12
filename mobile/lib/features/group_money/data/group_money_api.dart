import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/api/interceptors/auth_interceptor.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/features/goals/domain/goal_export.dart'
    show exportFileName, withJsonErrorBody;
import 'package:montra_mobile/features/group_money/domain/group_export.dart';

/// Filters of the group expense list (`GET /groups/{id}/expenses`); the
/// same filters are sent with every page.
@immutable
class GroupExpenseFilter {
  /// Creates a filter; the default lists active and disputed expenses.
  const GroupExpenseFilter({
    this.status,
    this.from,
    this.to,
    this.payerUserId,
    this.categoryKey,
  });

  /// `active`, `disputed` or `deleted` (deleted ones are only listed with
  /// this status); null for every expense that is not deleted.
  final String? status;

  /// First expense date (`YYYY-MM-DD`).
  final String? from;

  /// Last expense date (`YYYY-MM-DD`).
  final String? to;

  /// Only expenses this member paid (part of).
  final String? payerUserId;

  /// Only this starter category key (`uncategorized` for none).
  final String? categoryKey;

  /// Whether any filter is set.
  bool get isEmpty =>
      status == null &&
      from == null &&
      to == null &&
      payerUserId == null &&
      categoryKey == null;

  /// The query parameters.
  Map<String, Object?> toQuery() => <String, Object?>{
    'status': status,
    if (status == 'deleted') 'include_deleted': true,
    'from': from,
    'to': to,
    'payer_user_id': payerUserId,
    'category_key': categoryKey,
  };

  /// A copy with other values; `clear*` flags remove one.
  GroupExpenseFilter copyWith({
    String? status,
    String? from,
    String? to,
    String? payerUserId,
    String? categoryKey,
    bool clearStatus = false,
    bool clearDates = false,
    bool clearPayer = false,
    bool clearCategory = false,
  }) => GroupExpenseFilter(
    status: clearStatus ? null : (status ?? this.status),
    from: clearDates ? null : (from ?? this.from),
    to: clearDates ? null : (to ?? this.to),
    payerUserId: clearPayer ? null : (payerUserId ?? this.payerUserId),
    categoryKey: clearCategory ? null : (categoryKey ?? this.categoryKey),
  );

  @override
  bool operator ==(Object other) =>
      other is GroupExpenseFilter &&
      other.status == status &&
      other.from == from &&
      other.to == to &&
      other.payerUserId == payerUserId &&
      other.categoryKey == categoryKey;

  @override
  int get hashCode => Object.hash(status, from, to, payerUserId, categoryKey);

  @override
  String toString() => 'GroupExpenseFilter';
}

/// A settlement lifecycle action (`POST …/settlements/{id}/<action>`, body
/// `SettlementActionBody` with the displayed `version`).
enum SettlementAction {
  /// Payer: a proposed settlement was paid.
  markPaid(ApiEndpoints.markGroupSettlementPaid),

  /// Payee (or an admin for a former member): the money arrived.
  confirm(ApiEndpoints.confirmGroupSettlement),

  /// Either side: something is wrong (reason required).
  dispute(ApiEndpoints.disputeGroupSettlement),

  /// Either side or an admin: cancel the record (reason required).
  voidIt(ApiEndpoints.voidGroupSettlement),

  /// Record it in one of the caller's own accounts.
  record(ApiEndpoints.recordGroupSettlement),

  /// Remove the caller's own account record.
  unlink(ApiEndpoints.unlinkGroupSettlement);

  const SettlementAction(this.endpoint);

  /// The operation.
  final ApiEndpoint endpoint;
}

/// A lifecycle action of a recurring shared expense.
enum GroupRecurringAction {
  /// Stop adding occurrences for now.
  pause(ApiEndpoints.pauseGroupRecurring),

  /// Continue a paused one.
  resume(ApiEndpoints.resumeGroupRecurring),

  /// End it for good (history is kept).
  stop(ApiEndpoints.stopGroupRecurring);

  const GroupRecurringAction(this.endpoint);

  /// The operation.
  final ApiEndpoint endpoint;
}

/// Typed calls for group money: shared expenses, balances, settlements,
/// recurring shared expenses and group reports (`Groups` tag).
///
/// Creating an expense, a settlement, a correction, a recurring expense or
/// adding a recurring occurrence takes an `Idempotency-Key`, so a retry
/// after a lost connection never records anything twice. Montra never
/// moves money: settlements record payments made outside the app.
class GroupMoneyApi {
  /// Creates the API over [client]; [dio] serves the CSV export.
  GroupMoneyApi(this._client, this._dio);

  final ApiClient _client;
  final Dio _dio;

  /// Expenses per page.
  static const int pageSize = 50;

  Map<String, String> _g(String groupId) => <String, String>{'id': groupId};

  Map<String, String> _key(String key) => <String, String>{
    Idempotency.header: key,
  };

  /// `GET /groups/{id}/expenses`: newest first, one page.
  Future<CursorPage<GroupExpenseDto>> expenses(
    String groupId, {
    GroupExpenseFilter filter = const GroupExpenseFilter(),
    String? cursor,
    int limit = pageSize,
  }) => _client.send(
    ApiEndpoints.listGroupExpenses,
    pathParameters: _g(groupId),
    query: <String, Object?>{
      ...filter.toQuery(),
      'cursor': cursor,
      'limit': limit,
    },
    decode: (Map<String, Object?> json) {
      final EnvelopeListGroupExpenseDto envelope =
          decodeEnvelopeListGroupExpenseDto(json);
      final bool more = envelope.meta.hasMore ?? true;
      return CursorPage<GroupExpenseDto>(
        envelope.data,
        more ? envelope.meta.nextCursor : null,
      );
    },
  );

  /// `POST /groups/{id}/expenses` (idempotent with [key]).
  Future<GroupExpenseDetail> createExpense(
    String groupId,
    GroupExpenseInput input, {
    required String key,
  }) => _client.send(
    ApiEndpoints.createGroupExpense,
    pathParameters: _g(groupId),
    body: input.toJson(),
    headers: _key(key),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeGroupExpenseDetail(json).data,
  );

  /// `GET /groups/{id}/expenses/{expenseId}` with items, comments, disputes.
  Future<GroupExpenseDetail> expense(String groupId, String expenseId) =>
      _client.send(
        ApiEndpoints.getGroupExpense,
        pathParameters: <String, String>{'id': groupId, 'expenseId': expenseId},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeGroupExpenseDetail(json).data,
      );

  /// `PATCH /groups/{id}/expenses/{expenseId}`: the whole expense with its
  /// `version` (the history keeps the earlier split).
  Future<GroupExpenseDetail> updateExpense(
    String groupId,
    String expenseId,
    GroupExpenseInput input,
  ) => _client.send(
    ApiEndpoints.updateGroupExpense,
    pathParameters: <String, String>{'id': groupId, 'expenseId': expenseId},
    body: input.toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeGroupExpenseDetail(json).data,
  );

  /// `DELETE /groups/{id}/expenses/{expenseId}` (creator or an admin).
  Future<void> deleteExpense(String groupId, String expenseId) => _client.send(
    ApiEndpoints.deleteGroupExpense,
    pathParameters: <String, String>{'id': groupId, 'expenseId': expenseId},
    decode: decodeEnvelopeEmpty,
  );

  /// `POST …/expenses/{expenseId}/comments`.
  Future<GroupCommentDto> comment(
    String groupId,
    String expenseId,
    String body,
  ) => _client.send(
    ApiEndpoints.commentGroupExpense,
    pathParameters: <String, String>{'id': groupId, 'expenseId': expenseId},
    body: GroupCommentInput(body: body).toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeGroupCommentDto(json).data,
  );

  /// `POST …/expenses/{expenseId}/disputes`: says what is wrong.
  Future<GroupDisputeDto> dispute(
    String groupId,
    String expenseId,
    String reason,
  ) => _client.send(
    ApiEndpoints.disputeGroupExpense,
    pathParameters: <String, String>{'id': groupId, 'expenseId': expenseId},
    body: GroupDisputeInput(reason: reason).toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeGroupDisputeDto(json).data,
  );

  /// `POST /groups/{id}/disputes/{disputeId}/resolve`: an admin resolves
  /// it with a [resolution], or the person who raised it withdraws it.
  Future<void> resolveDispute(
    String groupId,
    String disputeId, {
    String? resolution,
    bool withdraw = false,
  }) => _client.send(
    ApiEndpoints.resolveGroupDispute,
    pathParameters: <String, String>{'id': groupId, 'disputeId': disputeId},
    body: ResolveDisputeInput(
      resolution: resolution,
      withdraw: withdraw ? true : null,
    ).toJson(),
    decode: decodeEnvelopeEmpty,
  );

  /// `POST …/expenses/{expenseId}/my-record`: links the caller's payment to
  /// [accountId], or unlinks it (null).
  Future<GroupExpenseDetail> myRecord(
    String groupId,
    String expenseId, {
    String? accountId,
  }) => _client.send(
    ApiEndpoints.recordGroupExpense,
    pathParameters: <String, String>{'id': groupId, 'expenseId': expenseId},
    body: ExpenseRecordInput(
      action: accountId == null
          ? ExpenseRecordInputAction.unlink
          : ExpenseRecordInputAction.link,
      accountId: accountId,
    ).toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeGroupExpenseDetail(json).data,
  );

  /// `GET /groups/{id}/balances`.
  Future<GroupBalancesDto> balances(String groupId) => _client.send(
    ApiEndpoints.groupBalances,
    pathParameters: _g(groupId),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeGroupBalancesDto(json).data,
  );

  /// `GET /groups/{id}/settlement-suggestions` (only the caller's with
  /// [mine]).
  Future<GroupSuggestionsDto> suggestions(
    String groupId, {
    bool mine = false,
  }) => _client.send(
    ApiEndpoints.groupSettlementSuggestions,
    pathParameters: _g(groupId),
    query: <String, Object?>{if (mine) 'mine': true},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeGroupSuggestionsDto(json).data,
  );

  /// `GET /groups/{id}/settlements`.
  Future<List<SettlementDto>> settlements(
    String groupId, {
    bool includeVoided = false,
  }) => _client.send(
    ApiEndpoints.listGroupSettlements,
    pathParameters: _g(groupId),
    query: <String, Object?>{if (includeVoided) 'include_voided': true},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListSettlementDto(json).data,
  );

  /// `GET /groups/{id}/settlements/{settlementId}`.
  Future<SettlementDto> settlement(String groupId, String settlementId) =>
      _client.send(
        ApiEndpoints.getGroupSettlement,
        pathParameters: <String, String>{
          'id': groupId,
          'settlementId': settlementId,
        },
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeSettlementDto(json).data,
      );

  /// `POST /groups/{id}/settlements` (idempotent with [key]).
  Future<SettlementDto> createSettlement(
    String groupId,
    SettlementInput input, {
    required String key,
  }) => _client.send(
    ApiEndpoints.createGroupSettlement,
    pathParameters: _g(groupId),
    body: input.toJson(),
    headers: _key(key),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeSettlementDto(json).data,
  );

  /// `POST …/settlements/{settlementId}/correct` (idempotent with [key]):
  /// voids the original and records [input] linked to it.
  Future<SettlementDto> correctSettlement(
    String groupId,
    String settlementId,
    SettlementInput input, {
    required String key,
  }) => _client.send(
    ApiEndpoints.correctGroupSettlement,
    pathParameters: <String, String>{
      'id': groupId,
      'settlementId': settlementId,
    },
    body: input.toJson(),
    headers: _key(key),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeSettlementDto(json).data,
  );

  /// A lifecycle [action] with the settlement's [version].
  Future<SettlementDto> settlementAction(
    String groupId,
    String settlementId,
    SettlementAction action, {
    required int version,
    String? accountId,
    String? reason,
  }) => _client.send(
    action.endpoint,
    pathParameters: <String, String>{
      'id': groupId,
      'settlementId': settlementId,
    },
    body: SettlementActionBody(
      version: version,
      accountId: accountId,
      reason: reason,
    ).toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeSettlementDto(json).data,
  );

  /// `GET /groups/{id}/recurring-expenses`.
  Future<List<GroupRecurringDto>> recurring(String groupId) => _client.send(
    ApiEndpoints.listGroupRecurring,
    pathParameters: _g(groupId),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListGroupRecurringDto(json).data,
  );

  /// `GET /groups/{id}/recurring-expenses/{ruleId}`.
  Future<GroupRecurringDto> recurringRule(String groupId, String ruleId) =>
      _client.send(
        ApiEndpoints.getGroupRecurring,
        pathParameters: <String, String>{'id': groupId, 'ruleId': ruleId},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeGroupRecurringDto(json).data,
      );

  /// `POST /groups/{id}/recurring-expenses` (idempotent with [key]).
  Future<GroupRecurringDto> createRecurring(
    String groupId,
    GroupRecurringInput input, {
    required String key,
  }) => _client.send(
    ApiEndpoints.createGroupRecurring,
    pathParameters: _g(groupId),
    body: input.toJson(),
    headers: _key(key),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeGroupRecurringDto(json).data,
  );

  /// `PATCH /groups/{id}/recurring-expenses/{ruleId}`: name, amount and
  /// split with the rule's `version`.
  Future<GroupRecurringDto> updateRecurring(
    String groupId,
    String ruleId,
    GroupRecurringUpdate input,
  ) => _client.send(
    ApiEndpoints.updateGroupRecurring,
    pathParameters: <String, String>{'id': groupId, 'ruleId': ruleId},
    body: input.toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeGroupRecurringDto(json).data,
  );

  /// Pause, resume or stop a recurring shared expense.
  Future<GroupRecurringDto> recurringAction(
    String groupId,
    String ruleId,
    GroupRecurringAction action,
  ) => _client.send(
    action.endpoint,
    pathParameters: <String, String>{'id': groupId, 'ruleId': ruleId},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeGroupRecurringDto(json).data,
  );

  /// Adds one occurrence as an expense (idempotent with [key]).
  Future<GroupExpenseDetail> addOccurrence(
    String groupId,
    String ruleId,
    String occurrenceId, {
    required String key,
  }) => _client.send(
    ApiEndpoints.addGroupRecurringOccurrence,
    pathParameters: <String, String>{
      'id': groupId,
      'ruleId': ruleId,
      'occurrenceId': occurrenceId,
    },
    headers: _key(key),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeGroupExpenseDetail(json).data,
  );

  /// Skips one occurrence (its creator or an admin).
  Future<GroupRecurringDto> skipOccurrence(
    String groupId,
    String ruleId,
    String occurrenceId,
  ) => _client.send(
    ApiEndpoints.skipGroupRecurringOccurrence,
    pathParameters: <String, String>{
      'id': groupId,
      'ruleId': ruleId,
      'occurrenceId': occurrenceId,
    },
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeGroupRecurringDto(json).data,
  );

  /// `GET /groups/{id}/reports` for [from]–[to] (all time when null).
  Future<GroupReportDto> report(String groupId, {String? from, String? to}) =>
      _client.send(
        ApiEndpoints.groupReports,
        pathParameters: _g(groupId),
        query: <String, Object?>{'from': from, 'to': to},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeGroupReportDto(json).data,
      );

  /// `GET /groups/{id}/export`: every expense and settlement as CSV
  /// (`text/csv`, named by `Content-Disposition`), read through [Dio]
  /// directly with the same auth and error handling as [ApiClient.send].
  Future<GroupExport> export(String groupId) async {
    const ApiEndpoint endpoint = ApiEndpoints.exportGroup;
    final Response<String> response;
    try {
      response = await _dio.request<String>(
        endpoint.resolve(_g(groupId)),
        options: Options(
          method: endpoint.method,
          responseType: ResponseType.plain,
          headers: <String, Object?>{Headers.acceptHeader: 'text/csv'},
          extra: <String, Object?>{
            AuthExtras.requiresAuth: endpoint.requiresAuth,
            AuthExtras.endpoint: endpoint.path,
          },
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(withJsonErrorBody(error));
    }
    final String? csv = response.data;
    if (csv == null) {
      throw ApiException.invalidResponse(
        statusCode: response.statusCode,
        requestId: response.headers.value('x-request-id'),
      );
    }
    return GroupExport(
      csv: csv,
      fileName: exportFileName(response.headers.value('content-disposition')),
    );
  }
}

/// Group money endpoints. Overridden in tests.
final Provider<GroupMoneyApi> groupMoneyApiProvider = Provider<GroupMoneyApi>(
  (Ref ref) =>
      GroupMoneyApi(ref.watch(apiClientProvider), ref.watch(apiDioProvider)),
);
