import { type QueryClient, useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { sharingKeys } from '@/shared/finance/keys';
import { socialApi } from './api';
import { socialKeys } from './keys';
import type { PublicProfile } from './types';

function friendsOnly(people: PublicProfile[]): PublicProfile[] {
  return people.filter((person) => person.connection === 'friend');
}

/** Your friends (GET /connections). */
export function useFriendsList() {
  return useQuery({
    queryKey: socialKeys.connections(),
    queryFn: ({ signal }) => socialApi.connections(signal),
    select: friendsOnly,
  });
}

/** Pending friend requests, sent and received (GET /friend-requests). */
export function useFriendRequests() {
  return useQuery({
    queryKey: socialKeys.requests(),
    queryFn: ({ signal }) => socialApi.requests(signal),
  });
}

/** Your own profile with username and social privacy settings (GET /me). */
export function useOwnProfile() {
  return useQuery({
    queryKey: socialKeys.profile(),
    queryFn: ({ signal }) => socialApi.ownProfile(signal),
  });
}

/** People you blocked, newest first, a page at a time (GET /blocks). */
export function useBlocks(enabled = true) {
  return useInfiniteQuery({
    queryKey: socialKeys.blocks(),
    queryFn: ({ pageParam, signal }) => socialApi.blocks(pageParam, signal),
    initialPageParam: '',
    getNextPageParam: (last) => last.nextCursor ?? undefined,
    enabled,
  });
}

/** People you muted, newest first, a page at a time (GET /mutes). */
export function useMutes(enabled = true) {
  return useInfiniteQuery({
    queryKey: socialKeys.mutes(),
    queryFn: ({ pageParam, signal }) => socialApi.mutes(pageParam, signal),
    initialPageParam: '',
    getNextPageParam: (last) => last.nextCursor ?? undefined,
    enabled,
  });
}

/** Every sharing key starts with this (friend and group pickers elsewhere). */
const sharingPrefix = [sharingKeys.connections()[0]] as const;

/**
 * After any social write: refetch friends, requests and the block and mute
 * lists, and mark the friend pickers used by budgets, goals and groups
 * stale so they refresh.
 */
export function invalidateSocial(queryClient: QueryClient): Promise<unknown> {
  return Promise.all([
    queryClient.invalidateQueries({ queryKey: socialKeys.connections() }),
    queryClient.invalidateQueries({ queryKey: socialKeys.requests() }),
    queryClient.invalidateQueries({ queryKey: socialKeys.blocks() }),
    queryClient.invalidateQueries({ queryKey: socialKeys.mutes() }),
    queryClient.invalidateQueries({ queryKey: sharingPrefix }),
  ]);
}
