import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for the deterministic insights (`Insights` tag): rules the
/// server runs over the user's own records. Nothing here uses AI:
/// `POST /ai/insights/generate` and every `/ai/*` endpoint are never called.
class InsightsApi {
  /// Creates the API over [client].
  InsightsApi(this._client);

  final ApiClient _client;

  /// Insights fetched per page.
  static const int pageSize = 50;

  /// `GET /insights`: one page, warnings first, then newest first. [all]
  /// includes dismissed, expected, resolved and muted ones; [kind] limits
  /// the page to one kind.
  Future<CursorPage<InsightDto>> list({
    bool all = false,
    String? kind,
    String? cursor,
    int limit = pageSize,
  }) => _client.send(
    ApiEndpoints.listInsights,
    query: <String, Object?>{
      if (all) 'all': true,
      'kind': kind,
      'cursor': cursor,
      'limit': limit,
    },
    decode: (Map<String, Object?> json) {
      final EnvelopeListInsightDto envelope = decodeEnvelopeListInsightDto(
        json,
      );
      final bool more = envelope.meta.hasMore ?? true;
      return CursorPage<InsightDto>(
        envelope.data,
        more ? envelope.meta.nextCursor : null,
      );
    },
  );

  /// `POST /insights/{id}/actions`: dismiss, snooze ([snoozeDays]), mark
  /// expected or resolved, mute this kind, or reopen. Never changes the
  /// user's records.
  Future<InsightDto> act(
    String id,
    ActionInputAction action, {
    int? snoozeDays,
  }) => _client.send(
    ApiEndpoints.actOnInsight,
    pathParameters: <String, String>{'id': id},
    body: ActionInput(action: action, snoozeDays: snoozeDays).toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeInsightDto(json).data,
  );

  /// `POST /insights/{id}/feedback`: one answer per insight (sending again
  /// updates it; an empty [note] clears it). Returns the insight with
  /// `my_feedback`.
  Future<InsightDto> feedback(
    String id,
    FeedbackInputFeedback feedback, {
    String? note,
  }) => _client.send(
    ApiEndpoints.insightFeedback,
    pathParameters: <String, String>{'id': id},
    body: FeedbackInput(feedback: feedback, note: note).toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeInsightDto(json).data,
  );

  /// `GET /insights/mutes`: the kinds of insight the user muted, and for
  /// which record (`*` = everywhere).
  Future<List<InsightMuteDto>> mutes() => _client.send(
    ApiEndpoints.listInsightMutes,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListInsightMuteDto(json).data,
  );

  /// `DELETE /insights/mutes?subtype=&scope=`: stops muting and reopens the
  /// insights the rule was hiding.
  Future<UnmuteResult> unmute(String subtype, {String? scope}) => _client.send(
    ApiEndpoints.unmuteInsights,
    query: <String, Object?>{'subtype': subtype, 'scope': scope},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeUnmuteResult(json).data,
  );
}

/// Insight endpoints. Overridden in tests.
final Provider<InsightsApi> insightsApiProvider = Provider<InsightsApi>(
  (Ref ref) => InsightsApi(ref.watch(apiClientProvider)),
);
