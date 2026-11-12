import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { money } from '@/tests/financeFixtures';
import { BILL_ID, RULE_ID, makeCalendarItem, makeRecurringReport } from '@/tests/planningFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const SUBSCRIPTION_ID = 'e1111111-1111-4111-8111-111111111111';
const GOAL_ID = 'f1111111-1111-4111-8111-111111111111';
const GROUP_RULE_ID = 'a9999999-9999-4999-8999-999999999999';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

function useReport() {
  server.use(
    http.get(`${API}/analytics/recurring`, () =>
      HttpResponse.json(envelope(makeRecurringReport())),
    ),
  );
}

// Load the lazy route module once up front so a cold transform cannot outlast the
// default query timeouts.
beforeAll(async () => {
  await import('./PlanningCalendarPage');
});

describe('PlanningCalendarPage', () => {
  beforeEach(() => {
    // Only Date is faked: "today" is 5 Nov 2026 in Asia/Kolkata.
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date('2026-11-05T06:00:00Z'));
  });

  it('lists the month by day with kinds, statuses, links and the regular commitments', async () => {
    const ranges: string[] = [];
    useReport();
    server.use(
      http.get(`${API}/calendar`, ({ request }) => {
        ranges.push(new URL(request.url).search);
        return HttpResponse.json(
          envelope([
            makeCalendarItem(),
            makeCalendarItem({
              date: '2026-11-16',
              kind: 'recurring',
              title: 'Allowance',
              amount: money('500.00'),
              status: 'projected',
              entity_type: 'recurring_rule',
              entity_id: RULE_ID,
              occurrence_id: undefined,
            }),
            makeCalendarItem({
              date: '2026-11-16',
              kind: 'subscription_renewal',
              title: 'Netflix',
              amount: money('649.00'),
              status: 'expected',
              entity_type: 'subscription',
              entity_id: SUBSCRIPTION_ID,
              occurrence_id: undefined,
            }),
            makeCalendarItem({
              date: '2026-11-25',
              kind: 'group_expense',
              title: 'Flat internet',
              status: 'overdue',
              entity_type: 'group_recurring_expense',
              entity_id: GROUP_RULE_ID,
            }),
            // Moved: listed on its new date, naming the date it was planned for.
            makeCalendarItem({
              date: '2026-11-20',
              title: 'Water',
              amount: money('300.00'),
              scheduled_on: '2026-11-12',
              postponed_to: '2026-11-20',
            }),
            makeCalendarItem({
              date: '2026-11-30',
              kind: 'goal_target',
              title: 'Trip',
              amount: undefined,
              status: 'target',
              entity_type: 'goal',
              entity_id: GOAL_ID,
              occurrence_id: undefined,
            }),
          ]),
        );
      }),
    );
    renderRoute('/planning', { user: signedIn() });
    await findPageHeading('Upcoming');
    expect(screen.getByRole('heading', { level: 2, name: 'November 2026' })).toBeInTheDocument();

    const today = (await screen.findByText('Thursday, November 5')).closest('li');
    expect(today).not.toBeNull();
    expect(within(today!).getByText('Today')).toBeInTheDocument();
    expect(within(today!).getByRole('link', { name: 'Electricity' })).toHaveAttribute(
      'href',
      `/planning/bills/${BILL_ID}`,
    );
    expect(within(today!).getByText('Bill')).toBeInTheDocument();
    expect(within(today!).getByText('Upcoming')).toBeInTheDocument();
    expect(within(today!).getByText('₹1,200.00')).toBeInTheDocument();

    const sixteenth = screen.getByText('Monday, November 16').closest('li');
    expect(within(sixteenth!).getByRole('link', { name: 'Allowance' })).toHaveAttribute(
      'href',
      `/planning/recurring/${RULE_ID}`,
    );
    expect(within(sixteenth!).getByText('Estimated')).toBeInTheDocument();
    expect(within(sixteenth!).getByRole('link', { name: 'Netflix' })).toHaveAttribute(
      'href',
      `/subscriptions/${SUBSCRIPTION_ID}`,
    );
    expect(within(sixteenth!).getByText('Subscription renewal')).toBeInTheDocument();

    const twentieth = screen.getByText('Friday, November 20').closest('li');
    expect(within(twentieth!).getByRole('link', { name: 'Water' })).toBeInTheDocument();
    expect(within(twentieth!).getByText('Moved from Nov 12, 2026')).toBeInTheDocument();

    // Shared group schedules have no page in the portal yet: shown without a link.
    expect(screen.getByText('Flat internet')).not.toHaveAttribute('href');
    expect(screen.getByText('Overdue')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Trip' })).toHaveAttribute('href', `/goals/${GOAL_ID}`);
    expect(screen.getByText('Goal target date')).toBeInTheDocument();
    expect(
      screen.getByText(
        'Estimated items are worked out from the schedule and haven’t been created yet.',
      ),
    ).toBeInTheDocument();
    expect(ranges).toEqual(['?from=2026-11-01&to=2026-11-30']);

    const commitments = screen.getByRole('region', { name: 'Regular commitments' });
    expect(within(commitments).getByText('Bills')).toBeInTheDocument();
    expect(within(commitments).getByText('₹2,400.00')).toBeInTheDocument();
    expect(within(commitments).getByText('Recurring income')).toBeInTheDocument();
    expect(
      within(commitments).getByText('1 schedule has a changing amount and isn’t included.'),
    ).toBeInTheDocument();
    // The API's English note is replaced by its note_code in the interface language.
    expect(within(commitments).queryByText(/Monthly equivalents use/)).not.toBeInTheDocument();
    expect(
      within(commitments).getByText(
        'Only fixed amounts are counted. Bills and income are what you expect, not money recorded yet.',
      ),
    ).toBeInTheDocument();
  });

  it('moves between months and back to this month', async () => {
    const ranges: string[] = [];
    useReport();
    server.use(
      http.get(`${API}/calendar`, ({ request }) => {
        ranges.push(new URL(request.url).search);
        return HttpResponse.json(envelope([makeCalendarItem()]));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/planning', { user: signedIn() });
    await findPageHeading('Upcoming');
    await screen.findByText('Thursday, November 5');

    await user.click(screen.getByRole('button', { name: 'Next month' }));
    expect(
      await screen.findByRole('heading', { level: 2, name: 'December 2026' }),
    ).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Previous month' }));
    await user.click(screen.getByRole('button', { name: 'Previous month' }));
    expect(
      await screen.findByRole('heading', { level: 2, name: 'October 2026' }),
    ).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'This month' }));
    expect(
      await screen.findByRole('heading', { level: 2, name: 'November 2026' }),
    ).toBeInTheDocument();
    expect(ranges).toEqual([
      '?from=2026-11-01&to=2026-11-30',
      '?from=2026-12-01&to=2026-12-31',
      '?from=2026-10-01&to=2026-10-31',
    ]);
  });

  it('shows an empty month with ways to add plans', async () => {
    server.use(
      http.get(`${API}/calendar`, () => HttpResponse.json(envelope([]))),
      http.get(`${API}/analytics/recurring`, () =>
        HttpResponse.json(envelope(makeRecurringReport({ commitments: [] }))),
      ),
    );
    renderRoute('/planning?month=2027-02', { user: signedIn() });
    await findPageHeading('Upcoming');
    expect(await screen.findByText('Nothing planned for February 2027')).toBeInTheDocument();
    expect(screen.getAllByRole('link', { name: 'Add bill' })[0]).toHaveAttribute(
      'href',
      '/planning/bills/new',
    );
    expect(await screen.findByText('No regular commitments yet.')).toBeInTheDocument();
  });

  it('shows a recoverable error and a permission message', async () => {
    useReport();
    server.use(
      http.get(`${API}/calendar`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-cal' }), {
          status: 500,
        }),
      ),
    );
    const { unmount } = renderRoute('/planning', { user: signedIn() });
    await findPageHeading('Upcoming');
    expect(await screen.findByText('We couldn’t load your calendar')).toBeInTheDocument();
    expect(screen.getByText('req-cal')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Try again' })).toBeInTheDocument();
    unmount();

    server.use(
      http.get(`${API}/calendar`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/planning', { user: signedIn() });
    await findPageHeading('Upcoming');
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });
});
