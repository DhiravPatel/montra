import { createHash } from 'node:crypto';
import type { Page } from '@playwright/test';
import { expect, retryRateLimitedReads, test } from './support/test';
import { api, newUser, pageHeading, todayInKolkata } from './support/session';

/*
 * Round 8 client features against the live API: saved filters on the
 * transactions list, help guides (HELP-001), photo compression before upload
 * (COST-001) and spending by payment method (ANL-002).
 */

interface Account {
  id: string;
}

test.beforeEach(async ({ context }) => {
  await retryRateLimitedReads(context);
});

function toast(page: Page, text: string) {
  return page.getByRole('region', { name: 'Notifications' }).getByText(text);
}

test('saves, applies and deletes a transactions filter', async ({ page }) => {
  await newUser(page, 'r8');
  const account = await api<Account>(page, 'POST', '/accounts', {
    name: 'Wallet',
    account_type: 'cash',
    currency: 'INR',
    opening_balance: '1000.00',
  });
  await api(page, 'POST', '/transactions', {
    type: 'expense',
    account_id: account.id,
    amount: '120.00',
    merchant_name: 'Chai Point',
    local_date: todayInKolkata(),
  });

  await page.goto('/transactions?type=expense');
  await expect(pageHeading(page, 'Transactions')).toBeVisible();
  await page.getByLabel('Search', { exact: true }).fill('chai');
  await page.getByRole('button', { name: 'Saved filters' }).click();
  const dialog = page.getByRole('dialog', { name: 'Saved filters' });
  await dialog.getByLabel('Name').fill('Chai runs');
  await dialog.getByRole('button', { name: 'Save' }).click();
  await expect(dialog.getByText('Chai runs')).toBeVisible();

  // The same name again (any case) is refused on the field.
  await dialog.getByLabel('Name').fill('CHAI RUNS');
  await dialog.getByRole('button', { name: 'Save' }).click();
  await expect(
    dialog.getByText('You already have a saved filter called “CHAI RUNS”. Choose another name.'),
  ).toBeVisible();
  await page.keyboard.press('Escape');

  const saved = await api<{ name: string; filter: unknown }[]>(
    page,
    'GET',
    '/saved-filters?scope=transactions',
  );
  expect(saved).toEqual([
    expect.objectContaining({
      name: 'Chai runs',
      filter: { sort: 'date_desc', type: ['expense'], q: 'chai' },
    }),
  ]);

  // A fresh list: applying the saved filter brings back the type and the search text.
  await page.goto('/transactions');
  await page.getByRole('button', { name: 'Saved filters (1)' }).click();
  await page.getByRole('button', { name: 'Apply Chai runs' }).click();
  await expect(page).toHaveURL(/type=expense/);
  await expect(page).not.toHaveURL(/chai/);
  await expect(page.getByLabel('Search', { exact: true })).toHaveValue('chai');
  await expect(page.getByRole('link', { name: 'Chai Point' })).toBeVisible();

  await page.getByRole('button', { name: 'Saved filters (1)' }).click();
  await page.getByRole('button', { name: 'Delete Chai runs' }).click();
  const confirm = page.getByRole('dialog', { name: 'Delete “Chai runs”?' });
  await confirm.getByRole('button', { name: 'Delete saved filter' }).click();
  await expect(
    page.getByRole('dialog', { name: 'Saved filters' }).getByText('Nothing saved yet.'),
  ).toBeVisible();
  expect(await api(page, 'GET', '/saved-filters?scope=transactions')).toEqual([]);
});

test('finds a help guide and opens it from the screen it is about', async ({ page }) => {
  await newUser(page, 'r8');
  await page.goto('/budgets');
  await expect(pageHeading(page, 'Budgets')).toBeVisible();
  await page.getByRole('link', { name: 'How this works: How budgets are calculated' }).click();
  await expect(pageHeading(page, 'How budgets are calculated')).toBeVisible();
  await page
    .getByRole('navigation', { name: 'On this page' })
    .getByRole('link', { name: 'Rollover' })
    .click();
  await expect(page).toHaveURL(/#rollover$/);
  await expect(page.getByRole('heading', { level: 2, name: 'Rollover' })).toBeInViewport();

  await page.getByRole('link', { name: 'All guides' }).click();
  await expect(pageHeading(page, 'Guides and how-tos')).toBeVisible();
  await page.getByRole('searchbox', { name: 'Search the guides' }).fill('recovery code');
  await page.getByRole('link', { name: 'Two-step verification and recovery' }).click();
  await expect(pageHeading(page, 'Two-step verification and recovery')).toBeVisible();
  // No status page is configured locally, so there is no status link.
  await expect(page.getByRole('link', { name: /Service status/ })).toHaveCount(0);
});

/** A 3000 × 2000 JPEG from the browser's canvas, with an Exif block holding GPS and orientation 6. */
async function bigPhotoWithGps(page: Page): Promise<Buffer> {
  const bytes = await page.evaluate(async () => {
    const canvas = new OffscreenCanvas(3000, 2000);
    const context = canvas.getContext('2d');
    if (!context) throw new Error('no 2d context');
    const gradient = context.createLinearGradient(0, 0, 3000, 2000);
    gradient.addColorStop(0, '#f97316');
    gradient.addColorStop(1, '#2563eb');
    context.fillStyle = gradient;
    context.fillRect(0, 0, 3000, 2000);
    for (let i = 0; i < 4000; i += 1) {
      context.fillStyle = `hsl(${(i * 37) % 360} 70% 50%)`;
      context.fillRect((i * 97) % 3000, (i * 53) % 2000, 12, 12);
    }
    const jpeg = new Uint8Array(
      await (await canvas.convertToBlob({ type: 'image/jpeg', quality: 0.95 })).arrayBuffer(),
    );
    const ascii = (text: string) => Array.from(text, (char) => char.charCodeAt(0));
    const payload = [
      ...ascii('Exif'),
      0,
      0,
      0x49,
      0x49,
      0x2a,
      0x00,
      0x08,
      0x00,
      0x00,
      0x00,
      0x02,
      0x00,
      0x12,
      0x01,
      0x03,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x06,
      0x00,
      0x00,
      0x00,
      0x25,
      0x88,
      0x04,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x26,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x01,
      0x00,
      0x02,
      0x00,
      0x02,
      0x00,
      0x00,
      0x00,
      0x4e,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ];
    const length = payload.length + 2;
    const app1 = [0xff, 0xe1, length >> 8, length & 0xff, ...payload];
    return [0xff, 0xd8, ...app1, ...jpeg.slice(2)];
  });
  return Buffer.from(bytes);
}

test('scales a large photo down before upload and strips its location', async ({ page }) => {
  await newUser(page, 'r8');
  const photo = await bigPhotoWithGps(page);
  let intent: { size_bytes?: number; checksum_sha256?: string; filename?: string } = {};
  let uploaded: Buffer | null = null;
  page.on('request', (request) => {
    if (request.url().endsWith('/files/upload-intent')) {
      intent = request.postDataJSON() as typeof intent;
    }
    if (request.method() === 'PUT' && /\/files\/[^/]+\/content$/.test(request.url())) {
      uploaded = request.postDataBuffer();
    }
  });

  await page.goto('/receipts');
  await expect(pageHeading(page, /^Receipts$/)).toBeVisible();
  await page.getByRole('button', { name: 'Add receipt' }).first().click();
  const add = page.getByRole('dialog', { name: 'Add a receipt' });
  await add
    .getByLabel('Choose files')
    .setInputFiles({ name: 'IMG_2001.jpg', mimeType: 'image/jpeg', buffer: photo });
  await add.getByRole('button', { name: 'Add receipt' }).click();
  await expect(toast(page, 'Receipt added')).toBeVisible();

  expect(uploaded).not.toBeNull();
  const body = uploaded as unknown as Buffer;
  // Size and checksum sent to upload-intent describe exactly the bytes uploaded.
  expect(intent.size_bytes).toBe(body.length);
  expect(intent.checksum_sha256).toBe(createHash('sha256').update(body).digest('hex'));
  expect(body.length).toBeLessThan(photo.length);
  // No metadata left: the canvas-encoded JPEG carries no Exif block (so no GPS).
  expect(body.includes(Buffer.from('Exif\0\0', 'latin1'))).toBe(false);
  expect(photo.includes(Buffer.from('Exif\0\0', 'latin1'))).toBe(true);
  // Orientation was applied: the 3000 × 2000 landscape is now 1365 × 2048 portrait.
  const size = await page.evaluate(async (data) => {
    const bitmap = await createImageBitmap(
      new Blob([new Uint8Array(data)], { type: 'image/jpeg' }),
    );
    return { width: bitmap.width, height: bitmap.height };
  }, Array.from(body));
  expect(size).toEqual({ width: 1365, height: 2048 });
});

test('shows spending by payment method and drills into spending without one', async ({ page }) => {
  await newUser(page, 'r8');
  const account = await api<Account>(page, 'POST', '/accounts', {
    name: 'Wallet',
    account_type: 'cash',
    currency: 'INR',
    opening_balance: '5000.00',
  });
  const card = await api<{ id: string }>(page, 'POST', '/payment-methods', {
    kind: 'credit_card',
    label: 'HDFC Card',
    network: 'visa',
    masked_hint: '4321',
  });
  const today = todayInKolkata();
  await api(page, 'POST', '/transactions', {
    type: 'expense',
    account_id: account.id,
    amount: '300.00',
    payment_method_id: card.id,
    merchant_name: 'Croma',
    local_date: today,
  });
  await api(page, 'POST', '/transactions', {
    type: 'expense',
    account_id: account.id,
    amount: '120.50',
    merchant_name: 'Chai Point',
    local_date: today,
  });

  await page.goto('/analytics?view=payment-methods&range=this_month');
  const report = page.getByRole('region', { name: 'Payment methods' });
  await expect(report.getByRole('link', { name: 'HDFC Card ending 4321' })).toBeVisible();
  await expect(
    report.getByRole('figure', { name: 'Spending by payment method in INR' }),
  ).toHaveAccessibleDescription(/You paid the most with HDFC Card ending 4321: ₹300\.00/);
  await report.getByRole('link', { name: 'No payment method' }).click();
  await expect(pageHeading(page, 'Transactions')).toBeVisible();
  await expect(page).toHaveURL(/payment_method_id=none/);
  await expect(page.getByText('Payment method: No payment method')).toBeVisible();
  await expect(page.getByRole('link', { name: 'Chai Point' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Croma' })).toHaveCount(0);
});
