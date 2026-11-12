import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { money } from '@/tests/financeFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import {
  SUB_GYM,
  SUB_NETFLIX,
  SUB_NETFLIX_FAMILY,
  makeDuplicateWarning,
  makeSubscription,
  makeSubscriptionSummary,
} from '@/tests/subscriptionsFixtures';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

function emptySummary() {
  return makeSubscriptionSummary({
    totals: [],
    upcoming_renewals: [],
    trials_ending_soon: [],
    pending_detections: 0,
  });
}

describe('SubscriptionsPage', () => {
  it('shows server costs per currency, upcoming renewals and each subscription', async () => {
    server.use(
      http.get(`${API}/subscriptions/summary`, () =>
        HttpResponse.json(
          envelope(
            makeSubscriptionSummary({
              totals: [
                {
                  currency: 'INR',
                  monthly: money('1448.00'),
                  annual: money('17376.00'),
                  count: 2,
                },
                {
                  currency: 'USD',
                  monthly: money('10.00', 'USD'),
                  annual: money('120.00', 'USD'),
                  count: 1,
                },
              ],
              trials_ending_soon: [
                makeSubscription({
                  id: SUB_GYM,
                  name: 'Gym',
                  status: 'trial',
                  trial_ends_on: '2026-11-15',
                }),
              ],
            }),
          ),
        ),
      ),
      http.get(`${API}/subscriptions`, () =>
        HttpResponse.json(
          envelope([
            makeSubscription(),
            makeSubscription({
              id: SUB_NETFLIX_FAMILY,
              name: 'Netflix family',
              plan_name: undefined,
              billing_frequency: 'custom',
              interval_count: 3,
              interval_unit: 'month',
              amount: money('1500.00'),
              monthly_cost: money('500.00'),
              annual_cost: money('6000.00'),
              duplicate_warnings: [
                makeDuplicateWarning({
                  subscription_id: SUB_NETFLIX,
                  name: 'Netflix',
                  reason: 'Same merchant',
                  reason_code: 'same_merchant',
                  reason_params: { name: 'Netflix' },
                }),
              ],
              owned: false,
            }),
          ]),
        ),
      ),
    );
    renderRoute('/subscriptions', { user: signedIn() });
    await findPageHeading('Subscriptions');

    const summary = await screen.findByRole('region', { name: 'What your subscriptions cost' });
    // Currencies are never added together.
    expect(within(summary).getByText('INR · 2 subscriptions')).toBeInTheDocument();
    expect(within(summary).getByText('₹1,448.00')).toBeInTheDocument();
    expect(within(summary).getByText('₹17,376.00')).toBeInTheDocument();
    expect(within(summary).getByText('USD · 1 subscription')).toBeInTheDocument();
    expect(within(summary).getByText('$120.00')).toBeInTheDocument();
    expect(
      within(summary).getByText(
        /1 repeating charge in your transactions looks like a subscription/,
      ),
    ).toBeInTheDocument();
    expect(within(summary).getByRole('link', { name: 'Review them' })).toHaveAttribute(
      'href',
      '/subscriptions/review',
    );
    expect(within(summary).getByRole('link', { name: 'Gym' })).toHaveAttribute(
      'href',
      `/subscriptions/${SUB_GYM}`,
    );
    expect(within(summary).getByText('November 15, 2026')).toBeInTheDocument();

    const list = screen.getByRole('region', { name: 'Your subscriptions' });
    const netflix = within(list).getByRole('link', { name: 'Netflix' }).closest('li')!;
    expect(within(netflix).getByText('Standard · Netflix · Monthly')).toBeInTheDocument();
    expect(within(netflix).getByText('Active')).toBeInTheDocument();
    expect(within(netflix).getByText('₹649.00 a month')).toBeInTheDocument();
    expect(within(netflix).getByText('₹7,788.00')).toBeInTheDocument();
    expect(within(netflix).getByText('Renews on November 10, 2026')).toBeInTheDocument();

    const family = within(list).getByRole('link', { name: 'Netflix family' }).closest('li')!;
    expect(within(family).getByText('₹1,500.00 · Every 3 months')).toBeInTheDocument();
    expect(within(family).getByText('₹500.00')).toBeInTheDocument();
    expect(within(family).getByText('Possible duplicate')).toBeInTheDocument();
    expect(within(family).getByText('Shared with you')).toBeInTheDocument();
  });

  it('filters by status through the API and offers to show everything', async () => {
    const seen: string[] = [];
    server.use(
      http.get(`${API}/subscriptions/summary`, () =>
        HttpResponse.json(envelope(makeSubscriptionSummary())),
      ),
      http.get(`${API}/subscriptions`, ({ request }) => {
        const status = new URL(request.url).searchParams.get('status') ?? '';
        seen.push(status);
        if (status === 'cancelled') return HttpResponse.json(envelope([]));
        return HttpResponse.json(
          envelope([
            status === 'all'
              ? makeSubscription({
                  status: 'cancelled',
                  cancelled_on: '2026-11-01',
                  next_renewal_date: undefined,
                })
              : makeSubscription(),
          ]),
        );
      }),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/subscriptions', { user: signedIn() });
    await findPageHeading('Subscriptions');
    const list = screen.getByRole('region', { name: 'Your subscriptions' });
    await within(list).findByRole('link', { name: 'Netflix' });

    await user.selectOptions(screen.getByLabelText('Show'), 'cancelled');
    expect(await screen.findByText('No subscriptions with this status')).toBeInTheDocument();
    expect(router.state.location.search).toBe('?status=cancelled');

    await user.click(screen.getByRole('button', { name: 'Show all' }));
    const row = (await within(list).findByRole('link', { name: 'Netflix' })).closest('li')!;
    expect(within(row).getByText('Cancelled')).toBeInTheDocument();
    // The calendar date from cancelled_on (no time-zone shift).
    expect(within(row).getByText('Cancelled on November 1, 2026')).toBeInTheDocument();
    expect(seen).toEqual(['', 'cancelled', 'all']);
  });

  it('invites the user to add one or check found ones when there are none', async () => {
    server.use(
      http.get(`${API}/subscriptions/summary`, () => HttpResponse.json(envelope(emptySummary()))),
      http.get(`${API}/subscriptions`, () => HttpResponse.json(envelope([]))),
    );
    renderRoute('/subscriptions', { user: signedIn() });
    await findPageHeading('Subscriptions');
    expect(await screen.findByText('No subscriptions yet')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Check found subscriptions' })).toHaveAttribute(
      'href',
      '/subscriptions/review',
    );
    expect(screen.getAllByRole('link', { name: 'Add subscription' })[0]).toHaveAttribute(
      'href',
      '/subscriptions/new',
    );
    // Nothing to sum up: no cost summary.
    expect(screen.queryByRole('region', { name: 'What your subscriptions cost' })).toBeNull();
  });

  it('shows a retryable error and keeps the summary error inside its card', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/subscriptions/summary`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 }),
      ),
      http.get(`${API}/subscriptions`, () => {
        calls += 1;
        if (calls === 1) {
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
        }
        return HttpResponse.json(envelope([makeSubscription()]));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/subscriptions', { user: signedIn() });
    await findPageHeading('Subscriptions');
    expect(await screen.findByText('We couldn’t load your subscriptions')).toBeInTheDocument();
    expect(screen.getByText('We couldn’t load your subscription costs')).toBeInTheDocument();
    const list = screen.getByRole('region', { name: 'Your subscriptions' });
    await user.click(within(list).getByRole('button', { name: 'Try again' }));
    expect(await within(list).findByRole('link', { name: 'Netflix' })).toBeInTheDocument();
  });

  it('explains when the user has no access', async () => {
    server.use(
      http.get(`${API}/subscriptions/summary`, () => HttpResponse.json(envelope(emptySummary()))),
      http.get(`${API}/subscriptions`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/subscriptions', { user: signedIn() });
    await findPageHeading('Subscriptions');
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });
});
