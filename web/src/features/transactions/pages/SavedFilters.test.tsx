import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import type { SavedFilter } from '@/shared/savedFilters/api';
import { expectNoAxeViolations } from '@/tests/axe';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { makeTransaction } from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const signedIn = () => makeUser({ onboarding_completed: true });

function saved(overrides: Partial<SavedFilter> = {}): SavedFilter {
  return {
    id: '9ec3544e-bd1f-40f3-8da2-54c315a75201',
    scope: 'transactions',
    name: 'Groceries this month',
    filter: { range: 'this_month', type: ['expense'], sort: 'date_desc' },
    created_at: '2026-11-10T09:00:00Z',
    ...overrides,
  };
}

function listRequests(record: URL[]) {
  return [
    http.get(`${API}/transactions`, ({ request }) => {
      record.push(new URL(request.url));
      return HttpResponse.json(envelope([makeTransaction()]));
    }),
    http.get(`${API}/transactions/search`, ({ request }) => {
      record.push(new URL(request.url));
      return HttpResponse.json(envelope([makeTransaction()]));
    }),
  ];
}

describe('saved filters on the transactions list', () => {
  it('saves the current filters in the API query shape, trims the name and refuses a blank one', async () => {
    const bodies: unknown[] = [];
    server.use(
      ...listRequests([]),
      http.post(`${API}/saved-filters`, async ({ request }) => {
        const body = (await request.json()) as { name: string; filter: unknown; scope: string };
        bodies.push(body);
        const created = saved({ id: 'b2', name: body.name, filter: body.filter });
        testBackend.savedFilters = [created];
        return HttpResponse.json(envelope(created), { status: 201 });
      }),
    );
    const user = userEvent.setup();
    renderRoute('/transactions?type=expense&range=this_month', { user: signedIn() });
    await findPageHeading('Transactions');
    await user.type(screen.getByLabelText('Search'), 'bazaar');

    await user.click(screen.getByRole('button', { name: 'Saved filters' }));
    const dialog = await screen.findByRole('dialog', { name: 'Saved filters' });
    expect(within(dialog).getByText('Nothing saved yet.')).toBeInTheDocument();
    const name = within(dialog).getByLabelText('Name');

    await user.type(name, '   ');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await within(dialog).findByText('Enter a name.')).toBeInTheDocument();
    expect(bodies).toHaveLength(0);

    await user.clear(name);
    await user.type(name, '  Food  ');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => {
      expect(bodies).toHaveLength(1);
    });
    expect(bodies[0]).toEqual({
      scope: 'transactions',
      name: 'Food',
      filter: { sort: 'date_desc', range: 'this_month', type: ['expense'], q: 'bazaar' },
    });
    expect(await within(dialog).findByText('Food')).toBeInTheDocument();
    // No Idempotency-Key: the contract does not take one for this create.
  });

  it('shows a duplicate name on the field and other refusals as a form message', async () => {
    let attempt = 0;
    server.use(
      ...listRequests([]),
      http.post(`${API}/saved-filters`, () => {
        attempt += 1;
        if (attempt === 1) {
          return HttpResponse.json(
            errorBody({
              code: 'CONFLICT',
              message: 'A saved filter with this name already exists.',
            }),
            { status: 409 },
          );
        }
        return HttpResponse.json(errorBody({ code: 'RATE_LIMITED' }), {
          status: 429,
          headers: { 'Retry-After': '30' },
        });
      }),
    );
    const user = userEvent.setup();
    renderRoute('/transactions?type=expense', { user: signedIn() });
    await findPageHeading('Transactions');
    await user.click(screen.getByRole('button', { name: 'Saved filters' }));
    const dialog = await screen.findByRole('dialog', { name: 'Saved filters' });
    const name = within(dialog).getByLabelText('Name');
    await user.type(name, 'Food');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(
      await within(dialog).findByText(
        'You already have a saved filter called “Food”. Choose another name.',
      ),
    ).toBeInTheDocument();
    expect(name).toHaveAttribute('aria-invalid', 'true');
    expect(name).toHaveFocus();

    await user.clear(name);
    await user.type(name, 'Food 2');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await within(dialog).findByRole('alert')).toHaveTextContent(/try again/i);
  });

  it('applies a saved filter, including its search text, and reports parts it left out', async () => {
    testBackend.savedFilters = [
      saved({
        filter: {
          type: ['expense'],
          range: 'last_month',
          q: 'tea',
          reconciliation_state: 'unreconciled',
          sort: 'amount_desc',
        },
      }),
      saved({ id: 'arr', name: 'From the future', filter: [1, 2] }),
    ];
    const requests: URL[] = [];
    server.use(...listRequests(requests));
    const user = userEvent.setup();
    const { router } = renderRoute('/transactions', { user: signedIn() });
    await findPageHeading('Transactions');
    await user.click(await screen.findByRole('button', { name: 'Saved filters (2)' }));
    const dialog = await screen.findByRole('dialog', { name: 'Saved filters' });
    expect(within(dialog).getByRole('button', { name: 'Apply From the future' })).toBeDisabled();
    expect(
      within(dialog).getByText('Can’t be used in this version of Montra.'),
    ).toBeInTheDocument();

    await user.click(within(dialog).getByRole('button', { name: 'Apply Groceries this month' }));
    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    });
    expect(router.state.location.search).toContain('range=last_month');
    expect(router.state.location.search).not.toContain('tea');
    expect(screen.getByLabelText('Search')).toHaveValue('tea');
    await waitFor(() => {
      const last = requests.at(-1)!.searchParams;
      expect(last.get('q')).toBe('tea');
      expect(last.get('sort')).toBe('amount_desc');
      expect(last.has('reconciliation_state')).toBe(false);
    });
    expect(
      await screen.findByText('Some of its filters aren’t available here and were left out.'),
    ).toBeInTheDocument();
  });

  it('deletes a saved filter after confirming, and treats one already gone as deleted', async () => {
    testBackend.savedFilters = [saved()];
    const deleted: string[] = [];
    server.use(
      ...listRequests([]),
      http.delete(`${API}/saved-filters/:id`, ({ params }) => {
        deleted.push(String(params.id));
        testBackend.savedFilters = [];
        return HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 });
      }),
    );
    const user = userEvent.setup();
    renderRoute('/transactions', { user: signedIn() });
    await findPageHeading('Transactions');
    await user.click(await screen.findByRole('button', { name: 'Saved filters (1)' }));
    const dialog = await screen.findByRole('dialog', { name: 'Saved filters' });
    await user.click(within(dialog).getByRole('button', { name: 'Delete Groceries this month' }));
    const confirm = await screen.findByRole('dialog', { name: 'Delete “Groceries this month”?' });
    await user.click(within(confirm).getByRole('button', { name: 'Cancel' }));
    expect(deleted).toHaveLength(0);

    await user.click(within(dialog).getByRole('button', { name: 'Delete Groceries this month' }));
    const again = await screen.findByRole('dialog', { name: 'Delete “Groceries this month”?' });
    await user.click(within(again).getByRole('button', { name: 'Delete saved filter' }));
    await waitFor(() => {
      expect(within(dialog).getByText('Nothing saved yet.')).toBeInTheDocument();
    });
    expect(deleted).toEqual([saved().id]);
  });

  it('has no axe violations with saved filters listed', async () => {
    testBackend.savedFilters = [saved(), saved({ id: 'x', name: 'Bad', filter: 'nope' })];
    server.use(...listRequests([]));
    const user = userEvent.setup();
    renderRoute('/transactions?type=expense', { user: signedIn() });
    await findPageHeading('Transactions');
    await user.click(await screen.findByRole('button', { name: 'Saved filters (2)' }));
    const dialog = await screen.findByRole('dialog', { name: 'Saved filters' });
    await expectNoAxeViolations(dialog);
  });
});
