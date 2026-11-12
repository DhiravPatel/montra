import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for what moderation did to the signed-in user: the
/// decisions about them, their appeals and the reports they filed. The
/// staff queues are web-only.
class ModerationApi {
  /// Creates the API over [client].
  ModerationApi(this._client);

  final ApiClient _client;

  /// `GET /me/moderation`: warnings, removals and sanctions that affected
  /// the caller, with the state of their appeal.
  Future<List<ModerationActionDto>> myModeration() => _client.send(
    ApiEndpoints.myModeration,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListModerationActionDto(json).data,
  );

  /// `GET /me/moderation/appeals`, newest first.
  Future<List<ModerationAppealDto>> myAppeals() => _client.send(
    ApiEndpoints.myModerationAppeals,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListModerationAppealDto(json).data,
  );

  /// `POST /moderation/actions/{id}/appeals` within the appeal window
  /// (422 `not_appealable` / `appeal_window_passed`).
  Future<ModerationAppealDto> appeal(String actionId, String statement) =>
      _client.send(
        ApiEndpoints.appealModerationAction,
        pathParameters: <String, String>{'id': actionId},
        body: ModerationAppealInput(statement: statement).toJson(),
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeModerationAppealDto(json).data,
      );

  /// `GET /content-reports`: reports the caller filed and their outcome.
  Future<List<ModerationReportDto>> myReports() => _client.send(
    ApiEndpoints.myContentReports,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListModerationReportDto(json).data,
  );

  /// `POST /content-reports`: reports a comment, profile, group or
  /// community (posts use `POST /posts/{id}/reports`).
  Future<ModerationReportDto> report(ModerationReportInput input) =>
      _client.send(
        ApiEndpoints.createContentReport,
        body: input.toJson(),
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeModerationReportDto(json).data,
      );
}

/// Moderation endpoints. Overridden in tests.
final Provider<ModerationApi> moderationApiProvider = Provider<ModerationApi>(
  (Ref ref) => ModerationApi(ref.watch(apiClientProvider)),
);
