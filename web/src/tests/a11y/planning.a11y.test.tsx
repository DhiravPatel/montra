import { screen, within } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import { describe, it, vi } from 'vitest';
import { makeCashFlowReport } from '@/tests/analyticsFixtures';
import { expectNoAxeViolations } from '@/tests/axe';
import { API, envelope, makeUser } from '@/tests/fixtures';
import { makeAccount, makeCard, money } from '@/tests/financeFixtures';
import {
  CONTRIBUTION_FRIEND,
  CONTRIBUTION_PLANNED,
  GOAL_FUND,
  GOAL_TRIP,
  makeContribution,
  makeForecast,
  makeGoal,
  makeGoalReport,
} from '@/tests/goalsFixtures';
import { IMPORT_OLD, makeBatch } from '@/tests/importsFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { RULE_ID, makeCalendarItem, makeRecurringReport } from '@/tests/planningFixtures';
import {
  RECEIPT_ID,
  RECEIPT_OTHER,
  makeExtraction,
  makeReceipt,
  makeReviewedReceipt,
  previewHandlers,
} from '@/tests/receiptsFixtures';
import { findPageHeading, renderRoute } from '@/tests/render';
import { FRIEND_ID } from '@/tests/sharingFixtures';
import {
  SUB_GYM,
  SUB_NETFLIX,
  SUB_NETFLIX_FAMILY,
  makeDuplicateWarning,
  makeSubscription,
  makeSubscriptionSummary,
} from '@/tests/subscriptionsFixtures';

const signedIn = () => makeUser({ onboarding_completed: true });

describe('axe: planning pages', () => {
  it('planning calendar', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date('2026-11-05T06:00:00Z'));
    server.use(
      http.get(`${API}/analytics/recurring`, () =>
        HttpResponse.json(envelope(makeRecurringReport())),
      ),
      http.get(`${API}/calendar`, () =>
        HttpResponse.json(
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
              entity_id: SUB_NETFLIX,
              occurrence_id: undefined,
            }),
            makeCalendarItem({
              date: '2026-11-20',
              title: 'Water',
              amount: money('300.00'),
              scheduled_on: '2026-11-12',
              postponed_to: '2026-11-20',
            }),
          ]),
        ),
      ),
    );
    renderRoute('/planning', { user: signedIn() });
    await findPageHeading('Upcoming');
    const today = (await screen.findByText('Thursday, November 5')).closest('li')!;
    within(today).getByRole('link', { name: 'Electricity' });
    await expectNoAxeViolations();
  });

  it('goals list', async () => {
    server.use(
      http.get(`${API}/goals`, () =>
        HttpResponse.json(
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
        ),
      ),
      http.get(`${API}/analytics/goals`, () => HttpResponse.json(envelope(makeGoalReport()))),
    );
    renderRoute('/goals', { user: signedIn() });
    await findPageHeading('Goals');
    await screen.findByRole('link', { name: 'Goa trip' });
    await screen.findByRole('region', { name: 'Saved so far' });
    await expectNoAxeViolations();
  });

  it('goals list, empty', async () => {
    server.use(
      http.get(`${API}/goals`, () => HttpResponse.json(envelope([]))),
      http.get(`${API}/analytics/goals`, () =>
        HttpResponse.json(envelope(makeGoalReport({ totals: [] }))),
      ),
    );
    renderRoute('/goals', { user: signedIn() });
    await findPageHeading('Goals');
    await screen.findByText(/no goals/i);
    await expectNoAxeViolations();
  });

  it('goal detail', async () => {
    server.use(
      http.get(`${API}/goals/:id`, () => HttpResponse.json(envelope(makeGoal()))),
      http.get(`${API}/goals/:id/forecast`, () => HttpResponse.json(envelope(makeForecast()))),
      http.get(`${API}/goals/:id/contributions`, () =>
        HttpResponse.json(
          envelope([
            makeContribution({ status: 'verified', amount: money('3000.00'), note: 'Salary day' }),
            makeContribution({
              id: CONTRIBUTION_FRIEND,
              user_id: FRIEND_ID,
              display_name: 'Ravi Kumar',
              mine: false,
              amount: undefined,
              percent_bp: 117,
            }),
            makeContribution({
              id: CONTRIBUTION_PLANNED,
              status: 'planned',
              amount: money('2000.00'),
              contributed_on: '2026-12-01',
            }),
          ]),
        ),
      ),
    );
    renderRoute(`/goals/${GOAL_TRIP}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    await within(screen.getByRole('region', { name: 'Outlook' })).findByText('₹7,714.29');
    await expectNoAxeViolations();
  });

  it('subscriptions list', async () => {
    server.use(
      http.get(`${API}/subscriptions/summary`, () =>
        HttpResponse.json(
          envelope(
            makeSubscriptionSummary({
              totals: [
                { currency: 'INR', monthly: money('1448.00'), annual: money('17376.00'), count: 2 },
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
              amount: money('1500.00'),
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
    await screen.findByRole('region', { name: 'What your subscriptions cost' });
    await screen.findByRole('link', { name: 'Netflix family' });
    await expectNoAxeViolations();
  });

  it('receipts list', async () => {
    server.use(
      http.get(`${API}/receipts`, () =>
        HttpResponse.json(
          envelope([
            makeReceipt({ status: 'reviewed', current: makeExtraction(), version: 2 }),
            makeReceipt({
              id: RECEIPT_OTHER,
              status: 'needs_review',
              duplicate_of_id: RECEIPT_ID,
            }),
          ]),
        ),
      ),
    );
    renderRoute('/receipts', { user: signedIn() });
    await findPageHeading('Receipts');
    await screen.findByRole('link', { name: 'Cafe Uno' });
    await expectNoAxeViolations();
  });

  it('receipts list, empty', async () => {
    server.use(http.get(`${API}/receipts`, () => HttpResponse.json(envelope([]))));
    renderRoute('/receipts', { user: signedIn() });
    await findPageHeading('Receipts');
    await screen.findByText('No receipts yet');
    await expectNoAxeViolations();
  });

  it('receipt detail', async () => {
    testBackend.accounts = [makeAccount()];
    server.use(
      http.get(`${API}/receipts/:id`, () => HttpResponse.json(envelope(makeReviewedReceipt()))),
      ...previewHandlers(),
    );
    renderRoute(`/receipts/${RECEIPT_ID}`, { user: signedIn() });
    await findPageHeading('Cafe Uno');
    await screen.findByRole('img', { name: 'Receipt image' });
    await expectNoAxeViolations();
  });

  it('imports list', async () => {
    testBackend.accounts = [makeAccount(), makeCard()];
    server.use(
      http.get(`${API}/imports`, () =>
        HttpResponse.json(
          envelope([
            makeBatch({ status: 'completed', imported_count: 3, skipped_count: 1, version: 2 }),
            makeBatch({
              id: IMPORT_OLD,
              status: 'needs_mapping',
              total_rows: 0,
              statement_start: undefined,
              statement_end: undefined,
              created_at: '2026-11-01T10:00:00Z',
            }),
          ]),
        ),
      ),
    );
    renderRoute('/imports', { user: signedIn() });
    await findPageHeading('Statement imports');
    const history = screen.getByRole('region', { name: 'Import history' });
    await within(history).findByRole('link', { name: /^Wallet · Nov 5, 2026/ });
    await expectNoAxeViolations();
  });

  it('new import', async () => {
    testBackend.accounts = [makeAccount(), makeCard()];
    renderRoute('/imports/new', { user: signedIn() });
    await findPageHeading('Import a statement');
    await screen.findByLabelText('Account');
    await expectNoAxeViolations();
  });

  it('analytics', async () => {
    testBackend.accounts = [makeAccount()];
    server.use(
      http.get(`${API}/analytics/cash-flow`, () =>
        HttpResponse.json(envelope(makeCashFlowReport())),
      ),
    );
    renderRoute('/analytics', { user: signedIn() });
    await findPageHeading('Analytics');
    await screen.findByRole('region', { name: 'In INR' });
    await expectNoAxeViolations();
  });
});
