import { api } from '@/shared/api/client';
import { compactQuery } from '@/shared/api/query';
import { apiData, apiEnvelope } from '@/shared/api/request';
import type {
  Challenge,
  ChallengeInput,
  ChallengePage,
  ChallengePatch,
  ChallengeProgressInput,
  ChallengeScope,
  ChallengeSharing,
  CommunityChoice,
  LeaderboardEntry,
} from './types';

/** Challenges per list page (the API allows up to 200). */
export const CHALLENGE_PAGE_SIZE = 50;

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

const challengePath = (id: string) => ({ params: { path: { id } } });

/**
 * Challenge endpoints (spec §4.16). Joining, sharing and the leaderboard are
 * opt-in: progress stays private unless the participant shares it, and the
 * leaderboard lists only people who chose to appear, by percentage.
 */
export const challengesApi = {
  /** One page (active challenges first); `cursor` continues the previous page. */
  list: async (
    scope: ChallengeScope,
    cursor: string | null,
    signal?: AbortSignal,
  ): Promise<ChallengePage> => {
    const envelope = await apiEnvelope(
      api.GET('/challenges', {
        params: {
          query: compactQuery({ scope, limit: CHALLENGE_PAGE_SIZE, cursor: cursor ?? undefined }),
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
  get: (id: string, signal?: AbortSignal): Promise<Challenge> =>
    apiData(api.GET('/challenges/{id}', { ...challengePath(id), ...signalOption(signal) })),
  /** Creates a challenge; the creator joins it with their progress private. */
  create: (body: ChallengeInput): Promise<Challenge> => apiData(api.POST('/challenges', { body })),
  /**
   * Edits a challenge you created: only the fields sent change (`""`
   * clears the description or rules) and the current `version` is
   * required (409 VERSION_CONFLICT when stale).
   */
  update: (id: string, body: ChallengePatch): Promise<Challenge> =>
    apiData(api.PATCH('/challenges/{id}', { ...challengePath(id), body })),
  /** Ends the challenge for everyone (its creator or the community's moderators). */
  cancel: (id: string): Promise<Challenge> =>
    apiData(api.POST('/challenges/{id}/cancel', challengePath(id))),
  join: (id: string, body: ChallengeSharing): Promise<Challenge> =>
    apiData(api.POST('/challenges/{id}/join', { ...challengePath(id), body })),
  /** Leaving keeps your check-ins privately and takes you off the leaderboard. */
  leave: (id: string) => apiData(api.POST('/challenges/{id}/leave', challengePath(id))),
  updateSharing: (id: string, body: ChallengeSharing): Promise<Challenge> =>
    apiData(api.PATCH('/challenges/{id}/participation', { ...challengePath(id), body })),
  /** Checks in for a day; sending the same day again corrects it. */
  recordProgress: (id: string, body: ChallengeProgressInput): Promise<Challenge> =>
    apiData(api.POST('/challenges/{id}/progress', { ...challengePath(id), body })),
  leaderboard: (id: string, signal?: AbortSignal): Promise<LeaderboardEntry[]> =>
    apiData(
      api.GET('/challenges/{id}/leaderboard', { ...challengePath(id), ...signalOption(signal) }),
    ),
  /** Communities you belong to (active or pending membership). */
  myCommunities: (signal?: AbortSignal): Promise<CommunityChoice[]> =>
    apiData(
      api.GET('/communities', { params: { query: { mine: true } }, ...signalOption(signal) }),
    ),
};
