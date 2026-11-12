import { keepPreviousData, useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { compactQuery } from '@/shared/api/query';
import { apiData, apiEnvelope } from '@/shared/api/request';
import { type CommunityListQuery, type FeedQuery, communitiesKeys } from './keys';
import type {
  Appeal,
  AppealDecision,
  Community,
  CommunityInput,
  CommunityInvitation,
  CommunityInvitationInput,
  CommunityInvitationPreview,
  CommunityMember,
  CommunityPatch,
  CommunityReactions,
  ContentTarget,
  FeedPage,
  MemberStatus,
  ModerationAction,
  ModerationActionInput,
  Poll,
  Post,
  PostComment,
  PostDetail,
  PostInput,
  ReactionKind,
  Report,
  ReportFilter,
  ReportReason,
} from './types';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

function byId(id: string) {
  return { params: { path: { id } } };
}

/** Posts requested per feed page (the API allows up to 50). */
export const FEED_PAGE_SIZE = 20;

/**
 * Communities (spec §4.16). Content is plain text that the API has already
 * cleaned; it is rendered as text, never as HTML. Invitation link tokens
 * travel only in request bodies.
 */
export const communitiesApi = {
  list: (query: CommunityListQuery, signal?: AbortSignal): Promise<Community[]> =>
    apiData(
      api.GET('/communities', {
        params: {
          query: compactQuery({
            q: query.q.trim(),
            topic: query.topic.trim().toLowerCase(),
            mine: query.mine || undefined,
          }),
        },
        ...signalOption(signal),
      }),
    ),
  /** By ID or URL name; invitation-only communities answer 404 to non-members. */
  get: (ref: string, signal?: AbortSignal): Promise<Community> =>
    apiData(api.GET('/communities/{ref}', { params: { path: { ref } }, ...signalOption(signal) })),
  create: (body: CommunityInput): Promise<Community> => apiData(api.POST('/communities', { body })),
  /**
   * Changes only the fields sent (`""` clears the description or rules;
   * `topics` replaces the list) and needs the current `version`: a stale
   * one answers 409 VERSION_CONFLICT.
   */
  update: (id: string, body: CommunityPatch): Promise<Community> =>
    apiData(api.PATCH('/communities/{id}', { ...byId(id), body })),
  archive: (id: string): Promise<Community> =>
    apiData(api.POST('/communities/{id}/archive', byId(id))),
  restore: (id: string): Promise<Community> =>
    apiData(api.POST('/communities/{id}/restore', byId(id))),
  /** Joins a public community, or asks to join a private one (`my_status: pending`). */
  join: (id: string): Promise<Community> => apiData(api.POST('/communities/{id}/join', byId(id))),
  /** Leaves, or withdraws a pending request. */
  leave: (id: string) => apiData(api.POST('/communities/{id}/leave', byId(id))),

  /** Moderators see everyone; others see the owner and moderators. */
  members: (
    id: string,
    status: MemberStatus | '',
    signal?: AbortSignal,
  ): Promise<CommunityMember[]> =>
    apiData(
      api.GET('/communities/{id}/members', {
        params: { path: { id }, query: status ? { status } : {} },
        ...signalOption(signal),
      }),
    ),
  setRole: (id: string, userId: string, role: 'moderator' | 'member') =>
    apiData(
      api.PATCH('/communities/{id}/members/{userId}', {
        params: { path: { id, userId } },
        body: { role },
      }),
    ),
  decideMember: (id: string, userId: string, approve: boolean) => {
    const options = { params: { path: { id, userId } } };
    return approve
      ? apiData(api.POST('/communities/{id}/members/{userId}/approve', options))
      : apiData(api.POST('/communities/{id}/members/{userId}/reject', options));
  },
  transferOwnership: (id: string, userId: string): Promise<Community> =>
    apiData(
      api.POST('/communities/{id}/transfer-ownership', { ...byId(id), body: { user_id: userId } }),
    ),

  /** A link invitation's one-time `token` is in this response only. */
  createInvitation: (id: string, body: CommunityInvitationInput): Promise<CommunityInvitation> =>
    apiData(api.POST('/communities/{id}/invitations', { ...byId(id), body })),
  /** The community's invitations (moderators): active ones, or every status; tokens are never repeated. */
  invitations: (
    id: string,
    includeInactive: boolean,
    signal?: AbortSignal,
  ): Promise<CommunityInvitation[]> =>
    apiData(
      api.GET('/communities/{id}/invitations', {
        params: { path: { id }, query: includeInactive ? { include_inactive: true } : {} },
        ...signalOption(signal),
      }),
    ),
  /** Withdraws an invitation; 409 `invitation_inactive` once used, declined, revoked or expired. */
  revokeInvitation: (id: string, invitationId: string) =>
    apiData(
      api.DELETE('/communities/{id}/invitations/{invitationId}', {
        params: { path: { id, invitationId } },
      }),
    ),
  invitationsToMe: (signal?: AbortSignal): Promise<CommunityInvitation[]> =>
    apiData(api.GET('/community-invitations', signalOption(signal))),
  acceptInvitation: (invitationId: string): Promise<Community> =>
    apiData(api.POST('/community-invitations/{id}/accept', byId(invitationId))),
  /** Declines a username invitation; declining twice answers 409 `invitation_used`. */
  declineInvitation: (invitationId: string) =>
    apiData(api.POST('/community-invitations/{id}/decline', byId(invitationId))),
  /** What a link is for, before joining (the token stays in the body; 410 for unknown links). */
  previewLink: (token: string): Promise<CommunityInvitationPreview> =>
    apiData(api.POST('/community-invitations/preview', { body: { token } })),
  acceptLink: (token: string): Promise<Community> =>
    apiData(api.POST('/community-invitations/accept', { body: { token } })),

  /** One feed page, pinned posts first; `cursor` continues the previous page of the same sort and query. */
  feed: async (
    communityId: string,
    query: FeedQuery & { limit: number; cursor: string | null },
    signal?: AbortSignal,
  ): Promise<FeedPage> => {
    const envelope = await apiEnvelope(
      api.GET('/communities/{id}/posts', {
        params: {
          path: { id: communityId },
          query: compactQuery({
            sort: query.sort,
            q: query.q.trim(),
            limit: query.limit,
            cursor: query.cursor ?? undefined,
          }),
        },
        ...signalOption(signal),
      }),
    );
    const more = envelope.meta.has_more ?? Boolean(envelope.meta.next_cursor);
    return {
      items: envelope.data,
      nextCursor: more && envelope.meta.next_cursor ? envelope.meta.next_cursor : null,
    };
  },
  createPost: (communityId: string, body: PostInput): Promise<Post> =>
    apiData(api.POST('/communities/{id}/posts', { ...byId(communityId), body })),
  post: (id: string, signal?: AbortSignal): Promise<PostDetail> =>
    apiData(api.GET('/posts/{id}', { ...byId(id), ...signalOption(signal) })),
  updatePost: (id: string, body: PostInput): Promise<Post> =>
    apiData(api.PATCH('/posts/{id}', { ...byId(id), body })),
  deletePost: (id: string) => apiData(api.DELETE('/posts/{id}', byId(id))),

  addComment: (postId: string, body: string, parentCommentId?: string): Promise<PostComment> =>
    apiData(
      api.POST('/posts/{id}/comments', {
        ...byId(postId),
        body: parentCommentId ? { body, parent_comment_id: parentCommentId } : { body },
      }),
    ),
  updateComment: (id: string, body: string): Promise<PostComment> =>
    apiData(api.PATCH('/comments/{id}', { ...byId(id), body: { body } })),
  deleteComment: (id: string) => apiData(api.DELETE('/comments/{id}', byId(id))),

  /** Adds (`on`) or removes the caller's reaction; answers the counts plus the caller's reactions. */
  react: (
    target: ContentTarget,
    id: string,
    kind: ReactionKind,
    on: boolean,
  ): Promise<CommunityReactions> => {
    if (target === 'post') {
      return on
        ? apiData(api.POST('/posts/{id}/reactions', { ...byId(id), body: { kind } }))
        : apiData(api.DELETE('/posts/{id}/reactions/{kind}', { params: { path: { id, kind } } }));
    }
    return on
      ? apiData(api.POST('/comments/{id}/reactions', { ...byId(id), body: { kind } }))
      : apiData(api.DELETE('/comments/{id}/reactions/{kind}', { params: { path: { id, kind } } }));
  },
  /** Replaces the caller's earlier vote; results are aggregate only. */
  vote: (postId: string, optionIds: string[]): Promise<Poll> =>
    apiData(
      api.POST('/posts/{id}/poll/votes', { ...byId(postId), body: { option_ids: optionIds } }),
    ),

  report: (
    target: ContentTarget,
    id: string,
    reason: ReportReason,
    details: string,
  ): Promise<Report> => {
    const extra = details ? { details } : {};
    return target === 'post'
      ? apiData(api.POST('/posts/{id}/reports', { ...byId(id), body: { reason, ...extra } }))
      : apiData(
          api.POST('/content-reports', {
            body: { target_type: target, target_id: id, reason, ...extra },
          }),
        );
  },

  reports: (communityId: string, status: ReportFilter, signal?: AbortSignal): Promise<Report[]> =>
    apiData(
      api.GET('/communities/{id}/moderation/reports', {
        params: { path: { id: communityId }, query: { status } },
        ...signalOption(signal),
      }),
    ),
  actions: (communityId: string, signal?: AbortSignal): Promise<ModerationAction[]> =>
    apiData(
      api.GET('/communities/{id}/moderation/actions', {
        ...byId(communityId),
        ...signalOption(signal),
      }),
    ),
  act: (communityId: string, body: ModerationActionInput): Promise<ModerationAction> =>
    apiData(api.POST('/communities/{id}/moderation/actions', { ...byId(communityId), body })),
  appeals: (communityId: string, signal?: AbortSignal): Promise<Appeal[]> =>
    apiData(
      api.GET('/communities/{id}/moderation/appeals', {
        ...byId(communityId),
        ...signalOption(signal),
      }),
    ),
  /** Undoes an action; the record stays in the log with `reversed_at`. */
  reverseAction: (actionId: string, note: string): Promise<ModerationAction> =>
    apiData(
      api.POST('/moderation/actions/{id}/reverse', {
        ...byId(actionId),
        body: note ? { note } : {},
      }),
    ),
  /** Overturning reverses the action. Another moderator decides appeals against yours. */
  decideAppeal: (appealId: string, decision: AppealDecision, note: string): Promise<Appeal> =>
    apiData(
      api.POST('/moderation/appeals/{id}/decide', {
        ...byId(appealId),
        body: note ? { decision, note } : { decision },
      }),
    ),
};

export function useCommunityList(query: CommunityListQuery) {
  return useQuery({
    queryKey: communitiesKeys.list(query),
    queryFn: ({ signal }) => communitiesApi.list(query, signal),
    placeholderData: keepPreviousData,
  });
}

export function useInvitationsToMe() {
  return useQuery({
    queryKey: communitiesKeys.invitationsToMe(),
    queryFn: ({ signal }) => communitiesApi.invitationsToMe(signal),
  });
}

export function useCommunity(ref: string) {
  return useQuery({
    queryKey: communitiesKeys.community(ref),
    queryFn: ({ signal }) => communitiesApi.get(ref, signal),
    enabled: Boolean(ref),
  });
}

export function useCommunityMembers(id: string, status: MemberStatus | '', enabled = true) {
  return useQuery({
    queryKey: communitiesKeys.members(id, status),
    queryFn: ({ signal }) => communitiesApi.members(id, status, signal),
    enabled: enabled && Boolean(id),
  });
}

/** The invitations moderators manage (active ones, or every status). */
export function useCommunityInvitations(id: string, includeInactive: boolean, enabled = true) {
  return useQuery({
    queryKey: communitiesKeys.invitations(id, includeInactive),
    queryFn: ({ signal }) => communitiesApi.invitations(id, includeInactive, signal),
    placeholderData: keepPreviousData,
    enabled: enabled && Boolean(id),
  });
}

/** Feed pages by cursor: "Show more" appears while the API reports more posts. */
export function useCommunityFeed(communityId: string, query: FeedQuery, enabled = true) {
  return useInfiniteQuery({
    queryKey: communitiesKeys.feed(communityId, query),
    queryFn: ({ pageParam, signal }) =>
      communitiesApi.feed(
        communityId,
        { ...query, limit: FEED_PAGE_SIZE, cursor: pageParam },
        signal,
      ),
    initialPageParam: null as string | null,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
    enabled: enabled && Boolean(communityId),
  });
}

export function usePost(id: string) {
  return useQuery({
    queryKey: communitiesKeys.post(id),
    queryFn: ({ signal }) => communitiesApi.post(id, signal),
    enabled: Boolean(id),
  });
}

export function useModerationReports(communityId: string, status: ReportFilter) {
  return useQuery({
    queryKey: communitiesKeys.reports(communityId, status),
    queryFn: ({ signal }) => communitiesApi.reports(communityId, status, signal),
    placeholderData: keepPreviousData,
  });
}

export function useModerationActions(communityId: string) {
  return useQuery({
    queryKey: communitiesKeys.actions(communityId),
    queryFn: ({ signal }) => communitiesApi.actions(communityId, signal),
  });
}

export function useModerationAppeals(communityId: string) {
  return useQuery({
    queryKey: communitiesKeys.appeals(communityId),
    queryFn: ({ signal }) => communitiesApi.appeals(communityId, signal),
  });
}
