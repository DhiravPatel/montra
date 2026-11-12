import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// What accepting an invitation link led to: the group was joined, or the
/// group requires approval and a join request now waits for its admins.
@immutable
sealed class JoinOutcome {
  const JoinOutcome();
}

/// `200`: the user is a member now.
final class Joined extends JoinOutcome {
  /// Creates the outcome.
  const Joined(this.group);

  /// The group joined.
  final GroupDetail group;
}

/// `202`: a join request waits for the admins.
final class JoinPending extends JoinOutcome {
  /// Creates the outcome.
  const JoinPending(this.request);

  /// The pending request (carries `invitation_id`).
  final GroupJoinRequestDto request;
}

/// Typed calls for the `Groups` tag: groups, members, invitations, join
/// requests, activity and balances. Group money (expenses, settlements,
/// recurring expenses, reports) has its own API.
///
/// Non-members get `404` for every group resource. Invitation tokens
/// travel in request bodies only and are never logged.
class GroupsApi {
  /// Creates the API over [client].
  GroupsApi(this._client);

  final ApiClient _client;

  /// `GET /groups` (archived ones too when [includeArchived]); every group
  /// carries `my_net`, the user's balance in the group currency.
  Future<List<GroupDto>> list({bool includeArchived = false}) => _client.send(
    ApiEndpoints.listGroups,
    query: <String, Object?>{if (includeArchived) 'include_archived': true},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListGroupDto(json).data,
  );

  /// `GET /groups/{id}` with its members.
  Future<GroupDetail> get(String id) => _client.send(
    ApiEndpoints.getGroup,
    pathParameters: <String, String>{'id': id},
    decode: _detail,
  );

  /// `POST /groups` (`201`).
  Future<GroupDetail> create(GroupInput input) => _client.send(
    ApiEndpoints.createGroup,
    body: input.toJson(),
    decode: _detail,
  );

  /// `PATCH /groups/{id}`: only the fields of [patch] change (`""` clears
  /// text and dates); `version` is required.
  Future<GroupDetail> update(String id, Map<String, Object?> patch) =>
      _client.send(
        ApiEndpoints.updateGroup,
        pathParameters: <String, String>{'id': id},
        body: patch,
        decode: _detail,
      );

  /// `DELETE /groups/{id}?confirm=true`: needs settled balances
  /// (422 `balances_open`); revokes open invitations.
  Future<GroupDto> delete(String id) => _client.send(
    ApiEndpoints.deleteGroup,
    pathParameters: <String, String>{'id': id},
    query: const <String, Object?>{'confirm': true},
    decode: _dto,
  );

  /// `POST /groups/{id}/archive` (409 `group_archived` when it already is).
  Future<GroupDto> archive(String id) =>
      _lifecycle(ApiEndpoints.archiveGroup, id);

  /// `POST /groups/{id}/restore` (409 `group_not_archived`).
  Future<GroupDto> restore(String id) =>
      _lifecycle(ApiEndpoints.restoreGroup, id);

  Future<GroupDto> _lifecycle(ApiEndpoint endpoint, String id) => _client.send(
    endpoint,
    pathParameters: <String, String>{'id': id},
    decode: _dto,
  );

  /// `POST /groups/{id}/transfer-ownership`.
  Future<GroupDetail> transferOwnership(String id, String userId) =>
      _client.send(
        ApiEndpoints.transferGroupOwnership,
        pathParameters: <String, String>{'id': id},
        body: TransferOwnershipInput(userId: userId).toJson(),
        decode: _detail,
      );

  /// `GET /groups/{id}/activity[?before=]`: typed events, newest first;
  /// pass the page's `nextBefore` for the next page.
  Future<GroupActivityPage> activity(String id, {int? before}) => _client.send(
    ApiEndpoints.groupActivity,
    pathParameters: <String, String>{'id': id},
    query: <String, Object?>{'before': before},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeGroupActivityPage(json).data,
  );

  /// `GET /groups/{id}/balances`.
  Future<GroupBalancesDto> balances(String id) => _client.send(
    ApiEndpoints.groupBalances,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeGroupBalancesDto(json).data,
  );

  // Members.

  /// `POST /groups/{id}/members`: a username invitation to one person
  /// (`username` of someone discoverable, or the `user_id` of a friend).
  Future<GroupInvitationDto> addMember(String id, AddMemberInput input) =>
      _client.send(
        ApiEndpoints.addGroupMember,
        pathParameters: <String, String>{'id': id},
        body: input.toJson(),
        decode: _invitation,
      );

  /// `PATCH /groups/{id}/members/{userId}`: role or notification level.
  Future<GroupDetail> updateMember(
    String id,
    String userId,
    GroupMemberUpdate update,
  ) => _client.send(
    ApiEndpoints.updateGroupMember,
    pathParameters: <String, String>{'id': id, 'userId': userId},
    body: update.toJson(),
    decode: _detail,
  );

  /// `DELETE /groups/{id}/members/{userId}`: removes a member (admins; an
  /// open balance is allowed and keeps counting) or leaves the group when
  /// [userId] is the caller (422 `balance_open`, `transfer_ownership_first`).
  Future<void> removeMember(String id, String userId) => _client.send(
    ApiEndpoints.removeGroupMember,
    pathParameters: <String, String>{'id': id, 'userId': userId},
    decode: decodeEnvelopeEmpty,
  );

  // Invitations.

  /// `GET /groups/{id}/invitations` (active ones unless [includeInactive]).
  Future<List<GroupInvitationDto>> invitations(
    String id, {
    bool includeInactive = false,
  }) => _client.send(
    ApiEndpoints.listGroupInvitations,
    pathParameters: <String, String>{'id': id},
    query: <String, Object?>{if (includeInactive) 'include_inactive': true},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListGroupInvitationDto(json).data,
  );

  /// `POST /groups/{id}/invitations` (`201`): a shareable link (its
  /// `token` is returned once) or a username invitation.
  Future<GroupInvitationDto> createInvitation(
    String id,
    GroupInvitationInput input,
  ) => _client.send(
    ApiEndpoints.createGroupInvitation,
    pathParameters: <String, String>{'id': id},
    body: input.toJson(),
    decode: _invitation,
  );

  /// `DELETE /groups/{id}/invitations/{invitationId}` (409
  /// `invitation_used` once accepted or declined).
  Future<void> revokeInvitation(String id, String invitationId) => _client.send(
    ApiEndpoints.revokeGroupInvitation,
    pathParameters: <String, String>{'id': id, 'invitationId': invitationId},
    decode: decodeEnvelopeEmpty,
  );

  /// `GET /group-invitations`: username invitations addressed to the user.
  Future<List<GroupInvitationDto>> myInvitations() => _client.send(
    ApiEndpoints.myGroupInvitations,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListGroupInvitationDto(json).data,
  );

  /// `POST /group-invitations/preview {token}`: what a link leads to
  /// (`410` for unknown, used-up or expired links).
  Future<GroupInvitationPreview> previewInvitation(String token) =>
      _client.send(
        ApiEndpoints.previewGroupInvitation,
        body: InvitationTokenInput(token: token).toJson(),
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeGroupInvitationPreview(json).data,
      );

  /// `POST /group-invitations/accept {token}`: `200` with the group, or
  /// `202` with a pending join request when the group requires approval.
  /// The two answers are told apart by their shape (a group lists its
  /// `members`; a join request has none).
  Future<JoinOutcome> acceptInvitationLink(String token) => _client.send(
    ApiEndpoints.acceptGroupInvitationLink,
    body: InvitationTokenInput(token: token).toJson(),
    decode: (Map<String, Object?> json) {
      final Object? data = json['data'];
      if (data is Map<String, Object?> && data['members'] is List<Object?>) {
        return Joined(_detail(json));
      }
      return JoinPending(decodeEnvelopeGroupJoinRequestDto(json).data);
    },
  );

  /// `POST /group-invitations/{invitationId}/accept`: a username
  /// invitation always joins directly.
  Future<GroupDetail> acceptInvitation(String invitationId) => _client.send(
    ApiEndpoints.acceptGroupInvitation,
    pathParameters: <String, String>{'invitationId': invitationId},
    decode: _detail,
  );

  /// `POST /group-invitations/{invitationId}/decline`.
  Future<void> declineInvitation(String invitationId) => _client.send(
    ApiEndpoints.declineGroupInvitation,
    pathParameters: <String, String>{'invitationId': invitationId},
    decode: decodeEnvelopeEmpty,
  );

  // Join requests.

  /// `GET /groups/{id}/join-requests` (admins).
  Future<List<GroupJoinRequestDto>> joinRequests(String id) => _client.send(
    ApiEndpoints.listGroupJoinRequests,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListGroupJoinRequestDto(json).data,
  );

  /// `POST /groups/{id}/join-requests` (`201`): asks to join a group that
  /// requires approval (409 `already_member` / `join_request_pending`).
  Future<GroupJoinRequestDto> createJoinRequest(String id, {String? message}) =>
      _client.send(
        ApiEndpoints.createGroupJoinRequest,
        pathParameters: <String, String>{'id': id},
        body: JoinRequestInput(message: message).toJson(),
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeGroupJoinRequestDto(json).data,
      );

  /// `POST /groups/{id}/join-requests/{requestId}/approve`.
  Future<GroupDetail> approveJoinRequest(String id, String requestId) =>
      _joinRequestAction(ApiEndpoints.approveGroupJoinRequest, id, requestId);

  /// `POST /groups/{id}/join-requests/{requestId}/decline`.
  Future<GroupDetail> declineJoinRequest(String id, String requestId) =>
      _joinRequestAction(ApiEndpoints.declineGroupJoinRequest, id, requestId);

  Future<GroupDetail> _joinRequestAction(
    ApiEndpoint endpoint,
    String id,
    String requestId,
  ) => _client.send(
    endpoint,
    pathParameters: <String, String>{'id': id, 'requestId': requestId},
    decode: _detail,
  );

  static GroupDetail _detail(Map<String, Object?> json) =>
      decodeEnvelopeGroupDetail(json).data;

  static GroupDto _dto(Map<String, Object?> json) =>
      decodeEnvelopeGroupDto(json).data;

  static GroupInvitationDto _invitation(Map<String, Object?> json) =>
      decodeEnvelopeGroupInvitationDto(json).data;
}

/// Group endpoints. Overridden in tests.
final Provider<GroupsApi> groupsApiProvider = Provider<GroupsApi>(
  (Ref ref) => GroupsApi(ref.watch(apiClientProvider)),
);
