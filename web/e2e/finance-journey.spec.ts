import { expect, type Page, test } from '@playwright/test';
import { waitForEmailLink } from './support/devMailbox';

/**
 * Money journey against the local Go API: onboarding with a first account,
 * the dashboard, an expense with a refund, a credit card, a transfer with a
 * fee (deleted and restored as one unit) and the transaction list. Creates a
 * throwaway account in the development database.
 * Run with: PW_CHANNEL=chrome pnpm e2e
 */
test.describe.configure({ mode: 'serial' });

const email = `e2e.${Date.now()}.money@example.com`;
const password = 'quiet-harbor-71-e2e';

async function signIn(page: Page) {
  await page.goto('/sign-in');
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Password', { exact: true }).fill(password);
  await page.getByRole('button', { name: 'Sign in' }).click();
}

test('set up, record money and see it everywhere', async ({ page }) => {
  test.setTimeout(180_000);

  // Sign up and verify.
  await page.goto('/sign-up');
  await page.getByLabel('Display name').fill('E2E Money');
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('New password').fill(password);
  await page.getByLabel('Main currency').selectOption('INR');
  await page.getByLabel(/I agree to the/).check();
  await page.getByLabel(/18 years of age or older/).check();
  await page.getByRole('button', { name: 'Create account' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Check your email' })).toBeVisible();
  // Local APIs may run with AUTH_DEV_AUTO_VERIFY_EMAIL=true (no email is sent then).
  const link = await waitForEmailLink(email, '/verify-email', 8_000).catch(() => null);
  if (link) {
    const url = new URL(link);
    await page.goto(url.pathname + url.hash);
    await expect(page.getByText('Your email is verified')).toBeVisible();
  }

  // Onboarding: every step, with a first account.
  await signIn(page);
  await expect(page.getByRole('heading', { level: 1, name: 'Set up Montra' })).toBeVisible();
  await page.getByRole('button', { name: 'Get started' }).click();
  await expect(page.getByRole('heading', { level: 2, name: 'Your privacy' })).toBeVisible();
  await page.getByRole('button', { name: 'Continue' }).click();
  await expect(page.getByRole('heading', { level: 2, name: 'Where you are' })).toBeVisible();
  await page.getByLabel('Country').selectOption('IN');
  await page.getByRole('button', { name: 'Continue' }).click();
  await expect(
    page.getByRole('heading', { level: 2, name: 'Your income (optional)' }),
  ).toBeVisible();
  await page.getByRole('button', { name: 'Skip this step' }).click();
  await expect(page.getByRole('heading', { level: 2, name: 'Your first account' })).toBeVisible();
  await page.getByLabel('Account name').fill('Wallet');
  await page.getByLabel('Account type').selectOption('cash');
  await page.getByLabel(/^Current balance/).fill('1500');
  await page.getByRole('button', { name: 'Add account' }).click();
  await expect(page.getByText('Added so far')).toBeVisible();
  await page.getByRole('button', { name: 'Continue' }).click();
  await expect(page.getByRole('heading', { level: 2, name: 'Categories' })).toBeVisible();
  await page.getByRole('button', { name: 'Continue' }).click();
  await expect(page.getByRole('heading', { level: 2, name: 'Email summaries' })).toBeVisible();
  await page.getByRole('button', { name: 'Finish' }).click();
  await expect(page.getByRole('heading', { level: 2, name: 'You’re all set' })).toBeVisible();
  await page.getByRole('link', { name: 'Go to Home' }).click();

  // Dashboard: the opening balance is a balance, not income.
  await expect(page.getByRole('heading', { level: 1, name: 'Home' })).toBeVisible();
  const balances = page.getByRole('region', { name: 'Balances' });
  await expect(balances.getByText('₹1,500.00').first()).toBeVisible();
  await expect(page.getByText('Finish setting up Montra')).toHaveCount(0);

  // An expense (the Wallet is the default account after onboarding).
  await page.goto('/transactions/new');
  await expect(page.getByLabel('Account', { exact: true })).toHaveValue(/[0-9a-f-]{36}/);
  await page.getByLabel('Amount').fill('250.75');
  await page.getByLabel(/^Category/).selectOption({ label: 'Groceries' });
  await page.getByLabel(/^Merchant or payee/).fill('Big Bazaar');
  await page.getByRole('button', { name: 'Save transaction' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Big Bazaar' })).toBeVisible();
  await expect(page.getByText('-₹250.75').first()).toBeVisible();
  await expect(page.getByRole('region', { name: 'History' }).getByText('Created')).toBeVisible();

  // A partial refund linked to it.
  await page.getByRole('button', { name: 'Record refund' }).click();
  const refund = page.getByRole('dialog', { name: 'Record a refund or reimbursement' });
  await refund.getByLabel('Amount received').fill('50');
  await refund.getByRole('button', { name: 'Save' }).click();
  await expect(page.getByText('Refund recorded')).toBeVisible();
  await expect(page.getByText('₹50.00 of ₹250.75')).toBeVisible();

  // A credit card, entered as the amount owed.
  await page.goto('/accounts/new');
  await page.getByLabel('Account name').fill('HDFC Credit');
  await page.getByLabel('Account type').selectOption('credit_card');
  await page.getByLabel(/^Amount you owe today/).fill('2000');
  await page.getByLabel(/^Credit limit/).fill('50000');
  await page.getByRole('button', { name: 'Add account' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'HDFC Credit' })).toBeVisible();
  await expect(
    page.getByRole('region', { name: 'Balance' }).getByText('Owed', { exact: true }),
  ).toBeVisible();

  // Pay the card from the wallet, with a fee.
  await page.goto('/transfers/new');
  await page.getByLabel('From account').selectOption({ label: 'Wallet (INR)' });
  await page.getByLabel('To account').selectOption({ label: 'HDFC Credit (INR)' });
  await page.getByLabel('Amount sent').fill('1000');
  await page.getByLabel(/^Fee/).fill('10');
  await page.getByLabel(/^Description/).fill('Card payment');
  await page.getByRole('button', { name: 'Save transfer' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Card payment' })).toBeVisible();
  const transfer = page.getByRole('region', { name: 'Transfer' });
  await expect(transfer.getByRole('link', { name: 'HDFC Credit' })).toBeVisible();
  await expect(transfer.getByText('₹10.00')).toBeVisible();

  // Delete the transfer as one unit, then restore it.
  await page.getByRole('button', { name: 'Delete transfer' }).click();
  await page
    .getByRole('dialog', { name: 'Delete this transfer?' })
    .getByRole('button', { name: 'Delete' })
    .click();
  await expect(page.getByText('This transaction was deleted')).toBeVisible();
  await page.getByRole('button', { name: 'Restore' }).click();
  await page
    .getByRole('dialog', { name: 'Restore this transaction?' })
    .getByRole('button', { name: 'Restore' })
    .click();
  await expect(page.getByText('This transaction was deleted')).toHaveCount(0);

  // Balances follow the ledger: 1500 − 250.75 + 50 − 1000 − 10 = 289.25 in the wallet.
  await page.goto('/accounts');
  await expect(page.getByRole('region', { name: 'Cash' }).getByText('₹289.25')).toBeVisible();
  await expect(
    page.getByRole('region', { name: 'Credit cards' }).getByText('₹1,000.00'),
  ).toBeVisible();

  // The list, filtered to expenses through the URL-safe filters.
  await page.goto('/transactions?type=expense');
  await expect(page.getByRole('heading', { level: 1, name: 'Transactions' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Big Bazaar' })).toBeVisible();
  await expect(page.getByText('Type: Expense')).toBeVisible();
  await expect(page.getByRole('link', { name: 'November salary' })).toHaveCount(0);

  // Nothing financial is kept in browser storage.
  const storage = await page.evaluate(() => JSON.stringify(Object.entries(window.localStorage)));
  expect(storage).not.toMatch(/Bazaar|250|Wallet|HDFC/);
});
