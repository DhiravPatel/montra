import type { QueryClient } from '@tanstack/react-query';
import type { NotificationFilters } from './types';

/**
 * Query keys for the notification center. Notifications are not finance
 * records, so they live under their own `notifications` prefix; the auth
 * layer drops them on sign-out with the rest of the signed-in cache.
 */
export const notificationsKeys = {
  all: ['notifications'] as const,
  unreadCount: () => ['notifications', 'unread-count'] as const,
  lists: () => ['notifications', 'list'] as const,
  list: (filters: NotificationFilters) => ['notifications', 'list', filters] as const,
  preferences: () => ['notifications', 'preferences'] as const,
  /** Whether the server can send Web Push (GET /notifications/push-config). */
  pushConfig: () => ['notifications', 'push-config'] as const,
  /** Browsers and devices registered for push (GET /me/push-endpoints). */
  pushEndpoints: () => ['notifications', 'push-endpoints'] as const,
  /** This browser's push state (permission and subscription), not server data. */
  browserPush: () => ['notifications', 'browser-push'] as const,
};

/** Refreshes the badge and every list after reads, unreads, archiving or read-all. */
export function refreshNotifications(queryClient: QueryClient): Promise<void> {
  return Promise.all([
    queryClient.invalidateQueries({ queryKey: notificationsKeys.unreadCount() }),
    queryClient.invalidateQueries({ queryKey: notificationsKeys.lists() }),
  ]).then(() => undefined);
}
