import { screen } from '@testing-library/react';
import type userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import type {
  BlockedPerson,
  FriendRequest,
  MutedPerson,
  OwnProfile,
  OwnProfilePatch,
  PublicProfile,
  SendFriendRequestInput,
} from '@/features/social/types';
import type { User } from '@/shared/api/types';
import { makePreferences } from './financeFixtures';
import { API, envelope, errorBody, makeUser, meta } from './fixtures';
import { testBackend } from './msw/backend';
import { server } from './msw/server';
import { renderRoute } from './render';
import { makeFriend } from './sharingFixtures';

/** People and requests for the Friends page (tests only). */
export const ME_ID = makeUser().id;
export const KABIR_ID = '3e7a1c55-2b9d-4f61-8a0e-6c4d2b1f9e07';
export const MEERA_ID = '8b2d4f6a-1c3e-4a5b-9d7f-0e2c4a6b8d1f';
export const REQUEST_IN_ID = 'c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f';
export const REQUEST_OUT_ID = 'd4e5f6a7-b8c9-4d0e-9f1a-2b3c4d5e6f70';

/** A friend (Ravi Kumar, @ravi). */
export { makeFriend };

/** Someone you are not connected with (Meera Shah, @meera_s). */
export function makePerson(overrides: Partial<PublicProfile> = {}): PublicProfile {
  return {
    user_id: MEERA_ID,
    display_name: 'Meera Shah',
    username: 'meera_s',
    connection: 'none',
    muted: false,
    blocked_by_me: false,
    ...overrides,
  };
}

function self(): PublicProfile {
  return {
    user_id: ME_ID,
    display_name: 'Asha Rao',
    username: 'asha',
    connection: 'self',
    muted: false,
    blocked_by_me: false,
  };
}

/** Someone you blocked (GET /blocks): Meera Shah, blocked on 3 November. */
export function makeBlocked(overrides: Partial<BlockedPerson> = {}): BlockedPerson {
  return {
    ...makePerson(),
    blocked_by_me: true,
    created_at: '2026-11-03T08:00:00Z',
    ...overrides,
  };
}

/** Someone you muted (GET /mutes): Ravi Kumar, muted on 2 November. */
export function makeMuted(overrides: Partial<MutedPerson> = {}): MutedPerson {
  return {
    ...makeFriend(),
    muted: true,
    created_at: '2026-11-02T08:00:00Z',
    ...overrides,
  };
}

/** Kabir Singh asked to be your friend. */
export function makeIncomingRequest(overrides: Partial<FriendRequest> = {}): FriendRequest {
  return {
    id: REQUEST_IN_ID,
    from: {
      user_id: KABIR_ID,
      display_name: 'Kabir Singh',
      username: 'kabir',
      connection: 'request_received',
      muted: false,
      blocked_by_me: false,
    },
    to: self(),
    status: 'pending',
    created_at: '2026-11-03T10:00:00Z',
    ...overrides,
  };
}

/** You asked Meera Shah to be your friend. */
export function makeOutgoingRequest(overrides: Partial<FriendRequest> = {}): FriendRequest {
  return {
    id: REQUEST_OUT_ID,
    from: self(),
    to: makePerson({ connection: 'request_sent' }),
    status: 'pending',
    created_at: '2026-11-02T09:30:00Z',
    ...overrides,
  };
}

export function makeOwnProfile(overrides: Partial<OwnProfile> = {}): OwnProfile {
  return {
    display_name: 'Asha Rao',
    username: 'asha',
    interests: [],
    profile_visibility: 'connections',
    discoverable_by_username: true,
    show_achievements: false,
    allow_friend_requests: 'everyone',
    updated_at: '2026-11-01T08:00:00Z',
    ...overrides,
  };
}

export interface RecordedCall {
  method: string;
  path: string;
  body: unknown;
}

/** In-memory social graph behind socialHandlers(); tests read `calls`. */
export interface SocialState {
  friends: PublicProfile[];
  requests: FriendRequest[];
  /** Discoverable people (search finds the exact username only, like the API). */
  people: PublicProfile[];
  profile: OwnProfile;
  /** GET /blocks, newest first. */
  blocks: BlockedPerson[];
  /** GET /mutes, newest first. */
  mutes: MutedPerson[];
  /** People per page of the block and mute lists (the API's default is 50). */
  pageSize: number;
  calls: RecordedCall[];
}

export function createSocialState(overrides: Partial<SocialState> = {}): SocialState {
  return {
    friends: [],
    requests: [],
    people: [],
    profile: makeOwnProfile(),
    blocks: [],
    mutes: [],
    pageSize: 50,
    calls: [],
    ...overrides,
  };
}

/** One cursor page of a list (the cursor is the offset, as text). */
function listPage(items: readonly unknown[], url: string, pageSize: number) {
  const params = new URL(url).searchParams;
  const start = Number(params.get('cursor') ?? '0');
  const limit = Number(params.get('limit') ?? String(pageSize));
  const page = items.slice(start, start + limit);
  const hasMore = start + limit < items.length;
  return HttpResponse.json({
    data: page,
    meta: {
      ...meta(),
      has_more: hasMore,
      ...(hasMore ? { next_cursor: String(start + limit) } : {}),
    },
  });
}

const notFound = (what: string) =>
  HttpResponse.json(errorBody({ code: 'NOT_FOUND', message: `The ${what} was not found.` }), {
    status: 404,
  });

const ok = () => HttpResponse.json(envelope({ ok: true }));

/**
 * Handlers shaped like the live API (checked against the dev server):
 * writes answer `{ok: true}` or the updated request, missing records 404,
 * and every write is recorded in `state.calls`.
 */
export function socialHandlers(state: SocialState) {
  const record = (method: string, path: string, body: unknown = null) => {
    state.calls.push({ method, path, body });
  };
  const pending = () => state.requests.filter((request) => request.status === 'pending');
  const isBlocked = (userId: string) => state.blocks.some((entry) => entry.user_id === userId);
  const isMuted = (userId: string) => state.mutes.some((entry) => entry.user_id === userId);
  /** Everyone the state knows, with the current muted / blocked flags. */
  const profileOf = (userId: string): PublicProfile | null => {
    const known = [
      ...state.friends,
      ...state.people,
      ...state.requests.flatMap((request) => [request.from, request.to]),
    ].find((person) => person.user_id === userId);
    return known ? { ...known, muted: isMuted(userId), blocked_by_me: isBlocked(userId) } : null;
  };
  const withFlags = (person: PublicProfile): PublicProfile => ({
    ...person,
    muted: isMuted(person.user_id),
    blocked_by_me: isBlocked(person.user_id),
  });
  return [
    http.get(`${API}/connections`, () => HttpResponse.json(envelope(state.friends.map(withFlags)))),
    http.get(`${API}/friend-requests`, () =>
      HttpResponse.json(
        envelope(
          pending().map((request) => ({
            ...request,
            from: withFlags(request.from),
            to: withFlags(request.to),
          })),
        ),
      ),
    ),
    http.get(`${API}/users/search`, ({ request }) => {
      const q = new URL(request.url).searchParams.get('q') ?? '';
      record('GET', `/users/search?q=${q}`);
      return HttpResponse.json(
        envelope(
          state.people
            .filter(
              (person) =>
                person.username?.toLowerCase() === q.toLowerCase() && !isBlocked(person.user_id),
            )
            .map(withFlags),
        ),
      );
    }),
    http.get(`${API}/blocks`, ({ request }) => listPage(state.blocks, request.url, state.pageSize)),
    http.get(`${API}/mutes`, ({ request }) => listPage(state.mutes, request.url, state.pageSize)),
    http.post(`${API}/friend-requests`, async ({ request }) => {
      const body = (await request.json()) as SendFriendRequestInput;
      record('POST', '/friend-requests', body);
      const person = state.people.find((entry) => entry.user_id === body.user_id);
      if (!person) return notFound('user');
      const created = makeOutgoingRequest({
        id: 'e5f6a7b8-c9d0-4e1f-8a2b-3c4d5e6f7a8b',
        to: { ...person, connection: 'request_sent' },
        ...(body.message ? { message: body.message } : {}),
      });
      state.requests.push(created);
      return HttpResponse.json(envelope(created), { status: 201 });
    }),
    http.post(`${API}/friend-requests/:id/:action`, ({ params }) => {
      const id = String(params.id);
      const action = String(params.action);
      record('POST', `/friend-requests/${id}/${action}`);
      const found = pending().find((request) => request.id === id);
      if (!found) return notFound('pending friend request');
      found.status =
        action === 'accept' ? 'accepted' : action === 'decline' ? 'declined' : 'cancelled';
      if (action === 'accept') state.friends.push({ ...found.from, connection: 'friend' });
      return HttpResponse.json(envelope(found));
    }),
    http.delete(`${API}/connections/:userId`, ({ params }) => {
      const userId = String(params.userId);
      record('DELETE', `/connections/${userId}`);
      if (!state.friends.some((friend) => friend.user_id === userId)) return notFound('connection');
      state.friends = state.friends.filter((friend) => friend.user_id !== userId);
      return ok();
    }),
    http.post(`${API}/users/:userId/block`, ({ params }) => {
      const userId = String(params.userId);
      record('POST', `/users/${userId}/block`);
      const person = profileOf(userId);
      if (!person) return notFound('user');
      // Blocking ends the friendship and cancels requests; the block list grows at the top.
      state.friends = state.friends.filter((friend) => friend.user_id !== userId);
      for (const request of pending()) {
        if (request.from.user_id === userId || request.to.user_id === userId) {
          request.status = 'cancelled';
        }
      }
      if (!isBlocked(userId)) {
        state.blocks.unshift({
          ...person,
          connection: 'none',
          blocked_by_me: true,
          created_at: '2026-11-05T10:00:00Z',
        });
      }
      return ok();
    }),
    http.delete(`${API}/users/:userId/block`, ({ params }) => {
      const userId = String(params.userId);
      record('DELETE', `/users/${userId}/block`);
      if (!isBlocked(userId)) return notFound('block');
      state.blocks = state.blocks.filter((entry) => entry.user_id !== userId);
      return ok();
    }),
    http.post(`${API}/users/:userId/mute`, async ({ params, request }) => {
      const userId = String(params.userId);
      const body = (await request.json()) as { muted: boolean };
      record('POST', `/users/${userId}/mute`, body);
      const person = profileOf(userId);
      if (!person) return notFound('user');
      if (body.muted && !isMuted(userId)) {
        state.mutes.unshift({ ...person, muted: true, created_at: '2026-11-05T10:00:00Z' });
      } else if (!body.muted) {
        state.mutes = state.mutes.filter((entry) => entry.user_id !== userId);
      }
      return ok();
    }),
    http.get(`${API}/me`, () => {
      const account = testBackend.user ?? makeUser();
      return HttpResponse.json(
        envelope({ account, profile: state.profile, preferences: makePreferences() }),
      );
    }),
    http.patch(`${API}/me`, async ({ request }) => {
      const body = (await request.json()) as OwnProfilePatch;
      record('PATCH', '/me', body);
      const { username, ...rest } = body;
      state.profile = { ...state.profile, ...rest, updated_at: '2026-11-05T10:00:00Z' };
      if (username !== undefined) {
        state.profile.username = username;
        // The session user carries the username too (refreshed after saving).
        if (testBackend.user) testBackend.user = { ...testBackend.user, username };
      }
      return HttpResponse.json(envelope(state.profile));
    }),
  ];
}

/** The writes a test made (reads are not recorded, except searches). */
export function writes(state: SocialState): RecordedCall[] {
  return state.calls.filter((call) => call.method !== 'GET');
}

/** A signed-in user who finished onboarding and has the username @asha. */
export function socialUser(overrides: Partial<User> = {}): User {
  return makeUser({ onboarding_completed: true, username: 'asha', ...overrides });
}

interface RenderFriendsOptions {
  path?: string;
  user?: User;
  /** Handlers that take precedence over the social backend (failures, delays). */
  overrides?: Parameters<typeof server.use>;
}

/** Renders the Friends page against `state` (see socialHandlers). */
export function renderFriends(
  state: SocialState,
  { path = '/friends', user = socialUser(), overrides = [] }: RenderFriendsOptions = {},
) {
  server.use(...socialHandlers(state));
  // A later server.use() call wins over earlier ones.
  if (overrides.length > 0) server.use(...overrides);
  return renderRoute(path, { user });
}

/** Opens someone's "More actions" menu and chooses `item`. */
export async function choosePersonAction(
  user: ReturnType<typeof userEvent.setup>,
  name: string,
  item: string,
) {
  await user.click(await screen.findByRole('button', { name: `More actions for ${name}` }));
  await user.click(await screen.findByRole('menuitem', { name: item }));
}
