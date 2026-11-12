import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/api/interceptors/auth_interceptor.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/features/goals/domain/goal_export.dart';

/// Typed calls for the `Goals` tag of the contract.
///
/// Creating a goal, adding a contribution and recording a planned one take
/// an `Idempotency-Key` (a retry after a lost connection never adds a
/// second one). Edits send only the changed fields ([GoalPatch]) with the
/// loaded `version`; lifecycle and member changes take the displayed
/// `version` too, so a change made elsewhere answers `VERSION_CONFLICT`.
class GoalsApi {
  /// Creates the API over [client]; [dio] serves the CSV export, which is
  /// not a JSON envelope.
  GoalsApi(this._client, this._dio);

  final ApiClient _client;
  final Dio _dio;

  /// Contributions per page (the server's default and maximum).
  static const int contributionsPageSize = 500;

  /// `GET /goals`: the user's own and shared goals with progress.
  ///
  /// [status] is one contract status, `all` (archived included) or null
  /// for every goal except archived ones.
  Future<List<GoalDto>> list({String? status}) => _client.send(
    ApiEndpoints.listGoals,
    query: <String, Object?>{'status': status},
    decode: (Map<String, Object?> json) => decodeEnvelopeListGoalDto(json).data,
  );

  /// `GET /goals/{id}`.
  Future<GoalDto> get(String id) => _goal(ApiEndpoints.getGoal, id);

  /// `POST /goals` with an `Idempotency-Key` ([key]).
  Future<GoalDto> create(GoalInput input, {required String key}) =>
      _client.send(
        ApiEndpoints.createGoal,
        body: input.toJson(),
        headers: <String, String>{Idempotency.header: key},
        decode: _decodeGoal,
      );

  /// `PATCH /goals/{id}`: only the fields in [patch] change (milestones
  /// and the starting amount are kept when omitted; `clear` removes the
  /// linked account or group); contributions never change.
  Future<GoalDto> update(String id, GoalPatch patch) => _client.send(
    ApiEndpoints.updateGoal,
    pathParameters: <String, String>{'id': id},
    body: patch.toJson(),
    decode: _decodeGoal,
  );

  /// `DELETE /goals/{id}`: archives the goal (history is kept).
  Future<GoalDto> archive(String id, {int? version}) =>
      _goal(ApiEndpoints.deleteGoal, id, version: version);

  /// `POST /goals/{id}/pause`.
  Future<GoalDto> pause(String id, {int? version}) =>
      _goal(ApiEndpoints.pauseGoal, id, version: version);

  /// `POST /goals/{id}/resume`.
  Future<GoalDto> resume(String id, {int? version}) =>
      _goal(ApiEndpoints.resumeGoal, id, version: version);

  /// `POST /goals/{id}/achieve`.
  Future<GoalDto> achieve(String id, {int? version}) =>
      _goal(ApiEndpoints.achieveGoal, id, version: version);

  /// `POST /goals/{id}/cancel`: ends the goal without reaching it.
  Future<GoalDto> cancel(String id, {int? version}) =>
      _goal(ApiEndpoints.cancelGoal, id, version: version);

  /// One page of `GET /goals/{id}/contributions`, newest first (each
  /// contributor's visibility choice applies).
  Future<CursorPage<GoalContributionDto>> contributions(
    String id, {
    String? cursor,
    int limit = contributionsPageSize,
  }) => _client.send(
    ApiEndpoints.listGoalContributions,
    pathParameters: <String, String>{'id': id},
    query: <String, Object?>{'cursor': cursor, 'limit': limit},
    decode: (Map<String, Object?> json) {
      final EnvelopeListGoalContributionDto envelope =
          decodeEnvelopeListGoalContributionDto(json);
      return CursorPage<GoalContributionDto>(
        envelope.data,
        envelope.meta.nextCursor,
      );
    },
  );

  /// `POST /goals/{id}/contributions` with an `Idempotency-Key`.
  Future<GoalContributionDto> addContribution(
    String id,
    GoalContributionInput input, {
    required String key,
  }) => _client.send(
    ApiEndpoints.addGoalContribution,
    pathParameters: <String, String>{'id': id},
    body: input.toJson(),
    headers: <String, String>{Idempotency.header: key},
    decode: _decodeContribution,
  );

  /// `POST /goals/{id}/contributions/{contributionId}/record` with an
  /// `Idempotency-Key`: the user's planned contribution becomes recorded
  /// (verified when [GoalContributionRecordInput.transactionId] is set),
  /// counted exactly once.
  Future<GoalContributionDto> recordContribution(
    String id,
    String contributionId,
    GoalContributionRecordInput input, {
    required String key,
  }) => _client.send(
    ApiEndpoints.recordGoalContribution,
    pathParameters: <String, String>{
      'id': id,
      'contributionId': contributionId,
    },
    body: input.toJson(),
    headers: <String, String>{Idempotency.header: key},
    decode: _decodeContribution,
  );

  /// `POST /goals/{id}/contributions/{contributionId}/void`: voids the
  /// user's own contribution (it stays in the history).
  Future<GoalDto> voidContribution(String id, String contributionId) =>
      _client.send(
        ApiEndpoints.voidGoalContribution,
        pathParameters: <String, String>{
          'id': id,
          'contributionId': contributionId,
        },
        decode: _decodeGoal,
      );

  /// `GET /goals/{id}/forecast`: required pace and projected completion.
  Future<GoalForecast> forecast(String id) => _client.send(
    ApiEndpoints.goalForecast,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeGoalForecast(json).data,
  );

  /// `POST /goals/{id}/members`: shares with a friend or group member.
  Future<GoalDto> addMember(String id, GoalMemberInput input, {int? version}) =>
      _client.send(
        ApiEndpoints.addGoalMember,
        pathParameters: <String, String>{'id': id},
        query: <String, Object?>{'version': version},
        body: input.toJson(),
        decode: _decodeGoal,
      );

  /// `PATCH /goals/{id}/members/{userId}`: a member's role (owner), or the
  /// user's own contribution visibility (the owner included).
  Future<GoalDto> updateMember(
    String id,
    String userId,
    GoalMemberUpdate update, {
    int? version,
  }) => _client.send(
    ApiEndpoints.updateGoalMember,
    pathParameters: <String, String>{'id': id, 'userId': userId},
    query: <String, Object?>{'version': version},
    body: update.toJson(),
    decode: _decodeGoal,
  );

  /// `DELETE /goals/{id}/members/{userId}`: removes a member, or leaves
  /// when [userId] is the user (past contributions stay). The owner can
  /// neither leave nor be removed.
  Future<void> removeMember(String id, String userId, {int? version}) async {
    await _client.send(
      ApiEndpoints.removeGoalMember,
      pathParameters: <String, String>{'id': id, 'userId': userId},
      query: <String, Object?>{'version': version},
      decode: decodeEnvelopeEmpty,
    );
  }

  /// `GET /goals/{id}/export`: every contribution as CSV (`text/csv`,
  /// named by `Content-Disposition`), read through [Dio] directly with the
  /// same auth and error handling as [ApiClient.send].
  Future<GoalExport> export(String id) async {
    const ApiEndpoint endpoint = ApiEndpoints.exportGoal;
    final Response<String> response;
    try {
      response = await _dio.request<String>(
        endpoint.resolve(<String, String>{'id': id}),
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
    return GoalExport(
      csv: csv,
      fileName: exportFileName(response.headers.value('content-disposition')),
    );
  }

  Future<GoalDto> _goal(ApiEndpoint endpoint, String id, {int? version}) =>
      _client.send(
        endpoint,
        pathParameters: <String, String>{'id': id},
        query: <String, Object?>{'version': version},
        decode: _decodeGoal,
      );

  static GoalDto _decodeGoal(Map<String, Object?> json) =>
      decodeEnvelopeGoalDto(json).data;

  static GoalContributionDto _decodeContribution(Map<String, Object?> json) =>
      decodeEnvelopeGoalContributionDto(json).data;
}

/// The [GoalsApi] over the shared client.
final Provider<GoalsApi> goalsApiProvider = Provider<GoalsApi>(
  (Ref ref) =>
      GoalsApi(ref.watch(apiClientProvider), ref.watch(apiDioProvider)),
);
