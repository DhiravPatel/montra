import { readFileSync } from 'node:fs';
import type { Page } from '@playwright/test';
import { expect, test } from './support/test';
import { api, newUser, pageHeading, PASSWORD, todayInKolkata } from './support/session';
import { readZip } from './support/zip';

/**
 * Privacy journeys against the local Go API (§14 journeys 23 and 24): a full
 * data export prepared by the worker and downloaded as a ZIP that holds the
 * user's own records, and an account deletion scheduled with its grace period
 * and then cancelled. Each test signs up its own throwaway user.
 */

/** Sensitive actions may ask for the password again (a fresh sign-in may count). */
async function confirmItsYouIfAsked(page: Page, done: ReturnType<Page['getByText']>) {
  const reauth = page.getByRole('dialog', { name: 'Confirm it’s you' });
  await expect(reauth.or(done).first()).toBeVisible({ timeout: 15_000 });
  if (await reauth.isVisible()) {
    await reauth.getByLabel('Password').fill(PASSWORD);
    await reauth.getByRole('button', { name: 'Confirm' }).click();
  }
}

test('export my data and download the ZIP (journey 23)', async ({ page }) => {
  await newUser(page, 'export', { name: 'E2E Exporter' });
  const account = await api<{ id: string }>(page, 'POST', '/accounts', {
    name: 'Export wallet',
    account_type: 'cash',
    currency: 'INR',
    opening_balance: '2500.00',
  });
  await api(page, 'POST', '/transactions', {
    type: 'expense',
    account_id: account.id,
    amount: '432.10',
    merchant_name: 'Export Test Bookshop',
    local_date: todayInKolkata(),
  });

  await page.goto('/settings/privacy');
  await expect(pageHeading(page, 'Privacy & data')).toBeVisible();
  const card = page.getByRole('region', { name: 'Download your data' });
  await card.getByRole('button', { name: 'Request my data' }).click();
  await confirmItsYouIfAsked(page, page.getByText('Export requested'));
  await expect(page.getByText('Export requested').first()).toBeVisible();

  // The worker builds the archive; the card follows it until it is ready.
  const download = card.getByRole('button', { name: 'Download ZIP' }).first();
  await expect(download).toBeVisible({ timeout: 90_000 });
  await expect(card.getByText('Your export is ready')).toBeVisible();
  const [file] = await Promise.all([page.waitForEvent('download'), download.click()]);
  await expect(page.getByText('Download started')).toBeVisible();
  expect(file.suggestedFilename()).toMatch(/\.zip$/);

  const entries = readZip(readFileSync(await file.path()));
  expect(entries.size).toBeGreaterThan(0);
  const everything = [...entries.values()].map((content) => content.toString('utf8')).join('\n');
  expect(everything).toContain('Export Test Bookshop');
  expect(everything).toContain('Export wallet');
  // Secrets are never exported.
  expect(everything).not.toContain(PASSWORD);
  expect(everything).not.toMatch(/password_hash|totp_secret/i);
});

test('schedule account deletion, see the grace period, then cancel it (journey 24)', async ({
  page,
}) => {
  await newUser(page, 'delete', { name: 'E2E Leaver' });

  await page.goto('/settings/privacy');
  const card = page.getByRole('region', { name: 'Delete your account' });
  await expect(card.getByRole('heading', { name: 'What happens' })).toBeVisible();
  await card.getByRole('button', { name: 'Delete my account…' }).click();

  const dialog = page.getByRole('dialog', { name: 'Delete your account?' });
  await expect(dialog.getByText(/deleted 7 days from now unless you cancel/)).toBeVisible();
  // The confirmation word is checked exactly.
  await dialog.getByLabel('Type DELETE to confirm').fill('delete please');
  await dialog.getByRole('button', { name: 'Schedule deletion' }).click();
  await expect(dialog.getByText('Type DELETE exactly as shown.')).toBeVisible();
  await dialog.getByLabel('Type DELETE to confirm').fill('DELETE');
  await dialog.getByLabel(/Why are you leaving\?/).fill('E2E check');
  await dialog.getByRole('button', { name: 'Schedule deletion' }).click();
  await confirmItsYouIfAsked(page, card.getByText('Your account is scheduled for deletion'));

  await expect(card.getByText('Your account is scheduled for deletion')).toBeVisible();
  await expect(
    page.getByText(/Your account will be deleted on .+ You can cancel until then\./),
  ).toBeVisible();
  const scheduled = await api<{ status: string; scheduled_for: string }>(
    page,
    'GET',
    '/me/deletion-request',
  );
  expect(scheduled.status).toBe('scheduled');
  const graceDays = (Date.parse(scheduled.scheduled_for) - Date.now()) / 86_400_000;
  expect(graceDays).toBeGreaterThan(6.9);
  expect(graceDays).toBeLessThan(7.1);

  // Still fully usable during the grace period; then cancel.
  await page.goto('/dashboard');
  await expect(pageHeading(page, 'Home')).toBeVisible();
  await page.goto('/settings/privacy');
  await card.getByRole('button', { name: 'Cancel deletion' }).click();
  await expect(page.getByText('Deletion cancelled')).toBeVisible();
  await expect(card.getByRole('button', { name: 'Delete my account…' })).toBeVisible();
  await expect(page.getByText(/Your account will be deleted on/)).toHaveCount(0);
  const cancelled = await api<{ status: string } | null>(page, 'GET', '/me/deletion-request');
  expect(cancelled?.status ?? 'none').not.toBe('scheduled');
});
