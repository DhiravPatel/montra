import { useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import type { SelectOption } from '@/shared/components/Select';
import type { Translate } from '@/shared/i18n/types';
import { sharingKeys } from './keys';
import type { Group, GroupDetail, PublicProfile } from './types';

/*
 * People a budget or goal can be shared with: the user's friends
 * (GET /connections) and the members of a group (GET /groups/{id}). The API
 * decides who may actually be added; these lists only offer choices.
 */

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

export const sharingApi = {
  connections: (signal?: AbortSignal): Promise<PublicProfile[]> =>
    apiData(api.GET('/connections', signalOption(signal))),
  groups: (signal?: AbortSignal): Promise<Group[]> =>
    apiData(api.GET('/groups', signalOption(signal))),
  group: (id: string, signal?: AbortSignal): Promise<GroupDetail> =>
    apiData(api.GET('/groups/{id}', { params: { path: { id } }, ...signalOption(signal) })),
};

/** The user's friends. */
export function useFriends(enabled = true) {
  return useQuery({
    queryKey: sharingKeys.connections(),
    queryFn: ({ signal }) => sharingApi.connections(signal),
    select: (people) => people.filter((person) => person.connection === 'friend'),
    staleTime: 5 * 60_000,
    enabled,
  });
}

/** Groups the user belongs to that are still active (for "track with a group"). */
export function useGroups(enabled = true) {
  return useQuery({
    queryKey: sharingKeys.groups(),
    queryFn: ({ signal }) => sharingApi.groups(signal),
    select: (groups) => groups.filter((group) => group.status === 'active'),
    staleTime: 5 * 60_000,
    enabled,
  });
}

/** A group with its members (when a budget or goal is tracked with a group). */
export function useGroupDetail(id: string | null | undefined) {
  return useQuery({
    queryKey: sharingKeys.group(id ?? ''),
    queryFn: ({ signal }) => sharingApi.group(id ?? '', signal),
    enabled: Boolean(id),
    staleTime: 5 * 60_000,
  });
}

export function groupOptions(groups: readonly Group[] | undefined): SelectOption[] {
  return (groups ?? []).map((group) => ({ value: group.id, label: group.name }));
}

export interface ShareCandidate {
  userId: string;
  name: string;
  /** "@username" when the person has one (helps tell people apart). */
  handle: string | null;
  source: 'friend' | 'group';
}

/**
 * Friends plus the active members of `groupId` (when given), without the
 * signed-in user and without `exclude` (people already added).
 */
export function useShareCandidates({
  groupId,
  exclude = [],
  enabled = true,
}: {
  groupId?: string | null;
  exclude?: readonly string[];
  enabled?: boolean;
}) {
  const me = useCurrentUser();
  const friends = useFriends(enabled);
  const group = useGroupDetail(enabled ? groupId : null);
  const skip = new Set([me.id, ...exclude]);
  const byId = new Map<string, ShareCandidate>();
  for (const person of friends.data ?? []) {
    if (skip.has(person.user_id)) continue;
    byId.set(person.user_id, {
      userId: person.user_id,
      name: person.display_name,
      handle: person.username ? `@${person.username}` : null,
      source: 'friend',
    });
  }
  for (const member of group.data?.members ?? []) {
    if (member.status !== 'active' || skip.has(member.user_id) || byId.has(member.user_id)) {
      continue;
    }
    byId.set(member.user_id, {
      userId: member.user_id,
      name: member.display_name,
      handle: member.username ? `@${member.username}` : null,
      source: 'group',
    });
  }
  const candidates = [...byId.values()].sort((a, b) => a.name.localeCompare(b.name));
  const loadingGroup = Boolean(groupId) && group.isPending;
  return {
    candidates,
    isPending: friends.isPending || loadingGroup,
    isError: friends.isError || group.isError,
    error: friends.error ?? group.error,
    refetch: () => {
      void friends.refetch();
      if (groupId) void group.refetch();
    },
  };
}

/** Select options for share candidates, e.g. "Asha Rao (@asha) · Friend". */
export function shareCandidateOptions(
  candidates: readonly ShareCandidate[],
  t: Translate,
): SelectOption[] {
  return candidates.map((candidate) => {
    const name = candidate.handle ? `${candidate.name} (${candidate.handle})` : candidate.name;
    const source =
      candidate.source === 'friend' ? t('sharing.source.friend') : t('sharing.source.group');
    return { value: candidate.userId, label: `${name} · ${source}` };
  });
}
