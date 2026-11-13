import type { Page } from '@playwright/test';
import { expect, test } from './support/test';
import { waitForEmailLink } from './support/devMailbox';
import { signInWithForm, submitHonouringRateLimit } from './support/session';

/**
 * Planning journey against the local Go API: a budget that counts a real
 * expense, a bill paid from Montra and shown on the calendar, a savings goal
 * with a contribution, a subscription with its normalized cost, and a
 * category created from the Categories area, then the dashboard's alert,
 * renewal and recurring cards. Creates a throwaway account in the
 * development database.
 * Run with: PW_CHANNEL=chrome pnpm e2e
 */
test.describe.configure({ mode: 'serial' });

const email = `e2e.${Date.now()}.plan@example.com`;
const password = 'quiet-harbor-71-e2e';

async function signIn(page: Page) {
  // Waits out the API's sign-in rate limit when all projects run back to back.
  await signInWithForm(page, { email, password });
}

function pageHeading(page: Page, name: string | RegExp) {
  return page.getByRole('heading', { level: 1, name });
}

test('plan ahead: budget, bill, calendar, goal, subscription and categories', async ({ page }) => {
  test.setTimeout(240_000);

  // Sign up (verification is skipped when the dev API auto-verifies emails).
  await page.goto('/sign-up');
  await page.getByLabel('Display name').fill('E2E Planner');
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('New password').fill(password);
  await page.getByLabel('Main currency').selectOption('INR');
  await page.getByLabel(/I agree to the/).check();
  await page.getByLabel(/18 years of age or older/).check();
  await submitHonouringRateLimit(
    page,
    page.getByRole('button', { name: 'Create account' }),
    '/api/v1/auth/register',
    () => page.getByLabel('New password').fill(password),
  );
  await expect(pageHeading(page, 'Check your email')).toBeVisible();
  const link = await waitForEmailLink(email, '/verify-email', 8_000).catch(() => null);
  if (link) {
    const url = new URL(link);
    await page.goto(url.pathname + url.hash);
    await expect(page.getByText('Your email is verified')).toBeVisible();
  }

  // Skip the optional setup, then add an account and one expense.
  await signIn(page);
  await expect(pageHeading(page, 'Set up Montra')).toBeVisible();
  await page.getByRole('button', { name: 'Skip setup' }).click();
  await expect(pageHeading(page, 'Home')).toBeVisible();

  await page.goto('/accounts/new');
  await page.getByLabel('Account name').fill('Wallet');
  await page.getByLabel('Account type').selectOption('cash');
  await page.getByLabel(/^Current balance/).fill('20000');
  await page.getByRole('button', { name: 'Add account' }).click();
  await expect(pageHeading(page, 'Wallet')).toBeVisible();

  await page.goto('/transactions/new');
  await expect(page.getByLabel('Account', { exact: true })).toHaveValue(/[0-9a-f-]{36}/);
  await page.getByLabel('Amount').fill('700');
  await page.getByLabel(/^Category/).selectOption({ label: 'Groceries' });
  await page.getByLabel(/^Merchant or payee/).fill('Big Bazaar');
  await page.getByRole('button', { name: 'Save transaction' }).click();
  await expect(pageHeading(page, 'Big Bazaar')).toBeVisible();

  // A monthly budget counts the expense (server progress, not client math).
  await page.goto('/budgets/new');
  await expect(pageHeading(page, 'Create a budget')).toBeVisible();
  await page.getByLabel('Name', { exact: true }).fill('Monthly spending');
  await page.getByRole('radio', { name: /^Overall/ }).check();
  await page.getByLabel('Period', { exact: true }).selectOption('monthly');
  await page.getByLabel(/^Limit for each period/).fill('1000');
  await page.getByRole('button', { name: 'Create budget' }).click();
  await expect(pageHeading(page, 'Monthly spending')).toBeVisible();
  await expect(page.getByText('₹700.00 of ₹1,000.00 spent').first()).toBeVisible();
  await page.goto('/budgets');
  await expect(page.getByRole('link', { name: 'Monthly spending' })).toBeVisible();

  // A bill, paid by recording the payment from Montra.
  await page.goto('/planning/bills/new');
  await expect(pageHeading(page, 'Add a bill')).toBeVisible();
  await page.getByLabel(/^Bill name/).fill('Electricity');
  await page.getByLabel(/^Usually paid from/).selectOption({ label: 'Wallet (INR)' });
  await page.getByLabel(/^Expected amount/).fill('1200');
  await page.getByRole('button', { name: 'Add bill' }).click();
  await expect(pageHeading(page, 'Electricity')).toBeVisible();
  await page.getByRole('button', { name: 'Mark paid' }).first().click();
  const markPaid = page.getByRole('dialog');
  await markPaid.getByLabel(/Record a new payment/).check();
  await markPaid.getByRole('button', { name: 'Continue' }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'Record payment' }).click();
  await expect(page.getByText('“Electricity” marked as paid')).toBeVisible();

  // The calendar lists what is coming up, linking back to the bill.
  await page.goto('/planning');
  await expect(page.getByRole('link', { name: 'Electricity' }).first()).toBeVisible();

  // A savings goal with a recorded contribution.
  await page.goto('/goals/new');
  await expect(pageHeading(page, 'New goal')).toBeVisible();
  await page.getByLabel('Name', { exact: true }).fill('Goa trip');
  await page.getByLabel('Type', { exact: true }).selectOption('travel');
  await page.getByLabel(/^Target amount/).fill('60000');
  await page.getByRole('button', { name: 'Create goal' }).click();
  await expect(pageHeading(page, 'Goa trip')).toBeVisible();
  await page.getByRole('button', { name: 'Add contribution' }).first().click();
  const contribution = page.getByRole('dialog', { name: 'Add to this goal' });
  await contribution.getByLabel(/^Amount/).fill('5000');
  await contribution.getByRole('button', { name: 'Add', exact: true }).click();
  await expect(page.getByText('Contribution added')).toBeVisible();
  await expect(page.getByText('₹5,000.00').first()).toBeVisible();

  // A subscription shows the server's normalized monthly and yearly cost.
  await page.goto('/subscriptions/new');
  await expect(pageHeading(page, 'Add a subscription')).toBeVisible();
  await page.getByLabel('Name', { exact: true }).fill('Music');
  await page.getByLabel(/^Price per billing cycle/).fill('1200');
  await page.getByLabel(/^Billing cycle/).selectOption('yearly');
  await page.getByRole('button', { name: 'Add subscription' }).click();
  await expect(pageHeading(page, 'Music')).toBeVisible();
  await expect(page.getByText('₹100.00').first()).toBeVisible(); // 1,200 a year = 100 a month

  // Categories: add one and see it in the list.
  await page.goto('/categories');
  await expect(pageHeading(page, 'Categories')).toBeVisible();
  await page
    .getByRole('button', { name: /^Add category/ })
    .first()
    .click();
  const category = page.getByRole('dialog');
  await category.getByLabel('Name', { exact: true }).fill('Pets');
  await category
    .getByRole('button', { name: /^(Add|Save|Create)/ })
    .last()
    .click();
  await expect(page.getByText('Pets').first()).toBeVisible();

  // Home: the planning cards from GET /dashboard/planning.
  await page.goto('/dashboard');
  await expect(pageHeading(page, 'Home')).toBeVisible();

  // Budget alerts are raised by the server in the background: reload until one is listed.
  const alerts = page.getByRole('region', { name: 'Budget alerts' });
  const alert = alerts.getByRole('link', { name: /^Monthly spending reached \d+% of its limit$/ });
  await expect(async () => {
    await page.reload();
    await expect(alert.first()).toBeVisible({ timeout: 3_000 });
  }).toPass({ timeout: 60_000 });
  await expect(alerts.getByText(/^\d+ of \d+ active alerts?$/)).toBeVisible();
  const message = (await alert.first().textContent()) ?? '';
  await alerts.getByRole('button', { name: `Dismiss: ${message}` }).click();
  await expect(page.getByText('Alert dismissed')).toBeVisible();
  await expect(alerts.getByRole('link', { name: message, exact: true })).toHaveCount(0);

  // The subscription renews within 30 days, with its price, linking to it.
  const renewals = page.getByRole('region', { name: 'Renewals and trials' });
  await expect(renewals.getByRole('link', { name: 'Music' })).toHaveAttribute(
    'href',
    /^\/subscriptions\/[0-9a-f-]{36}$/,
  );
  await expect(renewals.getByText(/^Renews /)).toBeVisible();
  await expect(renewals.getByText('₹1,200.00')).toBeVisible();

  // The bill as a monthly equivalent, with what the figures count.
  const recurring = page.getByRole('region', { name: 'Recurring per month' });
  const bills = recurring.getByRole('listitem').filter({ hasText: /^Bills \(1 schedule\)/ });
  await expect(bills.getByText('₹1,200.00').first()).toBeVisible();
  await expect(recurring.getByText(/^Only fixed amounts are counted\./)).toBeVisible();
  await expect(recurring.getByRole('link', { name: 'View recurring schedules' })).toHaveAttribute(
    'href',
    '/planning/recurring',
  );
});
