import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Account } from '@/shared/finance/types';
import type { ImportBatch } from '@/features/imports/types';
import type {
  Candidate,
  Match,
  Reconciliation,
  StatementLine,
} from '@/features/reconciliation/types';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  ACCOUNT_CARD,
  ACCOUNT_CASH,
  makeAccount,
  makeCard,
  makeTransaction,
  money,
} from '@/tests/financeFixtures';
import { IMPORT_ID, makeBatch, pageEnvelope } from '@/tests/importsFixtures';
import {
  MATCH_ID,
  STATEMENT_ROW,
  STATEMENT_ROW_COFFEE,
  TX_IMPORTED_COPY,
  TX_MANUAL,
  duplicateCandidate,
  makeMatch,
  makeReconciliation,
  makeStatementLine,
  statementCandidate,
} from '@/tests/reconciliationFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

interface PageData {
  account?: Account;
  history?: () => Reconciliation[];
  candidates?: () => Candidate[];
  matches?: () => Match[];
  /** Statement lines by the `status` asked for (unmatched by default). */
  lines?: (status: string) => StatementLine[];
  imports?: ImportBatch[];
}

/** Every read the page makes, with the URLs it asked for. */
function servePage({
  account = makeAccount(),
  history = () => [],
  candidates = () => [],
  matches = () => [],
  lines = () => [],
  imports = [makeBatch({ status: 'completed', imported_count: 3, version: 2 })],
}: PageData = {}) {
  const seen = { candidates: [] as URL[], imports: [] as URL[], lines: [] as URL[] };
  server.use(
    http.get(`${API}/accounts/:id`, () => HttpResponse.json(envelope(account))),
    http.get(`${API}/accounts/:id/reconciliations`, () => HttpResponse.json(envelope(history()))),
    http.get(`${API}/reconciliation/candidates`, ({ request }) => {
      seen.candidates.push(new URL(request.url));
      return HttpResponse.json(envelope(candidates()));
    }),
    http.get(`${API}/reconciliation/matches`, () => HttpResponse.json(envelope(matches()))),
    http.get(`${API}/accounts/:id/statement-lines`, ({ request }) => {
      const url = new URL(request.url);
      seen.lines.push(url);
      return HttpResponse.json(envelope(lines(url.searchParams.get('status') ?? 'unmatched')));
    }),
    http.get(`${API}/imports`, ({ request }) => {
      seen.imports.push(new URL(request.url));
      return HttpResponse.json(envelope(imports));
    }),
  );
  return seen;
}

const cashPath = `/accounts/${ACCOUNT_CASH}/reconcile`;

beforeAll(async () => {
  await import('./ReconciliationPage');
});

beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(new Date('2026-11-05T06:00:00Z'));
});

describe('ReconciliationPage', () => {
  it('shows suggested matches with the server’s confidence and reasons, matches and history', async () => {
    const seen = servePage({
      candidates: () => [statementCandidate()],
      matches: () => [makeMatch()],
      history: () => [
        makeReconciliation({
          id: 'c0000000-0000-4000-8000-000000000009',
          status: 'balanced',
          statement_balance: money('1500.50'),
          difference: money('0.00'),
          import_batch_id: IMPORT_ID,
          notes: 'October statement',
        }),
        makeReconciliation(),
      ],
    });
    renderRoute(cashPath, { user: signedIn() });
    await findPageHeading('Reconcile Wallet');
    expect(screen.getByRole('link', { name: 'Back to Wallet' })).toHaveAttribute(
      'href',
      `/accounts/${ACCOUNT_CASH}`,
    );
    expect(seen.imports[0]?.searchParams.get('account_id')).toBe(ACCOUNT_CASH);

    const suggestions = screen.getByRole('region', { name: 'Suggested matches' });
    expect(
      await within(suggestions).findByRole('heading', {
        name: 'Statement lines and your transactions',
      }),
    ).toBeInTheDocument();
    expect(within(suggestions).getByText('Confidence: 89%')).toBeInTheDocument();
    expect(
      within(suggestions).getByText(
        'Why: Same amount and direction, Same date, Similar description',
      ),
    ).toBeInTheDocument();
    expect(within(suggestions).getByText('On the statement')).toBeInTheDocument();
    expect(
      within(suggestions).getByText('Oct 26, 2026 · Posted · Entered by you'),
    ).toBeInTheDocument();
    expect(within(suggestions).getByText(/Nothing is added or removed\./)).toBeInTheDocument();

    const matches = screen.getByRole('region', { name: 'Confirmed matches' });
    expect(
      await within(matches).findByText('Statement lines and your transactions'),
    ).toBeInTheDocument();
    expect(within(matches).getByText('Set aside as matched')).toBeInTheDocument();
    expect(within(matches).getByRole('link', { name: 'View transaction' })).toHaveAttribute(
      'href',
      `/transactions/${TX_MANUAL}`,
    );
    // Each matched record with its date, description and state, and the matched amount.
    expect(within(matches).getByText('Grocer weekly shop')).toBeInTheDocument();
    expect(within(matches).getByText('Oct 26, 2026 · Skipped')).toBeInTheDocument();
    expect(within(matches).getByText('Oct 26, 2026 · Posted · Entered by you')).toBeInTheDocument();
    expect(within(matches).getByText('Matched amount:')).toBeInTheDocument();

    const history = screen.getByRole('region', { name: 'Reconciliation history' });
    const table = await within(history).findByRole('table', { name: 'Past balance checks' });
    const rows = within(table).getAllByRole('row');
    expect(rows).toHaveLength(3);
    expect(within(rows[1]!).getByText('Balanced')).toBeInTheDocument();
    expect(within(rows[1]!).getByText('October statement')).toBeInTheDocument();
    expect(within(rows[1]!).getByRole('link', { name: 'From an import' })).toHaveAttribute(
      'href',
      `/imports/${IMPORT_ID}`,
    );
    // The stored counts of each check.
    expect(
      within(rows[1]!).getByText(
        '0 transactions reconciled · 0 statement lines not matched · 6 transactions not reconciled',
      ),
    ).toBeInTheDocument();
    expect(within(rows[2]!).getByText('Not balanced')).toBeInTheDocument();
    expect(within(rows[2]!).getByText('-₹1,499.50')).toBeInTheDocument();
    expect(
      within(rows[2]!).getByText('0 transactions reconciled · 6 transactions not reconciled'),
    ).toBeInTheDocument();
  });

  it('matches a statement line by hand with a transaction of the account', async () => {
    const bodies: unknown[] = [];
    const searches: URL[] = [];
    let matched = false;
    const seen = servePage({
      lines: (status) =>
        status === 'unmatched'
          ? matched
            ? []
            : [makeStatementLine()]
          : matched
            ? [makeStatementLine({ match_id: MATCH_ID, record_status: 'skipped' })]
            : [],
      matches: () => (matched ? [makeMatch()] : []),
    });
    server.use(
      http.get(`${API}/transactions`, ({ request }) => {
        searches.push(new URL(request.url));
        return HttpResponse.json(
          envelope([
            makeTransaction({
              id: TX_MANUAL,
              merchant: undefined,
              description: 'Coffee',
              amount: money('120.00'),
            }),
          ]),
        );
      }),
      http.post(`${API}/reconciliation/matches`, async ({ request }) => {
        bodies.push(await request.json());
        matched = true;
        return HttpResponse.json(envelope(makeMatch()), { status: 201 });
      }),
    );
    const user = userEvent.setup();
    renderRoute(cashPath, { user: signedIn() });
    await findPageHeading('Reconcile Wallet');
    const card = screen.getByRole('region', { name: 'Statement lines to match' });
    expect(await within(card).findByText('COFFEE HOUSE')).toBeInTheDocument();
    expect(within(card).getByText('Oct 28, 2026 · Row 5')).toBeInTheDocument();
    expect(within(card).getByText('Ready')).toBeInTheDocument();
    expect(seen.lines[0]?.searchParams.get('status')).toBe('unmatched');
    expect(seen.lines[0]?.searchParams.get('limit')).toBe('50');

    await user.click(within(card).getByRole('button', { name: 'Match by hand: COFFEE HOUSE' }));
    const dialog = await screen.findByRole('dialog', { name: 'Match a statement line' });
    expect(
      within(dialog).getByText(/Choose the transaction that this line of October 28, 2026/),
    ).toBeInTheDocument();
    await user.click(await within(dialog).findByRole('radio', { name: /Coffee/ }));
    // The ledger search: this account, money out, not matched yet, around the line's date, every type.
    const search = searches[0]!.searchParams;
    expect(search.get('account_id')).toBe(ACCOUNT_CASH);
    expect(search.get('direction')).toBe('outflow');
    expect(search.get('reconciliation_state')).toBe('unreconciled');
    expect(search.get('from')).toBe('2026-10-14');
    expect(search.get('to')).toBe('2026-11-11');
    expect(search.has('type')).toBe(false);

    await user.click(within(dialog).getByRole('button', { name: 'Match line' }));
    expect(await screen.findByText('Statement line matched')).toBeInTheDocument();
    expect(bodies).toEqual([
      {
        kind: 'statement_to_ledger',
        account_id: ACCOUNT_CASH,
        statement_row_ids: [STATEMENT_ROW_COFFEE],
        transaction_ids: [TX_MANUAL],
      },
    ]);
    expect(
      await within(card).findByText('Every statement line is accounted for'),
    ).toBeInTheDocument();
    await user.click(within(card).getByRole('radio', { name: 'Matched' }));
    expect(await within(card).findByText('COFFEE HOUSE')).toBeInTheDocument();
    // The line now carries the "Matched" badge (the filter choice is also named Matched).
    expect(within(card).getAllByText('Matched')).toHaveLength(2);
    expect(within(card).queryByRole('button', { name: /^Match by hand/ })).not.toBeInTheDocument();
  });

  it('explains a refused hand-picked match and loads more lines with the cursor', async () => {
    servePage();
    const requests: URLSearchParams[] = [];
    server.use(
      http.get(`${API}/accounts/:id/statement-lines`, ({ request }) => {
        const params = new URL(request.url).searchParams;
        requests.push(params);
        return params.get('cursor') === 'page-2'
          ? HttpResponse.json(
              pageEnvelope([
                makeStatementLine({
                  import_row_id: 'e0000000-0000-4000-8000-000000000006',
                  row_number: 6,
                  description: 'BOOKSTORE',
                }),
              ]),
            )
          : HttpResponse.json(pageEnvelope([makeStatementLine()], 'page-2'));
      }),
      http.get(`${API}/transactions`, () =>
        HttpResponse.json(
          envelope([
            makeTransaction({ id: TX_MANUAL, merchant: undefined, description: 'Coffee' }),
          ]),
        ),
      ),
      http.post(`${API}/reconciliation/matches`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                message: 'The statement side and ledger side must add up to the same amount.',
                code: 'sums_differ',
                params: { statement: '120.00', ledger: '250.75', currency: 'INR' },
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(cashPath, { user: signedIn() });
    await findPageHeading('Reconcile Wallet');
    const card = screen.getByRole('region', { name: 'Statement lines to match' });
    await user.click(await within(card).findByRole('button', { name: 'Load more' }));
    expect(await within(card).findByText('BOOKSTORE')).toBeInTheDocument();
    expect(requests.map((params) => params.get('cursor'))).toEqual([null, 'page-2']);

    await user.click(within(card).getByRole('button', { name: 'Match by hand: COFFEE HOUSE' }));
    const dialog = await screen.findByRole('dialog', { name: 'Match a statement line' });
    await user.click(await within(dialog).findByRole('radio', { name: /Coffee/ }));
    await user.click(within(dialog).getByRole('button', { name: 'Match line' }));
    expect(
      await within(dialog).findByText(
        'The two sides don’t add up to the same amount: ₹120.00 on the statement and ₹250.75 in Montra.',
      ),
    ).toBeInTheDocument();
  });

  it('shows calm empty states', async () => {
    servePage({ imports: [] });
    renderRoute(cashPath, { user: signedIn() });
    await findPageHeading('Reconcile Wallet');
    expect(await screen.findByText('No suggestions right now')).toBeInTheDocument();
    expect(await screen.findByText('Every statement line is accounted for')).toBeInTheDocument();
    expect(await screen.findByText('No matches yet')).toBeInTheDocument();
    expect(await screen.findByText('No checks yet')).toBeInTheDocument();
  });

  it('checks a statement balance and shows the difference computed by the server', async () => {
    const bodies: unknown[] = [];
    let history: Reconciliation[] = [];
    const seen = servePage({ history: () => history });
    server.use(
      http.post(`${API}/accounts/:id/reconciliations`, async ({ request }) => {
        bodies.push(await request.json());
        const result = makeReconciliation({
          import_batch_id: IMPORT_ID,
          notes: 'Nov statement',
          unmatched_statement_rows: 2,
        });
        history = [result];
        return HttpResponse.json(envelope(result), { status: 201 });
      }),
    );
    const user = userEvent.setup();
    renderRoute(cashPath, { user: signedIn() });
    await findPageHeading('Reconcile Wallet');
    expect(screen.getByLabelText('Statement date')).toHaveValue('2026-11-05');

    // Choosing the statement import also narrows the suggestions to its rows.
    const statement = await screen.findByRole('option', {
      name: /^Statement Oct 26\s–\sNov 3, 2026$/,
    });
    await user.selectOptions(screen.getByLabelText(/^Statement import/), statement);
    await waitFor(() => {
      expect(seen.candidates.at(-1)?.searchParams.get('batch_id')).toBe(IMPORT_ID);
    });
    await user.type(screen.getByLabelText('Closing balance on the statement'), '1');
    await user.type(screen.getByLabelText(/^Notes/), 'Nov statement');
    await user.click(screen.getByRole('button', { name: 'Check balance' }));

    const result = await screen.findByRole('region', { name: 'Statement of November 5, 2026' });
    expect(bodies[0]).toEqual({
      statement_date: '2026-11-05',
      statement_balance: '1.00',
      import_batch_id: IMPORT_ID,
      notes: 'Nov statement',
    });
    expect(within(result).getByText('Not balanced')).toBeInTheDocument();
    expect(within(result).getByText('₹1.00')).toBeInTheDocument();
    expect(within(result).getByText('₹1,500.50')).toBeInTheDocument();
    expect(within(result).getByText('-₹1,499.50')).toBeInTheDocument();
    expect(
      within(result).getByText('6 transactions up to this date are not reconciled yet.'),
    ).toBeInTheDocument();
    expect(
      within(result).getByText('2 lines of the statement import aren’t matched yet.'),
    ).toBeInTheDocument();
    // The new check appears in the history.
    const history2 = screen.getByRole('region', { name: 'Reconciliation history' });
    expect(await within(history2).findByText('Nov statement')).toBeInTheDocument();
  });

  it('sends the amount owed for a credit card and reports what was reconciled', async () => {
    const bodies: unknown[] = [];
    servePage({ account: makeCard(), imports: [] });
    server.use(
      http.post(`${API}/accounts/:id/reconciliations`, async ({ request }) => {
        bodies.push(await request.json());
        return HttpResponse.json(
          envelope(
            makeReconciliation({
              account_id: ACCOUNT_CARD,
              status: 'balanced',
              statement_balance: money('-2000.00'),
              ledger_balance: money('-2000.00'),
              difference: money('0.00'),
              reconciled_count: 3,
              unreconciled_transactions: 0,
            }),
          ),
          { status: 201 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/accounts/${ACCOUNT_CARD}/reconcile`, { user: signedIn() });
    await findPageHeading('Reconcile HDFC Credit');
    expect(screen.getByRole('radio', { name: /Amount you owe/ })).toBeChecked();
    await user.type(screen.getByLabelText('Amount owed on the statement'), '2,000');
    await user.click(screen.getByRole('button', { name: 'Check balance' }));

    const result = await screen.findByRole('region', { name: 'Statement of November 5, 2026' });
    expect(bodies[0]).toEqual({
      statement_date: '2026-11-05',
      statement_balance: '2000.00',
      balance_kind: 'amount_owed',
    });
    expect(within(result).getAllByText('Balanced')).not.toHaveLength(0);
    expect(
      within(result).getByText('3 transactions up to this date are now marked as reconciled.'),
    ).toBeInTheDocument();
    expect(
      within(result).getByText('Shown as balances: negative means you owe.'),
    ).toBeInTheDocument();

    // A signed balance can be entered instead.
    await user.click(screen.getByRole('radio', { name: /^Balance/ }));
    expect(screen.getByLabelText('Closing balance on the statement')).toBeInTheDocument();
  });

  it('validates the date and amount before calling the API', async () => {
    servePage();
    const user = userEvent.setup();
    renderRoute(cashPath, { user: signedIn() });
    await findPageHeading('Reconcile Wallet');
    await user.clear(screen.getByLabelText('Statement date'));
    await user.click(screen.getByRole('button', { name: 'Check balance' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Statement date')).toHaveAccessibleDescription(
        /Choose a date\./,
      );
    });
    expect(screen.getByLabelText('Closing balance on the statement')).toHaveAccessibleDescription(
      /Enter an amount\./,
    );
    await user.type(screen.getByLabelText('Closing balance on the statement'), '12.345');
    await user.click(screen.getByRole('button', { name: 'Check balance' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Closing balance on the statement')).toHaveAccessibleDescription(
        /INR amounts can have at most 2 decimal places\./,
      );
    });
  });

  it('confirms a suggested statement match and refreshes the suggestions', async () => {
    const bodies: unknown[] = [];
    let confirmed = false;
    servePage({
      candidates: () => (confirmed ? [] : [statementCandidate()]),
      matches: () => (confirmed ? [makeMatch()] : []),
    });
    server.use(
      http.post(`${API}/reconciliation/matches`, async ({ request }) => {
        bodies.push(await request.json());
        confirmed = true;
        return HttpResponse.json(envelope(makeMatch()), { status: 201 });
      }),
    );
    const user = userEvent.setup();
    renderRoute(cashPath, { user: signedIn() });
    await findPageHeading('Reconcile Wallet');
    await user.click(
      await screen.findByRole('button', { name: 'Confirm match: UPI-GROCER-WEEKLY SHOP' }),
    );
    expect(await screen.findByText('Match confirmed')).toBeInTheDocument();
    expect(bodies[0]).toEqual({
      kind: 'statement_to_ledger',
      account_id: ACCOUNT_CASH,
      statement_row_ids: [STATEMENT_ROW],
      transaction_ids: [TX_MANUAL],
    });
    expect(await screen.findByText('No suggestions right now')).toBeInTheDocument();
    const matches = screen.getByRole('region', { name: 'Confirmed matches' });
    expect(await within(matches).findByText('Confirmed')).toBeInTheDocument();
  });

  it('keeps the copy the user chooses when a transaction was entered twice', async () => {
    const bodies: unknown[] = [];
    servePage({ candidates: () => [duplicateCandidate()] });
    server.use(
      http.post(`${API}/reconciliation/matches`, async ({ request }) => {
        bodies.push(await request.json());
        return HttpResponse.json(envelope(makeMatch({ kind: 'manual_to_imported', items: [] })), {
          status: 201,
        });
      }),
    );
    const user = userEvent.setup();
    renderRoute(cashPath, { user: signedIn() });
    await findPageHeading('Reconcile Wallet');
    expect(await screen.findByRole('heading', { name: 'Entered twice' })).toBeInTheDocument();
    expect(screen.getByText(/keeps one copy and removes the other/)).toBeInTheDocument();
    expect(screen.getByRole('radio', { name: 'The one you entered' })).toBeChecked();
    await user.click(screen.getByRole('radio', { name: 'The imported one' }));
    await user.click(screen.getByRole('button', { name: 'Confirm match: Interest' }));
    expect(await screen.findByText('Match confirmed')).toBeInTheDocument();
    expect(bodies[0]).toEqual({
      kind: 'manual_to_imported',
      account_id: ACCOUNT_CASH,
      transaction_ids: [TX_MANUAL, TX_IMPORTED_COPY],
      keep_transaction_id: TX_IMPORTED_COPY,
    });
  });

  it('explains a refused match with the amounts the server quoted', async () => {
    servePage({ candidates: () => [statementCandidate()] });
    server.use(
      http.post(`${API}/reconciliation/matches`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                message: 'The statement side and ledger side must add up to the same amount.',
                code: 'sums_differ',
                params: { statement: '1250.50', ledger: '1251.50', currency: 'INR' },
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(cashPath, { user: signedIn() });
    await findPageHeading('Reconcile Wallet');
    await user.click(
      await screen.findByRole('button', { name: 'Confirm match: UPI-GROCER-WEEKLY SHOP' }),
    );
    expect(
      await screen.findByText(
        'The two sides don’t add up to the same amount: ₹1,250.50 on the statement and ₹1,251.50 in Montra.',
      ),
    ).toBeInTheDocument();
  });

  it('undoes a confirmed match after confirmation and can show undone matches', async () => {
    let undone = false;
    const deleted: string[] = [];
    servePage({
      matches: () =>
        undone
          ? [
              makeMatch({
                status: 'unmatched',
                unmatched_at: '2026-11-05T09:00:00Z',
                items: makeMatch().items.map((item) => ({ ...item, active: false })),
              }),
            ]
          : [makeMatch()],
    });
    server.use(
      http.delete(`${API}/reconciliation/matches/:id`, ({ params }) => {
        deleted.push(String(params.id));
        undone = true;
        return HttpResponse.json(envelope(makeMatch({ status: 'unmatched' })));
      }),
    );
    const user = userEvent.setup();
    renderRoute(cashPath, { user: signedIn() });
    await findPageHeading('Reconcile Wallet');
    await user.click(
      await screen.findByRole('button', {
        name: 'Undo match: Statement lines and your transactions',
      }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Undo this match?' });
    expect(within(dialog).getByText(/Removed transactions are restored/)).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Undo match' }));
    expect(await screen.findByText('Match undone')).toBeInTheDocument();
    expect(deleted).toEqual([MATCH_ID]);

    const matches = screen.getByRole('region', { name: 'Confirmed matches' });
    expect(await within(matches).findByText('No matches yet')).toBeInTheDocument();
    await user.click(within(matches).getByLabelText('Show undone matches'));
    expect(await within(matches).findByText('Undone')).toBeInTheDocument();
    expect(within(matches).queryByRole('button', { name: /^Undo match/ })).not.toBeInTheDocument();
  });

  it('is read-only for an account shared with you', async () => {
    server.use(
      http.get(`${API}/accounts/:id`, () =>
        HttpResponse.json(envelope(makeAccount({ owned: false }))),
      ),
    );
    renderRoute(cashPath, { user: signedIn() });
    await findPageHeading('Reconcile Wallet');
    expect(screen.getByText('Only the owner can reconcile this account')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Check balance' })).not.toBeInTheDocument();
  });

  it('shows a not-found state and a recoverable error', async () => {
    server.use(
      http.get(`${API}/accounts/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    renderRoute(cashPath, { user: signedIn() });
    expect(await screen.findByText('Account not found')).toBeInTheDocument();
  });

  it('shows a recoverable error when the history cannot be loaded', async () => {
    let calls = 0;
    servePage();
    server.use(
      http.get(`${API}/accounts/:id/reconciliations`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 })
          : HttpResponse.json(envelope([]));
      }),
    );
    const user = userEvent.setup();
    renderRoute(cashPath, { user: signedIn() });
    await findPageHeading('Reconcile Wallet');
    const history = screen.getByRole('region', { name: 'Reconciliation history' });
    expect(await within(history).findByText('We couldn’t load the history')).toBeInTheDocument();
    await user.click(within(history).getByRole('button', { name: 'Try again' }));
    expect(await within(history).findByText('No checks yet')).toBeInTheDocument();
  });
});
