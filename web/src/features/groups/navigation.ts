import type { NavigateFunction } from 'react-router';
import { paths } from '@/shared/config/paths';

/**
 * After leaving or deleting a group: go to the list first, then clean up,
 * so the group's page never refetches (and flashes) a group that is gone.
 */
export async function leaveGroupPage(navigate: NavigateFunction, cleanUp: () => void) {
  await navigate(paths.groups, { replace: true });
  cleanUp();
}
