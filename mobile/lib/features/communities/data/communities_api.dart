import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for the `Communities` tag and the community-level part of
/// `Moderation`: communities, invitations, posts, comments, polls,
/// reactions, reports and the moderators' queue.
///
/// Community text is plain text (the screens render it escaped); invitation
/// tokens are sent in request bodies only, never in a URL.
class CommunitiesApi {
  /// Creates the API over [client].
  CommunitiesApi(this._client);

  final ApiClient _client;

  /// Posts fetched per page of a feed (the contract caps `limit` at 50).
  static const int postsPageSize = 20;

  // ----------------------------------------------------------- communities

  /// `GET /communities`: discover communities ([q] / [topic]), or the
  /// caller's own with [mine].
  Future<List<CommunityDto>> list({
    String? q,
    String? topic,
    bool mine = false,
  }) => _client.send(
    ApiEndpoints.listCommunities,
    query: <String, Object?>{'q': q, 'topic': topic, if (mine) 'mine': true},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListCommunityDto(json).data,
  );

  /// `POST /communities` (the caller becomes the owner).
  Future<CommunityDto> create(CommunityInput input) => _client.send(
    ApiEndpoints.createCommunity,
    body: input.toJson(),
    decode: _community,
  );

  /// `GET /communities/{ref}` by ID or URL name.
  Future<CommunityDto> get(String ref) => _client.send(
    ApiEndpoints.getCommunity,
    pathParameters: <String, String>{'ref': ref},
    decode: _community,
  );

  /// `PATCH /communities/{id}` with a partial [patch] (`CommunityPatch`
  /// JSON from `partialPatch`; only the fields sent change, `version`
  /// required).
  Future<CommunityDto> update(String id, Map<String, Object?> patch) =>
      _client.send(
        ApiEndpoints.updateCommunity,
        pathParameters: <String, String>{'id': id},
        body: patch,
        decode: _community,
      );

  /// `POST /communities/{id}/archive` (owner).
  Future<CommunityDto> archive(String id) => _client.send(
    ApiEndpoints.archiveCommunity,
    pathParameters: <String, String>{'id': id},
    decode: _community,
  );

  /// `POST /communities/{id}/restore` (owner).
  Future<CommunityDto> restore(String id) => _client.send(
    ApiEndpoints.restoreCommunity,
    pathParameters: <String, String>{'id': id},
    decode: _community,
  );

  /// `POST /communities/{id}/transfer-ownership`.
  Future<CommunityDto> transferOwnership(String id, String userId) =>
      _client.send(
        ApiEndpoints.transferCommunityOwnership,
        pathParameters: <String, String>{'id': id},
        body: CommunityOwnerInput(userId: userId).toJson(),
        decode: _community,
      );

  /// `POST /communities/{id}/join`: joins a public community or asks to
  /// join a private one (`my_status: pending`).
  Future<CommunityDto> join(String id) => _client.send(
    ApiEndpoints.joinCommunity,
    pathParameters: <String, String>{'id': id},
    decode: _community,
  );

  /// `POST /communities/{id}/leave`.
  Future<void> leave(String id) => _client.send(
    ApiEndpoints.leaveCommunity,
    pathParameters: <String, String>{'id': id},
    decode: decodeEnvelopeEmpty,
  );

  // --------------------------------------------------------------- members

  /// `GET /communities/{id}/members` (moderators see everyone; others
  /// see the moderators), optionally one [status].
  Future<List<CommunityMemberDto>> members(String id, {String? status}) =>
      _client.send(
        ApiEndpoints.listCommunityMembers,
        pathParameters: <String, String>{'id': id},
        query: <String, Object?>{'status': status},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeListCommunityMemberDto(json).data,
      );

  /// `PATCH /communities/{id}/members/{userId}`: moderator or member
  /// (owner).
  Future<void> setMemberRole(
    String id,
    String userId,
    CommunityMemberRoleInputRole role,
  ) => _client.send(
    ApiEndpoints.updateCommunityMemberRole,
    pathParameters: <String, String>{'id': id, 'userId': userId},
    body: CommunityMemberRoleInput(role: role).toJson(),
    decode: decodeEnvelopeEmpty,
  );

  /// `POST /communities/{id}/members/{userId}/approve`.
  Future<void> approveMember(String id, String userId) => _client.send(
    ApiEndpoints.approveCommunityMember,
    pathParameters: <String, String>{'id': id, 'userId': userId},
    decode: decodeEnvelopeEmpty,
  );

  /// `POST /communities/{id}/members/{userId}/reject`.
  Future<void> rejectMember(String id, String userId) => _client.send(
    ApiEndpoints.rejectCommunityMember,
    pathParameters: <String, String>{'id': id, 'userId': userId},
    decode: decodeEnvelopeEmpty,
  );

  // ----------------------------------------------------------- invitations

  /// `GET /communities/{id}/invitations` (moderators; tokens are never
  /// shown again).
  Future<List<CommunityInvitationDto>> invitations(
    String id, {
    bool includeInactive = false,
  }) => _client.send(
    ApiEndpoints.listCommunityInvitations,
    pathParameters: <String, String>{'id': id},
    query: <String, Object?>{if (includeInactive) 'include_inactive': true},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListCommunityInvitationDto(json).data,
  );

  /// `POST /communities/{id}/invitations`: a shareable link (no
  /// `username`) or an invitation addressed to one person. The link's
  /// token is in the answer once.
  Future<CommunityInvitationDto> createInvitation(
    String id,
    CommunityInvitationInput input,
  ) => _client.send(
    ApiEndpoints.createCommunityInvitation,
    pathParameters: <String, String>{'id': id},
    body: input.toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeCommunityInvitationDto(json).data,
  );

  /// `DELETE /communities/{id}/invitations/{invitationId}` (409
  /// `invitation_inactive` once used, declined, revoked or expired).
  Future<void> revokeInvitation(String id, String invitationId) => _client.send(
    ApiEndpoints.revokeCommunityInvitation,
    pathParameters: <String, String>{'id': id, 'invitationId': invitationId},
    decode: decodeEnvelopeEmpty,
  );

  /// `GET /community-invitations`: invitations addressed to the caller.
  Future<List<CommunityInvitationDto>> myInvitations() => _client.send(
    ApiEndpoints.myCommunityInvitations,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListCommunityInvitationDto(json).data,
  );

  /// `POST /community-invitations/preview` with the link's [token] (410
  /// for unknown, revoked, used or expired links).
  Future<CommunityInvitationPreview> previewInvitation(String token) =>
      _client.send(
        ApiEndpoints.previewCommunityInvitation,
        body: CommunityTokenInput(token: token).toJson(),
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeCommunityInvitationPreview(json).data,
      );

  /// `POST /community-invitations/accept` with the link's [token]: joins
  /// directly (409 `already_member`, 410 for a dead link).
  Future<CommunityDto> acceptInvitationLink(String token) => _client.send(
    ApiEndpoints.acceptCommunityInvitationLink,
    body: CommunityTokenInput(token: token).toJson(),
    decode: _community,
  );

  /// `POST /community-invitations/{id}/accept` (an invitation addressed to
  /// the caller).
  Future<CommunityDto> acceptInvitation(String id) => _client.send(
    ApiEndpoints.acceptCommunityInvitation,
    pathParameters: <String, String>{'id': id},
    decode: _community,
  );

  /// `POST /community-invitations/{id}/decline` (409 `invitation_used`
  /// the second time).
  Future<void> declineInvitation(String id) => _client.send(
    ApiEndpoints.declineCommunityInvitation,
    pathParameters: <String, String>{'id': id},
    decode: decodeEnvelopeEmpty,
  );

  // ----------------------------------------------------------------- posts

  /// `GET /communities/{id}/posts`: one page of the feed, pinned posts
  /// first. [cursor] continues the same [sort] and [q]; `offset` is never
  /// sent.
  Future<CursorPage<CommunityPostDto>> posts(
    String id, {
    String sort = 'new',
    String? q,
    String? cursor,
    int limit = postsPageSize,
  }) => _client.send(
    ApiEndpoints.listCommunityPosts,
    pathParameters: <String, String>{'id': id},
    query: <String, Object?>{
      'sort': sort,
      'q': q,
      'cursor': cursor,
      'limit': limit,
    },
    decode: (Map<String, Object?> json) {
      final EnvelopeListCommunityPostDto envelope =
          decodeEnvelopeListCommunityPostDto(json);
      final bool more = envelope.meta.hasMore ?? true;
      return CursorPage<CommunityPostDto>(
        envelope.data,
        more ? envelope.meta.nextCursor : null,
      );
    },
  );

  /// `POST /communities/{id}/posts` (members; plain text; daily caps answer
  /// 429 with `daily_cap`).
  Future<CommunityPostDto> createPost(String id, CommunityPostInput input) =>
      _client.send(
        ApiEndpoints.createCommunityPost,
        pathParameters: <String, String>{'id': id},
        body: input.toJson(),
        decode: _post,
      );

  /// `GET /posts/{id}` with its comments.
  Future<CommunityPostDetail> post(String postId) => _client.send(
    ApiEndpoints.getPost,
    pathParameters: <String, String>{'id': postId},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeCommunityPostDetail(json).data,
  );

  /// `PATCH /posts/{id}`: edits the caller's own post.
  Future<CommunityPostDto> updatePost(
    String postId,
    CommunityPostInput input,
  ) => _client.send(
    ApiEndpoints.updatePost,
    pathParameters: <String, String>{'id': postId},
    body: input.toJson(),
    decode: _post,
  );

  /// `DELETE /posts/{id}`: deletes the caller's own post.
  Future<void> deletePost(String postId) => _client.send(
    ApiEndpoints.deletePost,
    pathParameters: <String, String>{'id': postId},
    decode: decodeEnvelopeEmpty,
  );

  /// `POST /posts/{id}/comments`: a comment, or a reply with
  /// `parent_comment_id`.
  Future<CommunityCommentDto> comment(
    String postId,
    CommunityCommentInput input,
  ) => _client.send(
    ApiEndpoints.createComment,
    pathParameters: <String, String>{'id': postId},
    body: input.toJson(),
    decode: _comment,
  );

  /// `PATCH /comments/{id}`: edits the caller's own comment.
  Future<CommunityCommentDto> updateComment(
    String commentId,
    CommunityCommentInput input,
  ) => _client.send(
    ApiEndpoints.updateComment,
    pathParameters: <String, String>{'id': commentId},
    body: input.toJson(),
    decode: _comment,
  );

  /// `DELETE /comments/{id}`: deletes the caller's own comment.
  Future<void> deleteComment(String commentId) => _client.send(
    ApiEndpoints.deleteComment,
    pathParameters: <String, String>{'id': commentId},
    decode: decodeEnvelopeEmpty,
  );

  /// `POST /posts/{id}/poll/votes`: replaces the caller's earlier vote;
  /// the answer carries aggregate results only.
  Future<CommunityPollDto> vote(String postId, List<String> optionIds) =>
      _client.send(
        ApiEndpoints.votePoll,
        pathParameters: <String, String>{'id': postId},
        body: CommunityVoteInput(optionIds: optionIds).toJson(),
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeCommunityPollDto(json).data,
      );

  /// `POST /posts/{id}/reactions`: the counts and the caller's reactions
  /// afterwards (the screen renders exactly this answer).
  Future<CommunityReactionsDto> reactToPost(
    String postId,
    CommunityReactionInputKind kind,
  ) => _client.send(
    ApiEndpoints.addPostReaction,
    pathParameters: <String, String>{'id': postId},
    body: CommunityReactionInput(kind: kind).toJson(),
    decode: _reactions,
  );

  /// `DELETE /posts/{id}/reactions/{kind}`.
  Future<CommunityReactionsDto> unreactPost(
    String postId,
    CommunityReactionInputKind kind,
  ) => _client.send(
    ApiEndpoints.removePostReaction,
    pathParameters: <String, String>{'id': postId, 'kind': kind.json},
    decode: _reactions,
  );

  /// `POST /comments/{id}/reactions`.
  Future<CommunityReactionsDto> reactToComment(
    String commentId,
    CommunityReactionInputKind kind,
  ) => _client.send(
    ApiEndpoints.addCommentReaction,
    pathParameters: <String, String>{'id': commentId},
    body: CommunityReactionInput(kind: kind).toJson(),
    decode: _reactions,
  );

  /// `DELETE /comments/{id}/reactions/{kind}`.
  Future<CommunityReactionsDto> unreactComment(
    String commentId,
    CommunityReactionInputKind kind,
  ) => _client.send(
    ApiEndpoints.removeCommentReaction,
    pathParameters: <String, String>{'id': commentId, 'kind': kind.json},
    decode: _reactions,
  );

  /// `POST /posts/{id}/reports`.
  Future<ModerationReportDto> reportPost(
    String postId,
    PostReportInput input,
  ) => _client.send(
    ApiEndpoints.reportPost,
    pathParameters: <String, String>{'id': postId},
    body: input.toJson(),
    decode: _report,
  );

  // ------------------------------------------------- community moderation

  /// `GET /communities/{id}/moderation/reports` (moderators), optionally
  /// one [status].
  Future<List<ModerationReportDto>> moderationReports(
    String id, {
    String? status,
  }) => _client.send(
    ApiEndpoints.communityModerationReports,
    pathParameters: <String, String>{'id': id},
    query: <String, Object?>{'status': status},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListModerationReportDto(json).data,
  );

  /// `POST /communities/{id}/moderation/actions` (moderators; audited).
  Future<ModerationActionDto> moderate(
    String id,
    ModerationActionInput input,
  ) => _client.send(
    ApiEndpoints.communityModerationAct,
    pathParameters: <String, String>{'id': id},
    body: input.toJson(),
    decode: _action,
  );

  /// `GET /communities/{id}/moderation/appeals`: open appeals.
  Future<List<ModerationAppealDto>> moderationAppeals(String id) =>
      _client.send(
        ApiEndpoints.communityModerationAppeals,
        pathParameters: <String, String>{'id': id},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeListModerationAppealDto(json).data,
      );

  /// `GET /communities/{id}/moderation/actions`: the moderation log.
  Future<List<ModerationActionDto>> moderationLog(String id) => _client.send(
    ApiEndpoints.communityModerationLog,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListModerationActionDto(json).data,
  );

  /// `POST /moderation/actions/{id}/reverse` (the community's moderators;
  /// the record is kept).
  Future<ModerationActionDto> reverseAction(String actionId, {String? note}) =>
      _client.send(
        ApiEndpoints.reverseModerationAction,
        pathParameters: <String, String>{'id': actionId},
        body: ModerationReverseInput(note: note).toJson(),
        decode: _action,
      );

  /// `POST /moderation/appeals/{id}/decide`: uphold or overturn (another
  /// moderator; overturning reverses the action).
  Future<ModerationAppealDto> decideAppeal(
    String appealId,
    AppealDecisionInput input,
  ) => _client.send(
    ApiEndpoints.decideModerationAppeal,
    pathParameters: <String, String>{'id': appealId},
    body: input.toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeModerationAppealDto(json).data,
  );

  static CommunityDto _community(Map<String, Object?> json) =>
      decodeEnvelopeCommunityDto(json).data;

  static CommunityPostDto _post(Map<String, Object?> json) =>
      decodeEnvelopeCommunityPostDto(json).data;

  static CommunityCommentDto _comment(Map<String, Object?> json) =>
      decodeEnvelopeCommunityCommentDto(json).data;

  static CommunityReactionsDto _reactions(Map<String, Object?> json) =>
      decodeEnvelopeCommunityReactionsDto(json).data;

  static ModerationReportDto _report(Map<String, Object?> json) =>
      decodeEnvelopeModerationReportDto(json).data;

  static ModerationActionDto _action(Map<String, Object?> json) =>
      decodeEnvelopeModerationActionDto(json).data;
}

/// Communities endpoints. Overridden in tests.
final Provider<CommunitiesApi> communitiesApiProvider =
    Provider<CommunitiesApi>(
      (Ref ref) => CommunitiesApi(ref.watch(apiClientProvider)),
    );
