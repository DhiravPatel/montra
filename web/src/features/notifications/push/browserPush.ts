/**
 * Browser (Web Push) plumbing for the opt-in on the notification settings
 * page. Nothing here runs until the user explicitly asks for browser
 * notifications: the service worker is registered and the permission
 * prompt is shown only from that click.
 *
 * The service worker (public/push-sw.js) only shows notifications and
 * opens their app path on click; it has no fetch handler and caches
 * nothing.
 */

/** The push service worker, served from the site root so its scope covers the app. */
export const PUSH_WORKER_URL = '/push-sw.js';

/** How long to wait for the service worker to become active before giving up. */
const WORKER_START_TIMEOUT_MS = 15_000;

/** The browser refused or dismissed the permission prompt. */
export class PushPermissionError extends Error {
  readonly permission: NotificationPermission;
  constructor(permission: NotificationPermission) {
    super(`Notification permission: ${permission}`);
    this.name = 'PushPermissionError';
    this.permission = permission;
  }
}

/** The service worker did not start (blocked, offline or too slow). */
export class PushWorkerError extends Error {
  constructor() {
    super('The push service worker did not start.');
    this.name = 'PushWorkerError';
  }
}

/** Montra only sends to known browser push services; this browser uses another one. */
export class PushServiceUnsupportedError extends Error {
  constructor() {
    super('This browser push service is not supported.');
    this.name = 'PushServiceUnsupportedError';
  }
}

/** Whether this browser can receive Web Push at all (service workers, PushManager, Notification). */
export function browserPushSupported(): boolean {
  return (
    typeof window !== 'undefined' &&
    'serviceWorker' in navigator &&
    'PushManager' in window &&
    'Notification' in window
  );
}

/**
 * Asks for permission. Call it directly from the click handler (some
 * browsers only show the prompt during a user gesture). Older Safari
 * versions only support the callback form.
 */
export function requestNotificationPermission(): Promise<NotificationPermission> {
  return new Promise((resolve, reject) => {
    try {
      const result = Notification.requestPermission(resolve) as
        Promise<NotificationPermission> | undefined;
      if (result) result.then(resolve, reject);
    } catch (error) {
      reject(error instanceof Error ? error : new Error(String(error)));
    }
  });
}

/** This browser's push subscription for Montra, if any (never registers anything). */
export async function findBrowserSubscription(): Promise<PushSubscription | null> {
  const registration = await navigator.serviceWorker.getRegistration('/');
  if (!registration) return null;
  return registration.pushManager.getSubscription();
}

async function activeRegistration(): Promise<ServiceWorkerRegistration> {
  await navigator.serviceWorker.register(PUSH_WORKER_URL, { scope: '/' });
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_resolve, reject) => {
    timer = setTimeout(() => {
      reject(new PushWorkerError());
    }, WORKER_START_TIMEOUT_MS);
  });
  try {
    return await Promise.race([navigator.serviceWorker.ready, timeout]);
  } finally {
    clearTimeout(timer);
  }
}

function sameKey(subscription: PushSubscription, key: Uint8Array): boolean {
  const current = subscription.options.applicationServerKey;
  if (!current) return false;
  const bytes = new Uint8Array(current);
  return bytes.length === key.length && bytes.every((byte, index) => byte === key[index]);
}

/**
 * Subscribes this browser with the server's VAPID key. An existing
 * subscription for the same key is reused; `fresh` replaces it (a new
 * endpoint, e.g. when the old one belongs to another Montra account).
 */
export async function subscribeBrowser(
  applicationServerKey: Uint8Array<ArrayBuffer>,
  { fresh = false }: { fresh?: boolean } = {},
): Promise<PushSubscription> {
  const registration = await activeRegistration();
  const existing = await registration.pushManager.getSubscription();
  if (existing) {
    if (!fresh && sameKey(existing, applicationServerKey)) return existing;
    await existing.unsubscribe();
  }
  return registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey });
}

/**
 * Decodes a base64url VAPID public key: an uncompressed P-256 point
 * (65 bytes starting with 0x04). Returns null for anything else.
 */
export function decodeVapidKey(value: string): Uint8Array<ArrayBuffer> | null {
  const trimmed = value.trim().replace(/=+$/, '');
  if (!/^[A-Za-z0-9_-]+$/.test(trimmed)) return null;
  const base64 = trimmed.replace(/-/g, '+').replace(/_/g, '/');
  let binary: string;
  try {
    binary = atob(base64 + '='.repeat((4 - (base64.length % 4)) % 4));
  } catch {
    return null;
  }
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
  return bytes.length === 65 && bytes[0] === 4 ? bytes : null;
}

/**
 * The key browsers subscribe with, from GET /notifications/push-config
 * (`web_push.vapid_public_key`, served only when `available`). Null when
 * the server cannot send browser notifications or its key is not a valid
 * P-256 point, so the page says so instead of pretending to work.
 */
export function serverPushKey(config: {
  available: boolean;
  vapid_public_key?: string | undefined;
}): Uint8Array<ArrayBuffer> | null {
  if (!config.available || !config.vapid_public_key) return null;
  return decodeVapidKey(config.vapid_public_key);
}

/** A short, non-identifying name for this browser ("Firefox on Windows"). */
export function deviceLabel(userAgent: string = navigator.userAgent): string {
  const has = (...needles: string[]) => needles.some((needle) => userAgent.includes(needle));
  let browser = 'Browser';
  if (has('Edg/')) browser = 'Edge';
  else if (has('OPR/')) browser = 'Opera';
  else if (has('Firefox/')) browser = 'Firefox';
  else if (has('Chrome/')) browser = 'Chrome';
  else if (has('Safari/')) browser = 'Safari';
  let system = '';
  if (has('Android')) system = 'Android';
  else if (has('iPhone', 'iPad', 'iPod')) system = 'iOS';
  else if (has('Mac OS X')) system = 'macOS';
  else if (has('Windows')) system = 'Windows';
  else if (has('CrOS')) system = 'ChromeOS';
  else if (has('Linux')) system = 'Linux';
  return system ? `${browser} on ${system}` : browser;
}
