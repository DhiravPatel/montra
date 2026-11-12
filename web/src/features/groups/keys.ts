import type { QueryClient } from '@tanstack/react-query';
import { invalidateFinance } from '@/shared/finance/keys';

/**
 * Query keys for groups. They start with `finance` so that shared-expense
 * and settlement writes (invalidateFinance) also refresh balances and the
 * activity log. Everything about one group sits under `group(id)`, so one
 * invalidation refreshes its details, balances, activity and invitations.
 * Invitation tokens never appear in keys.
 */
export const groupsKeys = {
  all: ['finance', 'groups'] as const,
  list: (includeArchived: boolean) => ['finance', 'groups', 'list', { includeArchived }] as const,
  myInvitations: () => ['finance', 'groups', 'my-invitations'] as const,
  group: (id: string) => ['finance', 'groups', 'group', id] as const,
  balances: (id: string) => ['finance', 'groups', 'group', id, 'balances'] as const,
  activity: (id: string) => ['finance', 'groups', 'group', id, 'activity'] as const,
  invitations: (id: string, includeInactive: boolean) =>
    ['finance', 'groups', 'group', id, 'invitations', { includeInactive }] as const,
  joinRequests: (id: string) => ['finance', 'groups', 'group', id, 'join-requests'] as const,
};

/** Prefix of the shared people and group pickers (budgets and goals read groups too). */
const sharingPrefix = ['sharing'] as const;

/**
 * Refreshes group data after a write. `personal` also refreshes every
 * finance view: archiving, deleting or leaving a group pauses or stops its
 * recurring bills, which appear in the personal calendar.
 */
export async function refreshGroups(
  queryClient: QueryClient,
  { personal = false }: { personal?: boolean } = {},
): Promise<void> {
  await Promise.all([
    personal
      ? invalidateFinance(queryClient)
      : queryClient.invalidateQueries({ queryKey: groupsKeys.all }),
    queryClient.invalidateQueries({ queryKey: sharingPrefix }),
  ]);
}
