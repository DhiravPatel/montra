import { http, HttpResponse } from 'msw';
import type {
  Challenge,
  ChallengeParticipation,
  CommunityChoice,
  LeaderboardEntry,
} from '@/features/challenges/types';
import { addDaysToLocalDate, todayInTimeZone } from '@/shared/formatting/dates';
import { API, envelope, errorBody, makeUser } from './fixtures';
import { server } from './msw/server';

/** Challenges, participations and leaderboards for the challenges pages (tests only). */
export const CHALLENGE_PRIVATE = '0c7d3f1a-5b2e-4c8d-9a1f-2e3d4c5b6a70';
export const CHALLENGE_GROUP = '1d8e4a2b-6c3f-4d9e-8b2a-3f4e5d6c7b81';
export const CHALLENGE_OPEN = '2e9f5b3c-7d4a-4e1f-9c3b-4a5f6e7d8c92';
export const CHALLENGE_PAST = '3f1a6c4d-8e5b-4f2a-8d4c-5b6a7f8e9da3';
export const CHALLENGE_COMMUNITY = '4a2b7d5e-9f6c-4a3b-9e5d-6c7b8a9f0eb4';
export const CHALLENGE_GROUP_ID = '5b3c8e6f-1a7d-4b4c-8f6e-7d8c9b0a1fc5';
export const CHALLENGE_COMMUNITY_ID = '6c4d9f7a-2b8e-4c5d-9a7f-8e9d0c1b2ad6';

/** The signed-in test user's calendar date (makeUser() lives in Asia/Kolkata). */
export function testToday(): string {
  return todayInTimeZone(makeUser().timezone);
}

export function daysFromToday(days: number): string {
  return addDaysToLocalDate(testToday(), days);
}

export function makeParticipation(
  overrides: Partial<ChallengeParticipation> = {},
): ChallengeParticipation {
  return {
    status: 'active',
    share_progress: false,
    show_on_leaderboard: false,
    progress_value: 3,
    percent_complete: 42,
    current_streak: 2,
    best_streak: 3,
    joined_at: '2026-11-01T04:30:00Z',
    ...overrides,
  };
}

/** "Cook at home": your own private challenge, 3 of 7 days so far. */
export function makeChallenge(overrides: Partial<Challenge> = {}): Challenge {
  return {
    id: CHALLENGE_PRIVATE,
    title: 'Cook at home',
    description: 'Make dinner at home on weeknights.',
    challenge_type: 'meal_planning',
    rules: 'Home-cooked dinner counts as done.',
    metric: 'days',
    target_value: 7,
    starts_on: daysFromToday(-3),
    ends_on: daysFromToday(10),
    visibility: 'private',
    leaderboard_enabled: false,
    status: 'active',
    ended: false,
    participant_count: 1,
    mine: true,
    me: makeParticipation(),
    version: 1,
    created_at: '2026-11-01T04:30:00Z',
    ...overrides,
  };
}

/** "No-spend weekends": a group challenge with an opt-in leaderboard you take part in. */
export function makeGroupChallenge(overrides: Partial<Challenge> = {}): Challenge {
  return makeChallenge({
    id: CHALLENGE_GROUP,
    title: 'No-spend weekends',
    description: 'Skip non-essential spending on weekends.',
    challenge_type: 'no_spend',
    rules: undefined,
    metric: 'streak',
    target_value: 5,
    visibility: 'group',
    group_id: CHALLENGE_GROUP_ID,
    group: { id: CHALLENGE_GROUP_ID, name: 'Home' },
    leaderboard_enabled: true,
    participant_count: 4,
    mine: false,
    me: makeParticipation({
      progress_value: 2,
      percent_complete: 40,
      current_streak: 2,
      best_streak: 2,
    }),
    ...overrides,
  });
}

/** "Trip fund": a community challenge you have not joined. */
export function makeOpenChallenge(overrides: Partial<Challenge> = {}): Challenge {
  const challenge = makeChallenge({
    id: CHALLENGE_OPEN,
    title: 'Trip fund',
    description: 'Save step by step for a trip.',
    challenge_type: 'travel_savings',
    rules: undefined,
    metric: 'percent',
    target_value: 80,
    visibility: 'community',
    community_id: CHALLENGE_COMMUNITY_ID,
    community: { id: CHALLENGE_COMMUNITY_ID, name: 'Frugal Living' },
    leaderboard_enabled: true,
    participant_count: 12,
    mine: false,
    ...overrides,
  });
  if (!('me' in overrides)) delete challenge.me;
  return challenge;
}

export function makeLeaderboardEntry(overrides: Partial<LeaderboardEntry> = {}): LeaderboardEntry {
  return {
    rank: 1,
    display_name: 'Ravi Kumar',
    username: 'ravi',
    percent_complete: 100,
    current_streak: 5,
    completed: true,
    is_me: false,
    ...overrides,
  };
}

export function makeCommunity(overrides: Partial<CommunityChoice> = {}): CommunityChoice {
  return {
    id: CHALLENGE_COMMUNITY_ID,
    name: 'Frugal Living',
    slug: 'frugal-living',
    member_count: 120,
    my_role: 'member',
    my_status: 'active',
    can_moderate: false,
    version: 1,
    status: 'active',
    topics: ['saving'],
    visibility: 'public',
    created_at: '2026-10-01T08:00:00Z',
    ...overrides,
  };
}

/**
 * GET /challenges answers per scope (both default to empty lists), in
 * cursor pages of `pageSize` like the API (`meta.next_cursor` / `has_more`
 * while more follow). Returns the queries received (`scope=…&limit=…[&cursor=…]`).
 */
export function serveChallengeLists(
  lists: { mine?: Challenge[]; discover?: Challenge[] } = {},
  pageSize = 50,
) {
  const seen: string[] = [];
  server.use(
    http.get(`${API}/challenges`, ({ request }) => {
      const params = new URL(request.url).searchParams;
      seen.push(params.toString());
      const scope = params.get('scope') ?? '';
      const all = scope === 'discover' ? (lists.discover ?? []) : (lists.mine ?? []);
      const cursor = params.get('cursor');
      const offset = cursor ? Number(cursor.replace(/^after-/u, '')) : 0;
      const end = offset + pageSize;
      const page = envelope(all.slice(offset, end));
      const more = end < all.length;
      return HttpResponse.json({
        ...page,
        meta: { ...page.meta, has_more: more, ...(more ? { next_cursor: `after-${end}` } : {}) },
      });
    }),
  );
  return seen;
}

/**
 * GET /challenges/{id} from a mutable state, so a test can change what the
 * API returns after a write.
 */
export function serveChallenge(initial: Challenge) {
  const state = { challenge: initial };
  server.use(
    http.get(`${API}/challenges/:id`, ({ params }) => {
      if (params.id !== state.challenge.id) {
        return HttpResponse.json(errorBody({ code: 'NOT_FOUND', message: 'Not found.' }), {
          status: 404,
        });
      }
      return HttpResponse.json(envelope(state.challenge));
    }),
  );
  return state;
}

/** GET /communities?mine=true (the communities you belong to). */
export function serveMyCommunities(communities: CommunityChoice[] = [makeCommunity()]) {
  server.use(http.get(`${API}/communities`, () => HttpResponse.json(envelope(communities))));
}
