import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { expectNoAxeViolations } from '@/tests/axe';
import { makeBudget, makeSharedBudget } from '@/tests/budgetsFixtures';
import { API, envelope, makeUser, meta } from '@/tests/fixtures';
import {
  ACCOUNT_CASH,
  TX_GROCERIES,
  makeAccount,
  makeCard,
  makeCategory,
  makeIncome,
  makePaymentMethod,
  makeSummary,
  makeTag,
  makeTransaction,
  money,
  starterCategories,
} from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const signedIn = () => makeUser({ onboarding_completed: true });

function seedFinance() {
  testBackend.accounts = [makeAccount(), makeCard()];
  testBackend.categories = starterCategories();
  testBackend.tags = [makeTag()];
  testBackend.paymentMethods = [makePaymentMethod({ is_default: true })];
  testBackend.preferences = { ...testBackend.preferences, default_account_id: ACCOUNT_CASH };
}

function transactionDetailHandlers() {
  return [
    http.get(`${API}/transactions/:id`, () =>
      HttpResponse.json(envelope(makeTransaction({ refunded_total: money('100.00') }))),
    ),
    http.get(`${API}/transactions/:id/audit`, () =>
      HttpResponse.json(
        envelope([
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
            changes: { amount_minor: { from: 20000, to: 25075 } },
            created_at: '2026-11-04T07:00:00Z',
          },
        ]),
      ),
    ),
    http.get(`${API}/transactions/:id/attachments`, () =>
      HttpResponse.json(
        envelope([
          {
            file_id: 'f0f0f0f0-0000-4000-8000-000000000001',
            filename: 'receipt.jpg',
            content_type: 'image/jpeg',
            size_bytes: 204800,
            purpose: 'receipt',
            attached_at: '2026-11-04T07:10:00Z',
          },
        ]),
      ),
    ),
  ];
}

describe('axe: money pages', () => {
  it('dashboard with figures', async () => {
    seedFinance();
    server.use(
      http.get(`${API}/dashboard/summary`, () => HttpResponse.json(envelope(makeSummary()))),
    );
    renderRoute('/dashboard', { user: signedIn() });
    await findPageHeading('Home');
    await screen.findByRole('region', { name: 'Recent transactions' });
    // Each widget names its per-currency section after itself, so landmarks stay unique.
    await screen.findByRole('region', { name: 'Cash flow in INR' });
    await expectNoAxeViolations();
  });

  it('account menu (Radix dropdown) opened from the shell', async () => {
    testBackend.accounts = [makeAccount(), makeCard()];
    const user = userEvent.setup();
    renderRoute('/accounts', { user: signedIn() });
    await findPageHeading('Accounts');
    await screen.findByRole('region', { name: 'Credit cards' });
    // The first trigger is the desktop sidebar's (the second sits in the small-screen header).
    const trigger = screen.getAllByRole('button', { name: 'Account menu' })[0]!;
    await user.click(trigger);
    const menu = await screen.findByRole('menu', { name: 'Account menu' });
    expect(trigger).toHaveAttribute('aria-expanded', 'true');
    // Checked as its own context: the popup is portalled to <body> outside any
    // landmark by design (like every menu popup), which only the page-level
    // `region` rule would object to; the page behind it is covered above.
    await expectNoAxeViolations(menu);
  });

  it('transactions list', async () => {
    seedFinance();
    server.use(
      http.get(`${API}/transactions`, () =>
        HttpResponse.json({ data: [makeIncome(), makeTransaction()], meta: meta() }),
      ),
    );
    renderRoute('/transactions', { user: signedIn() });
    await findPageHeading('Transactions');
    await screen.findByRole('link', { name: 'Big Bazaar' });
    await expectNoAxeViolations();
  });

  it('transactions list, empty', async () => {
    server.use(
      http.get(`${API}/transactions`, () => HttpResponse.json({ data: [], meta: meta() })),
    );
    renderRoute('/transactions', { user: signedIn() });
    await findPageHeading('Transactions');
    await waitFor(() => {
      expect(screen.queryByRole('status', { name: /loading/i })).not.toBeInTheDocument();
    });
    await expectNoAxeViolations();
  });

  it('new transaction form', async () => {
    seedFinance();
    renderRoute('/transactions/new', { user: signedIn() });
    await findPageHeading('Add a transaction');
    await screen.findByLabelText('Amount');
    await expectNoAxeViolations();
  });

  it('new transaction form with field errors', async () => {
    seedFinance();
    const user = userEvent.setup();
    renderRoute('/transactions/new', { user: signedIn() });
    await findPageHeading('Add a transaction');
    const amount = await screen.findByLabelText('Amount');
    await user.click(screen.getByRole('button', { name: 'Save transaction' }));
    await waitFor(() => {
      expect(amount).toHaveAttribute('aria-invalid', 'true');
    });
    await expectNoAxeViolations();
  });

  it('transaction detail with history and files', async () => {
    testBackend.categories = [makeCategory()];
    server.use(...transactionDetailHandlers());
    renderRoute(`/transactions/${TX_GROCERIES}`, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    const files = screen.getByRole('region', { name: 'Files' });
    await within(files).findByText('receipt.jpg');
    await within(screen.getByRole('region', { name: 'History' })).findAllByRole('listitem');
    await expectNoAxeViolations();
  });

  it('refund dialog on a transaction', async () => {
    testBackend.categories = [makeCategory()];
    server.use(...transactionDetailHandlers());
    const user = userEvent.setup();
    renderRoute(`/transactions/${TX_GROCERIES}`, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    await user.click(screen.getByRole('button', { name: 'Record refund' }));
    await screen.findByRole('dialog', { name: 'Record a refund or reimbursement' });
    await expectNoAxeViolations();
  });

  it('delete confirmation dialog on a transaction', async () => {
    testBackend.categories = [makeCategory()];
    server.use(...transactionDetailHandlers());
    const user = userEvent.setup();
    renderRoute(`/transactions/${TX_GROCERIES}`, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    await user.click(screen.getByRole('button', { name: 'Delete' }));
    await screen.findByRole('dialog', { name: 'Delete this transaction?' });
    await expectNoAxeViolations();
  });

  it('accounts list', async () => {
    testBackend.accounts = [makeAccount(), makeCard()];
    renderRoute('/accounts', { user: signedIn() });
    await findPageHeading('Accounts');
    await screen.findByRole('region', { name: 'Credit cards' });
    await expectNoAxeViolations();
  });

  it('budgets list', async () => {
    server.use(
      http.get(`${API}/budgets`, () =>
        HttpResponse.json(envelope([makeBudget(), makeSharedBudget({ status: 'paused' })])),
      ),
      http.get(`${API}/budget-alerts`, () => HttpResponse.json(envelope([]))),
    );
    renderRoute('/budgets', { user: signedIn() });
    await findPageHeading('Budgets');
    await screen.findByRole('link', { name: 'Food' });
    await expectNoAxeViolations();
  });

  it('budget form', async () => {
    seedFinance();
    renderRoute('/budgets/new', { user: signedIn() });
    await findPageHeading('Create a budget');
    await expectNoAxeViolations();
  });
});
