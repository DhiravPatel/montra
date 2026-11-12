import type { ChallengeScope } from './types';

/**
 * Query keys of the challenges screens. Challenges hold no money, so they
 * are not finance keys: finance writes do not refetch them and challenge
 * writes leave finance data alone.
 */
export const challengeKeys = {
  all: ['challenges'] as const,
  /** Every list (prefix of `list`). */
  lists: () => ['challenges', 'list'] as const,
  list: (scope: ChallengeScope) => ['challenges', 'list', scope] as const,
  detail: (id: string) => ['challenges', 'detail', id] as const,
  leaderboard: (id: string) => ['challenges', 'leaderboard', id] as const,
  /** Communities you are an active member of (GET /communities?mine=true). */
  communities: () => ['challenges', 'communities'] as const,
};
