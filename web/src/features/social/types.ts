import type { components } from '@/shared/api/schema';

type Schemas = components['schemas'];

/**
 * The minimal profile the API shows of another person: display name,
 * username, avatar and how they relate to you (plus whether you muted or
 * blocked them: your own actions only). Never money.
 */
export type PublicProfile = Schemas['PublicProfile'];
export type ConnectionState = PublicProfile['connection'];
/** Someone you blocked (GET /blocks), with when you did. */
export type BlockedPerson = Schemas['BlockDTO'];
/** Someone you muted (GET /mutes), with when you did. */
export type MutedPerson = Schemas['MuteDTO'];
export type FriendRequest = Schemas['FriendRequestDTO'];
export type SendFriendRequestInput = Schemas['SendInput'];
/** The signed-in user's own profile (`GET /me` → `profile`). */
export type OwnProfile = Schemas['ProfileDTO'];
export type OwnProfilePatch = Schemas['ProfilePatch'];
export type FriendRequestPolicy = OwnProfile['allow_friend_requests'];

/** One page of a cursor list (blocks, mutes). */
export interface PeoplePage<T> {
  items: T[];
  /** `meta.next_cursor`; null on the last page. */
  nextCursor: string | null;
}

/** The parts of a profile an action needs (and that the page keeps in memory). */
export interface PersonRef {
  user_id: string;
  display_name: string;
  username?: string | undefined;
  /** Whether you muted them, when the profile says. */
  muted?: boolean | undefined;
}
