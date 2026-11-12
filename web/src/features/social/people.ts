import type { ConnectionState, FriendRequest, PersonRef, PublicProfile } from './types';

/** Usernames as the API stores them: 3-30 lowercase letters, digits, "_" or ".". */
const USERNAME = /^[a-z0-9_.]{3,30}$/;

/** "  @Asha_Rao " → "asha_rao" (the API ignores a leading @ and letter case). */
export function normalizeUsername(value: string): string {
  return value.trim().replace(/^@/, '').trim().toLowerCase();
}

export function isValidUsername(value: string): boolean {
  return USERNAME.test(value);
}

/**
 * The one person whose username is exactly `username`. The API finds
 * people by exact username only (spec §20B.16); this keeps the page honest
 * should a server ever answer with anything else.
 */
export function exactUsernameMatch(
  people: readonly PublicProfile[],
  username: string,
): PublicProfile | null {
  return people.find((person) => person.username?.toLowerCase() === username) ?? null;
}

/** The fields an action needs, without the rest of the profile. */
export function personRef(person: PersonRef): PersonRef {
  return { user_id: person.user_id, display_name: person.display_name, username: person.username };
}

export interface SplitRequests {
  /** Waiting for your answer. */
  incoming: FriendRequest[];
  /** Waiting for theirs. */
  outgoing: FriendRequest[];
}

/** Pending requests by direction, relative to the signed-in user. */
export function splitRequests(requests: readonly FriendRequest[], myUserId: string): SplitRequests {
  const incoming: FriendRequest[] = [];
  const outgoing: FriendRequest[] = [];
  for (const request of requests) {
    if (request.status !== 'pending') continue;
    if (request.to.user_id === myUserId) incoming.push(request);
    else if (request.from.user_id === myUserId) outgoing.push(request);
  }
  return { incoming, outgoing };
}

/** The pending request between you and `userId`, in either direction. */
export function pendingRequestWith(
  requests: readonly FriendRequest[] | undefined,
  userId: string,
): FriendRequest | null {
  return (
    requests?.find(
      (request) =>
        request.status === 'pending' &&
        (request.from.user_id === userId || request.to.user_id === userId),
    ) ?? null
  );
}

/**
 * How you relate to someone found by search, from your friends and
 * requests lists (refreshed after every social write) rather than from the
 * search answer, which only reflects the moment of the search.
 */
export function liveConnection(
  person: PublicProfile,
  friends: readonly PublicProfile[] | undefined,
  requests: readonly FriendRequest[] | undefined,
): ConnectionState {
  if (friends?.some((friend) => friend.user_id === person.user_id)) return 'friend';
  const pending = pendingRequestWith(requests, person.user_id);
  if (pending) return pending.from.user_id === person.user_id ? 'request_received' : 'request_sent';
  if (friends && requests) return 'none';
  return person.connection;
}

function firstGrapheme(word: string, locale: string): string {
  if (typeof Intl.Segmenter === 'function') {
    const segments = new Intl.Segmenter(locale, { granularity: 'grapheme' }).segment(word);
    for (const { segment } of segments) return segment;
    return '';
  }
  return Array.from(word)[0] ?? '';
}

/** Up to two initials, by grapheme so names in any script stay whole. */
export function initials(name: string, locale: string): string {
  return name
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((word) => firstGrapheme(word, locale).toLocaleUpperCase(locale))
    .join('');
}
