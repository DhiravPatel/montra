import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Recurring rules and their occurrences.
class RecurringApi {
  /// Creates the API over [client].
  RecurringApi(this._client);

  final ApiClient _client;

  /// `GET /recurring-rules`, optionally narrowed by [kind] (`expense`,
  /// `income`, `transfer`, `bill`) and [status] (`active`, `paused`,
  /// `ended`).
  Future<List<RecurringRuleDto>> list({String? kind, String? status}) =>
      _client.send(
        ApiEndpoints.listRecurringRules,
        query: <String, Object?>{'kind': kind, 'status': status},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeListRecurringRuleDto(json).data,
      );

  /// `GET /recurring-rules/{id}` with upcoming and past occurrences.
  Future<RecurringRuleDetail> get(String id) => _client.send(
    ApiEndpoints.getRecurringRule,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeRecurringRuleDetail(json).data,
  );

  /// `POST /recurring-rules` (idempotent: a retry with the same [key] and
  /// body returns the rule created first).
  Future<RecurringRuleDto> create(
    RecurringRuleInput input, {
    required String key,
  }) => _client.send(
    ApiEndpoints.createRecurringRule,
    body: input.toJson(),
    headers: <String, String>{Idempotency.header: key},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeRecurringRuleDto(json).data,
  );

  /// `PATCH /recurring-rules/{id}`: changes this and future occurrences.
  /// Only the fields in [patch] change; optional ones named in `clear` are
  /// removed. It carries the `version` shown.
  Future<RecurringRuleDto> update(String id, RecurringRulePatch patch) =>
      _client.send(
        ApiEndpoints.updateRecurringRule,
        pathParameters: <String, String>{'id': id},
        body: patch.toJson(),
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeRecurringRuleDto(json).data,
      );

  /// `DELETE /recurring-rules/{id}`: removes an unused rule or ends one
  /// with history (see [RecurringDeleteResult.outcome]).
  Future<RecurringDeleteResult> delete(String id) => _client.send(
    ApiEndpoints.deleteRecurringRule,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeRecurringDeleteResult(json).data,
  );

  /// `POST /recurring-rules/{id}/pause`. [version] is the version shown:
  /// a rule changed meanwhile answers `VERSION_CONFLICT`.
  Future<RecurringRuleDto> pause(String id, {int? version}) =>
      _ruleAction(ApiEndpoints.pauseRecurringRule, id, version);

  /// `POST /recurring-rules/{id}/resume`.
  Future<RecurringRuleDto> resume(String id, {int? version}) =>
      _ruleAction(ApiEndpoints.resumeRecurringRule, id, version);

  /// `POST /recurring-rules/{id}/skip-next`.
  Future<RecurringRuleDto> skipNext(String id, {int? version}) =>
      _ruleAction(ApiEndpoints.skipNextRecurring, id, version);

  /// `POST /recurring-rules/{id}/stop`: no more occurrences; history stays.
  Future<RecurringRuleDto> stop(String id, {int? version}) =>
      _ruleAction(ApiEndpoints.stopRecurringRule, id, version);

  Future<RecurringRuleDto> _ruleAction(
    ApiEndpoint endpoint,
    String id,
    int? version,
  ) => _client.send(
    endpoint,
    pathParameters: <String, String>{'id': id},
    query: <String, Object?>{'version': version},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeRecurringRuleDto(json).data,
  );

  /// `POST /recurring-occurrences/{id}/actions` (idempotent with [key]).
  Future<OccurrenceDto> act(
    String occurrenceId,
    OccurrenceAction action, {
    required String key,
  }) => _client.send(
    ApiEndpoints.recurringOccurrenceAction,
    pathParameters: <String, String>{'id': occurrenceId},
    body: action.toJson(),
    headers: <String, String>{Idempotency.header: key},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeOccurrenceDto(json).data,
  );
}

/// The [RecurringApi] over the shared client.
final Provider<RecurringApi> recurringApiProvider = Provider<RecurringApi>(
  (Ref ref) => RecurringApi(ref.watch(apiClientProvider)),
);
