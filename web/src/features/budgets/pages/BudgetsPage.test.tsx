import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import type { BudgetAlert } from '@/shared/finance/types';
import {
  ALERT_ID,
  BUDGET_ID,
  OTHER_ALERT_ID,
  SHARED_BUDGET_ID,
  makeBudget,
  makeBudgetAlert,
  makeSharedBudget,
  pageEnvelope,
} from '@/tests/budgetsFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

/** GET /budget-alerts by status (empty unless given). */
function alertsHandler(byStatus: Partial<Record<BudgetAlert['status'], BudgetAlert[]>> = {}) {
  return http.get(`${API}/budget-alerts`, ({ request }) => {
    const status = new URL(request.url).searchParams.get('status') as BudgetAlert['status'];
    return HttpResponse.json(envelope(byStatus[status] ?? []));
  });
}

describe('BudgetsPage', () => {
  it('lists budgets with this period’s progress in words and as a meter', async () => {
    server.use(
      http.get(`${API}/budgets`, () =>
        HttpResponse.json(envelope([makeBudget(), makeSharedBudget({ status: 'paused' })])),
      ),
      alertsHandler(),
    );
    renderRoute('/budgets', { user: signedIn() });
    await findPageHeading('Budgets');

    const food = (await screen.findByRole('link', { name: 'Food' })).closest('li');
    expect(food).not.toBeNull();
    const row = within(food!);
    expect(screen.getByRole('link', { name: 'Food' })).toHaveAttribute(
      'href',
      `/budgets/${BUDGET_ID}`,
    );
    const meter = row.getByRole('meter', { name: 'Food: budget used' });
    expect(meter).toHaveAttribute('aria-valuetext', '₹4,200.00 of ₹5,000.00 spent (84%)');
    expect(row.getByText('₹4,200.00 of ₹5,000.00 spent')).toBeInTheDocument();
    expect(row.getByText('₹800.00 left')).toBeInTheDocument();
    // Pace in words with an icon, never color alone.
    expect(row.getByText('Spending faster than expected')).toBeInTheDocument();
    expect(row.getByText(/By category · Monthly/)).toBeInTheDocument();

    const household = within(screen.getByRole('link', { name: 'Household' }).closest('li')!);
    // Who shared it (owner_display_name), never the owner's ID.
    expect(household.getByText('Shared by Kiran Shah · Can view')).toBeInTheDocument();
    expect(household.getByText('Paused')).toBeInTheDocument();
    expect(household.getByText('On track')).toBeInTheDocument();

    expect(screen.getByText('No alerts right now.')).toBeInTheDocument();
  });

  it('asks the API for archived budgets only when requested', async () => {
    const seen: string[] = [];
    server.use(
      http.get(`${API}/budgets`, ({ request }) => {
        const search = new URL(request.url).search;
        seen.push(search);
        return HttpResponse.json(
          envelope(
            search.includes('include_archived=true')
              ? [makeBudget({ status: 'archived', name: 'Old plan' })]
              : [makeBudget()],
          ),
        );
      }),
      alertsHandler(),
    );
    const user = userEvent.setup();
    renderRoute('/budgets', { user: signedIn() });
    await screen.findByRole('link', { name: 'Food' });
    await user.click(screen.getByLabelText('Show archived'));
    expect(await screen.findByRole('link', { name: 'Old plan' })).toBeInTheDocument();
    expect(screen.getByText('Archived')).toBeInTheDocument();
    expect(seen).toEqual(['', '?include_archived=true']);
  });

  it('offers to create the first budget', async () => {
    server.use(
      http.get(`${API}/budgets`, () => HttpResponse.json(envelope([]))),
      alertsHandler(),
    );
    renderRoute('/budgets', { user: signedIn() });
    expect(await screen.findByText('No budgets yet')).toBeInTheDocument();
    const links = screen.getAllByRole('link', { name: 'Create budget' });
    expect(links.length).toBeGreaterThan(0);
    for (const link of links) expect(link).toHaveAttribute('href', '/budgets/new');
  });

  it('shows an error with a retry', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/budgets`, () => {
        calls += 1;
        if (calls === 1) {
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
        }
        return HttpResponse.json(envelope([makeBudget()]));
      }),
      alertsHandler(),
    );
    const user = userEvent.setup();
    renderRoute('/budgets', { user: signedIn() });
    expect(await screen.findByText('We couldn’t load your budgets')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByRole('link', { name: 'Food' })).toBeInTheDocument();
  });

  it('explains when the budgets are not available to this account', async () => {
    server.use(
      http.get(`${API}/budgets`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
      alertsHandler(),
    );
    renderRoute('/budgets', { user: signedIn() });
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });

  it('dismisses, snoozes and reactivates alerts', async () => {
    const bodies: unknown[] = [];
    const active = makeBudgetAlert();
    const snoozed = makeBudgetAlert({
      id: ALERT_ID,
      status: 'snoozed',
      snoozed_until: '2026-11-12T06:00:00Z',
    });
    server.use(
      http.get(`${API}/budgets`, () => HttpResponse.json(envelope([makeBudget()]))),
      alertsHandler({ active: [active], snoozed: [snoozed] }),
      http.patch(`${API}/budget-alerts/:id`, async ({ request, params }) => {
        expect(params.id).toBe(ALERT_ID);
        bodies.push(await request.json());
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/budgets', { user: signedIn() });
    const alerts = await screen.findByRole('region', { name: 'Alerts' });
    const message = 'Food reached 75% of its limit';
    expect(await within(alerts).findByRole('link', { name: message })).toHaveAttribute(
      'href',
      `/budgets/${BUDGET_ID}`,
    );

    await user.click(within(alerts).getByRole('button', { name: `Dismiss: ${message}` }));
    expect(await screen.findByText('Alert dismissed')).toBeInTheDocument();
    expect(bodies[0]).toEqual({ status: 'dismissed' });

    await user.click(within(alerts).getByRole('button', { name: `Snooze: ${message}` }));
    await user.click(await screen.findByRole('menuitem', { name: 'For a week' }));
    expect(await screen.findByText(/Alert snoozed until/)).toBeInTheDocument();
    const snooze = bodies[1] as { status: string; snoozed_until: string };
    expect(snooze.status).toBe('snoozed');
    expect(Date.parse(snooze.snoozed_until)).toBeGreaterThan(Date.now() + 6 * 24 * 3600 * 1000);

    await user.click(within(alerts).getByRole('radio', { name: 'Snoozed' }));
    expect(await within(alerts).findByText(/Snoozed until/)).toBeInTheDocument();
    await user.click(within(alerts).getByRole('button', { name: `Reactivate: ${message}` }));
    expect(await screen.findByText('Alert is active again')).toBeInTheDocument();
    await waitFor(() => {
      expect(bodies[2]).toEqual({ status: 'active' });
    });
  });

  it('loads more alerts with the cursor from meta.next_cursor', async () => {
    const requests: URLSearchParams[] = [];
    server.use(
      http.get(`${API}/budgets`, () => HttpResponse.json(envelope([makeBudget()]))),
      http.get(`${API}/budget-alerts`, ({ request }) => {
        const params = new URL(request.url).searchParams;
        requests.push(params);
        return params.get('cursor') === 'page-2'
          ? HttpResponse.json(
              pageEnvelope([
                makeBudgetAlert({
                  id: OTHER_ALERT_ID,
                  budget_id: SHARED_BUDGET_ID,
                  budget_name: 'Trip',
                  threshold: 90,
                }),
              ]),
            )
          : HttpResponse.json(pageEnvelope([makeBudgetAlert()], 'page-2'));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/budgets', { user: signedIn() });
    const alerts = await screen.findByRole('region', { name: 'Alerts' });
    expect(
      await within(alerts).findByRole('link', { name: 'Food reached 75% of its limit' }),
    ).toBeInTheDocument();

    await user.click(within(alerts).getByRole('button', { name: 'Load more' }));
    expect(
      await within(alerts).findByRole('link', { name: 'Trip reached 90% of its limit' }),
    ).toBeInTheDocument();
    // Both pages stay on screen and the last page has no "Load more".
    expect(
      within(alerts).getByRole('link', { name: 'Food reached 75% of its limit' }),
    ).toBeVisible();
    expect(within(alerts).queryByRole('button', { name: 'Load more' })).not.toBeInTheDocument();
    expect(requests.map((params) => params.get('cursor'))).toEqual([null, 'page-2']);
    expect(requests.every((params) => params.get('status') === 'active')).toBe(true);
    expect(requests[0]?.get('limit')).toBe('50');
  });

  it('keeps the list usable when alerts fail to load', async () => {
    server.use(
      http.get(`${API}/budgets`, () => HttpResponse.json(envelope([makeBudget()]))),
      http.get(`${API}/budget-alerts`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 }),
      ),
    );
    renderRoute('/budgets', { user: signedIn() });
    expect(await screen.findByRole('link', { name: 'Food' })).toBeInTheDocument();
    expect(await screen.findByText('We couldn’t load your alerts')).toBeInTheDocument();
  });
});
