import { api } from '@/shared/api/client';
import { apiData, apiEnvelope } from '@/shared/api/request';
import type {
  BlockedPerson,
  FriendRequest,
  MutedPerson,
  OwnProfile,
  OwnProfilePatch,
  PeoplePage,
  PublicProfile,
  SendFriendRequestInput,
} from './types';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

/** Cursor query for the block and mute lists (the cursor stays in memory, never in the URL). */
function cursorQuery(cursor: string, signal?: AbortSignal) {
  return { params: { query: cursor ? { cursor } : {} }, ...signalOption(signal) };
}

function page<T>(envelope: { data: T[]; meta: { next_cursor?: string } }): PeoplePage<T> {
  return { items: envelope.data, nextCursor: envelope.meta.next_cursor ?? null };
}

const requestPath = (id: string) => ({ params: { path: { id } } });
const userPath = (userId: string) => ({ params: { path: { userId } } });

/**
 * The private-by-default social graph (spec §4.15): exact-username
 * discovery, friend requests, connections, blocks and mutes. Profiles never
 * carry balances or transactions.
 */
export const socialApi = {
  /** Your friends (minimal profiles). */
  connections: (signal?: AbortSignal): Promise<PublicProfile[]> =>
    apiData(api.GET('/connections', signalOption(signal))),
  /** Pending requests you sent or received. */
  requests: (signal?: AbortSignal): Promise<FriendRequest[]> =>
    apiData(api.GET('/friend-requests', signalOption(signal))),
  /** People who opted into discovery, by username (`q` without the leading @). */
  search: (username: string, signal?: AbortSignal): Promise<PublicProfile[]> =>
    apiData(
      api.GET('/users/search', { params: { query: { q: username } }, ...signalOption(signal) }),
    ),
  /** Sends a request, or accepts theirs when they already asked you (status `accepted`). */
  send: (body: SendFriendRequestInput): Promise<FriendRequest> =>
    apiData(api.POST('/friend-requests', { body })),
  accept: (id: string): Promise<FriendRequest> =>
    apiData(api.POST('/friend-requests/{id}/accept', requestPath(id))),
  decline: (id: string): Promise<FriendRequest> =>
    apiData(api.POST('/friend-requests/{id}/decline', requestPath(id))),
  cancel: (id: string): Promise<FriendRequest> =>
    apiData(api.POST('/friend-requests/{id}/cancel', requestPath(id))),
  /** Ends the friendship for both people. */
  removeFriend: (userId: string) => apiData(api.DELETE('/connections/{userId}', userPath(userId))),
  /** Removes the connection and pending requests; both sides stop seeing each other. */
  block: (userId: string) => apiData(api.POST('/users/{userId}/block', userPath(userId))),
  unblock: (userId: string) => apiData(api.DELETE('/users/{userId}/block', userPath(userId))),
  /** Mutes (or unmutes) someone's notifications; they are not told. */
  setMuted: (userId: string, muted: boolean) =>
    apiData(api.POST('/users/{userId}/mute', { ...userPath(userId), body: { muted } })),
  /** People you blocked, newest first (display name and username only). */
  blocks: async (cursor: string, signal?: AbortSignal): Promise<PeoplePage<BlockedPerson>> =>
    page(await apiEnvelope(api.GET('/blocks', cursorQuery(cursor, signal)))),
  /** People you muted, newest first. */
  mutes: async (cursor: string, signal?: AbortSignal): Promise<PeoplePage<MutedPerson>> =>
    page(await apiEnvelope(api.GET('/mutes', cursorQuery(cursor, signal)))),
  /** Your own profile, including username and social privacy settings. */
  ownProfile: async (signal?: AbortSignal): Promise<OwnProfile> =>
    (await apiData(api.GET('/me', signalOption(signal)))).profile,
  /** Changes only the fields sent (no version: the profile is not versioned). */
  updateProfile: (body: OwnProfilePatch): Promise<OwnProfile> =>
    apiData(api.PATCH('/me', { body })),
};
