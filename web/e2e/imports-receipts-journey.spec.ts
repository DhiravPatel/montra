import type { Locator, Page } from '@playwright/test';
import { expect, test } from './support/test';
import { csvFile, rawFile, receiptPng } from './support/files';
import { api, navigateTo, newUser, pageHeading } from './support/session';

/**
 * Statement import + reconciliation (spec §14 journey 12) and receipts
 * (journey 11) against the local Go API and its worker. Each test signs up
 * its own throwaway user; accounts and pre-existing transactions are set up
 * through the API, everything under test goes through the UI. Files are
 * small synthetic buffers (no real statements, no OCR or AI provider).
 * Run with: PW_CHANNEL=chrome pnpm e2e
 */

interface Account {
  id: string;
}

interface UploadIntent {
  file: { original_filename?: string };
}

/** Reading a file and importing rows happen in the worker; allow it time. */
const WORKER = { timeout: 45_000 };

/** A bank-style CSV whose headings Montra doesn't recognize, so columns are mapped by hand. */
const NOVEMBER = csvFile('hdfc-november-2026.csv', [
  ['On', 'Particulars', 'Chq', 'Out', 'In', 'Running'],
  ['01/11/2026', 'Salary November', 'NEFT001', '', '50000.00', '60000.00'],
  ['03/11/2026', 'Grocery Store', 'POS002', '1250.50', '', '58749.50'],
  ['05/11/2026', 'Electricity Bill', 'BIL003', '2100.00', '', '56649.50'],
]);

/** The value shown for a count (`<dt>` label → its `<dd>`) inside a region. */
function countOf(scope: Locator, label: string): Locator {
  return scope
    .locator('dt')
    .getByText(label, { exact: true })
    .locator('xpath=following-sibling::dd[1]');
}

/** A toast in the notifications region. */
function toast(page: Page, text: string): Locator {
  return page.getByRole('region', { name: 'Notifications' }).getByText(text);
}

/** The import row list item for one file row ("Row 3 …"). */
function importRow(page: Page, number: number): Locator {
  return page
    .getByRole('listitem')
    .filter({ has: page.getByText(new RegExp(`^Row ${number}\\b`)) });
}

async function chooseStatement(page: Page, file: Parameters<Locator['setInputFiles']>[0]) {
  await page.getByLabel('Statement file').setInputFiles(file);
  await page.getByRole('button', { name: 'Upload and read' }).click();
}

/** Columns step for NOVEMBER: the headings aren't recognized, so map them by hand. */
async function mapNovemberColumns(page: Page) {
  const step = page.getByRole('region', { name: 'Check the columns' });
  await expect(step.getByLabel('Date column')).toBeVisible(WORKER);
  await expect(step.getByText('Some required columns weren’t recognized.')).toBeVisible();
  await step.getByLabel('Date column').selectOption({ label: 'Column 1: On' });
  await step.getByLabel('How dates are written').selectOption('DD/MM/YYYY');
  await step.getByRole('radio', { name: /^Separate columns/ }).check();
  await step.getByLabel('Money out column').selectOption({ label: 'Column 4: Out' });
  await step.getByLabel('Money in column').selectOption({ label: 'Column 5: In' });
  await step.getByLabel('Reference column (optional)').selectOption({ label: 'Column 3: Chq' });
  await step.getByLabel('Balance column (optional)').selectOption({ label: 'Column 6: Running' });
  // The sample table labels each column with the role it now has.
  const sample = step.getByRole('table', { name: 'First rows of the file' });
  await expect(sample.getByRole('columnheader', { name: 'Column 4: Out Money out' })).toBeVisible();
  await expect(sample.getByRole('columnheader', { name: 'Column 5: In Money in' })).toBeVisible();
  await step.getByRole('button', { name: 'Apply and read rows' }).click();
}

test('12. import a statement, catch duplicates and reconcile the account', async ({ page }) => {
  test.setTimeout(240_000);
  await newUser(page, 'import', { name: 'E2E Importer' });
  const account = await api<Account>(page, 'POST', '/accounts', {
    name: 'HDFC Savings',
    account_type: 'bank',
    currency: 'INR',
    opening_balance: '10000.00',
    opening_date: '2026-10-01',
  });
  // Entered by hand before the statement arrives: the import must not add it twice.
  await api(page, 'POST', '/transactions', {
    type: 'expense',
    account_id: account.id,
    amount: '1250.50',
    merchant_name: 'Grocery Store',
    local_date: '2026-11-03',
  });

  // Account → file → columns.
  await page.goto('/dashboard');
  await expect(pageHeading(page, 'Home')).toBeVisible();
  await navigateTo(page, 'Imports');
  await expect(pageHeading(page, 'Statement imports')).toBeVisible();
  await page.getByRole('link', { name: 'New import' }).first().click();
  await expect(pageHeading(page, 'Import a statement')).toBeVisible();
  await page.getByLabel('Account', { exact: true }).selectOption({ label: 'HDFC Savings (INR)' });
  await page.getByRole('button', { name: 'Continue' }).click();
  await expect(page.getByRole('heading', { name: 'Upload the statement' })).toBeVisible();
  await chooseStatement(page, NOVEMBER);
  await mapNovemberColumns(page);

  // Review: two rows ready, the hand-entered grocery bill flagged as a possible duplicate.
  const review = page.getByRole('region', { name: 'Review the rows' });
  await expect(countOf(review, 'Will be imported')).toHaveText('2', WORKER);
  await expect(countOf(review, 'Rows in the file')).toHaveText('3');
  await expect(countOf(review, 'Possible duplicates')).toHaveText('1');
  await expect(countOf(review, 'Need fixing')).toHaveText('0');
  await expect(importRow(page, 2)).toContainText('Ready');
  await expect(importRow(page, 2)).toContainText('Salary November');
  await expect(importRow(page, 2)).toContainText('+₹50,000.00');
  await expect(importRow(page, 3)).toContainText('Possible duplicate');
  await expect(importRow(page, 3)).toContainText('Same amount and direction, Same date');
  await expect(
    importRow(page, 3).getByRole('button', { name: 'Import anyway: row 3' }),
  ).toBeVisible();
  await expect(importRow(page, 4)).toContainText('-₹2,100.00');
  await review.getByRole('button', { name: 'Continue' }).click();

  // Confirm: the statement facts add up, then import in the background.
  const confirm = page.getByRole('region', { name: 'Confirm the import' });
  await expect(confirm.getByRole('status')).toHaveText('2 rows will be imported.');
  const facts = confirm.getByRole('region', { name: 'Statement' });
  await expect(countOf(facts, 'Opening balance')).toHaveText('₹10,000.00');
  await expect(countOf(facts, 'Closing balance')).toHaveText('₹56,649.50');
  await expect(countOf(facts, 'Running balance')).toHaveText('Adds up');
  await confirm.getByRole('button', { name: 'Import transactions' }).click();
  const result = page.getByRole('region', { name: 'Import finished' });
  await expect(result).toBeVisible(WORKER);
  await expect(countOf(result, 'Imported')).toHaveText('2');
  await expect(countOf(result, 'Skipped')).toHaveText('1');
  await expect(countOf(result, 'Not added')).toHaveText('0');

  // The imported transactions are in the account's list and on /transactions.
  await result.getByRole('link', { name: 'View imported transactions' }).click();
  await expect(pageHeading(page, 'Transactions')).toBeVisible();
  await expect(page.getByRole('link', { name: 'Salary November' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Electricity Bill' })).toBeVisible();
  await page.goto('/transactions');
  await expect(page.getByRole('link', { name: 'Salary November' })).toHaveCount(1);
  await expect(page.getByRole('link', { name: 'Electricity Bill' })).toHaveCount(1);
  // The bank's grocery line was not added next to the hand-entered one.
  await expect(page.getByRole('link', { name: 'Grocery Store' })).toHaveCount(1);
  await page.goto(`/accounts/${account.id}`);
  await expect(pageHeading(page, 'HDFC Savings')).toBeVisible();
  await expect(page.getByText('₹56,649.50').first()).toBeVisible();
  await expect(page.getByRole('link', { name: 'Salary November' })).toBeVisible();

  // Reconcile: a wrong statement balance is not balanced and shows the difference.
  await page.goto(`/accounts/${account.id}/reconcile`);
  await expect(pageHeading(page, 'Reconcile HDFC Savings')).toBeVisible();
  const check = page.getByRole('region', { name: 'Check a statement balance' });
  await expect(check).toContainText('Balance in Montra today: ₹56,649.50');
  await check.getByLabel('Statement date').fill('2026-11-05');
  await check.getByLabel('Closing balance on the statement').fill('56000');
  await check.getByRole('button', { name: 'Check balance' }).click();
  const outcome = check.getByRole('region', { name: 'Statement of November 5, 2026' });
  await expect(outcome).toContainText('Not balanced yet');
  await expect(countOf(outcome, 'Statement balance')).toHaveText('₹56,000.00');
  await expect(countOf(outcome, 'Balance in Montra')).toHaveText('₹56,649.50');
  await expect(countOf(outcome, 'Difference')).toHaveText('-₹649.50');

  // The skipped statement line is unmatched until its suggested match is confirmed.
  const lines = page.getByRole('region', { name: 'Statement lines to match' });
  await expect(lines.getByRole('button', { name: 'Match by hand: Grocery Store' })).toBeVisible();
  const suggestions = page.getByRole('region', { name: 'Suggested matches' });
  await expect(suggestions).toContainText('Confidence: 95%');
  await suggestions.getByRole('button', { name: 'Confirm match: Grocery Store' }).click();
  await expect(toast(page, 'Match confirmed')).toBeVisible();
  await expect(lines.getByText('Every statement line is accounted for')).toBeVisible();
  const matches = page.getByRole('region', { name: 'Confirmed matches' });
  await expect(matches).toContainText('Matched amount: ₹1,250.50');
  await expect(
    matches.getByRole('button', { name: 'Undo match: Statement lines and your transactions' }),
  ).toBeVisible();

  // The right statement balance reconciles the account.
  await check.getByLabel('Closing balance on the statement').fill('56649.50');
  await check.getByRole('button', { name: 'Check balance' }).click();
  await expect(countOf(outcome, 'Statement balance')).toHaveText('₹56,649.50');
  await expect(countOf(outcome, 'Difference')).toHaveText('₹0.00');
  await expect(outcome.getByText('Balanced', { exact: true }).first()).toBeVisible();
  await expect(outcome).toContainText('now marked as reconciled');
  const history = page.getByRole('table', { name: 'Past balance checks' });
  await expect(history.getByRole('row')).toHaveCount(3);
  await expect(history.getByRole('row').nth(1)).toContainText('Balanced');
  await expect(history.getByRole('row').nth(2)).toContainText('Not balanced');

  // Importing the same file again: every row is recognized, nothing can be added.
  await page.getByRole('link', { name: 'Import statement' }).click();
  await expect(pageHeading(page, 'Import a statement')).toBeVisible();
  await page.getByRole('button', { name: 'Continue' }).click();
  await chooseStatement(page, NOVEMBER);
  await expect(page.getByText('You imported this file before')).toBeVisible(WORKER);
  await mapNovemberColumns(page);
  await expect(countOf(review, 'Will be imported')).toHaveText('0', WORKER);
  await expect(countOf(review, 'Possible duplicates')).toHaveText('3');
  await expect(importRow(page, 2)).toContainText('Already imported');
  await expect(importRow(page, 2)).toContainText(
    'This row was already imported into this account.',
  );
  await expect(importRow(page, 4)).toContainText('Already imported');
  await expect(importRow(page, 3)).toContainText('Possible duplicate');
  await review.getByRole('button', { name: 'Continue' }).click();
  await expect(confirm.getByRole('status')).toHaveText('0 rows will be imported.');
  await confirm.getByRole('button', { name: 'Cancel import' }).click();
  const cancel = page.getByRole('dialog', { name: 'Cancel this import?' });
  await cancel.getByRole('button', { name: 'Cancel import' }).click();
  await expect(toast(page, 'Import cancelled')).toBeVisible();
  await expect(pageHeading(page, 'Statement imports')).toBeVisible();

  // Still exactly one of each transaction.
  await page.goto('/transactions');
  await expect(page.getByRole('link', { name: 'Salary November' })).toHaveCount(1);
  await expect(page.getByRole('link', { name: 'Electricity Bill' })).toHaveCount(1);
  await expect(page.getByRole('link', { name: 'Grocery Store' })).toHaveCount(1);
});

test('12. reject malformed statements and unsafe file names, then undo an import', async ({
  page,
}) => {
  test.setTimeout(240_000);
  // A file name must never run as markup.
  const dialogs: string[] = [];
  page.on('dialog', (dialog) => {
    dialogs.push(dialog.message());
    void dialog.dismiss();
  });
  await newUser(page, 'badfile', { name: 'E2E Careful' });
  const account = await api<Account>(page, 'POST', '/accounts', {
    name: 'Axis Current',
    account_type: 'bank',
    currency: 'INR',
    opening_balance: '0',
    opening_date: '2026-10-01',
  });
  const fileStep = `/imports/new?account_id=${account.id}&step=file`;

  // A PDF is refused before anything is uploaded.
  await page.goto(fileStep);
  await expect(page.getByRole('heading', { name: 'Upload the statement' })).toBeVisible();
  await chooseStatement(page, rawFile('statement.pdf', 'application/pdf', '%PDF-1.4\n%%EOF\n'));
  await expect(
    page.getByText('PDF statements can’t be imported. Choose a CSV, XLSX or OFX file.'),
  ).toBeVisible();

  // Binary content dressed up as CSV is refused by the server's content check.
  await chooseStatement(page, receiptPng('statement.csv'));
  await expect(
    page.getByRole('alert').filter({ hasText: 'That file type isn’t supported.' }),
  ).toBeVisible();

  // A CSV the worker can't use, under a hostile name: a clear reason, no markup.
  const wide = Array.from({ length: 70 }, (_, index) => `c${index + 1}`).join(',');
  const intent = page.waitForResponse((response) =>
    response.url().endsWith('/files/upload-intent'),
  );
  await chooseStatement(
    page,
    rawFile('<img src=x onerror="window.__pwned=1">.csv', 'text/csv', `${wide}\r\n${wide}\r\n`),
  );
  const stored = ((await (await intent).json()) as { data: UploadIntent }).data.file;
  expect(stored.original_filename ?? '').not.toMatch(/[<>"]/);
  const failed = page.getByRole('region', { name: 'This file couldn’t be imported' });
  await expect(failed).toBeVisible(WORKER);
  await expect(failed).toContainText('The file has too many columns to be a statement.');
  expect(await page.evaluate(() => '__pwned' in window)).toBe(false);

  // Choosing another file goes back to the file step for the same account.
  await failed.getByRole('link', { name: 'Choose another file' }).click();
  await expect(page.getByText('Account: Axis Current (INR)')).toBeVisible();

  // A path-like name is reduced to its base name; recognized columns need no mapping.
  const pathIntent = page.waitForResponse((response) =>
    response.url().endsWith('/files/upload-intent'),
  );
  await chooseStatement(
    page,
    csvFile('../../etc/passwd.csv', [
      ['Date', 'Description', 'Amount'],
      ['07/11/2026', 'Coffee Beans', '-450.00'],
      ['08/11/2026', 'Store Cashback', '120.00'],
    ]),
  );
  const pathStored = ((await (await pathIntent).json()) as { data: UploadIntent }).data.file;
  expect(pathStored.original_filename).toBe('passwd.csv');
  const columns = page.getByRole('region', { name: 'Check the columns' });
  await expect(columns.getByLabel('Amount column', { exact: true })).toHaveValue('2', WORKER);
  await columns.getByRole('button', { name: 'Columns look right' }).click();
  const review = page.getByRole('region', { name: 'Review the rows' });
  await expect(countOf(review, 'Will be imported')).toHaveText('2', WORKER);
  await review.getByRole('button', { name: 'Continue' }).click();
  await page.getByRole('button', { name: 'Import transactions' }).click();
  const result = page.getByRole('region', { name: 'Import finished' });
  await expect(result).toBeVisible(WORKER);
  await expect(countOf(result, 'Imported')).toHaveText('2');
  const detailsHref = await result
    .getByRole('link', { name: 'View import details' })
    .getAttribute('href');
  expect(detailsHref).toMatch(/^\/imports\/[0-9a-f-]{36}$/);

  await page.goto('/transactions');
  await expect(page.getByRole('link', { name: 'Coffee Beans' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Store Cashback' })).toBeVisible();

  // Undo the import from its page: both transactions are removed.
  await page.goto(detailsHref ?? '/imports');
  await expect(pageHeading(page, /^Statement import$/)).toBeVisible();
  await page.getByRole('button', { name: 'Undo import' }).click();
  const undo = page.getByRole('dialog', { name: 'Undo this import?' });
  await expect(undo).toContainText('This removes the 2 transactions this import added.');
  await undo.getByRole('button', { name: 'Undo import' }).click();
  const status = page.getByRole('region', { name: 'Status' });
  await expect(status.getByText('Import undone')).toBeVisible(WORKER);
  await expect(status).toContainText('Transactions removed: 2.');
  await expect(importRow(page, 2)).toContainText('Removed when the import was undone.');

  await page.goto('/transactions');
  await expect(pageHeading(page, 'Transactions')).toBeVisible();
  await expect(page.getByRole('link', { name: 'Coffee Beans' })).toHaveCount(0);
  await expect(page.getByRole('link', { name: 'Store Cashback' })).toHaveCount(0);

  // The import history lists every attempt, with its outcome.
  await navigateTo(page, 'Imports');
  await expect(pageHeading(page, 'Statement imports')).toBeVisible();
  await expect(page.getByText('Undone').first()).toBeVisible();
  await expect(page.getByText('Couldn’t read the file').first()).toBeVisible();
  expect(dialogs).toEqual([]);
});

test('11. upload a receipt, enter it by hand and link it to its transaction', async ({ page }) => {
  test.setTimeout(240_000);
  await newUser(page, 'receipt', { name: 'E2E Receipts' });
  const account = await api<Account>(page, 'POST', '/accounts', {
    name: 'ICICI Savings',
    account_type: 'bank',
    currency: 'INR',
    opening_balance: '5000.00',
    opening_date: '2026-10-01',
  });
  // An expense recorded earlier, waiting for its receipt.
  await api(page, 'POST', '/transactions', {
    type: 'expense',
    account_id: account.id,
    amount: '899.00',
    merchant_name: 'Croma',
    local_date: '2026-11-09',
  });

  // Upload a photo (a tiny synthetic PNG). Without automatic reading it waits for details.
  await page.goto('/dashboard');
  await expect(pageHeading(page, 'Home')).toBeVisible();
  await navigateTo(page, 'Receipts');
  await expect(pageHeading(page, /^Receipts$/)).toBeVisible();
  await expect(page.getByText('No receipts yet')).toBeVisible();
  await page.getByRole('button', { name: 'Add receipt' }).first().click();
  const add = page.getByRole('dialog', { name: 'Add a receipt' });
  await add.getByLabel('Choose files').setInputFiles(receiptPng('chai-point.png'));
  await expect(add.getByText('chai-point.png')).toBeVisible();
  await add.getByRole('button', { name: 'Add receipt' }).click();
  await expect(toast(page, 'Receipt added')).toBeVisible();
  await expect(pageHeading(page, /^Receipt$/)).toBeVisible();
  await expect(page.getByText('Needs details', { exact: true })).toBeVisible();
  await expect(page.getByRole('figure', { name: /Receipt image/ })).toBeVisible();

  // Manual entry: merchant, date and total.
  const details = page.getByRole('region', { name: 'Details' });
  await details.getByLabel('Merchant (optional)').fill('Chai Point');
  await details.getByLabel('Date on the receipt').fill('2026-11-10');
  await details.getByLabel('Total', { exact: true }).fill('240.00');
  await details.getByRole('button', { name: 'Save details' }).click();
  await expect(toast(page, 'Details saved')).toBeVisible();
  await expect(pageHeading(page, 'Chai Point')).toBeVisible();
  await expect(page.getByText('Reviewed', { exact: true })).toBeVisible();
  await expect(page.getByRole('region', { name: 'History' })).toContainText(
    'Details entered by you',
  );

  // Record it as a new expense.
  const link = page.getByRole('region', { name: 'Transaction' });
  await link.getByRole('button', { name: 'Record as expense' }).click();
  const record = page.getByRole('dialog', { name: 'Record as expense' });
  await expect(record).toContainText('₹240.00');
  await record
    .getByLabel('Account', { exact: true })
    .selectOption({ label: 'ICICI Savings (INR)' });
  await record.getByLabel('Category (optional)').selectOption({ label: 'Food & dining' });
  await record.getByRole('button', { name: 'Record expense' }).click();
  await expect(toast(page, 'Expense recorded and linked')).toBeVisible();
  await expect(page.getByText('Linked', { exact: true })).toBeVisible();
  await expect(link).toContainText('-₹240.00');

  // The new transaction shows the receipt and its file.
  await link.getByRole('link', { name: 'Chai Point' }).click();
  await expect(pageHeading(page, 'Chai Point')).toBeVisible();
  await expect(page.getByRole('region', { name: 'Amount' })).toContainText('-₹240.00');
  const files = page.getByRole('region', { name: 'Files' });
  await expect(files.getByRole('link', { name: 'Open receipt' })).toBeVisible();
  await expect(files.getByText('chai-point.png')).toBeVisible();
  await files.getByRole('link', { name: 'Open receipt' }).click();
  await expect(pageHeading(page, 'Chai Point')).toBeVisible();

  // A second receipt matches the expense recorded earlier.
  await page.getByRole('link', { name: 'All receipts' }).click();
  await expect(pageHeading(page, /^Receipts$/)).toBeVisible();
  await page.getByRole('button', { name: 'Add receipt' }).first().click();
  await add.getByLabel('Choose files').setInputFiles(receiptPng('croma-invoice.png'));
  await add.getByRole('button', { name: 'Add receipt' }).click();
  await expect(pageHeading(page, /^Receipt$/)).toBeVisible();
  await details.getByLabel('Merchant (optional)').fill('Croma');
  await details.getByLabel('Date on the receipt').fill('2026-11-09');
  await details.getByLabel('Total', { exact: true }).fill('899.00');
  await details.getByRole('button', { name: 'Save details' }).click();
  await expect(pageHeading(page, 'Croma')).toBeVisible();
  await link.getByRole('button', { name: 'Link existing transaction' }).click();
  const match = page.getByRole('dialog', { name: 'Link a transaction' });
  const suggestion = match.getByRole('radio', { name: /^Croma .*Same amount as the total/ });
  await expect(suggestion).toBeVisible();
  await suggestion.check();
  await match.getByRole('button', { name: 'Link receipt' }).click();
  // The dialog closes once the receipt is linked, with a confirmation.
  await expect(toast(page, 'Receipt linked')).toBeVisible();
  await expect(match).toBeHidden();
  await expect(page.getByText('Linked', { exact: true })).toBeVisible();
  await expect(link).toContainText('-₹899.00');
  await link.getByRole('link', { name: 'Croma' }).click();
  await expect(pageHeading(page, 'Croma')).toBeVisible();
  await expect(
    page.getByRole('region', { name: 'Files' }).getByRole('link', { name: 'Open receipt' }),
  ).toBeVisible();

  // Both receipts are linked; the recorded expense is in the transaction list once.
  await page.goto('/receipts');
  await expect(page.getByText('Showing 2 receipts')).toBeVisible();
  const inbox = page.getByRole('region', { name: 'Your receipts' }).getByRole('listitem');
  await expect(inbox).toHaveCount(2);
  for (const [merchant, total] of [
    ['Croma', '₹899.00'],
    ['Chai Point', '₹240.00'],
  ] as const) {
    const item = inbox.filter({ has: page.getByRole('link', { name: merchant }) });
    await expect(item).toContainText('Linked');
    await expect(item).toContainText(total);
  }
  await page.goto('/transactions');
  await expect(page.getByRole('link', { name: 'Chai Point' })).toHaveCount(1);
  await expect(page.getByRole('link', { name: 'Croma' })).toHaveCount(1);
});
