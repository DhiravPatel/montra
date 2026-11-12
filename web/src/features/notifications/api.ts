import { useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { compactQuery } from '@/shared/api/query';
import { apiData, apiEnvelope } from '@/shared/api/request';
import type { Preferences } from '@/shared/finance/types';
import { usePageVisible } from './hooks/usePageVisible';
import { notificationsKeys } from './keys';
import type {
  AppNotification,
  EmailDigest,
  NotificationFilters,
  NotificationPage,
  NotificationPreference,
  NotificationPreferencePatch,
  PushEndpoint,
  PushEndpointInput,
  UnsubscribeResult,
  WebPushConfig,
} from './types';

/** Notifications per page of the center ("Load more" fetches the next cursor page). */
export const NOTIFICATION_PAGE_SIZE = 30;

/** How often the bell asks for the unread count while the tab is visible. */
export const UNREAD_POLL_MS = 60_000;

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

/**
 * Notification center, preferences, push registration and the public
 * unsubscribe endpoint. Notification titles and bodies are safe summaries
 * written by the server (no amounts); they are still rendered as text.
 */
export const notificationsApi = {
  list: async (
    filters: NotificationFilters,
    cursor: string,
    signal?: AbortSignal,
  ): Promise<NotificationPage> => {
    const envelope = await apiEnvelope(
      api.GET('/notifications', {
        params: {
          query: compactQuery({
            unread: filters.view === 'unread' ? true : undefined,
            archived: filters.view === 'archived' ? true : undefined,
            category: filters.category,
            cursor,
            limit: NOTIFICATION_PAGE_SIZE,
          }),
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
  /** The typed UnreadCount's `unread` (never below zero). */
  unreadCount: async (signal?: AbortSignal): Promise<number> => {
    const { unread } = await apiData(api.GET('/notifications/unread-count', signalOption(signal)));
    return Number.isFinite(unread) && unread > 0 ? unread : 0;
  },
  update: (id: string, body: { read?: boolean; archived?: boolean }): Promise<AppNotification> =>
    apiData(
      api.PATCH('/notifications/{notificationId}', {
        params: { path: { notificationId: id } },
        body,
      }),
    ),
  readAll: () => apiData(api.POST('/notifications/read-all')),
  preferences: (signal?: AbortSignal): Promise<NotificationPreference[]> =>
    apiData(api.GET('/notifications/preferences', signalOption(signal))),
  /** Each item changes only the fields it carries (`enabled`, `digest`); the rest stay as they are. */
  updatePreferences: (items: NotificationPreferencePatch[]): Promise<NotificationPreference[]> =>
    apiData(api.PATCH('/notifications/preferences', { body: { items } })),
  /** Account-level summary email (`off` sends optional emails as they happen). */
  updateEmailDigest: (emailDigest: EmailDigest): Promise<Preferences> =>
    apiData(api.PATCH('/me/preferences', { body: { email_digest: emailDigest } })),
  updateQuietHours: (body: {
    quiet_hours_enabled: boolean;
    quiet_hours_start: string;
    quiet_hours_end: string;
  }): Promise<Preferences> => apiData(api.PATCH('/me/preferences', { body })),
  /** Whether this server can send Web Push, and the public key to subscribe with. */
  pushConfig: async (signal?: AbortSignal): Promise<WebPushConfig> =>
    (await apiData(api.GET('/notifications/push-config', signalOption(signal)))).web_push,
  /** Browsers and devices registered for push, this session's marked `current_session`. */
  pushEndpoints: (signal?: AbortSignal): Promise<PushEndpoint[]> =>
    apiData(api.GET('/me/push-endpoints', signalOption(signal))),
  /** Registers (or re-registers) a push endpoint for this session and returns its ID. */
  registerPush: async (body: PushEndpointInput): Promise<string> => {
    const data = await apiData(api.POST('/me/push-endpoints', { body }));
    const id = data.id;
    if (!id) throw new Error('The API did not return a push endpoint ID.');
    return id;
  },
  removePush: (id: string) =>
    apiData(
      api.DELETE('/me/push-endpoints/{endpointId}', { params: { path: { endpointId: id } } }),
    ),
  /** Public: turns off one category of optional email from a signed link (no sign-in). */
  unsubscribe: (token: string): Promise<UnsubscribeResult> =>
    apiData(api.POST('/notifications/unsubscribe', { body: { token } })),
};

/**
 * The bell's unread count. Polls gently while the tab is visible, stops
 * while it is hidden, and refreshes when the tab is shown again.
 */
export function useUnreadCount() {
  const visible = usePageVisible();
  return useQuery({
    queryKey: notificationsKeys.unreadCount(),
    queryFn: ({ signal }) => notificationsApi.unreadCount(signal),
    refetchInterval: visible ? UNREAD_POLL_MS : false,
    refetchIntervalInBackground: false,
    refetchOnWindowFocus: true,
    staleTime: 30_000,
  });
}

/** Cursor pages of the notification center for one view and category. */
export function useNotificationList(filters: NotificationFilters) {
  return useInfiniteQuery({
    queryKey: notificationsKeys.list(filters),
    queryFn: ({ pageParam, signal }) => notificationsApi.list(filters, pageParam, signal),
    initialPageParam: '',
    getNextPageParam: (last) => last.nextCursor ?? undefined,
    staleTime: 30_000,
    refetchOnWindowFocus: true,
  });
}

/** Every category and channel preference (defaults merged in by the server). */
export function useNotificationPreferences() {
  return useQuery({
    queryKey: notificationsKeys.preferences(),
    queryFn: ({ signal }) => notificationsApi.preferences(signal),
  });
}

/** Whether browser notifications can be turned on at all (server VAPID keys). */
export function usePushConfig(enabled = true) {
  return useQuery({
    queryKey: notificationsKeys.pushConfig(),
    queryFn: ({ signal }) => notificationsApi.pushConfig(signal),
    staleTime: 5 * 60_000,
    enabled,
  });
}

/** The browsers and devices registered for push (this session's marked). */
export function usePushEndpoints(enabled = true) {
  return useQuery({
    queryKey: notificationsKeys.pushEndpoints(),
    queryFn: ({ signal }) => notificationsApi.pushEndpoints(signal),
    enabled,
  });
}
