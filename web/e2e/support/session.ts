import { type APIResponse, expect, type Locator, type Page } from '@playwright/test';

/**
 * Throwaway users and API shortcuts for journeys against the local Go API.
 * Each spec creates its own users (never shared between specs), so specs stay
 * independent. Setup that is not the subject of a journey goes through the
 * API; the behaviour under test goes through the UI.
 */
export const PASSWORD = 'quiet-harbor-71-e2e';

export interface TestUser {
  email: string;
  password: string;
  name: string;
  id: string;
}

let sequence = 0;

/** `e2e.<timestamp>.<tag><n>@example.com`, unique per call. */
export function uniqueEmail(tag: string): string {
  sequence += 1;
  return `e2e.${Date.now()}.${tag}${sequence}@example.com`;
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * The API limits sign-up/sign-in to ~10 a minute per IP (rate policy
 * "auth"). Many journeys on three projects exceed that, so wait out a 429 the
 * way a client honouring Retry-After would.
 */
export async function honourRateLimit(send: () => Promise<APIResponse>): Promise<APIResponse> {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const response = await send();
    if (response.status() !== 429) return response;
    const retryAfter = Number(response.headers()['retry-after'] ?? '6');
    await sleep((Number.isFinite(retryAfter) ? retryAfter : 6) * 1000 + 250);
  }
  throw new Error('Still rate limited after 20 attempts');
}

async function csrfToken(page: Page): Promise<string> {
  const cookie = (await page.context().cookies()).find((item) => item.name === 'montra_csrf');
  return cookie ? decodeURIComponent(cookie.value) : '';
}

/** Calls the API as the browser's signed-in user (cookies + CSRF), returns `data`. */
export async function api<T = unknown>(
  page: Page,
  method: 'GET' | 'POST' | 'PATCH' | 'DELETE',
  path: string,
  data?: unknown,
): Promise<T> {
  const headers: Record<string, string> = { 'X-Montra-Client': 'web' };
  if (method !== 'GET') {
    headers['X-CSRF-Token'] = await csrfToken(page);
    headers['Idempotency-Key'] = `e2e-${crypto.randomUUID()}`;
  }
  const response = await honourRateLimit(() =>
    page.request.fetch(`/api/v1${path}`, {
      method,
      headers,
      ...(data === undefined ? {} : { data }),
    }),
  );
  const text = await response.text();
  expect(response.ok(), `${method} ${path} → ${response.status()} ${text}`).toBe(true);
  return (text ? (JSON.parse(text) as { data: T }).data : undefined) as T;
}

interface NewUserOptions {
  name?: string;
  currency?: string;
  country?: string;
  /** Mark the optional setup as done so pages open directly (default true). */
  onboard?: boolean;
}

/**
 * Registers a user through the API (the dev API verifies email automatically),
 * then signs this browser context in as that user.
 */
export async function newUser(
  page: Page,
  tag: string,
  { name = 'E2E Person', currency = 'INR', country = 'IN', onboard = true }: NewUserOptions = {},
): Promise<TestUser> {
  const email = uniqueEmail(tag);
  const register = await honourRateLimit(() =>
    page.request.post('/api/v1/auth/register', {
      headers: { 'X-Montra-Client': 'web' },
      data: {
        email,
        password: PASSWORD,
        display_name: name,
        accept_terms: true,
        confirm_adult: true,
        terms_version: '2026-11-01',
        privacy_version: '2026-11-01',
        currency,
        country,
        timezone: 'Asia/Kolkata',
        locale: 'en-IN',
      },
    }),
  );
  expect(register.status(), await register.text()).toBe(202);
  const user = await signInWithApi(page, { email, password: PASSWORD, name, id: '' });
  if (onboard) {
    await api(page, 'POST', '/me/onboarding', {
      completed_steps: [],
      skipped_steps: [],
      complete: true,
    });
  }
  return user;
}

/** Signs this browser context in (session cookies set by the API response). */
export async function signInWithApi(page: Page, user: TestUser): Promise<TestUser> {
  const login = await honourRateLimit(() =>
    page.request.post('/api/v1/auth/login', {
      headers: { 'X-Montra-Client': 'web' },
      data: { email: user.email, password: user.password },
    }),
  );
  const body = await login.text();
  expect(login.status(), body).toBe(200);
  const id = (JSON.parse(body) as { data: { user: { id: string } } }).data.user.id;
  return { ...user, id };
}

/**
 * Clicks a button that submits to a rate-limited auth endpoint. When the API
 * answers 429 the form shows the rate-limit message; wait as told (as a
 * person would) and submit again. The auth forms clear the password after a
 * failed attempt, so `refill` re-enters what was cleared before each retry.
 */
export async function submitHonouringRateLimit(
  page: Page,
  button: Locator,
  endpoint: `/api/v1/${string}`,
  refill: () => Promise<void> = () => Promise.resolve(),
): Promise<void> {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    if (attempt > 0) await refill();
    const [response] = await Promise.all([
      page.waitForResponse(
        (item) => item.url().endsWith(endpoint) && item.request().method() === 'POST',
      ),
      button.click(),
    ]);
    if (response.status() !== 429) return;
    const retryAfter = Number(response.headers()['retry-after'] ?? '6');
    await sleep((Number.isFinite(retryAfter) ? retryAfter : 6) * 1000 + 250);
  }
  throw new Error(`${endpoint} still rate limited after 20 attempts`);
}

/** Signs in through the sign-in form, waiting out the auth rate limit. */
export async function signInWithForm(page: Page, user: Pick<TestUser, 'email' | 'password'>) {
  await page.goto('/sign-in');
  await page.getByLabel('Email').fill(user.email);
  const password = page.getByLabel('Password', { exact: true });
  await password.fill(user.password);
  await submitHonouringRateLimit(
    page,
    page.getByRole('button', { name: 'Sign in' }),
    '/api/v1/auth/login',
    () => password.fill(user.password),
  );
}

/** The page's single h1. */
export function pageHeading(page: Page, name: string | RegExp) {
  return page.getByRole('heading', { level: 1, name });
}

/**
 * Follows a main-navigation destination the way a person would at this
 * viewport: the sidebar (md and up), else the bottom tab bar, else "More".
 */
export async function navigateTo(page: Page, name: string) {
  const nav = page.getByRole('navigation', { name: 'Main' });
  const link = nav.getByRole('link', { name, exact: true });
  if (await link.isVisible()) {
    await link.click();
    return;
  }
  await nav.getByRole('button', { name: 'More' }).click();
  await page.getByRole('menuitem', { name, exact: true }).click();
}

/** Today in the API user's timezone (journeys register users in Asia/Kolkata). */
export function todayInKolkata(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata' }).format(new Date());
}
