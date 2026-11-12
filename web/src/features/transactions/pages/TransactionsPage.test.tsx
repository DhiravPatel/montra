import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser, meta } from '@/tests/fixtures';
import {
  ACCOUNT_CASH,
  CATEGORY_GROCERIES,
  TX_GROCERIES,
  TX_SALARY,
  makeAccount,
  makeCategory,
  makeIncome,
  makeTag,
  makeTransaction,
} from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const signedIn = () => makeUser({ onboarding_completed: true });

function listHandler(record: URL[], pages: { items: unknown[]; next?: string }[]) {
  return http.get(`${API}/transactions`, ({ request }) => {
    const url = new URL(request.url);
    record.push(url);
    const cursor = url.searchParams.get('cursor');
    const page = cursor ? pages[1] : pages[0];
    return HttpResponse.json({
      data: page?.items ?? [],
      meta: { ...meta(), ...(page?.next ? { next_cursor: page.next, has_more: true } : {}) },
    });
  });
}

describe('TransactionsPage', () => {
  it('lists transactions with signed amounts, category names and badges', async () => {
    testBackend.categories = [makeCategory()];
    const requests: URL[] = [];
    server.use(listHandler(requests, [{ items: [makeIncome(), makeTransaction()] }]));
    renderRoute('/transactions', { user: signedIn() });
    await findPageHeading('Transactions');

    const income = (await screen.findByRole('link', { name: 'November salary' })).closest('li')!;
    expect(within(income).getByText('+₹5,000.00')).toBeInTheDocument();
    expect(within(income).getByText(/Money in/)).toBeInTheDocument();

    const expense = screen.getByRole('link', { name: 'Big Bazaar' }).closest('li')!;
    expect(within(expense).getByText('-₹250.75')).toBeInTheDocument();
    expect(within(expense).getByText(/Groceries/)).toBeInTheDocument();
    expect(within(expense).getByText('home')).toBeInTheDocument();
    expect(screen.getByText('Showing 2 transactions')).toBeInTheDocument();
    expect(requests[0]?.searchParams.get('sort')).toBe('date_desc');
  });

  it('applies URL filters (drill-down links) and serializes lists the way the contract expects', async () => {
    testBackend.categories = [makeCategory()];
    const requests: URL[] = [];
    server.use(listHandler(requests, [{ items: [makeTransaction()] }]));
    renderRoute(
      `/transactions?from=2026-11-01&to=2026-11-30&category_id=${CATEGORY_GROCERIES}&type=expense,refund`,
      { user: signedIn() },
    );
    await findPageHeading('Transactions');
    expect(await screen.findByText('Category: Groceries')).toBeInTheDocument();
    const params = requests[0]!.searchParams;
    expect(params.get('from')).toBe('2026-11-01');
    expect(params.get('to')).toBe('2026-11-30');
    expect(params.get('category_id')).toBe(CATEGORY_GROCERIES);
    // explode: false → one comma-separated value (repeating the key would drop values).
    expect(params.getAll('type')).toEqual(['expense,refund']);
  });

  it('shows transactions without a category from a drill-down link, never with a category filter', async () => {
    testBackend.categories = [makeCategory()];
    const requests: URL[] = [];
    server.use(listHandler(requests, [{ items: [makeTransaction({ category: undefined })] }]));
    const user = userEvent.setup();
    const { router } = renderRoute(
      `/transactions?from=2026-11-01&to=2026-11-30&uncategorized=true&category_id=${CATEGORY_GROCERIES}`,
      { user: signedIn() },
    );
    await findPageHeading('Transactions');
    expect(await screen.findByText('Category: Uncategorized')).toBeInTheDocument();
    const params = requests[0]!.searchParams;
    expect(params.get('uncategorized')).toBe('true');
    expect(params.has('category_id')).toBe(false); // the API refuses both together

    // Removing the chip drops the filter from the request and the address bar.
    await user.click(
      screen.getByRole('button', { name: /Remove filter: Category: Uncategorized/ }),
    );
    await waitFor(() => {
      expect(requests.at(-1)?.searchParams.has('uncategorized')).toBe(false);
    });
    expect(router.state.location.search).not.toContain('uncategorized');
  });

  it('searches without putting the search text in the address bar', async () => {
    const searches: URL[] = [];
    server.use(
      listHandler([], [{ items: [makeTransaction()] }]),
      http.get(`${API}/transactions/search`, ({ request }) => {
        searches.push(new URL(request.url));
        return HttpResponse.json(envelope([makeTransaction()]));
      }),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/transactions', { user: signedIn() });
    await findPageHeading('Transactions');
    await screen.findByRole('link', { name: 'Big Bazaar' });
    await user.type(screen.getByLabelText('Search'), 'bazaar');
    await waitFor(() => {
      expect(searches.at(-1)?.searchParams.get('q')).toBe('bazaar');
    });
    expect(router.state.location.search).not.toContain('bazaar');
  });

  it('loads the next page with the cursor from meta.next_cursor', async () => {
    const requests: URL[] = [];
    server.use(
      listHandler(requests, [
        { items: [makeTransaction()], next: 'cursor-2' },
        { items: [makeIncome()] },
      ]),
    );
    const user = userEvent.setup();
    renderRoute('/transactions', { user: signedIn() });
    await findPageHeading('Transactions');
    expect(await screen.findByText('Showing the first 1 transaction')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Load more' }));
    expect(await screen.findByRole('link', { name: 'November salary' })).toBeInTheDocument();
    expect(requests[1]?.searchParams.get('cursor')).toBe('cursor-2');
    expect(screen.queryByRole('button', { name: 'Load more' })).not.toBeInTheDocument();
  });

  it('shows an empty state for a new user and a no-matches state when filtered', async () => {
    server.use(listHandler([], [{ items: [] }]));
    const first = renderRoute('/transactions', { user: signedIn() });
    await findPageHeading('Transactions');
    expect(await screen.findByText('No transactions yet')).toBeInTheDocument();
    first.unmount();

    renderRoute('/transactions?range=last_week', { user: signedIn() });
    await findPageHeading('Transactions');
    expect(await screen.findByText('No transactions match')).toBeInTheDocument();
  });

  it('shows an error with retry', async () => {
    let fail = true;
    server.use(
      http.get(`${API}/transactions`, () =>
        fail
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-tx' }), {
              status: 500,
            })
          : HttpResponse.json(envelope([makeTransaction()])),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/transactions', { user: signedIn() });
    await findPageHeading('Transactions');
    expect(await screen.findByText('We couldn’t load your transactions')).toBeInTheDocument();
    fail = false;
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByRole('link', { name: 'Big Bazaar' })).toBeInTheDocument();
  });

  it('bulk-tags and bulk-deletes selected transactions after confirmation', async () => {
    testBackend.tags = [makeTag()];
    testBackend.accounts = [makeAccount()];
    let update: unknown = null;
    let remove: unknown = null;
    server.use(
      listHandler([], [{ items: [makeTransaction(), makeIncome()] }]),
      http.post(`${API}/transactions/bulk-update`, async ({ request }) => {
        update = await request.json();
        return HttpResponse.json(envelope({ updated: 2 }));
      }),
      http.post(`${API}/transactions/bulk-delete`, async ({ request }) => {
        remove = await request.json();
        return HttpResponse.json(envelope({ updated: 1 }));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/transactions', { user: signedIn() });
    await findPageHeading('Transactions');
    await user.click(await screen.findByLabelText('Select Big Bazaar'));
    await user.click(screen.getByLabelText('Select November salary'));
    const bar = screen.getByRole('region', { name: 'Selected transactions' });
    expect(within(bar).getByText('2 selected')).toBeInTheDocument();
    await user.selectOptions(within(bar).getByLabelText('Change'), 'addTag');
    await user.selectOptions(within(bar).getByLabelText('Tag'), makeTag().id);
    await user.click(within(bar).getByRole('button', { name: 'Apply' }));
    expect(await screen.findByText('Updated 2 transactions')).toBeInTheDocument();
    expect(update).toEqual({
      transaction_ids: [TX_GROCERIES, TX_SALARY],
      add_tag_ids: [makeTag().id],
    });

    await user.click(screen.getByLabelText('Select Big Bazaar'));
    await user.click(
      within(screen.getByRole('region', { name: 'Selected transactions' })).getByRole('button', {
        name: 'Delete',
      }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Delete 1 transaction?' });
    await user.click(within(dialog).getByRole('button', { name: 'Delete 1 transaction' }));
    expect(await screen.findByText('Deleted 1 transaction')).toBeInTheDocument();
    expect(remove).toEqual({ confirm: true, transaction_ids: [TX_GROCERIES] });
  });

  it('filters by an amount range kept out of the URL, re-validated when the currency changes', async () => {
    const requests: URL[] = [];
    server.use(listHandler(requests, [{ items: [makeTransaction()] }]));
    const user = userEvent.setup();
    const { router } = renderRoute('/transactions', { user: signedIn() });
    await findPageHeading('Transactions');
    await user.click(screen.getByRole('button', { name: 'More filters' }));
    await user.type(await screen.findByLabelText(/^At least/), '100');
    await user.type(screen.getByLabelText(/^At most/), '500.5');
    await user.tab();
    await waitFor(() => {
      expect(requests.at(-1)?.searchParams.get('max_amount')).toBe('500.50');
    });
    expect(requests.at(-1)?.searchParams.get('min_amount')).toBe('100.00');
    expect(requests.at(-1)?.searchParams.get('currency')).toBe('INR');
    expect(router.state.location.search).toBe('');

    await user.selectOptions(screen.getByLabelText('Currency'), 'JPY');
    // 500.5 is not a valid JPY amount: its error is shown and that bound is left out.
    await waitFor(() => {
      expect(requests.at(-1)?.searchParams.get('currency')).toBe('JPY');
    });
    expect(requests.at(-1)?.searchParams.get('min_amount')).toBe('100');
    expect(requests.at(-1)?.searchParams.has('max_amount')).toBe(false);
    expect(screen.getByLabelText(/^At most/)).toHaveAccessibleDescription(
      /JPY amounts are whole numbers/,
    );
  });

  it('filters by account from the filter panel', async () => {
    testBackend.accounts = [makeAccount()];
    const requests: URL[] = [];
    server.use(listHandler(requests, [{ items: [makeTransaction()] }]));
    const user = userEvent.setup();
    const { router } = renderRoute('/transactions', { user: signedIn() });
    await findPageHeading('Transactions');
    await user.click(screen.getByRole('button', { name: 'More filters' }));
    await user.selectOptions(await screen.findByLabelText(/^Account \(optional\)/), ACCOUNT_CASH);
    await waitFor(() => {
      expect(requests.at(-1)?.searchParams.get('account_id')).toBe(ACCOUNT_CASH);
    });
    expect(router.state.location.search).toBe(`?account_id=${ACCOUNT_CASH}`);
    expect(screen.getByRole('button', { name: 'Filters (1)' })).toBeInTheDocument();
  });
});
