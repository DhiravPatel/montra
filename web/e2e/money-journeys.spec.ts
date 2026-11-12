import type { Page } from '@playwright/test';
import { expect, test } from './support/test';
import { addDays, apiResponse, openPeerPage, waitForNotification } from './support/community';
import { api, newUser, pageHeading, todayInKolkata } from './support/session';

/**
 * Money journeys against the local Go API that the first finance journey
 * leaves out: income and an edit (§14 journeys 4 and 5), a budget threshold
 * alert (8), a subscription with renewal reminders (10), multi-currency with
 * a manual exchange rate, a CSV report download, and cross-user denial (25).
 * Every test signs up its own throwaway user; setup that is not under test
 * goes through the API.
 */

interface Account {
  id: string;
  name: string;
}

interface Transaction {
  id: string;
}

async function addAccount(
  page: Page,
  name: string,
  { currency = 'INR', opening = '10000.00' } = {},
): Promise<Account> {
  return api<Account>(page, 'POST', '/accounts', {
    name,
    account_type: 'bank',
    currency,
    opening_balance: opening,
  });
}

test('income is recorded and an edit is saved with its history (journeys 4 and 5)', async ({
  page,
}) => {
  await newUser(page, 'income', { name: 'E2E Earner' });
  await addAccount(page, 'Salary account', { opening: '1000.00' });

  // Income through the form: the type switch offers the income categories.
  await page.goto('/transactions/new');
  await expect(pageHeading(page, 'Add a transaction')).toBeVisible();
  await expect(page.getByLabel('Account', { exact: true })).toHaveValue(/[0-9a-f-]{36}/);
  await page.getByRole('radio', { name: 'Income' }).check();
  await page.getByLabel('Amount').fill('50000');
  await page.getByLabel(/^Category/).selectOption({ label: 'Salary' });
  await page.getByLabel(/^Description/).fill('November salary');
  await page.getByRole('button', { name: 'Save transaction' }).click();
  await expect(pageHeading(page, 'November salary')).toBeVisible();
  await expect(page.getByText('+₹50,000.00').first()).toBeVisible();

  // Edit the amount and description; the history records the edit.
  await page.getByRole('link', { name: 'Edit' }).click();
  await expect(pageHeading(page, 'Edit transaction')).toBeVisible();
  await page.getByLabel('Amount').fill('52500.50');
  await page.getByLabel(/^Description/).fill('November salary with bonus');
  await page.getByRole('button', { name: 'Save changes' }).click();
  await expect(pageHeading(page, 'November salary with bonus')).toBeVisible();
  await expect(page.getByText('+₹52,500.50').first()).toBeVisible();
  const history = page.getByRole('region', { name: 'History' });
  await expect(history.getByText('Edited')).toBeVisible();
  await expect(history.getByText('Created')).toBeVisible();

  // The account balance follows the edited amount: 1,000 + 52,500.50.
  await page.goto('/accounts');
  await expect(page.getByText('₹53,500.50').first()).toBeVisible();

  // Income is listed as money in, and the old amount is gone.
  await page.goto('/transactions?type=income');
  const row = page.getByRole('listitem').filter({
    has: page.getByRole('link', { name: 'November salary with bonus' }),
  });
  await expect(row.getByText('+₹52,500.50')).toBeVisible();
  await expect(page.getByText('+₹50,000.00')).toHaveCount(0);
});

test('spending past a budget threshold raises an alert (journey 8)', async ({ page }) => {
  await newUser(page, 'alert', { name: 'E2E Budgeter' });
  await addAccount(page, 'Wallet');

  await page.goto('/budgets/new');
  await expect(pageHeading(page, 'Create a budget')).toBeVisible();
  await page.getByLabel('Name', { exact: true }).fill('Food budget');
  await page.getByRole('radio', { name: /^Overall/ }).check();
  await page.getByLabel('Period', { exact: true }).selectOption('monthly');
  await page.getByLabel(/^Limit for each period/).fill('1000');
  await page.getByRole('button', { name: 'Create budget' }).click();
  await expect(pageHeading(page, 'Food budget')).toBeVisible();
  const budgetUrl = page.url();

  // 800 of 1,000 crosses the default 50% and 75% thresholds (not 90%).
  await page.goto('/transactions/new');
  await expect(page.getByLabel('Account', { exact: true })).toHaveValue(/[0-9a-f-]{36}/);
  await page.getByLabel('Amount').fill('800');
  await page.getByLabel(/^Category/).selectOption({ label: 'Groceries' });
  await page.getByLabel(/^Merchant or payee/).fill('Fresh Mart');
  await page.getByRole('button', { name: 'Save transaction' }).click();
  await expect(pageHeading(page, 'Fresh Mart')).toBeVisible();

  // The API worker evaluates budgets a few seconds after the change.
  await waitForNotification(page, 'Food budget budget at 75%');
  await page.goto(budgetUrl);
  await expect(page.getByText('₹800.00 of ₹1,000.00 spent').first()).toBeVisible();
  const alerts = page.getByRole('region', { name: 'Alerts' });
  await expect(alerts.getByText('Food budget reached 75% of its limit')).toBeVisible();
  await expect(alerts.getByText('Food budget reached 50% of its limit')).toBeVisible();
  await expect(alerts.getByText('Food budget reached 90% of its limit')).toHaveCount(0);

  // The same alert is in the notification centre.
  await page.goto('/notifications');
  await expect(pageHeading(page, 'Notifications')).toBeVisible();
  await expect(page.getByText('Food budget budget at 75%')).toBeVisible();
  await expect(page.getByText(/used 75% of this period.s budget/)).toBeVisible();
});

test('a subscription keeps its renewal reminders and shows on the calendar (journey 10)', async ({
  page,
}) => {
  await newUser(page, 'subs', { name: 'E2E Subscriber' });
  await addAccount(page, 'Card account');
  const renewal = addDays(todayInKolkata(), 5);

  await page.goto('/subscriptions/new');
  await expect(pageHeading(page, 'Add a subscription')).toBeVisible();
  await page.getByLabel('Name', { exact: true }).fill('Video streaming');
  await page.getByLabel(/^Price per billing cycle/).fill('649');
  await page.getByLabel(/^Billing cycle/).selectOption('monthly');
  await page.getByLabel(/^Next renewal/).fill(renewal);
  const reminders = page.getByRole('group', { name: 'Reminders' });
  await expect(reminders.getByRole('checkbox', { name: '3 days before' })).toBeChecked();
  await reminders.getByRole('checkbox', { name: '1 day before' }).check();
  await page.getByRole('button', { name: 'Add subscription' }).click();

  await expect(pageHeading(page, 'Video streaming')).toBeVisible();
  await expect(page.getByText('3 days before, 1 day before')).toBeVisible();
  const saved = await api<{ reminder_days_before: number[]; next_renewal_date: string }>(
    page,
    'GET',
    page.url().replace(/^.*\/subscriptions\//, '/subscriptions/'),
  );
  expect([...saved.reminder_days_before].sort()).toEqual([1, 3]);
  expect(saved.next_renewal_date).toBe(renewal);

  // The renewal is on the planning calendar, linking back.
  await page.goto('/planning');
  await expect(page.getByRole('link', { name: 'Video streaming' }).first()).toBeVisible();
});

test('a foreign-currency account keeps original amounts and converts with my rate', async ({
  page,
}) => {
  await newUser(page, 'fx', { name: 'E2E Traveller' });
  await addAccount(page, 'Travel card', { currency: 'USD', opening: '500.00' });

  // A manual rate, then a conversion that discloses it.
  await page.goto('/settings/exchange-rates');
  await expect(pageHeading(page, 'Exchange rates')).toBeVisible();
  const add = page.getByRole('region', { name: 'Add your own rate' });
  await add.getByLabel('From currency').selectOption('USD');
  await add.getByLabel('To currency').selectOption('INR');
  await add.getByLabel('Rate').fill('83.25');
  await add.getByRole('button', { name: 'Save rate' }).click();
  await expect(page.getByText('Rate saved')).toBeVisible();
  const mine = page.getByRole('region', { name: 'Your rates' });
  await expect(mine.getByText('1 USD = 83.25 INR')).toBeVisible();

  const convert = page.getByRole('region', { name: 'Convert an amount' });
  await convert.getByLabel('From', { exact: true }).selectOption('USD');
  await convert.getByLabel('To', { exact: true }).selectOption('INR');
  await convert.getByLabel('Amount').fill('20');
  await convert.getByRole('button', { name: 'Convert' }).click();
  const result = convert.getByRole('status');
  await expect(result.getByText('₹1,665.00')).toBeVisible();
  await expect(result.getByText('Manual rate')).toBeVisible();

  // An expense in the account's own currency keeps its currency.
  await page.goto('/transactions/new');
  await page.getByLabel('Account', { exact: true }).selectOption({ label: 'Travel card (USD)' });
  await page.getByLabel('Amount').fill('20');
  await page.getByLabel(/^Merchant or payee/).fill('Airport cafe');
  await page.getByRole('button', { name: 'Save transaction' }).click();
  await expect(pageHeading(page, 'Airport cafe')).toBeVisible();
  await expect(page.getByText('-$20.00').first()).toBeVisible();

  await page.goto('/accounts');
  await expect(page.getByText('$480.00').first()).toBeVisible();
});

test('a CSV transactions report is generated and downloads with my data', async ({ page }) => {
  await newUser(page, 'report', { name: 'E2E Reporter' });
  const account = await addAccount(page, 'Everyday');
  const today = todayInKolkata();
  for (const [merchant, amount] of [
    ['Corner Bakery', '120.50'],
    ['City Pharmacy', '349.00'],
  ] as const) {
    await api(page, 'POST', '/transactions', {
      type: 'expense',
      account_id: account.id,
      amount,
      merchant_name: merchant,
      local_date: today,
    });
  }

  await page.goto('/reports');
  await expect(pageHeading(page, 'Reports')).toBeVisible();
  await page.getByRole('button', { name: 'New report' }).first().click();
  const dialog = page.getByRole('dialog', { name: 'New report' });
  await dialog.getByLabel('Report').selectOption('transactions');
  await dialog.getByLabel('CSV').check();
  await dialog.getByLabel('Title (optional)').fill('E2E transactions');
  await dialog.getByRole('button', { name: 'Create report' }).click();
  await expect(page.getByText('Report requested')).toBeVisible();

  // The worker prepares it; the page follows it until it is ready.
  const download = page.getByRole('button', { name: 'Download E2E transactions' });
  await expect(download).toBeVisible({ timeout: 60_000 });
  const [file] = await Promise.all([page.waitForEvent('download'), download.click()]);
  expect(file.suggestedFilename()).toMatch(/\.csv$/);
  const path = await file.path();
  const { readFileSync } = await import('node:fs');
  const csv = readFileSync(path, 'utf8');
  expect(csv).toContain('Corner Bakery');
  expect(csv).toContain('City Pharmacy');
  expect(csv).toMatch(/120\.50/);
  expect(csv).toMatch(/349\.00/);
});

test('another person cannot see or change my records (journey 25)', async ({
  page,
  browser,
}, testInfo) => {
  await newUser(page, 'owner', { name: 'E2E Owner' });
  const account = await addAccount(page, 'Private savings');
  const created = await api<{ transaction: Transaction }>(page, 'POST', '/transactions', {
    type: 'expense',
    account_id: account.id,
    amount: '999.00',
    merchant_name: 'Secret Jeweller',
    local_date: todayInKolkata(),
  });
  const transactionId = created.transaction.id;
  const goal = await api<{ id: string }>(page, 'POST', '/goals', {
    name: 'Private goal',
    goal_type: 'custom',
    target_amount: '5000',
  });

  const other = await openPeerPage(browser, testInfo);
  try {
    await newUser(other, 'intruder', { name: 'E2E Intruder' });

    // The pages say "not found" without revealing anything.
    await other.goto(`/transactions/${transactionId}`);
    await expect(other.getByText(/couldn’t find|not found|isn’t available/i).first()).toBeVisible();
    await expect(other.getByText('Secret Jeweller')).toHaveCount(0);
    await other.goto(`/accounts/${account.id}`);
    await expect(other.getByText(/couldn’t find|not found|isn’t available/i).first()).toBeVisible();
    await expect(other.getByText('Private savings')).toHaveCount(0);
    await other.goto(`/goals/${goal.id}`);
    await expect(other.getByText(/couldn’t find|not found|isn’t available/i).first()).toBeVisible();
    await expect(other.getByText('Private goal')).toHaveCount(0);

    // The API refuses reads and writes the same way (no existence leak).
    for (const path of [
      `/transactions/${transactionId}`,
      `/accounts/${account.id}`,
      `/goals/${goal.id}`,
    ]) {
      expect((await apiResponse(other, 'GET', path)).status()).toBe(404);
    }
    const write = await apiResponse(other, 'POST', '/transactions', {
      type: 'expense',
      account_id: account.id,
      amount: '1.00',
      local_date: todayInKolkata(),
    });
    expect([403, 404, 422]).toContain(write.status());
    const list = await api<{ id: string }[]>(other, 'GET', '/transactions');
    expect(list.map((item) => item.id)).not.toContain(transactionId);
  } finally {
    await other.context().close();
  }

  // The owner's record is untouched.
  await page.goto(`/transactions/${transactionId}`);
  await expect(pageHeading(page, 'Secret Jeweller')).toBeVisible();
  await expect(page.getByText('-₹999.00').first()).toBeVisible();
});
