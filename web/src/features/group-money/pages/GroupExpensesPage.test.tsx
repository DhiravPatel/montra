import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { money } from '@/tests/financeFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  EXPENSE_2,
  EXPENSE_ID,
  MEERA,
  MONEY_GROUP,
  RAVI,
  expensesPage,
  makeGroupExpense,
  makeGroupWithFormerMember,
  makeMoneyGroup,
  serveMoneyGroup,
} from '@/tests/groupMoneyFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

const PATH = `/groups/${MONEY_GROUP}/expenses`;
const EXPENSE_3 = 'e1e1e1e1-0000-4000-8000-000000000003';

describe('GroupExpensesPage', () => {
  it('lists shared expenses with server amounts, payers, your share and statuses', async () => {
    serveMoneyGroup();
    server.use(
      http.get(`${API}/groups/:id/expenses`, () =>
        HttpResponse.json(
          envelope([
            makeGroupExpense(),
            makeGroupExpense({
              id: EXPENSE_2,
              description: 'Airport taxi',
              category_key: 'transport',
              amount: money('8325.00'),
              original_amount: money('100.00', 'USD'),
              fx_rate: '83.25',
              fx_rate_source: 'manual',
              fx_rate_at: '2026-11-04T10:00:00Z',
              payers: [{ user_id: MEERA, paid: money('8325.00') }],
              my_paid: money('0.00'),
              my_share: money('2775.00'),
              status: 'disputed',
            }),
          ]),
        ),
      ),
    );
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Expenses');
    expect(await screen.findByText('Flat 4B')).toBeInTheDocument();

    const groceries = (await screen.findByRole('link', { name: 'Groceries' })).closest('li')!;
    expect(screen.getByRole('link', { name: 'Groceries' })).toHaveAttribute(
      'href',
      `/groups/${MONEY_GROUP}/expenses/${EXPENSE_ID}`,
    );
    expect(within(groceries).getByText('₹100.00')).toBeInTheDocument();
    expect(within(groceries).getByText('Paid by you')).toBeInTheDocument();
    expect(within(groceries).getByText('₹33.34')).toBeInTheDocument();

    const taxi = screen.getByRole('link', { name: 'Airport taxi' }).closest('li')!;
    expect(within(taxi).getByText('₹8,325.00')).toBeInTheDocument();
    expect(within(taxi).getByText('$100.00')).toBeInTheDocument();
    expect(within(taxi).getByText('Paid by Meera Rao')).toBeInTheDocument();
    expect(within(taxi).getByText('Disputed')).toBeInTheDocument();
    expect(screen.getByText('2 expenses', { selector: 'p' })).toBeInTheDocument();
    expect(screen.getAllByRole('link', { name: 'Add expense' })[0]).toHaveAttribute(
      'href',
      `/groups/${MONEY_GROUP}/expenses/new`,
    );
  });

  it('filters by status on the server and asks for deleted expenses only when requested', async () => {
    serveMoneyGroup();
    const seen: string[] = [];
    server.use(
      http.get(`${API}/groups/:id/expenses`, ({ request }) => {
        const url = new URL(request.url);
        seen.push(url.search);
        const status = url.searchParams.get('status');
        const all = [
          makeGroupExpense(),
          makeGroupExpense({ id: EXPENSE_2, description: 'Movie', status: 'disputed' }),
          makeGroupExpense({ id: EXPENSE_3, description: 'Old bill', status: 'deleted' }),
        ];
        const list = status
          ? all.filter((item) => item.status === status)
          : all.filter(
              (item) => item.status !== 'deleted' || url.searchParams.has('include_deleted'),
            );
        return HttpResponse.json(expensesPage(list));
      }),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Expenses');
    await screen.findByRole('link', { name: 'Groceries' });
    expect(screen.queryByRole('link', { name: 'Old bill' })).not.toBeInTheDocument();

    await user.selectOptions(screen.getByLabelText('Status'), 'disputed');
    expect(await screen.findByText('1 expense', { selector: 'p' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Movie' })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Groceries' })).not.toBeInTheDocument();
    // Deleted expenses are listed by status; the checkbox only applies to "All".
    expect(screen.getByLabelText('Show deleted')).toBeDisabled();

    await user.selectOptions(screen.getByLabelText('Status'), '');
    await user.click(await screen.findByLabelText('Show deleted'));
    expect(await screen.findByRole('link', { name: 'Old bill' })).toBeInTheDocument();
    expect(screen.getByText('3 expenses', { selector: 'p' })).toBeInTheDocument();

    await user.selectOptions(screen.getByLabelText('Status'), 'deleted');
    expect(await screen.findByText('1 expense', { selector: 'p' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Old bill' })).toBeInTheDocument();
    // Going back to "All" reuses the cached first page.
    expect(seen).toEqual([
      '?limit=50',
      '?status=disputed&limit=50',
      '?include_deleted=true&limit=50',
      '?status=deleted&limit=50',
    ]);
  });

  it('sends who paid, the category and a checked date range with every page', async () => {
    serveMoneyGroup();
    const seen: string[] = [];
    server.use(
      http.get(`${API}/groups/:id/expenses`, ({ request }) => {
        seen.push(new URL(request.url).search);
        return HttpResponse.json(expensesPage([makeGroupExpense()]));
      }),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Expenses');
    await screen.findByRole('link', { name: 'Groceries' });

    await user.selectOptions(screen.getByLabelText('Paid by'), MEERA);
    await waitFor(() => {
      expect(seen).toContain(`?payer_user_id=${MEERA}&limit=50`);
    });
    await user.selectOptions(screen.getByLabelText('Category'), 'uncategorized');
    await waitFor(() => {
      expect(seen).toContain(`?payer_user_id=${MEERA}&category_key=uncategorized&limit=50`);
    });

    // A reversed range is refused before anything is sent.
    await user.type(screen.getByLabelText('From'), '2026-11-30');
    await user.type(screen.getByLabelText('To'), '2026-11-01');
    await user.click(screen.getByRole('button', { name: 'Apply' }));
    expect(screen.getByLabelText('To')).toHaveAccessibleDescription(
      /The start date must be on or before the end date./,
    );
    await user.clear(screen.getByLabelText('From'));
    await user.type(screen.getByLabelText('From'), '2026-10-01');
    await user.click(screen.getByRole('button', { name: 'Apply' }));
    await waitFor(() => {
      expect(seen).toContain(
        `?from=2026-10-01&to=2026-11-01&payer_user_id=${MEERA}&category_key=uncategorized&limit=50`,
      );
    });

    await user.click(screen.getByRole('button', { name: 'Clear filters' }));
    expect(screen.getByLabelText('Paid by')).toHaveValue('');
    expect(screen.getByLabelText('From')).toHaveValue('');
    expect(seen.filter((search) => search === '?limit=50')).toHaveLength(1);
  });

  it('loads the next page with the server’s cursor and keeps the filters', async () => {
    serveMoneyGroup(makeGroupWithFormerMember());
    const seen: string[] = [];
    server.use(
      http.get(`${API}/groups/:id/expenses`, ({ request }) => {
        const url = new URL(request.url);
        seen.push(url.search);
        if (url.searchParams.get('cursor') === 'page-2') {
          return HttpResponse.json(
            expensesPage([makeGroupExpense({ id: EXPENSE_3, description: 'Water' })]),
          );
        }
        return HttpResponse.json(
          expensesPage(
            [
              makeGroupExpense(),
              makeGroupExpense({
                id: EXPENSE_2,
                description: 'Movie',
                payers: [{ user_id: RAVI, paid: money('100.00') }],
              }),
            ],
            'page-2',
          ),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Expenses');
    expect(
      await screen.findByText('2 expenses shown; there are more.', { selector: 'p' }),
    ).toBeInTheDocument();
    // Former members can be chosen as the payer: their expenses stay.
    await user.selectOptions(screen.getByLabelText('Paid by'), RAVI);
    expect(screen.getByRole('option', { name: 'Ravi Kumar (@ravi) · Removed from the group' }));
    await screen.findByRole('link', { name: 'Movie' });

    await user.click(screen.getByRole('button', { name: 'Load more' }));
    expect(await screen.findByRole('link', { name: 'Water' })).toBeInTheDocument();
    expect(screen.getByText('3 expenses', { selector: 'p' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Load more' })).not.toBeInTheDocument();
    expect(seen).toEqual([
      '?limit=50',
      `?payer_user_id=${RAVI}&limit=50`,
      `?payer_user_id=${RAVI}&cursor=page-2&limit=50`,
    ]);
  });

  it('shows a first-use empty state with the add action', async () => {
    serveMoneyGroup();
    server.use(http.get(`${API}/groups/:id/expenses`, () => HttpResponse.json(envelope([]))));
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Expenses');
    expect(await screen.findByText('No shared expenses yet')).toBeInTheDocument();
    expect(screen.getAllByRole('link', { name: 'Add expense' })).toHaveLength(2);
  });

  it('says when nothing matches the filters and offers to clear them', async () => {
    serveMoneyGroup();
    server.use(
      http.get(`${API}/groups/:id/expenses`, ({ request }) =>
        HttpResponse.json(
          expensesPage(new URL(request.url).searchParams.has('status') ? [] : [makeGroupExpense()]),
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Expenses');
    await screen.findByRole('link', { name: 'Groceries' });
    await user.selectOptions(screen.getByLabelText('Status'), 'disputed');
    expect(await screen.findByText('No expenses match')).toBeInTheDocument();
    // The empty state offers the clear action too.
    await user.click(screen.getAllByRole('button', { name: 'Clear filters' })[1]!);
    expect(await screen.findByRole('link', { name: 'Groceries' })).toBeInTheDocument();
  });

  it('shows a recoverable error with the request reference', async () => {
    serveMoneyGroup();
    let calls = 0;
    server.use(
      http.get(`${API}/groups/:id/expenses`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-gm' }), {
              status: 500,
            })
          : HttpResponse.json(envelope([makeGroupExpense()]));
      }),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Expenses');
    expect(await screen.findByText('We couldn’t load the expenses')).toBeInTheDocument();
    expect(screen.getByText('req-gm')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByRole('link', { name: 'Groceries' })).toBeInTheDocument();
  });

  it('shows permission and not-found states without leaking the group', async () => {
    serveMoneyGroup();
    server.use(
      http.get(`${API}/groups/:id/expenses`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    const { unmount } = renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Expenses');
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
    unmount();

    // Non-members get 404 for every group resource.
    renderRoute('/groups/00000000-0000-4000-8000-00000000dead/expenses', { user: signedIn() });
    await findPageHeading('Expenses');
    expect(await screen.findByText('Group not found')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Back to groups' })).toHaveAttribute('href', '/groups');
  });

  it('is read-only in an archived group', async () => {
    serveMoneyGroup(makeMoneyGroup({ status: 'archived' }));
    server.use(
      http.get(`${API}/groups/:id/expenses`, () =>
        HttpResponse.json(envelope([makeGroupExpense()])),
      ),
    );
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Expenses');
    expect(await screen.findByText('This group is archived')).toBeInTheDocument();
    await screen.findByRole('link', { name: 'Groceries' });
    expect(screen.queryByRole('link', { name: 'Add expense' })).not.toBeInTheDocument();
  });
});
