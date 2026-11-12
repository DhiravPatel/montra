import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeEach, describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import {
  emptyResults,
  HIT_ACCOUNT,
  HIT_BILL,
  HIT_BUDGET,
  HIT_CATEGORY,
  HIT_RECURRING,
  HIT_SUBSCRIPTION,
  HIT_GOAL,
  HIT_GROUP,
  HIT_MERCHANT,
  HIT_POST,
  HIT_TX_COFFEE,
  HIT_TX_MUSEUM,
  makeRecent,
  makeResults,
  makeTransactionHit,
  shellHandlers,
} from '@/tests/searchFixtures';

const user0 = () => makeUser({ onboarding_completed: true });

/** Records every GET /search and answers with `respond` (default: one hit per section). */
function searchBackend(
  respond: (params: URLSearchParams, request: Request) => Response | Promise<Response> = (params) =>
    HttpResponse.json(envelope(makeResults(params.get('q') ?? ''))),
) {
  const calls: Record<string, string>[] = [];
  server.use(
    http.get(`${API}/search`, ({ request }) => {
      const params = new URL(request.url).searchParams;
      calls.push(Object.fromEntries(params));
      return respond(params, request);
    }),
  );
  return calls;
}

function recentBackend(items = [makeRecent()]) {
  server.use(http.get(`${API}/search/recent`, () => HttpResponse.json(envelope(items))));
}

function field() {
  return screen.getByRole('searchbox', { name: 'Search for' });
}

function section(name: RegExp | string) {
  const heading = screen.getByRole('heading', { level: 2, name });
  const container = heading.closest('section');
  if (!container) throw new Error('section not found');
  return container;
}

function announcer() {
  return screen.getByTestId('announcer-polite');
}

describe('SearchPage', () => {
  beforeEach(() => {
    server.use(...shellHandlers());
  });

  it('groups results by type with ID-only links, server amounts and labels', async () => {
    recentBackend([]);
    const calls = searchBackend();
    const user = userEvent.setup();
    const { router } = renderRoute('/search', { user: user0() });
    await findPageHeading('Search');

    await user.type(field(), 'holiday');

    const transactions = await screen.findByRole('heading', { level: 2, name: /Transactions/ });
    expect(calls).toEqual([{ q: 'holiday', scope: 'all', limit: '5', sort: 'relevance' }]);
    expect(screen.getByText('13 results for “holiday”')).toBeInTheDocument();
    await waitFor(() => {
      expect(announcer()).toHaveTextContent('13 results found');
    });

    const tx = transactions.closest('section')!;
    const coffee = within(tx).getByRole('link', { name: /Blue Tokai/ });
    expect(coffee).toHaveAttribute('href', `/transactions/${HIT_TX_COFFEE}`);
    expect(within(coffee).getByText('₹250.00')).toBeInTheDocument();
    expect(coffee).toHaveTextContent('Holiday coffee · Expense · Nov 3, 2026');
    const museum = within(tx).getByRole('link', { name: /museum/ });
    expect(museum).toHaveAttribute('href', `/transactions/${HIT_TX_MUSEUM}`);
    expect(within(museum).getByText('$42.50')).toBeInTheDocument();
    expect(within(museum).getByText('Shared with you')).toBeInTheDocument();

    expect(
      within(section('Accounts')).getByRole('link', { name: /Holiday Savings/ }),
    ).toHaveAttribute('href', `/accounts/${HIT_ACCOUNT}`);
    expect(within(section('Accounts')).getByText('Savings account')).toBeInTheDocument();
    expect(within(section('Merchants')).getByRole('link')).toHaveAttribute(
      'href',
      `/categories/merchants/${HIT_MERCHANT}`,
    );
    expect(within(section('Goals')).getByRole('link', { name: /Holiday 2027/ })).toHaveAttribute(
      'href',
      `/goals/${HIT_GOAL}`,
    );
    expect(within(section('Goals')).getByText('Active')).toBeInTheDocument();
    expect(within(section('Groups')).getByRole('link', { name: /Holiday trip/ })).toHaveAttribute(
      'href',
      `/groups/${HIT_GROUP}`,
    );
    expect(within(section('Groups')).getByText('Trip')).toBeInTheDocument();
    // The planning sections link to their own pages (IDs only); categories open their transactions.
    expect(within(section('Categories')).getByRole('link', { name: /Holidays/ })).toHaveAttribute(
      'href',
      `/transactions?category_id=${HIT_CATEGORY}`,
    );
    expect(within(section('Categories')).getByText('Spending')).toBeInTheDocument();
    expect(within(section('Budgets')).getByRole('link')).toHaveAttribute(
      'href',
      `/budgets/${HIT_BUDGET}`,
    );
    expect(within(section('Budgets')).getByText('By category')).toBeInTheDocument();
    expect(within(section('Bills')).getByRole('link')).toHaveAttribute(
      'href',
      `/planning/bills/${HIT_BILL}`,
    );
    expect(within(section('Bills')).getByText('Active bill')).toBeInTheDocument();
    expect(within(section('Subscriptions')).getByRole('link')).toHaveAttribute(
      'href',
      `/subscriptions/${HIT_SUBSCRIPTION}`,
    );
    expect(within(section('Subscriptions')).getByText('Free trial')).toBeInTheDocument();
    expect(within(section('Recurring items')).getByRole('link')).toHaveAttribute(
      'href',
      `/planning/recurring/${HIT_RECURRING}`,
    );
    expect(within(section('Recurring items')).getByText('Transfer')).toBeInTheDocument();
    const post = within(section('Community posts')).getByRole('link');
    expect(post).toHaveAttribute('href', `/posts/${HIT_POST}`);
    expect(post).toHaveTextContent('Budget travellers');
    const people = section('People');
    expect(people).toHaveTextContent('Holiday Fan@holidayfan');
    expect(within(people).getByRole('link', { name: 'Find people' })).toHaveAttribute(
      'href',
      '/friends?tab=find',
    );
    // The matched text is marked.
    expect(within(museum).getByText('Holiday', { selector: 'mark' })).toBeInTheDocument();

    // Nothing personal in the URL, history state only, and a generic tab title.
    expect(router.state.location.search).toBe('');
    expect(router.state.location.state).toEqual({ q: 'holiday', scope: 'all' });
    expect(document.title).toBe('Search · Montra');
  });

  it('waits for a pause in typing, and needs at least 2 characters', async () => {
    recentBackend([]);
    const calls = searchBackend();
    const user = userEvent.setup();
    renderRoute('/search', { user: user0() });
    await findPageHeading('Search');

    await user.type(field(), 'c');
    expect(await screen.findByText('Type at least 2 characters to search.')).toBeInTheDocument();
    await new Promise((resolve) => setTimeout(resolve, 450));
    expect(calls).toEqual([]);

    await user.type(field(), 'offee');
    await screen.findByRole('heading', { level: 2, name: /Transactions/ });
    // One request for the whole word, not one per keystroke.
    expect(calls).toEqual([{ q: 'coffee', scope: 'all', limit: '5', sort: 'relevance' }]);
  });

  it('cancels a search that is no longer wanted and shows only the latest results', async () => {
    recentBackend([]);
    const aborted: string[] = [];
    const calls = searchBackend(async (params, request) => {
      const q = params.get('q') ?? '';
      if (q === 'cof') {
        // Never answers; resolves when the client gives up on it.
        await new Promise<void>((resolve) => {
          request.signal.addEventListener('abort', () => {
            aborted.push(q);
            resolve();
          });
        });
        return HttpResponse.json(envelope(makeResults(q)));
      }
      return HttpResponse.json(
        envelope({
          ...emptyResults(q),
          transactions: [makeTransactionHit({ description: 'Cold coffee' })],
        }),
      );
    });
    const user = userEvent.setup();
    renderRoute('/search', { user: user0() });
    await findPageHeading('Search');

    await user.type(field(), 'cof');
    await waitFor(() => {
      expect(calls.map((call) => call.q)).toEqual(['cof']);
    });
    expect(await screen.findByText('Searching…')).toBeInTheDocument();

    await user.type(field(), 'fee');
    expect(await screen.findByText('1 result for “coffee”')).toBeInTheDocument();
    expect(calls.map((call) => call.q)).toEqual(['cof', 'coffee']);
    await waitFor(() => {
      expect(aborted).toEqual(['cof']);
    });
    expect(screen.getByRole('link', { name: /Cold coffee/ })).toBeInTheDocument();
  });

  it('remembers a search only when it is submitted', async () => {
    recentBackend([]);
    const calls = searchBackend();
    const user = userEvent.setup();
    renderRoute('/search', { user: user0() });
    await findPageHeading('Search');

    await user.type(field(), 'holiday');
    await screen.findByRole('heading', { level: 2, name: /Transactions/ });
    await user.click(screen.getByRole('button', { name: 'Search' }));

    await waitFor(() => {
      expect(calls).toHaveLength(2);
    });
    // Typing never asks the API to remember the search (save is false by default).
    expect(calls[0]).toEqual({ q: 'holiday', scope: 'all', limit: '5', sort: 'relevance' });
    expect(calls[1]).toMatchObject({ q: 'holiday', save: 'true' });
  });

  it('lists recent searches and runs one again with its section', async () => {
    recentBackend([
      makeRecent({ query: 'blue tokai', scope: 'merchants' }),
      makeRecent({ query: 'rent', scope: 'all', created_at: '2026-11-03T09:00:00Z' }),
    ]);
    const calls = searchBackend((params) =>
      HttpResponse.json(
        envelope({
          ...emptyResults(params.get('q') ?? '', 'merchants'),
          merchants: [{ id: HIT_MERCHANT, name: 'Blue Tokai' }],
        }),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/search', { user: user0() });
    await findPageHeading('Search');

    const recent = section('Recent searches');
    const tokai = await within(recent).findByRole('button', { name: /blue tokai/ });
    expect(tokai).toHaveTextContent('In Merchants');
    expect(within(recent).getByRole('button', { name: /rent/ })).toBeInTheDocument();

    await user.click(tokai);

    expect(await screen.findByRole('link', { name: /Blue Tokai/ })).toHaveAttribute(
      'href',
      `/categories/merchants/${HIT_MERCHANT}`,
    );
    expect(calls).toEqual([
      { q: 'blue tokai', scope: 'merchants', limit: '20', sort: 'relevance', save: 'true' },
    ]);
    expect(field()).toHaveValue('blue tokai');
    expect(field()).toHaveFocus();
    expect(screen.getByRole('combobox', { name: 'Look in' })).toHaveValue('merchants');
  });

  it('clears the search history after confirming', async () => {
    let items = [makeRecent()];
    server.use(
      http.get(`${API}/search/recent`, () => HttpResponse.json(envelope(items))),
      http.delete(`${API}/search/recent`, () => {
        const deleted = items.length;
        items = [];
        return HttpResponse.json(envelope({ deleted }));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/search', { user: user0() });
    await findPageHeading('Search');
    await screen.findByRole('button', { name: /blue tokai/ });

    await user.click(screen.getByRole('button', { name: 'Clear history' }));
    const dialog = await screen.findByRole('dialog', { name: 'Clear your search history?' });
    expect(within(dialog).getByText(/Your records don’t change/)).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Clear history' }));

    expect(await screen.findByText('Search history cleared')).toBeInTheDocument();
    expect(await screen.findByText('No recent searches yet.')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /blue tokai/ })).not.toBeInTheDocument();
    await waitFor(() => {
      expect(field()).toHaveFocus();
    });
  });

  it('keeps the history when clearing fails', async () => {
    recentBackend();
    server.use(
      http.delete(`${API}/search/recent`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 }),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/search', { user: user0() });
    await findPageHeading('Search');
    await user.click(await screen.findByRole('button', { name: 'Clear history' }));
    const dialog = await screen.findByRole('dialog', { name: 'Clear your search history?' });
    await user.click(within(dialog).getByRole('button', { name: 'Clear history' }));

    expect(await within(dialog).findByRole('alert')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /blue tokai/, hidden: true })).toBeInTheDocument();
  });

  it('says so when nothing matches, and offers to search everything', async () => {
    recentBackend([]);
    const calls = searchBackend((params) =>
      HttpResponse.json(
        envelope(emptyResults(params.get('q') ?? '', params.get('scope') ?? 'all')),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/search', { user: user0() });
    await findPageHeading('Search');

    await user.selectOptions(screen.getByRole('combobox', { name: 'Look in' }), 'goals');
    await user.type(field(), 'zzz{Enter}');

    expect(
      await screen.findByRole('heading', { name: 'No results for “zzz”' }),
    ).toBeInTheDocument();
    await waitFor(() => {
      expect(announcer()).toHaveTextContent('No results found');
    });
    expect(calls.at(-1)).toEqual({
      q: 'zzz',
      scope: 'goals',
      limit: '20',
      sort: 'relevance',
      save: 'true',
    });

    await user.click(screen.getByRole('button', { name: 'Search everything' }));
    await waitFor(() => {
      expect(calls.at(-1)).toEqual({ q: 'zzz', scope: 'all', limit: '5', sort: 'relevance' });
    });
  });

  it('orders results with the sort control and shows the order the API applied', async () => {
    recentBackend([]);
    const calls = searchBackend((params) =>
      HttpResponse.json(
        envelope(
          makeResults(params.get('q') ?? '', {
            sort: (params.get('sort') ?? 'relevance') as 'relevance' | 'name' | 'recent',
          }),
        ),
      ),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/search', { user: user0() });
    await findPageHeading('Search');
    const order = screen.getByRole('combobox', { name: 'Order' });
    expect(order).toHaveValue('relevance');

    await user.type(field(), 'holiday{Enter}');
    await screen.findByRole('heading', { level: 2, name: /Transactions/ });
    expect(screen.queryByText(/^Sorted:/)).not.toBeInTheDocument();

    await user.selectOptions(order, 'recent');
    expect(await screen.findByText('Sorted: Newest first')).toBeInTheDocument();
    // Changing the order searches again without remembering the search a second time.
    expect(calls.at(-1)).toEqual({ q: 'holiday', scope: 'all', limit: '5', sort: 'recent' });
    expect(calls.filter((call) => call.save === 'true')).toHaveLength(1);
    expect(router.state.location.state).toEqual({ q: 'holiday', scope: 'all', sort: 'recent' });
    expect(router.state.location.search).toBe('');
  });

  it('searches one of the new sections on its own', async () => {
    recentBackend([]);
    const calls = searchBackend((params) =>
      HttpResponse.json(
        envelope({
          ...emptyResults(params.get('q') ?? '', 'bills'),
          bills: [{ id: HIT_BILL, name: 'Electricity', kind: 'paused' }],
        }),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/search', { user: user0() });
    await findPageHeading('Search');
    await user.selectOptions(screen.getByRole('combobox', { name: 'Look in' }), 'bills');
    await user.type(field(), 'electric');
    const bills = await screen.findByRole('heading', { level: 2, name: /Bills/ });
    expect(within(bills.closest('section')!).getByText('Paused bill')).toBeInTheDocument();
    expect(calls.at(-1)).toEqual({
      q: 'electric',
      scope: 'bills',
      limit: '20',
      sort: 'relevance',
    });
  });

  it('shows an error with a retry', async () => {
    recentBackend([]);
    let fail = true;
    searchBackend((params) =>
      fail
        ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-123' }), {
            status: 500,
          })
        : HttpResponse.json(envelope(makeResults(params.get('q') ?? ''))),
    );
    const user = userEvent.setup();
    renderRoute('/search', { user: user0() });
    await findPageHeading('Search');

    await user.type(field(), 'holiday');
    expect(
      await screen.findByRole('heading', { name: 'We couldn’t search right now' }),
    ).toBeVisible();
    expect(screen.getByText('req-123')).toBeInTheDocument();

    fail = false;
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByRole('heading', { level: 2, name: /Transactions/ })).toBeVisible();
  });

  it('shows more of one section on request', async () => {
    recentBackend([]);
    const calls = searchBackend((params) => {
      const scope = params.get('scope') ?? 'all';
      const count = scope === 'all' ? 5 : 7;
      return HttpResponse.json(
        envelope({
          ...emptyResults(params.get('q') ?? '', scope),
          transactions: Array.from({ length: count }, (_, index) =>
            makeTransactionHit({
              id: `b0b0b0b0-0000-4000-8000-00000000000${String(index)}`,
              description: `Taxi ${String(index + 1)}`,
              merchant: undefined,
            }),
          ),
        }),
      );
    });
    const user = userEvent.setup();
    renderRoute('/search', { user: user0() });
    await findPageHeading('Search');

    await user.type(field(), 'taxi');
    await user.click(await screen.findByRole('button', { name: 'Show more in Transactions' }));

    expect(await screen.findByText('7 results for “taxi”')).toBeInTheDocument();
    expect(calls.at(-1)).toEqual({
      q: 'taxi',
      scope: 'transactions',
      limit: '20',
      sort: 'relevance',
    });
    expect(screen.getByRole('combobox', { name: 'Look in' })).toHaveValue('transactions');
    expect(screen.queryByRole('button', { name: /Show more/ })).not.toBeInTheDocument();
    await waitFor(() => {
      expect(screen.getByRole('heading', { level: 2, name: /Transactions/ })).toHaveFocus();
    });
  });

  it('moves a query from an old ?q= link out of the URL', async () => {
    const calls = searchBackend();
    const { router } = renderRoute('/search?q=holiday', { user: user0() });
    await findPageHeading('Search');

    await screen.findByRole('heading', { level: 2, name: /Transactions/ });
    expect(calls).toEqual([{ q: 'holiday', scope: 'all', limit: '5', sort: 'relevance' }]);
    await waitFor(() => {
      expect(router.state.location.search).toBe('');
    });
    expect(router.state.location.state).toEqual({ q: 'holiday', scope: 'all' });
    expect(field()).toHaveValue('holiday');
  });

  it('shows an error when recent searches cannot load', async () => {
    server.use(
      http.get(`${API}/search/recent`, () =>
        HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 }),
      ),
    );
    renderRoute('/search', { user: user0() });
    await findPageHeading('Search');
    expect(await screen.findByText('We couldn’t load your recent searches')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Try again' })).toBeInTheDocument();
  });
});
