import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { GOAL_FUND, GOAL_TRIP, makeGoal, makeGoalReport } from '@/tests/goalsFixtures';
import { money } from '@/tests/financeFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

function reportHandler(report = makeGoalReport()) {
  return http.get(`${API}/analytics/goals`, () => HttpResponse.json(envelope(report)));
}

describe('GoalsPage', () => {
  it('lists active goals with server progress, sharing and per-currency totals', async () => {
    const seen: string[] = [];
    server.use(
      http.get(`${API}/goals`, ({ request }) => {
        seen.push(new URL(request.url).search);
        return HttpResponse.json(
          envelope([
            makeGoal(),
            makeGoal({
              id: GOAL_FUND,
              name: 'Emergency fund',
              goal_type: 'emergency_fund',
              access: 'contributor',
              target_date: undefined,
              target: money('100000.00'),
              progress: {
                saved: money('100000.00'),
                remaining: money('0.00'),
                percent_bp: 10000,
                verified: money('0.00'),
                planned: money('0.00'),
                contribution_count: 4,
              },
            }),
          ]),
        );
      }),
      reportHandler(),
    );
    renderRoute('/goals', { user: signedIn() });
    await findPageHeading('Goals');

    expect(await screen.findByRole('link', { name: 'Goa trip' })).toHaveAttribute(
      'href',
      `/goals/${GOAL_TRIP}`,
    );
    expect(screen.getByRole('meter', { name: 'Goa trip' })).toHaveAttribute(
      'aria-valuetext',
      '₹6,000.00 of ₹60,000.00 saved (10%)',
    );
    expect(screen.getByText('₹6,000.00 saved of ₹60,000.00')).toBeInTheDocument();
    expect(screen.getByText('₹54,000.00 to go')).toBeInTheDocument();
    expect(screen.getByText(/^Travel · Target date .*2027$/)).toBeInTheDocument();

    // A shared goal says how it is shared; a finished one says so in words.
    expect(screen.getByText('Shared with you · You can contribute')).toBeInTheDocument();
    expect(screen.getByText('Emergency fund · No target date')).toBeInTheDocument();
    expect(screen.getByText('Target amount reached')).toBeInTheDocument();

    const totals = screen.getByRole('region', { name: 'Saved so far' });
    expect(within(totals).getByText('₹6,000.00 of ₹60,000.00')).toBeInTheDocument();
    expect(within(totals).getByText('1 goal · 0 achieved')).toBeInTheDocument();
    expect(seen).toEqual(['?status=active']);
  });

  it('filters by status and keeps the choice in the address', async () => {
    const seen: string[] = [];
    server.use(
      http.get(`${API}/goals`, ({ request }) => {
        const status = new URL(request.url).searchParams.get('status') ?? '';
        seen.push(status);
        return HttpResponse.json(
          envelope(status === 'all' ? [makeGoal({ status: 'archived', name: 'Old plan' })] : []),
        );
      }),
      reportHandler(makeGoalReport({ goals: [], totals: [] })),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/goals', { user: signedIn() });
    await findPageHeading('Goals');
    expect(await screen.findByText('No goals yet')).toBeInTheDocument();

    await user.selectOptions(screen.getByLabelText('Show'), 'All goals');
    expect(await screen.findByRole('link', { name: 'Old plan' })).toBeInTheDocument();
    expect(screen.getByText('Archived')).toBeInTheDocument();
    expect(router.state.location.search).toBe('?status=all');
    expect(seen).toEqual(['active', 'all']);
  });

  it('shows a first-use empty state with a way to start', async () => {
    server.use(
      http.get(`${API}/goals`, () => HttpResponse.json(envelope([]))),
      reportHandler(makeGoalReport({ goals: [], totals: [] })),
    );
    renderRoute('/goals', { user: signedIn() });
    await findPageHeading('Goals');
    expect(await screen.findByText('No goals yet')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Create a goal' })).toHaveAttribute(
      'href',
      '/goals/new',
    );
    expect(screen.queryByRole('region', { name: 'Saved so far' })).not.toBeInTheDocument();
  });

  it('says when a filtered status has no goals', async () => {
    server.use(
      http.get(`${API}/goals`, () => HttpResponse.json(envelope([]))),
      reportHandler(),
    );
    renderRoute('/goals?status=paused', { user: signedIn() });
    await findPageHeading('Goals');
    expect(await screen.findByText('No goals with this status')).toBeInTheDocument();
    expect(screen.getByLabelText('Show')).toHaveValue('paused');
  });

  it('shows a recoverable error and keeps working when totals fail', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/goals`, () => {
        calls += 1;
        if (calls === 1) {
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-goals' }), {
            status: 500,
          });
        }
        return HttpResponse.json(envelope([makeGoal()]));
      }),
      http.get(`${API}/analytics/goals`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 }),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/goals', { user: signedIn() });
    await findPageHeading('Goals');
    expect(await screen.findByText('We couldn’t load your goals')).toBeInTheDocument();
    expect(screen.getByText('req-goals')).toBeInTheDocument();
    expect(await screen.findByText('Totals aren’t available right now.')).toBeInTheDocument();

    await user.click(screen.getAllByRole('button', { name: 'Try again' })[1]!);
    expect(await screen.findByRole('link', { name: 'Goa trip' })).toBeInTheDocument();
  });

  it('explains when the goals cannot be shown to this account', async () => {
    server.use(
      http.get(`${API}/goals`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
      reportHandler(),
    );
    renderRoute('/goals', { user: signedIn() });
    await findPageHeading('Goals');
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
    await waitFor(() => {
      expect(screen.queryByText('Loading your goals…')).not.toBeInTheDocument();
    });
  });
});
