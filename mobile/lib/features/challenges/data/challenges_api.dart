import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for the `Challenges` tag: shared goals with daily check-ins
/// whose progress stays private unless the participant shares it.
class ChallengesApi {
  /// Creates the API over [client].
  ChallengesApi(this._client);

  final ApiClient _client;

  /// Challenges fetched per page (the contract's default).
  static const int pageSize = 50;

  /// `GET /challenges`: one page (`scope` `mine` or `discover`, or every
  /// visible challenge when null), optionally for one group or community.
  Future<CursorPage<ChallengeDto>> list({
    String? scope,
    String? groupId,
    String? communityId,
    String? cursor,
    int limit = pageSize,
  }) => _client.send(
    ApiEndpoints.listChallenges,
    query: <String, Object?>{
      'scope': scope,
      'group_id': groupId,
      'community_id': communityId,
      'cursor': cursor,
      'limit': limit,
    },
    decode: (Map<String, Object?> json) {
      final EnvelopeListChallengeDto envelope = decodeEnvelopeListChallengeDto(
        json,
      );
      final bool more = envelope.meta.hasMore ?? true;
      return CursorPage<ChallengeDto>(
        envelope.data,
        more ? envelope.meta.nextCursor : null,
      );
    },
  );

  /// `POST /challenges` (10 a day; 429 `daily_cap`).
  Future<ChallengeDto> create(ChallengeInput input) => _client.send(
    ApiEndpoints.createChallenge,
    body: input.toJson(),
    decode: _challenge,
  );

  /// `GET /challenges/{id}` with the caller's participation.
  Future<ChallengeDto> get(String id) => _client.send(
    ApiEndpoints.getChallenge,
    pathParameters: <String, String>{'id': id},
    decode: _challenge,
  );

  /// `PATCH /challenges/{id}` with a partial [patch] (`ChallengePatch`
  /// JSON from `partialPatch`; `version` required).
  Future<ChallengeDto> update(String id, Map<String, Object?> patch) =>
      _client.send(
        ApiEndpoints.updateChallenge,
        pathParameters: <String, String>{'id': id},
        body: patch,
        decode: _challenge,
      );

  /// `POST /challenges/{id}/cancel` (the creator or the community's
  /// moderators).
  Future<ChallengeDto> cancel(String id) => _client.send(
    ApiEndpoints.cancelChallenge,
    pathParameters: <String, String>{'id': id},
    decode: _challenge,
  );

  /// `POST /challenges/{id}/join`.
  Future<ChallengeDto> join(String id, ChallengeJoinInput input) =>
      _client.send(
        ApiEndpoints.joinChallenge,
        pathParameters: <String, String>{'id': id},
        body: input.toJson(),
        decode: _challenge,
      );

  /// `POST /challenges/{id}/leave`.
  Future<void> leave(String id) => _client.send(
    ApiEndpoints.leaveChallenge,
    pathParameters: <String, String>{'id': id},
    decode: decodeEnvelopeEmpty,
  );

  /// `PATCH /challenges/{id}/participation`: what the caller shares.
  Future<ChallengeDto> updateParticipation(
    String id,
    ChallengeJoinInput input,
  ) => _client.send(
    ApiEndpoints.updateChallengeParticipation,
    pathParameters: <String, String>{'id': id},
    body: input.toJson(),
    decode: _challenge,
  );

  /// `POST /challenges/{id}/progress`: a check-in for one day (sending
  /// the same day again corrects it).
  Future<ChallengeDto> recordProgress(
    String id,
    ChallengeProgressInput input,
  ) => _client.send(
    ApiEndpoints.recordChallengeProgress,
    pathParameters: <String, String>{'id': id},
    body: input.toJson(),
    decode: _challenge,
  );

  /// `GET /challenges/{id}/leaderboard`: participants who chose to appear
  /// (422 `leaderboard_opt_in_required` unless the caller appears too).
  Future<List<ChallengeLeaderboardEntry>> leaderboard(String id) =>
      _client.send(
        ApiEndpoints.challengeLeaderboard,
        pathParameters: <String, String>{'id': id},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeListChallengeLeaderboardEntry(json).data,
      );

  static ChallengeDto _challenge(Map<String, Object?> json) =>
      decodeEnvelopeChallengeDto(json).data;
}

/// Challenges endpoints. Overridden in tests.
final Provider<ChallengesApi> challengesApiProvider = Provider<ChallengesApi>(
  (Ref ref) => ChallengesApi(ref.watch(apiClientProvider)),
);
