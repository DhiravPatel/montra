import {
  type APIResponse,
  type Browser,
  type BrowserContextOptions,
  expect,
  type Page,
  type TestInfo,
} from '@playwright/test';
import { api, honourRateLimit } from './session';
import { retryRateLimitedReads } from './test';

/**
 * Helpers for the community journeys: a second person in their own browser
 * context (same device as the project), unique names, raw API answers for
 * asserting denials, and waiting for notifications the API worker creates.
 */

let counter = 0;

/** Lowercase letters and digits, unique per call (usable in names and usernames). */
export function runStamp(): string {
  counter += 1;
  return `${Date.now().toString(36)}${counter}`;
}

/** The project's device settings (viewport, touch, user agent…) for another context. */
export function projectContextOptions(testInfo: TestInfo): BrowserContextOptions {
  const use = testInfo.project.use;
  return {
    baseURL: use.baseURL,
    viewport: use.viewport,
    userAgent: use.userAgent,
    deviceScaleFactor: use.deviceScaleFactor,
    isMobile: use.isMobile,
    hasTouch: use.hasTouch,
    locale: use.locale,
    timezoneId: use.timezoneId,
  };
}

/** A fresh, signed-out page in a new context on the same device as the project. */
export async function openPeerPage(browser: Browser, testInfo: TestInfo): Promise<Page> {
  const context = await browser.newContext(projectContextOptions(testInfo));
  await retryRateLimitedReads(context);
  return context.newPage();
}

async function csrfToken(page: Page): Promise<string> {
  const cookie = (await page.context().cookies()).find((item) => item.name === 'montra_csrf');
  return cookie ? decodeURIComponent(cookie.value) : '';
}

/** Calls the API as the page's user and returns the raw response (for asserting refusals). */
export async function apiResponse(
  page: Page,
  method: 'GET' | 'POST',
  path: string,
  data?: unknown,
): Promise<APIResponse> {
  const headers: Record<string, string> = { 'X-Montra-Client': 'web' };
  if (method !== 'GET') {
    headers['X-CSRF-Token'] = await csrfToken(page);
    headers['Idempotency-Key'] = `e2e-${crypto.randomUUID()}`;
  }
  return honourRateLimit(() =>
    page.request.fetch(`/api/v1${path}`, {
      method,
      headers,
      ...(data === undefined ? {} : { data }),
    }),
  );
}

interface AppNotification {
  id: string;
  title: string;
  read_at?: string | null;
  deep_link?: string;
}

/**
 * Waits until the API worker has created a notification with this title for
 * the page's user (notifications are written asynchronously from the outbox).
 */
export async function waitForNotification(page: Page, title: string): Promise<AppNotification> {
  let found: AppNotification | undefined;
  await expect
    .poll(
      async () => {
        const items = await api<AppNotification[]>(page, 'GET', '/notifications?limit=50');
        found = items.find((item) => item.title === title);
        return found ? 'created' : 'missing';
      },
      { message: `notification “${title}”`, timeout: 60_000 },
    )
    .toBe('created');
  if (!found) throw new Error(`Notification “${title}” not found`);
  return found;
}

export async function unreadCount(page: Page): Promise<number> {
  const { unread } = await api<{ unread: number }>(page, 'GET', '/notifications/unread-count');
  return unread;
}

/**
 * The notification bell in the sidebar (md and up) or the phone header, once
 * it knows the unread count ("Notifications, …"); the settings link in the
 * navigation is plainly "Notifications".
 */
export function notificationBell(page: Page) {
  return page.getByRole('link', { name: /^Notifications, / });
}

/** The bell's accessible name for an unread count. */
export function bellName(count: number): string {
  return count === 0 ? 'Notifications, none unread' : `Notifications, ${String(count)} unread`;
}

/** A local calendar date `days` after `date` (YYYY-MM-DD). */
export function addDays(date: string, days: number): string {
  const next = new Date(`${date}T00:00:00Z`);
  next.setUTCDate(next.getUTCDate() + days);
  return next.toISOString().slice(0, 10);
}

/** The community ID from a `/communities/<id>` URL. */
export function communityIdFrom(page: Page): string {
  const id = /\/communities\/([0-9a-f-]{36})/u.exec(page.url())?.[1];
  if (!id) throw new Error(`No community ID in ${page.url()}`);
  return id;
}
