import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it, vi } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  TX_GROCERIES,
  makeAccount,
  makeCard,
  makeCategory,
  makeTransaction,
  makeTransfer,
  money,
} from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const signedIn = () => makeUser({ onboarding_completed: true });

function handlers(
  transaction = makeTransaction(),
  extra: { audit?: unknown[]; attachments?: unknown[] } = {},
) {
  return [
    http.get(`${API}/transactions/:id`, () => HttpResponse.json(envelope(transaction))),
    http.get(`${API}/transactions/:id/audit`, () => HttpResponse.json(envelope(extra.audit ?? []))),
    http.get(`${API}/transactions/:id/attachments`, () =>
      HttpResponse.json(envelope(extra.attachments ?? [])),
    ),
  ];
}

describe('TransactionDetailPage', () => {
  it('shows details, audit history and attachments', async () => {
    testBackend.categories = [makeCategory()];
    server.use(
      ...handlers(makeTransaction({ attachment_count: 1 }), {
        audit: [
          {
            id: 1,
            action: 'created',
            actor_kind: 'user',
            version: 1,
            changes: {},
            created_at: '2026-11-04T06:30:00Z',
          },
          {
            id: 2,
            action: 'updated',
            actor_kind: 'user',
            version: 2,
            changes: {
              amount_minor: { from: 20000, to: 25075 },
              category_id: { from: null, to: 'x' },
            },
            created_at: '2026-11-04T07:00:00Z',
          },
          {
            id: 3,
            action: 'rule_categorized',
            actor_kind: 'system',
            version: 3,
            changes: {},
            created_at: '2026-11-04T07:05:00Z',
          },
        ],
        attachments: [
          {
            file_id: 'f0f0f0f0-0000-4000-8000-000000000001',
            filename: 'receipt.jpg',
            content_type: 'image/jpeg',
            size_bytes: 204800,
            purpose: 'receipt',
            attached_at: '2026-11-04T07:10:00Z',
          },
        ],
      }),
    );
    renderRoute(`/transactions/${TX_GROCERIES}`, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    expect(screen.getByText('-₹250.75')).toBeInTheDocument();
    const details = screen.getByRole('region', { name: 'Details' });
    expect(within(details).getByText('Groceries')).toBeInTheDocument();
    expect(within(details).getByRole('link', { name: 'Wallet' })).toBeInTheDocument();

    const history = screen.getByRole('region', { name: 'History' });
    const items = await within(history).findAllByRole('listitem');
    expect(items.map((item) => item.querySelector('p')?.textContent)).toEqual([
      'Category set by a rule',
      'Edited',
      'Created',
    ]);
    expect(within(items[1]!).getByText('Changed: amount, category')).toBeInTheDocument();

    const files = screen.getByRole('region', { name: 'Files' });
    expect(await within(files).findByText('receipt.jpg')).toBeInTheDocument();
    expect(within(files).getByText(/image\/jpeg · 200 kB/)).toBeInTheDocument();
  });

  it('opens an attachment through a short-lived link', async () => {
    const tab = { opener: {}, location: { href: '' }, close: vi.fn() };
    const open = vi.spyOn(window, 'open').mockReturnValue(tab as unknown as Window);
    server.use(
      ...handlers(makeTransaction({ attachment_count: 1 }), {
        attachments: [
          {
            file_id: 'f0f0f0f0-0000-4000-8000-000000000001',
            filename: 'receipt.jpg',
            purpose: 'receipt',
            attached_at: '2026-11-04T07:10:00Z',
          },
        ],
      }),
      http.get(`${API}/files/:fileId/access`, () =>
        HttpResponse.json(
          envelope({
            url: 'https://files.example/receipt?sig=1',
            filename: 'receipt.jpg',
            content_type: 'image/jpeg',
            expires_at: '2026-11-04T08:00:00Z',
          }),
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(`/transactions/${TX_GROCERIES}`, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    await user.click(await screen.findByRole('button', { name: 'Open: receipt.jpg' }));
    await waitFor(() => {
      expect(tab.location.href).toBe('https://files.example/receipt?sig=1');
    });
    expect(open).toHaveBeenCalledWith('', '_blank');
    expect(tab.opener).toBeNull();
  });

  it('deletes after confirmation, then restores', async () => {
    let current = makeTransaction();
    server.use(
      http.get(`${API}/transactions/:id`, () => HttpResponse.json(envelope(current))),
      http.get(`${API}/transactions/:id/audit`, () => HttpResponse.json(envelope([]))),
      http.get(`${API}/transactions/:id/attachments`, () => HttpResponse.json(envelope([]))),
      http.delete(`${API}/transactions/:id`, () => {
        current = makeTransaction({
          status: 'voided',
          deleted_at: '2026-11-04T09:00:00Z',
          version: 4,
        });
        return HttpResponse.json(envelope(current));
      }),
      http.post(`${API}/transactions/:id/restore`, () => {
        current = makeTransaction({ version: 5 });
        return HttpResponse.json(envelope(current));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/transactions/${TX_GROCERIES}`, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    await user.click(screen.getByRole('button', { name: 'Delete' }));
    const dialog = await screen.findByRole('dialog', { name: 'Delete this transaction?' });
    expect(within(dialog).getByRole('button', { name: 'Cancel' })).toHaveFocus();
    await user.click(within(dialog).getByRole('button', { name: 'Delete' }));
    expect(await screen.findByText('Transaction deleted')).toBeInTheDocument();
    expect(await screen.findByText('This transaction was deleted')).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Restore' }));
    const restore = await screen.findByRole('dialog', { name: 'Restore this transaction?' });
    await user.click(within(restore).getByRole('button', { name: 'Restore' }));
    expect(await screen.findByText('Transaction restored')).toBeInTheDocument();
    await waitFor(() => {
      expect(screen.queryByText('This transaction was deleted')).not.toBeInTheDocument();
    });
  });

  it('explains why a transaction with refunds cannot be deleted', async () => {
    server.use(
      ...handlers(),
      http.delete(`${API}/transactions/:id`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            message: 'Delete the linked refunds first.',
            details: [{ code: 'has_linked_refunds', message: 'Delete the linked refunds first.' }],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(`/transactions/${TX_GROCERIES}`, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    await user.click(screen.getByRole('button', { name: 'Delete' }));
    const dialog = await screen.findByRole('dialog', { name: 'Delete this transaction?' });
    await user.click(within(dialog).getByRole('button', { name: 'Delete' }));
    expect(
      await within(dialog).findByText(/Delete its refunds or reimbursements first/),
    ).toBeInTheDocument();
  });

  it('records a partial refund with an Idempotency-Key and reports the cap the API enforces', async () => {
    testBackend.accounts = [makeAccount()];
    const bodies: unknown[] = [];
    const keys: (string | null)[] = [];
    server.use(
      ...handlers(makeTransaction({ refunded_total: money('100.00') })),
      http.post(`${API}/transactions/:id/refunds`, async ({ request }) => {
        bodies.push(await request.json());
        keys.push(request.headers.get('Idempotency-Key'));
        if (bodies.length === 1) {
          return HttpResponse.json(
            errorBody({
              code: 'DOMAIN_RULE_VIOLATION',
              message: 'Refunds and reimbursements cannot exceed the original amount.',
              details: [
                {
                  code: 'refund_exceeds_remaining',
                  message: 'Refunds and reimbursements cannot exceed the original amount.',
                  params: { remaining: '150.75', currency: 'INR' },
                },
              ],
            }),
            { status: 422 },
          );
        }
        return HttpResponse.json(
          envelope({
            transaction: makeTransaction({
              id: 'r',
              type: 'refund',
              direction: 'inflow',
              amount: money('50.00'),
            }),
            possible_duplicates: [],
          }),
          { status: 201 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/transactions/${TX_GROCERIES}`, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    expect(screen.getByText('₹100.00 of ₹250.75')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Record refund' }));
    const dialog = await screen.findByRole('dialog', { name: 'Record a refund or reimbursement' });
    expect(within(dialog).getByText('₹100.00')).toBeInTheDocument(); // already refunded (server value)
    await user.type(within(dialog).getByLabelText('Amount received'), '200');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    // Coded rule with parameters: localized, with the server's remaining amount.
    expect(
      await within(dialog).findByText(
        'Refunds can’t add up to more than the original. ₹150.75 can still be refunded, unless you mark a deliberate correction.',
      ),
    ).toBeInTheDocument();

    const amount = within(dialog).getByLabelText('Amount received');
    await user.clear(amount);
    await user.type(amount, '50');
    await user.click(within(dialog).getByLabelText(/^Reimbursement/));
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Reimbursement recorded')).toBeInTheDocument();
    expect(bodies[0]).toMatchObject({ type: 'refund', amount: '200.00' });
    expect(bodies[1]).toMatchObject({ type: 'reimbursement', amount: '50.00' });
    expect(keys[0]).toMatch(/^web-/);
  });

  it('duplicates to a chosen date and opens the copy', async () => {
    let body: unknown = null;
    server.use(
      ...handlers(),
      http.post(`${API}/transactions/:id/duplicate`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(
          envelope({
            transaction: makeTransaction({ id: 'cccccccc-cccc-4ccc-8ccc-cccccccccc01' }),
            possible_duplicates: [],
          }),
          { status: 201 },
        );
      }),
    );
    const user = userEvent.setup();
    const { router } = renderRoute(`/transactions/${TX_GROCERIES}`, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    await user.click(screen.getByRole('button', { name: 'Duplicate' }));
    const dialog = await screen.findByRole('dialog', { name: 'Duplicate this transaction?' });
    const date = within(dialog).getByLabelText('Date of the copy');
    await user.clear(date);
    await user.type(date, '2026-11-10');
    await user.click(within(dialog).getByRole('button', { name: 'Create copy' }));
    await waitFor(() => {
      expect(router.state.location.pathname).toBe(
        '/transactions/cccccccc-cccc-4ccc-8ccc-cccccccccc01',
      );
    });
    expect(body).toEqual({ local_date: '2026-11-10' });
  });

  it('shows both sides of a transfer and deletes them as one unit', async () => {
    testBackend.accounts = [makeAccount(), makeCard()];
    const transfer = makeTransfer();
    const leg = makeTransaction({
      id: transfer.from_transaction_id,
      type: 'transfer',
      transfer_id: transfer.id,
      merchant: undefined,
      category: undefined,
      description: 'Card payment',
      amount: money('1000.00'),
    });
    let voided = '';
    server.use(
      ...handlers(leg),
      http.get(`${API}/transactions/transfers/:id`, () => HttpResponse.json(envelope(transfer))),
      http.delete(`${API}/transactions/transfers/:id`, ({ params }) => {
        voided = String(params.id);
        return HttpResponse.json(envelope({ ...transfer, status: 'voided' }));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/transactions/${leg.id}`, { user: signedIn() });
    await findPageHeading('Card payment');
    const section = screen.getByRole('region', { name: 'Transfer' });
    expect(await within(section).findByRole('link', { name: 'HDFC Credit' })).toBeInTheDocument();
    expect(within(section).getByText('₹10.00')).toBeInTheDocument();
    expect(within(section).getByText(/not counted as income or spending/)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Record refund' })).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Delete transfer' }));
    const dialog = await screen.findByRole('dialog', { name: 'Delete this transfer?' });
    expect(
      within(dialog).getByText(/Both sides of the transfer and its fee are deleted together/),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Delete' }));
    expect(await screen.findByText('Transfer deleted')).toBeInTheDocument();
    expect(voided).toBe(transfer.id);
  });

  it('restores a deleted transfer as one unit, with its date and description', async () => {
    testBackend.accounts = [makeAccount(), makeCard()];
    const transfer = makeTransfer({ description: 'Card bill', status: 'voided' });
    const leg = makeTransaction({
      id: transfer.from_transaction_id,
      type: 'transfer',
      transfer_id: transfer.id,
      status: 'voided',
      merchant: undefined,
      category: undefined,
      description: 'Card payment',
      amount: money('1000.00'),
    });
    let restored = '';
    server.use(
      ...handlers(leg),
      http.get(`${API}/transactions/transfers/:id`, () => HttpResponse.json(envelope(transfer))),
      http.post(`${API}/transactions/transfers/:id/restore`, ({ params }) => {
        restored = String(params.id);
        return HttpResponse.json(envelope({ ...transfer, status: 'posted' }));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/transactions/${leg.id}`, { user: signedIn() });
    await findPageHeading('Card payment');
    const section = screen.getByRole('region', { name: 'Transfer' });
    expect(await within(section).findByText('Card bill')).toBeInTheDocument();
    expect(within(section).getByText(/November 4, 2026|4 November 2026/)).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Restore' }));
    const dialog = await screen.findByRole('dialog', { name: 'Restore this transaction?' });
    await user.click(within(dialog).getByRole('button', { name: 'Restore' }));
    expect(await screen.findByText('Transaction restored')).toBeInTheDocument();
    expect(restored).toBe(transfer.id);
  });

  it('shows a not-found state', async () => {
    server.use(
      http.get(`${API}/transactions/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    renderRoute(`/transactions/${TX_GROCERIES}`, { user: signedIn() });
    expect(await screen.findByText('Transaction not found')).toBeInTheDocument();
  });
});
