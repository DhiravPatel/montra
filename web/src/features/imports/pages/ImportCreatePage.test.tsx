import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { importKeys } from '@/features/imports/keys';
import type { ImportBatch, ImportRow, ImportRowUpdate } from '@/features/imports/types';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { ACCOUNT_CARD, ACCOUNT_CASH, makeAccount, makeCard, money } from '@/tests/financeFixtures';
import {
  FILE_ID,
  IMPORT_ID,
  ROW_DUPLICATE,
  ROW_INVALID,
  ROW_SALARY,
  TX_EXISTING,
  makeBatch,
  makeNewBatch,
  makeUnmappedBatch,
  previewRows,
  serveRows,
  statementFile,
  unmappedRows,
  uploadHandlers,
} from '@/tests/importsFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const wizard = `/imports/new?import_id=${IMPORT_ID}`;

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

/** Serves GET /imports/{id}: each call takes the next batch, the last one repeats. */
function serveBatch(...sequence: ImportBatch[]) {
  const state = { calls: 0 };
  server.use(
    http.get(`${API}/imports/:id`, () => {
      const batch = sequence[Math.min(state.calls, sequence.length - 1)]!;
      state.calls += 1;
      return HttpResponse.json(envelope(batch));
    }),
  );
  return state;
}

function setVisibility(state: 'visible' | 'hidden') {
  Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => state });
  document.dispatchEvent(new Event('visibilitychange'));
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

beforeAll(async () => {
  await import('./ImportCreatePage');
});

beforeEach(() => {
  testBackend.accounts = [makeAccount(), makeCard()];
});

afterEach(() => {
  Reflect.deleteProperty(document, 'visibilityState');
});

describe('ImportCreatePage: account and file', () => {
  it('preselects the account from the link and asks for one when none is chosen', async () => {
    const user = userEvent.setup();
    renderRoute(`/imports/new?account_id=${ACCOUNT_CARD}`, { user: signedIn() });
    await findPageHeading('Import a statement');
    const steps = screen.getByRole('list', { name: 'Import steps' });
    expect(within(steps).getByText('Account').closest('li')).toHaveAttribute(
      'aria-current',
      'step',
    );
    const account = await screen.findByLabelText('Account');
    expect(account).toHaveValue(ACCOUNT_CARD);
    expect(
      screen.getByText('Rows are imported in INR, the account’s currency.'),
    ).toBeInTheDocument();

    await user.selectOptions(account, '');
    await user.click(screen.getByRole('button', { name: 'Continue' }));
    await waitFor(() => {
      expect(account).toHaveAccessibleDescription(/Choose an account\./);
    });

    await user.selectOptions(account, ACCOUNT_CASH);
    await user.click(screen.getByRole('button', { name: 'Continue' }));
    expect(await screen.findByRole('heading', { name: 'Upload the statement' })).toHaveFocus();
    expect(screen.getByText('Account: Wallet (INR)')).toBeInTheDocument();
    expect(screen.getByLabelText('Statement file')).toHaveAttribute(
      'accept',
      expect.stringContaining('.csv') as string,
    );
    expect(screen.getByLabelText('Statement file').getAttribute('accept')).not.toContain('pdf');
    expect(
      screen.getByText(/PDF statements can’t be imported, because reading them needs AI/),
    ).toBeInTheDocument();
  });

  it('offers to add an account when there is none to import into', async () => {
    testBackend.accounts = [makeAccount({ owned: false })];
    renderRoute('/imports/new', { user: signedIn() });
    await findPageHeading('Import a statement');
    expect(await screen.findByText('No account to import into')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Add an account' })).toHaveAttribute(
      'href',
      '/accounts/new',
    );
  });

  it('refuses PDFs, other types and oversized files before uploading anything', async () => {
    const intents: unknown[] = [];
    server.use(
      http.post(`${API}/files/upload-intent`, () => {
        intents.push(true);
        return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
      }),
    );
    const user = userEvent.setup({ applyAccept: false });
    renderRoute(`/imports/new?account_id=${ACCOUNT_CASH}&step=file`, { user: signedIn() });
    await findPageHeading('Import a statement');
    const input = await screen.findByLabelText('Statement file');

    await user.click(screen.getByRole('button', { name: 'Upload and read' }));
    await waitFor(() => {
      expect(input).toHaveAccessibleDescription(/Choose a statement file\./);
    });

    await user.upload(input, statementFile('statement.pdf', 'application/pdf'));
    await user.click(screen.getByRole('button', { name: 'Upload and read' }));
    await waitFor(() => {
      expect(input).toHaveAccessibleDescription(
        /PDF statements can’t be imported\. Choose a CSV, XLSX or OFX file\./,
      );
    });

    await user.upload(input, statementFile('notes.txt', 'text/plain'));
    await user.click(screen.getByRole('button', { name: 'Upload and read' }));
    await waitFor(() => {
      expect(input).toHaveAccessibleDescription(/This file type can’t be imported\./);
    });

    const big = statementFile();
    Object.defineProperty(big, 'size', { value: 10 * 1024 * 1024 + 1 });
    await user.upload(input, big);
    await user.click(screen.getByRole('button', { name: 'Upload and read' }));
    await waitFor(() => {
      expect(input).toHaveAccessibleDescription(/This file is larger than 10 MB\./);
    });
    expect(intents).toHaveLength(0);
  });

  it('uploads the file, starts the import and shows the columns step once the server has read it', async () => {
    const seen: string[] = [];
    let created: unknown = null;
    let key: string | null = null;
    server.use(
      ...uploadHandlers(seen),
      http.post(`${API}/imports`, async ({ request }) => {
        created = await request.json();
        key = request.headers.get('Idempotency-Key');
        return HttpResponse.json(envelope(makeNewBatch()), { status: 201 });
      }),
      serveRows(unmappedRows),
    );
    const reads = serveBatch(makeNewBatch({ status: 'parsing' }), makeUnmappedBatch());
    const user = userEvent.setup();
    const { router } = renderRoute(`/imports/new?account_id=${ACCOUNT_CASH}`, {
      user: signedIn(),
    });
    await findPageHeading('Import a statement');
    await user.click(await screen.findByRole('button', { name: 'Continue' }));
    await user.upload(await screen.findByLabelText('Statement file'), statementFile());
    await user.click(screen.getByRole('button', { name: 'Upload and read' }));

    expect(await screen.findByText('Reading your statement…')).toBeInTheDocument();
    expect(seen).toEqual(['intent', 'content', 'complete']);
    expect(created).toEqual({ account_id: ACCOUNT_CASH, file_id: FILE_ID });
    // A financial create: the key lets a retry replay the same batch.
    expect(key).toMatch(/^web-[0-9a-f-]{36}$/);
    expect(router.state.location.search).toBe(`?import_id=${IMPORT_ID}`);

    expect(await screen.findByLabelText('Date column')).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Check the columns' })).toBeInTheDocument();
    expect(
      screen.getByText('No row with column names was found. Choose the columns yourself.'),
    ).toBeInTheDocument();
    expect(reads.calls).toBeGreaterThanOrEqual(2);
  });

  it('explains why the import could not start and keeps the same key for another try', async () => {
    let attempts = 0;
    const keys: (string | null)[] = [];
    server.use(
      ...uploadHandlers(),
      http.post(`${API}/imports`, ({ request }) => {
        attempts += 1;
        keys.push(request.headers.get('Idempotency-Key'));
        return HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [{ message: 'Imports need an active account.', code: 'account_inactive' }],
          }),
          { status: 422 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/imports/new?account_id=${ACCOUNT_CASH}&step=file`, { user: signedIn() });
    await findPageHeading('Import a statement');
    await user.upload(await screen.findByLabelText('Statement file'), statementFile());
    await user.click(screen.getByRole('button', { name: 'Upload and read' }));
    expect(
      await screen.findByText('This account is archived or closed. Restore it first.'),
    ).toBeInTheDocument();
    // Nothing is stuck: the form can be submitted again, with the same key (nothing was created).
    await user.click(screen.getByRole('button', { name: 'Upload and read' }));
    await waitFor(() => {
      expect(attempts).toBe(2);
    });
    expect(keys[1]).toBe(keys[0]);
  });

  it('shows a not-found state for an import that no longer exists', async () => {
    server.use(
      http.get(`${API}/imports/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    renderRoute(wizard, { user: signedIn() });
    expect(await screen.findByText('Import not found')).toBeInTheDocument();
    expect(screen.getAllByRole('link', { name: 'All imports' }).at(-1)).toHaveAttribute(
      'href',
      '/imports',
    );
  });

  it('explains why the server could not read the file and offers another try', async () => {
    serveBatch(
      makeNewBatch({
        status: 'failed',
        error_code: 'currency_mismatch',
        error_message: 'The statement is in USD but the account is in INR.',
        error_params: { statement_currency: 'USD', account_currency: 'INR' },
      }),
    );
    renderRoute(wizard, { user: signedIn() });
    expect(await screen.findByText('This file couldn’t be imported')).toBeInTheDocument();
    expect(
      screen.getByText(
        'The statement is in USD, but the account is in INR. Import it into an account in USD.',
      ),
    ).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Choose another file' })).toHaveAttribute(
      'href',
      `/imports/new?account_id=${ACCOUNT_CASH}&step=file`,
    );
  });
});

describe('ImportCreatePage: columns', () => {
  it('validates the mapping, then sends it with the version and reads the rows again', async () => {
    const bodies: unknown[] = [];
    let mapped = false;
    server.use(
      serveRows(() => (mapped ? previewRows() : unmappedRows())),
      http.patch(`${API}/imports/:id/mapping`, async ({ request }) => {
        bodies.push(await request.json());
        mapped = true;
        return HttpResponse.json(
          envelope(makeUnmappedBatch({ status: 'parsing', version: 2, mapping_notes: [] })),
        );
      }),
    );
    server.use(
      http.get(`${API}/imports/:id`, () =>
        HttpResponse.json(envelope(mapped ? makeBatch({ version: 2 }) : makeUnmappedBatch())),
      ),
    );
    const user = userEvent.setup();
    renderRoute(wizard, { user: signedIn() });
    await findPageHeading('Import a statement');
    const dateColumn = await screen.findByLabelText('Date column');

    await user.click(screen.getByRole('button', { name: 'Apply and read rows' }));
    await waitFor(() => {
      expect(dateColumn).toHaveAccessibleDescription(/Choose the column with the date\./);
    });
    expect(screen.getByLabelText('How dates are written')).toHaveAccessibleDescription(
      /Choose how dates are written\./,
    );
    expect(screen.getByLabelText('Amount column')).toHaveAccessibleDescription(
      /Choose the column with the amount\./,
    );
    expect(bodies).toHaveLength(0);

    await user.selectOptions(screen.getByLabelText(/^Row with the column names/), '0');
    // Column names now come from the chosen row.
    expect(within(dateColumn).getByRole('option', { name: 'Column 1: When' })).toBeInTheDocument();
    await user.selectOptions(dateColumn, '0');
    await user.selectOptions(screen.getByLabelText('How dates are written'), 'YYYY-MM-DD');
    await user.selectOptions(screen.getByLabelText('Amount column'), '2');
    await user.click(screen.getByRole('checkbox', { name: 'Column 2: What' }));
    // The sample shows what each column is used for.
    const sample = screen.getByRole('table', { name: 'First rows of the file' });
    expect(
      within(sample).getByRole('columnheader', { name: /Column 3: How much\s*Amount/ }),
    ).toBeInTheDocument();
    expect(within(sample).getAllByRole('row')).toHaveLength(3);

    await user.click(screen.getByRole('button', { name: 'Apply and read rows' }));
    expect(await screen.findByText('Reading the rows with your columns…')).toBeInTheDocument();
    expect(bodies[0]).toEqual({
      mapping: {
        header_row: 0,
        date_column: 0,
        date_format: 'YYYY-MM-DD',
        decimal_separator: '.',
        description_columns: [1],
        amount_column: 2,
        sign_convention: 'negative_is_outflow',
      },
      version: 1,
    });
    expect(await screen.findByRole('heading', { name: 'Review the rows' })).toHaveFocus();
    expect(await screen.findByText('Row 4')).toBeInTheDocument();
  });

  it('sends separate money out and money in columns', async () => {
    const bodies: { mapping: Record<string, unknown> }[] = [];
    server.use(
      serveRows(previewRows),
      http.patch(`${API}/imports/:id/mapping`, async ({ request }) => {
        bodies.push((await request.json()) as { mapping: Record<string, unknown> });
        return HttpResponse.json(envelope(makeBatch({ status: 'parsing', version: 2 })));
      }),
    );
    serveBatch(makeBatch(), makeBatch({ status: 'parsing', version: 2 }));
    const user = userEvent.setup();
    renderRoute(wizard, { user: signedIn() });
    await findPageHeading('Import a statement');
    // The detected mapping (separate columns) is shown; changing a column re-reads the rows.
    expect(await screen.findByLabelText('Money out column')).toHaveValue('3');
    expect(screen.getByLabelText('Money in column')).toHaveValue('4');
    await user.selectOptions(screen.getByLabelText('Money in column'), '3');
    await user.click(screen.getByRole('button', { name: 'Apply and read rows' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Money in column')).toHaveAccessibleDescription(
        /Money out and money in must be different columns\./,
      );
    });
    await user.selectOptions(screen.getByLabelText('Money in column'), '4');
    await user.selectOptions(screen.getByLabelText(/^Balance column/), '');
    await user.click(screen.getByRole('button', { name: 'Apply and read rows' }));
    await waitFor(() => {
      expect(bodies).toHaveLength(1);
    });
    expect(bodies[0]?.mapping).toEqual({
      header_row: 1,
      date_column: 0,
      date_format: 'DD/MM/YYYY',
      decimal_separator: '.',
      description_columns: [1],
      debit_column: 3,
      credit_column: 4,
      reference_column: 2,
    });
  });

  it('reloads the import after a version conflict and keeps the user informed', async () => {
    server.use(
      serveRows(unmappedRows),
      http.patch(`${API}/imports/:id/mapping`, () =>
        HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 }),
      ),
    );
    const reads = serveBatch(makeUnmappedBatch(), makeUnmappedBatch({ version: 2 }));
    const user = userEvent.setup();
    renderRoute(wizard, { user: signedIn() });
    await findPageHeading('Import a statement');
    await user.selectOptions(await screen.findByLabelText('Date column'), '0');
    await user.selectOptions(screen.getByLabelText('How dates are written'), 'YYYY-MM-DD');
    await user.selectOptions(screen.getByLabelText('Amount column'), '2');
    await user.click(screen.getByRole('button', { name: 'Apply and read rows' }));
    expect(await screen.findByText('This was changed somewhere else')).toBeInTheDocument();
    await waitFor(() => {
      expect(reads.calls).toBe(2);
    });
    // The form was reset to the reloaded import's mapping.
    await waitFor(() => {
      expect(screen.getByLabelText('Date column')).toHaveValue('');
    });
  });
});

describe('ImportCreatePage: review', () => {
  it('shows duplicate and invalid rows with their reasons, and fixes, skips and imports rows', async () => {
    let rows: ImportRow[] = previewRows();
    const updates: { rowId: string; body: ImportRowUpdate }[] = [];
    server.use(
      serveRows(() => rows),
      http.patch(`${API}/imports/:id/rows/:rowId`, async ({ params, request }) => {
        const body = (await request.json()) as ImportRowUpdate;
        const rowId = String(params.rowId);
        updates.push({ rowId, body });
        rows = rows.map((row) => {
          if (row.id !== rowId) return row;
          if (body.amount) {
            return {
              ...row,
              status: 'ready',
              error_code: undefined,
              error_message: undefined,
              posted_date: body.posted_date,
              amount: money(body.amount),
              direction: body.direction,
              description: body.description,
            };
          }
          return { ...row, user_decision: body.decision };
        });
        return HttpResponse.json(envelope(rows.find((row) => row.id === rowId)));
      }),
    );
    serveBatch(makeBatch());
    const user = userEvent.setup();
    renderRoute(wizard, { user: signedIn() });
    await findPageHeading('Import a statement');
    await user.click(await screen.findByRole('button', { name: 'Columns look right' }));
    expect(await screen.findByRole('heading', { name: 'Review the rows' })).toHaveFocus();

    const counts = screen.getByText('Possible duplicates', { selector: 'dt' }).closest('div')!;
    expect(within(counts).getByText('1')).toBeInTheDocument();
    expect(
      await screen.findByText(
        'This may already be in your records: Same amount and direction, Same date, Similar description.',
      ),
    ).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'View the existing transaction' })).toHaveAttribute(
      'href',
      `/transactions/${TX_EXISTING}`,
    );
    // The reason by error_code (with its params) and the value to correct (error_field).
    expect(
      screen.getByText('The amount isn’t a valid INR amount. Correct the amount.'),
    ).toBeInTheDocument();
    expect(screen.getByText('The column headings.')).toBeInTheDocument();
    // What confirming would import now, as the server counts it (to_import_rows).
    const toImport = screen.getByText('Will be imported', { selector: 'dt' }).closest('div')!;
    expect(within(toImport).getByText('2')).toBeInTheDocument();

    // Only the rows that need fixing.
    await user.click(screen.getByRole('radio', { name: 'Need fixing' }));
    await waitFor(() => {
      expect(screen.queryByText('Row 4')).not.toBeInTheDocument();
    });
    await user.click(await screen.findByRole('button', { name: 'Fix row 7' }));
    const dialog = await screen.findByRole('dialog', { name: 'Correct row 7' });
    expect(
      within(dialog).getByText('31/10/2026 · BOOKSTORE · abc · 1,08,509.50'),
    ).toBeInTheDocument();
    // The value the server named is the first thing to fix.
    expect(within(dialog).getByText('Correct the amount.')).toBeInTheDocument();
    expect(within(dialog).getByLabelText('Amount')).toHaveFocus();
    await user.click(within(dialog).getByRole('button', { name: 'Save correction' }));
    await waitFor(() => {
      expect(within(dialog).getByLabelText('Date')).toHaveAccessibleDescription(/Choose a date\./);
    });
    expect(within(dialog).getByRole('group', { name: 'Direction' })).toHaveAccessibleDescription(
      /Choose money in or money out\./,
    );
    await user.type(within(dialog).getByLabelText('Date'), '2026-10-31');
    await user.click(within(dialog).getByRole('radio', { name: 'Money out' }));
    await user.type(within(dialog).getByLabelText('Amount'), '300');
    await user.type(within(dialog).getByLabelText(/^Description/), 'Bookstore');
    await user.click(within(dialog).getByRole('button', { name: 'Save correction' }));
    expect(await screen.findByText('Row 7 corrected and ready to import')).toBeInTheDocument();
    expect(updates[0]).toEqual({
      rowId: ROW_INVALID,
      body: {
        posted_date: '2026-10-31',
        amount: '300.00',
        direction: 'outflow',
        description: 'Bookstore',
      },
    });

    // Skip a ready row, then import the possible duplicate anyway.
    await user.click(screen.getByRole('radio', { name: 'All rows' }));
    await user.click(await screen.findByRole('button', { name: 'Skip row 4' }));
    expect(await screen.findByText('Row 4 will be skipped')).toBeInTheDocument();
    expect(updates[1]).toEqual({ rowId: ROW_SALARY, body: { decision: 'skip' } });
    expect(await screen.findByText('You chose to skip')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Include row 4' })).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Import anyway: row 3' }));
    expect(await screen.findByText('Row 3 will be imported')).toBeInTheDocument();
    expect(updates[2]).toEqual({ rowId: ROW_DUPLICATE, body: { decision: 'import' } });
    expect(await screen.findByText('You chose to import')).toBeInTheDocument();
  });

  it('loads more rows with the row cursor', async () => {
    const many = Array.from({ length: 60 }, (_, index) => ({
      ...previewRows()[3]!,
      id: `e2000000-0000-4000-8000-${String(index).padStart(12, '0')}`,
      row_number: index + 1,
    }));
    const seen: URL[] = [];
    server.use(serveRows(() => many, seen));
    serveBatch(makeBatch({ total_rows: 60 }));
    const user = userEvent.setup();
    renderRoute(wizard, { user: signedIn() });
    await findPageHeading('Import a statement');
    await user.click(await screen.findByRole('button', { name: 'Columns look right' }));
    expect(await screen.findByText('Row 50')).toBeInTheDocument();
    expect(screen.queryByText('Row 51')).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Load more rows' }));
    expect(await screen.findByText('Row 60')).toBeInTheDocument();
    const pages = seen.filter((url) => url.searchParams.get('limit') === '50');
    expect(pages.at(-1)?.searchParams.get('after_row')).toBe('50');
    expect(screen.queryByRole('button', { name: 'Load more rows' })).not.toBeInTheDocument();
  });
});

describe('ImportCreatePage: confirm and result', () => {
  it('confirms with an Idempotency-Key, polls while importing and shows the server counts', async () => {
    const confirms: { key: string | null; body: unknown }[] = [];
    server.use(
      serveRows(previewRows),
      http.post(`${API}/imports/:id/confirm`, async ({ request }) => {
        confirms.push({ key: request.headers.get('Idempotency-Key'), body: await request.json() });
        return HttpResponse.json(envelope(makeBatch({ status: 'confirmed', version: 2 })), {
          status: 202,
        });
      }),
    );
    serveBatch(
      makeBatch(),
      makeBatch({ status: 'processing', version: 2 }),
      makeBatch({
        status: 'completed',
        version: 2,
        imported_count: 5,
        skipped_count: 1,
        duplicate_rows: 0,
        invalid_rows: 1,
        completed_at: '2026-11-05T08:56:00Z',
      }),
    );
    const user = userEvent.setup();
    renderRoute(wizard, { user: signedIn() });
    await findPageHeading('Import a statement');
    await user.click(await screen.findByRole('button', { name: 'Columns look right' }));
    await user.click(await screen.findByRole('button', { name: 'Continue' }));
    expect(await screen.findByRole('heading', { name: 'Confirm the import' })).toHaveFocus();
    expect(screen.getByText('Into: Wallet')).toBeInTheDocument();
    expect(screen.getByText('2 rows will be imported.')).toBeInTheDocument();
    expect(screen.getByText('Adds up')).toBeInTheDocument();
    expect(screen.getByText('₹60,000.00')).toBeInTheDocument(); // money in, from the server's totals

    await user.click(screen.getByRole('button', { name: 'Import transactions' }));
    expect(await screen.findByText('Adding your transactions…')).toBeInTheDocument();
    expect(confirms).toEqual([
      { key: expect.stringMatching(/^web-[0-9a-f-]{36}$/) as string, body: { version: 1 } },
    ]);

    expect(await screen.findByRole('heading', { name: 'Import finished' })).toBeInTheDocument();
    const grid = (label: string) => screen.getByText(label, { selector: 'dt' }).closest('div')!;
    expect(within(grid('Imported')).getByText('5')).toBeInTheDocument();
    expect(within(grid('Skipped')).getByText('1')).toBeInTheDocument();
    expect(within(grid('Not added')).getByText('0')).toBeInTheDocument();
    expect(within(grid('Possible duplicates')).getByText('0')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'View import details' })).toHaveAttribute(
      'href',
      `/imports/${IMPORT_ID}`,
    );
    expect(screen.getByRole('link', { name: 'Reconcile the account' })).toHaveAttribute(
      'href',
      `/accounts/${ACCOUNT_CASH}/reconcile`,
    );
  });

  it('explains when there is nothing to import and keeps the same key for a retry', async () => {
    const keys: (string | null)[] = [];
    server.use(
      serveRows(previewRows),
      http.post(`${API}/imports/:id/confirm`, ({ request }) => {
        keys.push(request.headers.get('Idempotency-Key'));
        return HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [{ message: 'There are no rows to import.', code: 'no_rows' }],
          }),
          { status: 422 },
        );
      }),
    );
    serveBatch(makeBatch());
    const user = userEvent.setup();
    renderRoute(wizard, { user: signedIn() });
    await findPageHeading('Import a statement');
    await user.click(await screen.findByRole('button', { name: 'Columns look right' }));
    await user.click(await screen.findByRole('button', { name: 'Continue' }));
    await user.click(await screen.findByRole('button', { name: 'Import transactions' }));
    expect(
      await screen.findByText(
        'There are no rows to import. Include at least one row, or cancel this import.',
      ),
    ).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Import transactions' }));
    await waitFor(() => {
      expect(keys).toHaveLength(2);
    });
    expect(keys[1]).toBe(keys[0]);
  });

  it('reloads after a version conflict and confirms the latest version', async () => {
    const confirms: { key: string | null; body: unknown }[] = [];
    let conflicted = false;
    let reloads = 0;
    server.use(
      serveRows(previewRows),
      http.post(`${API}/imports/:id/confirm`, async ({ request }) => {
        confirms.push({ key: request.headers.get('Idempotency-Key'), body: await request.json() });
        if (confirms.length === 1) {
          conflicted = true;
          return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
        }
        return HttpResponse.json(envelope(makeBatch({ status: 'confirmed', version: 3 })), {
          status: 202,
        });
      }),
      http.get(`${API}/imports/:id`, () => {
        if (conflicted) reloads += 1;
        return HttpResponse.json(envelope(makeBatch({ version: conflicted ? 2 : 1 })));
      }),
    );
    const user = userEvent.setup();
    const { queryClient } = renderRoute(wizard, { user: signedIn() });
    await findPageHeading('Import a statement');
    await user.click(await screen.findByRole('button', { name: 'Columns look right' }));
    await user.click(await screen.findByRole('button', { name: 'Continue' }));
    await user.click(await screen.findByRole('button', { name: 'Import transactions' }));
    expect(await screen.findByText('This was changed somewhere else')).toBeInTheDocument();
    // The reloaded import (version 2) is what gets confirmed next.
    await waitFor(() => {
      expect(queryClient.getQueryData<ImportBatch>(importKeys.batch(IMPORT_ID))?.version).toBe(2);
    });
    expect(reloads).toBeGreaterThan(0);
    await user.click(screen.getByRole('button', { name: 'Import transactions' }));
    await waitFor(() => {
      expect(confirms).toHaveLength(2);
    });
    expect(confirms[0]?.body).toEqual({ version: 1 });
    expect(confirms[1]?.body).toEqual({ version: 2 });
    // Nothing was stored for the refused attempt, so the same draft key is reused.
    expect(confirms[1]?.key).toBe(confirms[0]?.key);
  });

  it('cancels the import before it is confirmed', async () => {
    let cancelled = false;
    server.use(
      serveRows(previewRows),
      http.post(`${API}/imports/:id/cancel`, () => {
        cancelled = true;
        return HttpResponse.json(envelope(makeBatch({ status: 'cancelled', version: 2 })));
      }),
      http.get(`${API}/imports`, () => HttpResponse.json(envelope([]))),
    );
    serveBatch(makeBatch());
    const user = userEvent.setup();
    const { router } = renderRoute(wizard, { user: signedIn() });
    await findPageHeading('Import a statement');
    await user.click(await screen.findByRole('button', { name: 'Cancel import' }));
    const dialog = await screen.findByRole('dialog', { name: 'Cancel this import?' });
    expect(within(dialog).getByRole('button', { name: 'Keep it' })).toHaveFocus();
    await user.click(within(dialog).getByRole('button', { name: 'Cancel import' }));
    expect(await screen.findByText('Import cancelled')).toBeInTheDocument();
    expect(cancelled).toBe(true);
    await waitFor(() => {
      expect(router.state.location.pathname).toBe('/imports');
    });
  });
});

describe('ImportCreatePage: polling', () => {
  it('pauses polling while the page is hidden and catches up when it is visible again', async () => {
    const reads = serveBatch(makeNewBatch({ status: 'parsing' }));
    renderRoute(wizard, { user: signedIn() });
    expect(await screen.findByText('Reading your statement…')).toBeInTheDocument();
    await waitFor(() => {
      expect(reads.calls).toBe(1);
    });
    setVisibility('hidden');
    await sleep(1400);
    expect(reads.calls).toBe(1);

    setVisibility('visible');
    await waitFor(() => {
      expect(reads.calls).toBe(2);
    });
  });

  it('stops polling once the import has finished', async () => {
    const reads = serveBatch(
      makeBatch({ status: 'processing', version: 2 }),
      makeBatch({ status: 'completed', version: 2, imported_count: 3 }),
    );
    renderRoute(wizard, { user: signedIn() });
    expect(await screen.findByRole('heading', { name: 'Import finished' })).toBeInTheDocument();
    await sleep(300);
    const settled = reads.calls;
    await sleep(1400);
    expect(reads.calls).toBe(settled);
  });
});
