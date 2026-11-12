import AxeBuilder from '@axe-core/playwright';
import type { Page } from '@playwright/test';
import { expect, test } from './support/test';
import { openPeerPage } from './support/community';
import { api, newUser, todayInKolkata } from './support/session';

/**
 * Browser-level accessibility checks on the real app against the local API
 * (§16; WEB-010, WEB-011, A11Y-001): axe (WCAG 2.x A/AA, including colour
 * contrast, which jsdom cannot check) on the main pages in light and dark
 * themes, no horizontal scrolling at the project's width (phone, tablet,
 * desktop), and reduced motion. Component-level axe runs live in
 * src/tests/a11y.
 */

const WCAG = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'];

interface AxeScope {
  /** Only check inside this selector. */
  include?: string;
  /** Rules known to fail on this page, each with a reported reason. */
  knownIssues?: string[];
}

async function axeViolations(page: Page, { include, knownIssues = [] }: AxeScope = {}) {
  let builder = new AxeBuilder({ page }).withTags(WCAG);
  if (include) builder = builder.include(include);
  if (knownIssues.length > 0) builder = builder.disableRules(knownIssues);
  const results = await builder.analyze();
  return results.violations.map(
    (violation) =>
      `${violation.id} (${violation.impact ?? 'n/a'}): ${violation.help}\n    ` +
      violation.nodes
        .slice(0, 6)
        .map((node) => `${node.target.join(' ')} — ${node.html.slice(0, 600)}`)
        .join('\n    '),
  );
}

/** The page fits the viewport: nothing forces sideways scrolling. */
async function horizontalOverflow(page: Page): Promise<number> {
  return page.evaluate(
    () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
  );
}

/** Waits until the page has its h1 and no loading indicators. */
async function settle(page: Page) {
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await page.waitForLoadState('networkidle');
  await expect(page.locator('[aria-busy="true"]')).toHaveCount(0);
}

async function checkPage(page: Page, path: string, scope: AxeScope = {}) {
  await page.goto(path);
  await settle(page);
  expect.soft(await axeViolations(page, scope), `axe on ${path}`).toEqual([]);
  expect.soft(await horizontalOverflow(page), `horizontal overflow on ${path} (px)`).toBe(0);
}

const PUBLIC_PAGES = ['/', '/sign-in', '/sign-up', '/forgot-password', '/privacy', '/terms'];

for (const theme of ['light', 'dark'] as const) {
  test(`public pages pass axe and fit the screen (${theme})`, async ({ page }) => {
    await page.addInitScript((value) => {
      window.localStorage.setItem('montra.theme', value);
    }, theme);
    for (const path of PUBLIC_PAGES) await checkPage(page, path);
  });
}

interface Created {
  id: string;
}

/** One user with something on every main page (API setup only). */
async function seed(page: Page, peer: Page) {
  const me = await newUser(page, 'a11y', { name: 'E2E Access' });
  const friend = await newUser(peer, 'a11ypeer', { name: 'E2E Friend' });
  const today = todayInKolkata();
  const account = await api<Created>(page, 'POST', '/accounts', {
    name: 'Everyday account',
    account_type: 'bank',
    currency: 'INR',
    opening_balance: '25000.00',
  });
  const created = await api<{ transaction: Created }>(page, 'POST', '/transactions', {
    type: 'expense',
    account_id: account.id,
    amount: '1250.50',
    merchant_name: 'Big Bazaar',
    local_date: today,
  });
  await api(page, 'POST', '/transactions', {
    type: 'income',
    account_id: account.id,
    amount: '50000',
    description: 'Salary',
    local_date: today,
  });
  await api(page, 'POST', '/budgets', {
    name: 'Monthly spending',
    budget_type: 'total',
    period: 'monthly',
    currency: 'INR',
    limit: '20000',
    starts_on: today,
  });
  const goal = await api<Created>(page, 'POST', '/goals', {
    name: 'Emergency fund',
    goal_type: 'emergency_fund',
    target_amount: '100000',
  });
  await api(page, 'POST', '/subscriptions', {
    name: 'Music',
    amount: '119',
    billing_frequency: 'monthly',
    start_date: today,
  });
  const group = await api<Created>(page, 'POST', '/groups', {
    name: 'Flat 4B',
    group_type: 'household',
    base_currency: 'INR',
    timezone: 'Asia/Kolkata',
    default_split_method: 'equal',
    simplify_debts: true,
    allow_member_invites: false,
    require_join_approval: false,
  });
  const invitation = await api<{ token: string }>(page, 'POST', `/groups/${group.id}/invitations`, {
    kind: 'link',
    expires_in_days: 1,
  });
  await api(peer, 'POST', '/group-invitations/accept', { token: invitation.token });
  await api(page, 'POST', `/groups/${group.id}/expenses`, {
    description: 'Electricity',
    amount: '1800',
    split_method: 'equal',
    participants: [{ user_id: me.id }, { user_id: friend.id }],
    payers: [{ user_id: me.id, amount: '1800' }],
  });
  await api(page, 'POST', '/communities', {
    name: `E2E Access ${Date.now().toString(36)}`,
    visibility: 'public',
    description: 'Accessible money talk.',
  });
  return { transactionId: created.transaction.id, goalId: goal.id, groupId: group.id };
}

for (const theme of ['light', 'dark'] as const) {
  test(`signed-in pages pass axe and fit the screen (${theme})`, async ({
    page,
    browser,
  }, testInfo) => {
    test.setTimeout(300_000);
    await page.addInitScript((value) => {
      window.localStorage.setItem('montra.theme', value);
    }, theme);
    const peer = await openPeerPage(browser, testInfo);
    const { transactionId, goalId, groupId } = await seed(page, peer).finally(() =>
      peer.context().close(),
    );

    const pages = [
      '/dashboard',
      '/transactions',
      '/transactions/new',
      `/transactions/${transactionId}`,
      '/accounts',
      '/accounts/new',
      '/budgets',
      '/budgets/new',
      '/planning',
      '/goals',
      `/goals/${goalId}`,
      '/subscriptions',
      '/receipts',
      '/imports',
      '/imports/new',
      '/analytics',
      '/reports',
      '/groups',
      `/groups/${groupId}`,
      `/groups/${groupId}/expenses/new`,
      `/groups/${groupId}/balances`,
      '/communities',
      '/notifications',
      '/settings/security',
      '/settings/privacy',
      '/settings/exchange-rates',
      '/help',
    ];
    for (const path of pages) await checkPage(page, path);
  });
}

test('field errors and an open dialog pass axe', async ({ page }) => {
  await newUser(page, 'a11yforms', { name: 'E2E Forms' });
  await api(page, 'POST', '/accounts', {
    name: 'Wallet',
    account_type: 'cash',
    currency: 'INR',
    opening_balance: '100.00',
  });

  // A submitted empty form: errors are tied to their fields.
  await page.goto('/transactions/new');
  await settle(page);
  await page.getByRole('button', { name: 'Save transaction' }).click();
  await expect(page.getByLabel('Amount')).toHaveAttribute('aria-invalid', 'true');
  await expect(page.getByLabel('Amount')).toBeFocused();
  expect.soft(await axeViolations(page), 'axe with field errors').toEqual([]);

  // The account menu (Radix) and a modal dialog.
  await page.getByRole('button', { name: 'Account menu' }).click();
  await expect(page.getByRole('menu')).toBeVisible();
  // The open menu itself. Radix hides the rest of the page from assistive
  // technology while the menu is open (aria-hidden on the app root) and keeps
  // focus in the menu, so the page behind is checked separately above.
  expect
    .soft(await axeViolations(page, { include: '[role="menu"]' }), 'axe on the open account menu')
    .toEqual([]);
  await page.keyboard.press('Escape');
  await expect(page.getByRole('menu')).toHaveCount(0);

  await page.goto('/reports');
  await settle(page);
  await page.getByRole('button', { name: 'New report' }).first().click();
  const dialog = page.getByRole('dialog', { name: 'New report' });
  await expect(dialog).toBeVisible();
  expect.soft(await axeViolations(page), 'axe with a dialog open').toEqual([]);
  // Focus is trapped in the dialog and returns to the trigger on close.
  await page.keyboard.press('Escape');
  await expect(dialog).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'New report' }).first()).toBeFocused();
});

test.describe('reduced motion', () => {
  async function buttonTransition(page: Page) {
    return page.getByRole('button', { name: 'Sign in' }).evaluate((element) => {
      const style = getComputedStyle(element);
      return { property: style.transitionProperty, duration: style.transitionDuration };
    });
  }

  test('transitions run normally without the setting', async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await page.goto('/sign-in');
    const transition = await buttonTransition(page);
    expect(transition.property).toContain('color');
    expect(transition.duration).not.toMatch(/^0s$/);
  });

  test('prefers-reduced-motion turns transitions and animations off', async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto('/sign-in');
    await expect(page.getByRole('heading', { level: 1, name: 'Sign in' })).toBeVisible();
    // Buttons animate their colours (transition-colors motion-reduce:transition-none).
    const transition = await buttonTransition(page);
    expect(transition.property).toBe('none');

    // Loading spinners and skeletons stop spinning/pulsing: hold the session check.
    let release: () => void = () => undefined;
    const held = new Promise<void>((resolve) => {
      release = resolve;
    });
    await page.route('**/api/v1/auth/session', async (route) => {
      await held;
      await route.continue();
    });
    await page.goto('/dashboard');
    const animated = page.locator('.animate-spin, .animate-pulse').first();
    await expect(animated).toBeAttached();
    // motion-reduce:animate-none removes the animation outright.
    expect(await animated.evaluate((element) => getComputedStyle(element).animationName)).toBe(
      'none',
    );
    release();
  });
});
