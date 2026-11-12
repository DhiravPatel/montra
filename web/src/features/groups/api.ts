import { useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData, apiEnvelope } from '@/shared/api/request';
import { groupsKeys } from './keys';
import type {
  AcceptLinkResult,
  AddMemberInput,
  Group,
  GroupActivityPage,
  GroupBalances,
  GroupDetail,
  GroupInput,
  GroupInvitation,
  GroupInvitationInput,
  GroupMemberUpdate,
  GroupPatch,
  InvitationPreview,
  JoinRequest,
} from './types';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

function groupPath(id: string) {
  return { params: { path: { id } } };
}

function isJoinRequest(data: GroupDetail | JoinRequest): data is JoinRequest {
  return !('members' in data);
}

/**
 * Groups, households, trips and events (spec §4.15). Membership is checked
 * by the API on every request: non-members get 404 for every group
 * resource. Link invitation tokens travel only in request bodies.
 */
export const groupsApi = {
  list: (includeArchived: boolean, signal?: AbortSignal): Promise<Group[]> =>
    apiData(
      api.GET('/groups', {
        params: { query: includeArchived ? { include_archived: true } : {} },
        ...signalOption(signal),
      }),
    ),
  get: (id: string, signal?: AbortSignal): Promise<GroupDetail> =>
    apiData(api.GET('/groups/{id}', { ...groupPath(id), ...signalOption(signal) })),
  create: (body: GroupInput): Promise<GroupDetail> => apiData(api.POST('/groups', { body })),
  /**
   * Changes only the fields sent (an empty string clears text and dates);
   * `version` is required and a stale one answers 409 VERSION_CONFLICT.
   */
  update: (id: string, body: GroupPatch): Promise<GroupDetail> =>
    apiData(api.PATCH('/groups/{id}', { ...groupPath(id), body })),
  /** Owner only; balances must be settled first. */
  remove: (id: string): Promise<Group> =>
    apiData(api.DELETE('/groups/{id}', { params: { path: { id }, query: { confirm: true } } })),
  archive: (id: string): Promise<Group> => apiData(api.POST('/groups/{id}/archive', groupPath(id))),
  restore: (id: string): Promise<Group> => apiData(api.POST('/groups/{id}/restore', groupPath(id))),

  balances: (id: string, signal?: AbortSignal): Promise<GroupBalances> =>
    apiData(api.GET('/groups/{id}/balances', { ...groupPath(id), ...signalOption(signal) })),
  /** One page of activity, newest first; pass `next_before` for older events. */
  activity: (id: string, before: number, signal?: AbortSignal): Promise<GroupActivityPage> =>
    apiData(
      api.GET('/groups/{id}/activity', {
        params: { path: { id }, query: before > 0 ? { before } : {} },
        ...signalOption(signal),
      }),
    ),

  /** Admins see every invitation; members see the ones they created. Tokens are never repeated. */
  invitations: (
    id: string,
    includeInactive: boolean,
    signal?: AbortSignal,
  ): Promise<GroupInvitation[]> =>
    apiData(
      api.GET('/groups/{id}/invitations', {
        params: { path: { id }, query: includeInactive ? { include_inactive: true } : {} },
        ...signalOption(signal),
      }),
    ),
  /** A link invitation's `token` is in this response only. */
  createInvitation: (id: string, body: GroupInvitationInput): Promise<GroupInvitation> =>
    apiData(api.POST('/groups/{id}/invitations', { ...groupPath(id), body })),
  revokeInvitation: (id: string, invitationId: string) =>
    apiData(
      api.DELETE('/groups/{id}/invitations/{invitationId}', {
        params: { path: { id, invitationId } },
      }),
    ),

  /** Username invitations addressed to the signed-in user. */
  myInvitations: (signal?: AbortSignal): Promise<GroupInvitation[]> =>
    apiData(api.GET('/group-invitations', signalOption(signal))),
  acceptInvitation: (invitationId: string): Promise<GroupDetail> =>
    apiData(
      api.POST('/group-invitations/{invitationId}/accept', {
        params: { path: { invitationId } },
      }),
    ),
  declineInvitation: (invitationId: string) =>
    apiData(
      api.POST('/group-invitations/{invitationId}/decline', {
        params: { path: { invitationId } },
      }),
    ),
  /** What a link invitation is for (the token stays in the body). */
  previewLink: (token: string): Promise<InvitationPreview> =>
    apiData(api.POST('/group-invitations/preview', { body: { token } })),
  /**
   * Joins (200 with the group) or, when the group requires approval,
   * creates a join request for the admins (202 with the request). A group
   * always carries `members`; a join request never does.
   */
  acceptLink: async (token: string): Promise<AcceptLinkResult> => {
    const { data } = await apiEnvelope(api.POST('/group-invitations/accept', { body: { token } }));
    if (isJoinRequest(data)) return { outcome: 'pending', request: data };
    return { outcome: 'joined', group: data };
  },

  requestToJoin: (id: string, message: string): Promise<JoinRequest> =>
    apiData(
      api.POST('/groups/{id}/join-requests', {
        ...groupPath(id),
        body: message ? { message } : {},
      }),
    ),
  joinRequests: (id: string, signal?: AbortSignal): Promise<JoinRequest[]> =>
    apiData(api.GET('/groups/{id}/join-requests', { ...groupPath(id), ...signalOption(signal) })),
  decideJoinRequest: (id: string, requestId: string, approve: boolean): Promise<GroupDetail> => {
    const options = { params: { path: { id, requestId } } };
    return approve
      ? apiData(api.POST('/groups/{id}/join-requests/{requestId}/approve', options))
      : apiData(api.POST('/groups/{id}/join-requests/{requestId}/decline', options));
  },

  /**
   * Invites a friend (`user_id`, found even without username discovery) or
   * someone findable by `username`; they join when they accept.
   */
  addMember: (id: string, body: AddMemberInput): Promise<GroupInvitation> =>
    apiData(api.POST('/groups/{id}/members', { ...groupPath(id), body })),
  updateMember: (id: string, userId: string, body: GroupMemberUpdate): Promise<GroupDetail> =>
    apiData(api.PATCH('/groups/{id}/members/{userId}', { params: { path: { id, userId } }, body })),
  /** Removes someone (admins) or leaves (yourself). */
  removeMember: (id: string, userId: string) =>
    apiData(api.DELETE('/groups/{id}/members/{userId}', { params: { path: { id, userId } } })),
  transferOwnership: (id: string, userId: string): Promise<GroupDetail> =>
    apiData(
      api.POST('/groups/{id}/transfer-ownership', { ...groupPath(id), body: { user_id: userId } }),
    ),
};

/** Your groups; archived ones only on request. */
export function useGroupsList(includeArchived: boolean) {
  return useQuery({
    queryKey: groupsKeys.list(includeArchived),
    queryFn: ({ signal }) => groupsApi.list(includeArchived, signal),
  });
}

export function useMyInvitations() {
  return useQuery({
    queryKey: groupsKeys.myInvitations(),
    queryFn: ({ signal }) => groupsApi.myInvitations(signal),
  });
}

export function useGroup(id: string) {
  return useQuery({
    queryKey: groupsKeys.group(id),
    queryFn: ({ signal }) => groupsApi.get(id, signal),
    enabled: Boolean(id),
  });
}

export function useGroupBalances(id: string, enabled = true) {
  return useQuery({
    queryKey: groupsKeys.balances(id),
    queryFn: ({ signal }) => groupsApi.balances(id, signal),
    enabled: enabled && Boolean(id),
  });
}

/** Activity pages, newest first (`before` = the previous page's `next_before`). */
export function useGroupActivity(id: string, enabled = true) {
  return useInfiniteQuery({
    queryKey: groupsKeys.activity(id),
    queryFn: ({ pageParam, signal }) => groupsApi.activity(id, pageParam, signal),
    initialPageParam: 0,
    getNextPageParam: (last) => last.next_before ?? undefined,
    enabled: enabled && Boolean(id),
  });
}

export function useGroupInvitations(id: string, includeInactive: boolean, enabled = true) {
  return useQuery({
    queryKey: groupsKeys.invitations(id, includeInactive),
    queryFn: ({ signal }) => groupsApi.invitations(id, includeInactive, signal),
    enabled: enabled && Boolean(id),
  });
}

export function useJoinRequests(id: string, enabled = true) {
  return useQuery({
    queryKey: groupsKeys.joinRequests(id),
    queryFn: ({ signal }) => groupsApi.joinRequests(id, signal),
    enabled: enabled && Boolean(id),
  });
}
