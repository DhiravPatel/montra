import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import type { ImportBatch, ImportRow, ImportRowUpdate } from '@/features/imports/types';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { makeAccount, money } from '@/tests/financeFixtures';
import {
  IMPORT_ID,
  IMPORT_OLD,
  ROW_FAILED,
  TX_IMPORTED,
  makeBatch,
  makeRow,
  serveRows,
} from '@/tests/importsFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const path = `/imports/${IMPORT_ID}`;

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

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

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** An import that finished with rows the ledger refused (e.g. a date far in the future). */
function withErrors(overrides: Partial<ImportBatch> = {}): ImportBatch {
  return makeBatch({
    status: 'completed_with_errors',
    version: 2,
    imported_count: 2,
    skipped_count: 1,
    failed_count: 3,
    duplicate_rows: 0,
    invalid_rows: 1,
    confirmed_at: '2026-11-05T08:55:56Z',
    completed_at: '2026-11-05T08:55:58Z',
    ...overrides,
  });
}

function resultRows(): ImportRow[] {
  return [
    makeRow({ status: 'imported', transaction_id: TX_IMPORTED }),
    makeRow({
      id: ROW_FAILED,
      row_number: 8,
      raw: ['03/11/2028', 'ELECTRICITY BILL', 'BBPS9', '2,000.00', '', '1,06,509.50'],
      posted_date: '2028-11-03',
      amount: money('2000.00'),
      direction: 'outflow',
      description: 'ELECTRICITY BILL',
      status: 'failed',
      // The ledger's coded reason, with the value to correct.
      error_code: 'invalid_date',
      error_field: 'posted_date',
      error_message: 'Date is too far in the future.',
    }),
    makeRow({
      id: 'e0000000-0000-4000-8000-000000000009',
      row_number: 9,
      status: 'failed',
      // A domain rule the row hit while it was imported.
      error_code: 'account_inactive',
      error_message: 'Restore the account before adjusting its balance.',
    }),
    makeRow({
      id: 'e0000000-0000-4000-8000-000000000010',
      row_number: 10,
      status: 'failed',
      // A code newer than this client: the server's own words are shown.
      error_code: 'quarantined',
      error_message: 'The row was quarantined.',
    }),
  ];
}

beforeAll(async () => {
  await import('./ImportDetailPage');
});

beforeEach(() => {
  testBackend.accounts = [makeAccount()];
});

describe('ImportDetailPage', () => {
  it('shows the status, server counts, the statement and the rows by status with reasons', async () => {
    const seen: URL[] = [];
    server.use(serveRows(resultRows, seen));
    serveBatch(withErrors({ previous_import_of_file: IMPORT_OLD }));
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Statement import');
    expect(screen.getByText(/^Wallet · started Nov 5, 2026/)).toBeInTheDocument();
    expect(screen.getByText('Imported, some rows not added')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'View the earlier import' })).toHaveAttribute(
      'href',
      `/imports/${IMPORT_OLD}`,
    );

    const counts = screen.getByRole('region', { name: 'Rows' });
    const grid = (label: string) =>
      within(counts).getByText(label, { selector: 'dt' }).closest('div')!;
    expect(within(grid('Imported')).getByText('2')).toBeInTheDocument();
    expect(within(grid('Skipped')).getByText('1')).toBeInTheDocument();
    expect(within(grid('Not added')).getByText('3')).toBeInTheDocument();

    const statement = screen.getByRole('region', { name: 'Statement' });
    expect(within(statement).getByText('Oct 26 – Nov 3, 2026')).toBeInTheDocument();
    expect(within(statement).getByText('₹108,629.50')).toBeInTheDocument(); // closing balance

    // Rows that were not added are shown first, with the ledger's reason by error_code
    // and the value to correct (error_field).
    const rows = screen.getByRole('region', { name: 'Statement rows' });
    expect(within(rows).getByRole('radio', { name: 'Not added' })).toBeChecked();
    expect(
      await within(rows).findByText(
        'The date couldn’t be accepted (for example, too far in the future). Correct the date.',
      ),
    ).toBeInTheDocument();
    // A domain-rule code is worded like everywhere else; an unknown code keeps the server's words.
    expect(
      within(rows).getByText('This account is archived or closed. Restore it first.'),
    ).toBeInTheDocument();
    expect(
      within(rows).getByText('This row couldn’t be added: The row was quarantined.'),
    ).toBeInTheDocument();
    expect(seen.at(-1)?.searchParams.get('status')).toBe('failed');

    await user.click(within(rows).getByRole('radio', { name: 'Imported' }));
    expect(await within(rows).findByRole('link', { name: 'View transaction' })).toHaveAttribute(
      'href',
      `/transactions/${TX_IMPORTED}`,
    );
  });

  it('fixes a row that was not added, then retries the failed rows', async () => {
    const updates: ImportRowUpdate[] = [];
    let retried = 0;
    server.use(
      serveRows(resultRows),
      http.patch(`${API}/imports/:id/rows/:rowId`, async ({ request }) => {
        updates.push((await request.json()) as ImportRowUpdate);
        return HttpResponse.json(envelope(makeRow({ id: ROW_FAILED, status: 'ready' })));
      }),
      http.post(`${API}/imports/:id/retry-failed`, () => {
        retried += 1;
        return HttpResponse.json(envelope(withErrors({ status: 'confirmed', version: 3 })));
      }),
    );
    let polls = 0;
    server.use(
      http.get(`${API}/imports/:id`, () => {
        if (retried === 0) return HttpResponse.json(envelope(withErrors()));
        polls += 1;
        return HttpResponse.json(
          envelope(
            polls < 2
              ? withErrors({ status: 'processing', version: 3 })
              : withErrors({ status: 'completed', version: 3, imported_count: 3, failed_count: 0 }),
          ),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Statement import');
    await user.click(await screen.findByRole('button', { name: 'Fix row 8' }));
    const dialog = await screen.findByRole('dialog', { name: 'Correct row 8' });
    const date = within(dialog).getByLabelText('Date');
    expect(date).toHaveValue('2028-11-03');
    // The server named the date (error_field): it is focused and called out.
    expect(date).toHaveFocus();
    expect(within(dialog).getByText('Correct the date.')).toBeInTheDocument();
    expect(within(dialog).getByLabelText('Amount')).toHaveValue('2000.00');
    await user.clear(date);
    await user.type(date, '2026-11-03');
    await user.click(within(dialog).getByRole('button', { name: 'Save correction' }));
    expect(
      await screen.findByText('Row 8 corrected. Retry the rows that weren’t added to import it.'),
    ).toBeInTheDocument();
    expect(updates[0]).toEqual({
      posted_date: '2026-11-03',
      amount: '2000.00',
      direction: 'outflow',
      description: 'ELECTRICITY BILL',
    });

    await user.click(screen.getByRole('button', { name: 'Retry rows not added' }));
    expect(await screen.findByText('Trying the rows again…')).toBeInTheDocument();
    expect(retried).toBe(1);
    expect(await screen.findByText('Importing your transactions…')).toBeInTheDocument();
    // Polling picks up the finished import; the retry is no longer offered.
    await waitFor(() => {
      expect(screen.queryByText('Importing your transactions…')).not.toBeInTheDocument();
    });
    expect(screen.queryByRole('button', { name: 'Retry rows not added' })).not.toBeInTheDocument();
    const counts = screen.getByRole('region', { name: 'Rows' });
    const imported = within(counts).getByText('Imported', { selector: 'dt' }).closest('div')!;
    expect(within(imported).getByText('3')).toBeInTheDocument();
  });

  it('undoes an import after confirming what is removed and what is kept', async () => {
    let rolledBack = 0;
    server.use(
      serveRows(resultRows),
      http.post(`${API}/imports/:id/rollback`, () => {
        rolledBack += 1;
        return HttpResponse.json(
          envelope(makeBatch({ status: 'processing', version: 3, imported_count: 5 })),
        );
      }),
    );
    let polls = 0;
    server.use(
      http.get(`${API}/imports/:id`, () => {
        if (rolledBack === 0) {
          return HttpResponse.json(
            envelope(makeBatch({ status: 'completed', version: 2, imported_count: 5 })),
          );
        }
        polls += 1;
        return HttpResponse.json(
          envelope(
            polls < 2
              ? makeBatch({ status: 'processing', version: 3, imported_count: 5 })
              : makeBatch({
                  status: 'cancelled',
                  version: 3,
                  imported_count: 1,
                  skipped_count: 5,
                  error_code: 'rolled_back',
                  error_message:
                    'Rolled back 4 transactions; kept 1 that were edited or linked after import.',
                  error_params: { voided: '4', kept: '1' },
                  cancelled_at: '2026-11-05T09:00:00Z',
                }),
          ),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Statement import');
    await user.click(screen.getByRole('button', { name: 'Undo import' }));
    const dialog = await screen.findByRole('dialog', { name: 'Undo this import?' });
    expect(
      within(dialog).getByText('This removes the 5 transactions this import added.'),
    ).toBeInTheDocument();
    expect(
      within(dialog).getByText(
        'Transactions you changed, matched, reconciled or linked since the import are kept.',
      ),
    ).toBeInTheDocument();
    expect(within(dialog).getByRole('button', { name: 'Keep transactions' })).toHaveFocus();
    await user.click(within(dialog).getByRole('button', { name: 'Undo import' }));
    expect(await screen.findByText('Undoing the import…')).toBeInTheDocument();
    expect(rolledBack).toBe(1);
    expect(await screen.findByText('Import undone')).toBeInTheDocument();
    expect(
      screen.getByText(
        'Transactions removed: 4. Kept because they were changed, matched or reconciled after the import: 1.',
      ),
    ).toBeInTheDocument();
    expect(screen.getByText('Undone')).toBeInTheDocument();
  });

  it('does not link transactions an undo removed, and still links the ones it kept', async () => {
    const TX_KEPT = '77777777-7777-4777-8777-777777777712';
    server.use(
      serveRows(() => [
        // Removed by the undo: the server keeps the transaction ID, but the
        // transaction is gone (voided), so it is shown as removed, not linked.
        makeRow({
          status: 'skipped',
          transaction_id: TX_IMPORTED,
          error_code: 'rolled_back',
          error_message: 'Removed by rolling back this import.',
        }),
        // Kept because it changed after the import: still in the ledger.
        makeRow({
          id: 'e0000000-0000-4000-8000-000000000011',
          row_number: 5,
          description: 'COFFEE',
          status: 'imported',
          transaction_id: TX_KEPT,
        }),
      ]),
    );
    serveBatch(
      makeBatch({
        status: 'cancelled',
        version: 3,
        imported_count: 1,
        skipped_count: 1,
        error_code: 'rolled_back',
        error_params: { voided: '1', kept: '1' },
        cancelled_at: '2026-11-05T09:00:00Z',
      }),
    );
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Statement import');
    expect(screen.getByText('Undone')).toBeInTheDocument();

    const rows = screen.getByRole('region', { name: 'Statement rows' });
    const removed = (await within(rows).findByText('Row 4')).closest('li')!;
    expect(within(removed).getByText('Removed by undo')).toBeInTheDocument();
    expect(within(removed).getByText('Removed when the import was undone.')).toBeInTheDocument();
    expect(within(removed).queryByRole('link')).not.toBeInTheDocument();

    const kept = within(rows).getByText('Row 5').closest('li')!;
    expect(within(kept).getByRole('link', { name: 'View transaction' })).toHaveAttribute(
      'href',
      `/transactions/${TX_KEPT}`,
    );
    expect(within(rows).getAllByRole('link', { name: 'View transaction' })).toHaveLength(1);
  });

  it('stops a running import after confirmation and stops polling once it has stopped', async () => {
    let cancels = 0;
    server.use(
      http.post(`${API}/imports/:id/cancel`, () => {
        cancels += 1;
        return HttpResponse.json(
          envelope(makeBatch({ status: 'processing', version: 3, cancel_requested: true })),
        );
      }),
    );
    const reads = serveBatch(
      makeBatch({ status: 'processing', version: 2 }),
      makeBatch({ status: 'processing', version: 3, cancel_requested: true }),
      makeBatch({
        status: 'cancelled',
        version: 3,
        imported_count: 2,
        cancelled_at: '2026-11-05T09:00:00Z',
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Statement import');
    await user.click(screen.getByRole('button', { name: 'Stop importing' }));
    const dialog = await screen.findByRole('dialog', { name: 'Stop importing?' });
    expect(within(dialog).getByText(/Rows already added stay in your account/)).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Stop importing' }));
    expect(await screen.findByText('Stopping the import…')).toBeInTheDocument();
    expect(cancels).toBe(1);
    expect(await screen.findByText('Import cancelled')).toBeInTheDocument();
    await sleep(300);
    const settled = reads.calls;
    await sleep(1400);
    expect(reads.calls).toBe(settled);
  });

  it('links back to the wizard while the rows still need review', async () => {
    server.use(serveRows(resultRows));
    serveBatch(makeBatch());
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Statement import');
    expect(screen.getByRole('link', { name: 'Continue review' })).toHaveAttribute(
      'href',
      `/imports/new?import_id=${IMPORT_ID}`,
    );
    expect(
      screen.getByText('The rows are ready for your review. Nothing has been imported yet.'),
    ).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Cancel import' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Undo import' })).not.toBeInTheDocument();
  });

  it('shows an import that could not be read with the server’s reason', async () => {
    serveBatch(
      makeBatch({
        status: 'failed',
        error_code: 'malformed',
        error_message: 'The file could not be read.',
        totals: undefined,
      }),
    );
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Statement import');
    expect(screen.getByText('What went wrong')).toBeInTheDocument();
    expect(
      screen.getByText(
        'The file couldn’t be read. Check that it’s a statement export and try again.',
      ),
    ).toBeInTheDocument();
    expect(
      screen.getByText('The file couldn’t be read, so there are no rows.'),
    ).toBeInTheDocument();
  });

  it('shows a permission message when access is refused', async () => {
    server.use(
      http.get(`${API}/imports/:id`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute(path, { user: signedIn() });
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });

  it('shows a not-found state', async () => {
    server.use(
      http.get(`${API}/imports/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    renderRoute(path, { user: signedIn() });
    expect(await screen.findByText('Import not found')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'All imports' })).toHaveAttribute('href', '/imports');
  });

  it('shows a recoverable error and retries', async () => {
    let calls = 0;
    server.use(
      serveRows(resultRows),
      http.get(`${API}/imports/:id`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 })
          : HttpResponse.json(envelope(withErrors()));
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    expect(await screen.findByText('We couldn’t load this import')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    await findPageHeading('Statement import');
    await waitFor(() => {
      expect(screen.getByText('Imported, some rows not added')).toBeInTheDocument();
    });
  });
});
