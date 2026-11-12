import { http, HttpResponse } from 'msw';
import { vi } from 'vitest';
import type {
  AppNotification,
  NotificationPreference,
  PushEndpoint,
  WebPushConfig,
} from '@/features/notifications/types';
import { API, envelope, errorBody, meta } from './fixtures';
import { server } from './msw/server';

export const NOTIFICATION_GOAL = 'a1f0c3e2-1111-4a2b-8c3d-000000000001';
export const NOTIFICATION_SECURITY = 'a1f0c3e2-1111-4a2b-8c3d-000000000002';
export const NOTIFICATION_BILL = 'a1f0c3e2-1111-4a2b-8c3d-000000000003';
export const NOTIFICATION_EXPENSE = 'a1f0c3e2-1111-4a2b-8c3d-000000000004';
export const GOAL_ID = 'b2e1d4f3-2222-4b3c-9d4e-000000000010';
export const BILL_ID = 'b2e1d4f3-2222-4b3c-9d4e-000000000011';
export const GROUP_ID = 'b2e1d4f3-2222-4b3c-9d4e-000000000012';
export const EXPENSE_ID = 'b2e1d4f3-2222-4b3c-9d4e-000000000013';
export const PUSH_ENDPOINT_ID = 'c3f2e5a4-3333-4c4d-8e5f-000000000020';
export const PHONE_ENDPOINT_ID = 'c3f2e5a4-3333-4c4d-8e5f-000000000021';
export const OLD_ENDPOINT_ID = 'c3f2e5a4-3333-4c4d-8e5f-000000000022';
export const SUPPORT_REQUEST_ID = 'd4e5f6a7-4444-4d5e-8f60-000000000031';

/** A goal milestone notification (unread), shaped like GET /notifications items. */
export function makeNotification(overrides: Partial<AppNotification> = {}): AppNotification {
  return {
    id: NOTIFICATION_GOAL,
    category: 'goal',
    event_type: 'goal_milestone',
    title: 'Emergency fund reached 50%',
    body: 'Open the goal to see progress.',
    deep_link: `/goals/${GOAL_ID}`,
    entity_type: 'goal',
    entity_id: GOAL_ID,
    priority: 'normal',
    created_at: '2026-11-04T09:00:00Z',
    ...overrides,
  };
}

export function securityNotification(overrides: Partial<AppNotification> = {}): AppNotification {
  return {
    id: NOTIFICATION_SECURITY,
    category: 'security',
    event_type: 'security.password_changed',
    title: 'Your password was changed',
    body: 'If this wasn’t you, reset your password and review your signed-in devices.',
    deep_link: '/settings/security',
    priority: 'high',
    read_at: '2026-11-04T08:00:00Z',
    created_at: '2026-11-04T07:30:00Z',
    ...overrides,
  };
}

/** A staff reply on a support request (category account, event support_reply). */
export function supportReplyNotification(
  overrides: Partial<AppNotification> = {},
): AppNotification {
  return {
    id: 'a1f0c3e2-1111-4a2b-8c3d-000000000005',
    category: 'account',
    event_type: 'support_reply',
    title: 'Support replied to request D4E5F6A7',
    body: 'Open the request to read the reply.',
    deep_link: `/help/requests/${SUPPORT_REQUEST_ID}`,
    entity_type: 'support_request',
    entity_id: SUPPORT_REQUEST_ID,
    priority: 'normal',
    created_at: '2026-11-04T09:30:00Z',
    ...overrides,
  };
}

/** A list page envelope with cursor metadata like the API's. */
export function notificationPage(items: AppNotification[], nextCursor?: string) {
  return {
    data: items,
    meta: {
      ...meta(),
      has_more: Boolean(nextCursor),
      ...(nextCursor ? { next_cursor: nextCursor } : {}),
    },
  };
}

/** Serves GET /notifications/unread-count; `counts` are returned in order (the last repeats). */
export function serveUnreadCount(...counts: number[]) {
  const state = { calls: 0 };
  server.use(
    http.get(`${API}/notifications/unread-count`, () => {
      const unread = counts[Math.min(state.calls, counts.length - 1)] ?? 0;
      state.calls += 1;
      return HttpResponse.json(envelope({ unread }));
    }),
  );
  return state;
}

const CATEGORIES = [
  'budget',
  'bill',
  'subscription',
  'recurring',
  'goal',
  'group',
  'settlement',
  'trip',
  'community',
  'challenge',
  'security',
  'import',
  'receipt',
  'export',
  'account',
  'insight',
  'system',
  'social',
] as const;
const CHANNELS = ['in_app', 'email', 'web_push', 'push'] as const;
const EMAIL_DEFAULT = new Set(['security', 'account', 'export']);
const ALWAYS_ON = new Set(['security', 'account']);

/**
 * GET /notifications/preferences as the server builds it: every category
 * and channel, defaults merged in, security/account in-app and email
 * locked on. `changes` overrides rows by `category|channel`.
 */
export function makeNotificationPreferences(
  changes: Readonly<Record<string, Partial<NotificationPreference>>> = {},
): NotificationPreference[] {
  const rows: NotificationPreference[] = [];
  for (const category of CATEGORIES) {
    for (const channel of CHANNELS) {
      const locked = ALWAYS_ON.has(category) && (channel === 'in_app' || channel === 'email');
      rows.push({
        category,
        channel,
        enabled: channel !== 'email' || EMAIL_DEFAULT.has(category),
        digest: 'immediate',
        locked,
        ...changes[`${category}|${channel}`],
      });
    }
  }
  return rows;
}

/** A valid base64url VAPID public key (65-byte uncompressed point) for tests. */
export const TEST_VAPID_KEY =
  'BAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0-P0A';

/** Serves GET /notifications/push-config (available with the test key unless overridden). */
export function servePushConfig(config: Partial<WebPushConfig> = {}) {
  const webPush: WebPushConfig = { available: true, vapid_public_key: TEST_VAPID_KEY, ...config };
  server.use(
    http.get(`${API}/notifications/push-config`, () =>
      HttpResponse.json(envelope({ web_push: webPush })),
    ),
  );
}

/** This browser's registration for the current session, as GET /me/push-endpoints lists it. */
export function makePushEndpoint(overrides: Partial<PushEndpoint> = {}): PushEndpoint {
  return {
    id: PUSH_ENDPOINT_ID,
    kind: 'webpush',
    device_label: 'Chrome on macOS',
    created_at: '2026-11-04T09:00:00Z',
    last_used_at: '2026-11-04T10:00:00Z',
    current_session: true,
    ...overrides,
  };
}

/**
 * Serves GET /me/push-endpoints from a mutable list and DELETE
 * /me/push-endpoints/{id} against it (404 once gone), recording deletes.
 */
export function servePushEndpoints(initial: PushEndpoint[]) {
  const state = { endpoints: initial, deleted: [] as string[] };
  server.use(
    http.get(`${API}/me/push-endpoints`, () => HttpResponse.json(envelope(state.endpoints))),
    http.delete(`${API}/me/push-endpoints/:id`, ({ params }) => {
      const id = String(params.id);
      state.deleted.push(id);
      if (!state.endpoints.some((endpoint) => endpoint.id === id)) {
        return HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 });
      }
      state.endpoints = state.endpoints.filter((endpoint) => endpoint.id !== id);
      return HttpResponse.json(envelope({}));
    }),
  );
  return state;
}

function base64url(text: string): string {
  return btoa(text).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** An unsubscribe token shaped like the server's: base64url(user|category|expiry).signature. */
export function makeUnsubscribeToken(category = 'goal'): string {
  const payload = base64url(`7c9e6679-7425-40de-944b-e07fc1f90ae7|${category}|1893456000`);
  return `${payload}.Qm9ndXMtc2lnbmF0dXJlLWZvci10ZXN0cy1vbmx5LTAx`;
}

interface FakePushOptions {
  /** Notification.permission before anything happens. */
  permission?: NotificationPermission;
  /** What the permission prompt answers. */
  answer?: NotificationPermission;
  /** This browser already has a registered worker and a push subscription. */
  subscribed?: boolean;
}

export interface FakeSubscriptionJSON {
  endpoint: string;
  expirationTime: null;
  keys: { p256dh: string; auth: string };
}

/**
 * Installs a fake service worker container, PushManager and Notification
 * (jsdom has none). Endpoints are on a real push service host so the
 * payload looks like a browser's.
 */
export function installFakePush({
  permission = 'default',
  answer = 'granted',
  subscribed = false,
}: FakePushOptions = {}) {
  let counter = 0;
  const state: {
    registered: boolean;
    subscription: ReturnType<typeof makeSubscription> | null;
    unsubscribed: string[];
  } = { registered: subscribed, subscription: null, unsubscribed: [] };

  function makeSubscription(key: ArrayBuffer | null) {
    counter += 1;
    const endpoint = `https://fcm.googleapis.com/fcm/send/test-endpoint-${counter}`;
    const subscription = {
      endpoint,
      options: { applicationServerKey: key, userVisibleOnly: true },
      toJSON: (): FakeSubscriptionJSON => ({
        endpoint,
        expirationTime: null,
        keys: {
          p256dh:
            'BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkM',
          auth: 'tBHItJI5svbpez7KI4CCXg',
        },
      }),
      unsubscribe: vi.fn(() => {
        state.unsubscribed.push(endpoint);
        if (state.subscription?.endpoint === endpoint) state.subscription = null;
        return Promise.resolve(true);
      }),
    };
    return subscription;
  }

  const keyBytes = Uint8Array.from(
    atob(TEST_VAPID_KEY.replace(/-/g, '+').replace(/_/g, '/') + '='),
    (char) => char.charCodeAt(0),
  ).buffer;
  if (subscribed) state.subscription = makeSubscription(keyBytes);

  const pushManager = {
    getSubscription: vi.fn(() => Promise.resolve(state.subscription)),
    subscribe: vi.fn((options: { applicationServerKey: Uint8Array }) => {
      state.subscription = makeSubscription(new Uint8Array(options.applicationServerKey).buffer);
      return Promise.resolve(state.subscription);
    }),
  };
  const registration = { pushManager, scope: 'http://localhost:5173/' };
  const serviceWorker = {
    register: vi.fn(() => {
      state.registered = true;
      return Promise.resolve(registration);
    }),
    ready: Promise.resolve(registration),
    getRegistration: vi.fn(() => Promise.resolve(state.registered ? registration : undefined)),
  };
  const notification = {
    permission,
    requestPermission: vi.fn(() => {
      notification.permission = answer;
      return Promise.resolve(answer);
    }),
  };
  Object.defineProperty(navigator, 'serviceWorker', { configurable: true, value: serviceWorker });
  vi.stubGlobal('PushManager', function PushManager() {
    // presence check only
  });
  vi.stubGlobal('Notification', notification);

  return {
    state,
    serviceWorker,
    pushManager,
    notification,
    uninstall: () => {
      Reflect.deleteProperty(navigator, 'serviceWorker');
      vi.unstubAllGlobals();
    },
  };
}
