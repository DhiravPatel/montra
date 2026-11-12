import { expect, test } from './support/test';
import { api, newUser, pageHeading, todayInKolkata } from './support/session';

/**
 * Failure handling against the local API (§14 "validation and failure
 * handling"): a list that fails to load explains itself and recovers with
 * "Try again", and a transaction saved while the connection is down is kept in the form and
 * saved exactly once when the connection is back (the Idempotency-Key is
 * reused for the retry).
 */

test('a list that fails to load says so and recovers on retry', async ({ page }) => {
  await newUser(page, 'flaky', { name: 'E2E Flaky' });
  const account = await api<{ id: string }>(page, 'POST', '/accounts', {
    name: 'Wallet',
    account_type: 'cash',
    currency: 'INR',
    opening_balance: '500.00',
  });
  await api(page, 'POST', '/transactions', {
    type: 'expense',
    account_id: account.id,
    amount: '42.00',
    merchant_name: 'Tea Stall',
    local_date: todayInKolkata(),
  });

  // The API answers 503 for the list (as during an outage).
  await page.route('**/api/v1/transactions?**', (route) =>
    route.fulfill({
      status: 503,
      contentType: 'application/json',
      body: JSON.stringify({
        error: {
          code: 'SERVICE_UNAVAILABLE',
          message: 'The service is temporarily unavailable.',
          details: [],
          request_id: 'e2e-outage',
        },
      }),
    }),
  );
  await page.goto('/transactions');
  await expect(pageHeading(page, 'Transactions')).toBeVisible();
  const problem = page.getByRole('alert').filter({ hasText: 'We couldn’t load your transactions' });
  await expect(problem).toBeVisible();
  await expect(
    problem.getByText('Montra is temporarily unavailable. Try again in a moment.'),
  ).toBeVisible();
  await expect(problem.getByText('e2e-outage')).toBeVisible(); // reference for support

  // The outage ends; "Try again" loads the list without a page reload.
  await page.unroute('**/api/v1/transactions?**');
  await problem.getByRole('button', { name: 'Try again' }).click();
  await expect(page.getByRole('link', { name: 'Tea Stall' })).toBeVisible();
  await expect(problem).toHaveCount(0);
});

test('a transaction saved while the connection is down is kept and saved once when back online', async ({
  page,
}) => {
  await newUser(page, 'offline', { name: 'E2E Offline' });
  await api(page, 'POST', '/accounts', {
    name: 'Wallet',
    account_type: 'cash',
    currency: 'INR',
    opening_balance: '1000.00',
  });

  await page.goto('/transactions/new');
  await expect(page.getByLabel('Account', { exact: true })).toHaveValue(/[0-9a-f-]{36}/);
  await page.getByLabel('Amount').fill('199.99');
  await page.getByLabel(/^Merchant or payee/).fill('Offline Kirana');
  const keys: string[] = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && request.url().endsWith('/api/v1/transactions')) {
      keys.push(request.headers()['idempotency-key'] ?? '');
    }
  });

  // The connection drops for API calls (context.setOffline would also cut the
  // dev server's live-reload socket, which reloads the page on reconnect).
  await page.route('**/api/v1/**', (route) => route.abort('internetdisconnected'));
  await page.getByRole('button', { name: 'Save transaction' }).click();
  await expect(
    page.getByText('We couldn’t reach Montra. Check your internet connection and try again.'),
  ).toBeVisible();
  // Nothing typed is lost.
  await expect(page.getByLabel('Amount')).toHaveValue('199.99');
  await expect(page.getByLabel(/^Merchant or payee/)).toHaveValue('Offline Kirana');

  await page.unroute('**/api/v1/**');
  await page.getByRole('button', { name: 'Save transaction' }).click();
  await expect(pageHeading(page, 'Offline Kirana')).toBeVisible();
  await expect(page.getByText('-₹199.99').first()).toBeVisible();

  // One transaction, and the retry reused the first attempt's key.
  const list = await api<{ merchant_name?: string; amount: { amount: string } }[]>(
    page,
    'GET',
    '/transactions',
  );
  expect(list.filter((item) => item.amount.amount === '199.99')).toHaveLength(1);
  expect(keys.length).toBeGreaterThanOrEqual(1);
  expect(new Set(keys.filter(Boolean)).size).toBe(1);
});
