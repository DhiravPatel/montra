import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for the `Social` tag and the profile (`GET`/`PATCH /me`):
/// connections, friend requests, exact-username search, blocks and mutes,
/// and the privacy settings behind them.
///
/// People are found by their whole username only (docs/API.md "Social and
/// groups notes"); a blocked person looks absent (404) to both sides, and
/// being blocked is never disclosed.
class SocialApi {
  /// Creates the API over [client].
  SocialApi(this._client);

  final ApiClient _client;

  /// Rows fetched per page of the blocks and mutes lists.
  static const int pageSize = 50;

  /// `GET /connections`: the user's connections (friends and pending
  /// requests, as `connection` says).
  Future<List<PublicProfile>> connections() => _client.send(
    ApiEndpoints.listFriends,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListPublicProfile(json).data,
  );

  /// `GET /users/search?q=`: at most one person, whose whole username is
  /// [username] (case-insensitive, a leading `@` ignored) and who opted
  /// into username discovery.
  Future<List<PublicProfile>> searchUsername(String username) => _client.send(
    ApiEndpoints.searchUsers,
    query: <String, Object?>{'q': normalizeUsername(username)},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListPublicProfile(json).data,
  );

  /// `GET /friend-requests`: incoming and outgoing requests.
  Future<List<FriendRequestDto>> friendRequests() => _client.send(
    ApiEndpoints.listFriendRequests,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListFriendRequestDto(json).data,
  );

  /// `POST /friend-requests` to [userId] (`201`). When that person had
  /// already asked, their request is accepted instead and the result's
  /// status is `accepted`. 409 `already_friends` / `request_pending`; 422
  /// `requests_closed`.
  Future<FriendRequestDto> sendFriendRequest(
    String userId, {
    String? message,
  }) => _client.send(
    ApiEndpoints.sendFriendRequest,
    body: SendInput(userId: userId, message: message).toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeFriendRequestDto(json).data,
  );

  /// `POST /friend-requests/{id}/accept`.
  Future<FriendRequestDto> acceptFriendRequest(String id) =>
      _requestAction(ApiEndpoints.acceptFriendRequest, id);

  /// `POST /friend-requests/{id}/decline`.
  Future<FriendRequestDto> declineFriendRequest(String id) =>
      _requestAction(ApiEndpoints.declineFriendRequest, id);

  /// `POST /friend-requests/{id}/cancel` (a request the user sent).
  Future<FriendRequestDto> cancelFriendRequest(String id) =>
      _requestAction(ApiEndpoints.cancelFriendRequest, id);

  Future<FriendRequestDto> _requestAction(ApiEndpoint endpoint, String id) =>
      _client.send(
        endpoint,
        pathParameters: <String, String>{'id': id},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeFriendRequestDto(json).data,
      );

  /// `DELETE /connections/{userId}`: ends the friendship.
  Future<void> removeFriend(String userId) => _client.send(
    ApiEndpoints.removeFriend,
    pathParameters: <String, String>{'userId': userId},
    decode: decodeEnvelopeEmpty,
  );

  /// `POST /users/{userId}/block`.
  Future<void> block(String userId) => _client.send(
    ApiEndpoints.blockUser,
    pathParameters: <String, String>{'userId': userId},
    decode: decodeEnvelopeEmpty,
  );

  /// `DELETE /users/{userId}/block`.
  Future<void> unblock(String userId) => _client.send(
    ApiEndpoints.unblockUser,
    pathParameters: <String, String>{'userId': userId},
    decode: decodeEnvelopeEmpty,
  );

  /// `POST /users/{userId}/mute {"muted": …}`: mutes or unmutes.
  Future<void> setMuted(String userId, {required bool muted}) => _client.send(
    ApiEndpoints.muteUser,
    pathParameters: <String, String>{'userId': userId},
    body: MuteInput(muted: muted).toJson(),
    decode: decodeEnvelopeEmpty,
  );

  /// `GET /blocks`: one page of the people the user blocked, newest first.
  Future<CursorPage<BlockDto>> blocks({String? cursor, int limit = pageSize}) =>
      _client.send(
        ApiEndpoints.listBlocks,
        query: <String, Object?>{'cursor': cursor, 'limit': limit},
        decode: (Map<String, Object?> json) {
          final EnvelopeListBlockDto envelope = decodeEnvelopeListBlockDto(
            json,
          );
          return CursorPage<BlockDto>(envelope.data, _next(envelope.meta));
        },
      );

  /// `GET /mutes`: one page of the people the user muted, newest first.
  Future<CursorPage<MuteDto>> mutes({String? cursor, int limit = pageSize}) =>
      _client.send(
        ApiEndpoints.listMutes,
        query: <String, Object?>{'cursor': cursor, 'limit': limit},
        decode: (Map<String, Object?> json) {
          final EnvelopeListMuteDto envelope = decodeEnvelopeListMuteDto(json);
          return CursorPage<MuteDto>(envelope.data, _next(envelope.meta));
        },
      );

  /// `GET /me`: account, profile (username and privacy settings) and
  /// preferences.
  Future<MeDto> me() => _client.send(
    ApiEndpoints.getMe,
    decode: (Map<String, Object?> json) => decodeEnvelopeMeDto(json).data,
  );

  /// `PATCH /me`: changes only the profile fields sent (`username: ""`
  /// clears the username; a leading `@` is ignored by the server).
  Future<ProfileDto> updateProfile(ProfilePatch patch) => _client.send(
    ApiEndpoints.updateProfile,
    body: patch.toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeProfileDto(json).data,
  );

  static String? _next(Meta meta) {
    final bool more = meta.hasMore ?? true;
    return more ? meta.nextCursor : null;
  }
}

/// A username as the server reads it: trimmed, without a leading `@`.
String normalizeUsername(String input) {
  final String trimmed = input.trim();
  return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
}

/// Social endpoints. Overridden in tests.
final Provider<SocialApi> socialApiProvider = Provider<SocialApi>(
  (Ref ref) => SocialApi(ref.watch(apiClientProvider)),
);
