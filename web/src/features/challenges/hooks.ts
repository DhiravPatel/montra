import { type QueryClient, useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { challengesApi } from './api';
import { challengeKeys } from './keys';
import type { Challenge, ChallengeScope } from './types';

/** Your challenges (`mine`) or ones open to you (`discover`), a cursor page at a time. */
export function useChallengeList(scope: ChallengeScope) {
  return useInfiniteQuery({
    queryKey: challengeKeys.list(scope),
    queryFn: ({ pageParam, signal }) => challengesApi.list(scope, pageParam, signal),
    initialPageParam: null as string | null,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
}

export function useChallenge(id: string) {
  return useQuery({
    queryKey: challengeKeys.detail(id),
    queryFn: ({ signal }) => challengesApi.get(id, signal),
    enabled: Boolean(id),
  });
}

/** Opted-in participants; only requested while the viewer appears on it too. */
export function useLeaderboard(id: string, enabled: boolean) {
  return useQuery({
    queryKey: challengeKeys.leaderboard(id),
    queryFn: ({ signal }) => challengesApi.leaderboard(id, signal),
    enabled: enabled && Boolean(id),
  });
}

/** Communities you are an active member of (for community challenges and names). */
export function useMyCommunities(enabled = true) {
  return useQuery({
    queryKey: challengeKeys.communities(),
    queryFn: ({ signal }) => challengesApi.myCommunities(signal),
    select: (communities) =>
      communities.filter(
        (community) => community.my_status === 'active' && community.status === 'active',
      ),
    staleTime: 5 * 60_000,
    enabled,
  });
}

/**
 * After a challenge write: show the challenge the API returned at once, and
 * refresh the lists and the leaderboard (they changed too).
 */
export function challengeChanged(queryClient: QueryClient, challenge: Challenge): Promise<unknown> {
  queryClient.setQueryData(challengeKeys.detail(challenge.id), challenge);
  return Promise.all([
    queryClient.invalidateQueries({ queryKey: challengeKeys.lists() }),
    queryClient.invalidateQueries({ queryKey: challengeKeys.leaderboard(challenge.id) }),
  ]);
}

/** After a write that returns no challenge (leaving): reload it and the lists. */
export function challengeStale(queryClient: QueryClient, id: string): Promise<unknown> {
  return Promise.all([
    queryClient.invalidateQueries({ queryKey: challengeKeys.detail(id) }),
    queryClient.invalidateQueries({ queryKey: challengeKeys.lists() }),
    queryClient.invalidateQueries({ queryKey: challengeKeys.leaderboard(id) }),
  ]);
}
