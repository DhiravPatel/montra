import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  TX_GROCERIES,
  makeAccount,
  makeTransaction,
  starterCategories,
} from '@/tests/financeFixtures';
import {
  BILL_ID,
  BILL_RULE_ID,
  OCC_RULE,
  OCC_RULE_SKIPPED,
  RULE_ID,
  makeOccurrence,
  makeRule,
  makeRuleDetail,
} from '@/tests/planningFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const path = `/planning/recurring/${RULE_ID}`;
const MERCHANT_ID = '99999999-9999-4999-8999-999999999902';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

function serveRule(rule = makeRuleDetail()) {
  server.use(http.get(`${API}/recurring-rules/:id`, () => HttpResponse.json(envelope(rule))));
}

interface ActionRequest {
  id: string;
  key: string | null;
  body: unknown;
}

function recordActions(respond?: (count: number) => Response | undefined) {
  const requests: ActionRequest[] = [];
  server.use(
    http.post(`${API}/recurring-occurrences/:id/actions`, async ({ request, params }) => {
      requests.push({
        id: String(params.id),
        key: request.headers.get('Idempotency-Key'),
        body: await request.json(),
      });
      return (
        respond?.(requests.length) ??
        HttpResponse.json(envelope(makeOccurrence({ id: String(params.id) })))
      );
    }),
  );
  return requests;
}

async function openActions(user: ReturnType<typeof userEvent.setup>, date: string, item: string) {
  await user.click(await screen.findByRole('button', { name: `Actions for ${date}` }));
  await user.click(await screen.findByRole('menuitem', { name: item }));
}

beforeAll(async () => {
  await import('./RecurringRuleDetailPage');
});

beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(new Date('2026-11-05T06:00:00Z'));
  testBackend.accounts = [makeAccount()];
  testBackend.categories = starterCategories();
});

describe('RecurringRuleDetailPage', () => {
  it('shows the schedule, amounts and occurrences', async () => {
    serveRule(
      makeRuleDetail({
        merchant_id: MERCHANT_ID,
        merchant: { id: MERCHANT_ID, name: 'Landlord' },
      }),
    );
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Rent');
    const summary = screen.getByRole('region', { name: 'At a glance' });
    expect(within(summary).getByText('Active')).toBeInTheDocument();
    expect(within(summary).getByText('₹15,000.00')).toBeInTheDocument();
    expect(within(summary).getByText('November 30, 2026')).toBeInTheDocument();
    expect(within(summary).getByText('2 times')).toBeInTheDocument();
    expect(within(summary).getByText('No, you record it')).toBeInTheDocument();

    const details = screen.getByRole('region', { name: 'Details' });
    expect(within(details).getByText('Every month on the last day')).toBeInTheDocument();
    expect(within(details).getByText('1 day before')).toBeInTheDocument();
    expect(await within(details).findByText('Wallet')).toBeInTheDocument();
    expect(await within(details).findByText('Groceries')).toBeInTheDocument();
    // The payee comes with the rule: no extra merchant request.
    expect(within(details).getByText('Paid to')).toBeInTheDocument();
    expect(within(details).getByText('Landlord')).toBeInTheDocument();

    const occurrences = screen.getByRole('region', { name: 'Occurrences' });
    expect(within(occurrences).getByText('Upcoming')).toBeInTheDocument();
    expect(within(occurrences).getByText('Skipped')).toBeInTheDocument();
  });

  it('shows a moved occurrence with the date it moved to', async () => {
    serveRule(
      makeRuleDetail({
        occurrences: [
          makeOccurrence({
            id: OCC_RULE,
            rule_id: RULE_ID,
            rule_name: 'Rent',
            kind: 'expense',
            occurrence_date: '2026-11-30',
            effective_date: '2026-12-02',
            postponed_to: '2026-12-02',
            status: 'scheduled',
            bill_id: undefined,
          }),
        ],
      }),
    );
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Rent');
    const occurrences = screen.getByRole('region', { name: 'Occurrences' });
    expect(within(occurrences).getByText('November 30, 2026')).toBeInTheDocument();
    expect(within(occurrences).getByText('Moved to Dec 2, 2026')).toBeInTheDocument();
    expect(within(occurrences).getByText('Upcoming')).toBeInTheDocument();
    expect(
      within(occurrences).getByRole('button', { name: 'Actions for November 30, 2026' }),
    ).toBeInTheDocument();
  });

  it('records and moves occurrences, each with its own Idempotency-Key', async () => {
    serveRule();
    const requests = recordActions();
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Rent');

    await openActions(user, 'November 30, 2026', 'Record now');
    const record = await screen.findByRole('dialog', { name: 'Record this occurrence' });
    expect(within(record).getByText('Leave empty to use ₹15,000.00.')).toBeInTheDocument();
    // Recording early uses today's date unless changed.
    expect(await within(record).findByLabelText('Date')).toHaveValue('2026-11-05');
    await user.click(within(record).getByRole('button', { name: 'Record' }));
    expect(await screen.findByText('Recorded')).toBeInTheDocument();

    await openActions(user, 'November 30, 2026', 'Move to another date');
    const move = await screen.findByRole('dialog', { name: 'Move to another date' });
    const date = await within(move).findByLabelText('New date');
    await user.type(date, '2026-11-20');
    await user.click(within(move).getByRole('button', { name: 'Move' }));
    expect(
      await within(move).findByText('Choose a date after the current one.'),
    ).toBeInTheDocument();
    await user.clear(date);
    await user.type(date, '2026-12-02');
    await user.click(within(move).getByRole('button', { name: 'Move' }));
    expect(await screen.findByText('Moved to the new date')).toBeInTheDocument();

    expect(requests.map(({ id, body }) => ({ id, body }))).toEqual([
      { id: OCC_RULE, body: { action: 'confirm', date: '2026-11-05' } },
      { id: OCC_RULE, body: { action: 'postpone', postpone_to: '2026-12-02' } },
    ]);
    expect(requests[0]?.key).toMatch(/^web-/);
    expect(requests[1]?.key).toMatch(/^web-/);
    expect(requests[1]?.key).not.toBe(requests[0]?.key);
  });

  it('changes one amount and links a recorded transaction', async () => {
    serveRule();
    const requests = recordActions();
    server.use(
      http.get(`${API}/transactions`, ({ request }) => {
        expect(new URL(request.url).searchParams.get('type')).toBe('expense,group_expense');
        return HttpResponse.json(envelope([makeTransaction()]));
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Rent');

    await openActions(user, 'November 30, 2026', 'Change amount');
    const change = await screen.findByRole('dialog', {
      name: 'Change the amount for this occurrence',
    });
    await user.type(await within(change).findByLabelText('New amount'), '15500');
    await user.click(within(change).getByRole('button', { name: 'Save amount' }));
    expect(await screen.findByText('Amount updated')).toBeInTheDocument();

    await openActions(user, 'November 30, 2026', 'Link a transaction');
    const picker = await screen.findByRole('dialog', { name: 'Link a transaction you recorded' });
    await user.click(await within(picker).findByRole('radio', { name: /Big Bazaar/ }));
    await user.click(within(picker).getByRole('button', { name: 'Link transaction' }));
    expect(await screen.findByText('Transaction linked')).toBeInTheDocument();

    expect(requests.map((request) => request.body)).toEqual([
      { action: 'set_amount', amount: '15500.00' },
      { action: 'link_transaction', transaction_id: TX_GROCERIES },
    ]);
  });

  it('keeps the key when a skip is retried and explains an already-handled occurrence', async () => {
    serveRule();
    const requests = recordActions((count) =>
      count === 1
        ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 })
        : HttpResponse.json(errorBody({ code: 'CONFLICT' }), { status: 409 }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Rent');
    await openActions(user, 'November 30, 2026', 'Skip');
    const dialog = await screen.findByRole('dialog', { name: 'Skip this occurrence?' });
    await user.click(within(dialog).getByRole('button', { name: 'Skip' }));
    expect(
      await within(dialog).findByText('Something went wrong on our side. Try again in a moment.'),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Skip' }));
    expect(
      await within(dialog).findByText(
        'This was already handled or changed. We’ve refreshed it, so check and try again if needed.',
      ),
    ).toBeInTheDocument();
    expect(requests).toHaveLength(2);
    expect(requests[1]?.key).toBe(requests[0]?.key);
    expect(requests[0]?.body).toEqual({ action: 'skip' });
  });

  it('undoes a skip', async () => {
    serveRule();
    const requests = recordActions();
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Rent');
    await openActions(user, 'October 31, 2026', 'Undo skip');
    expect(await screen.findByText('Occurrence is due again')).toBeInTheDocument();
    expect(requests.map(({ id, body }) => ({ id, body }))).toEqual([
      { id: OCC_RULE_SKIPPED, body: { action: 'reopen' } },
    ]);
    expect(requests[0]?.key).toMatch(/^web-/);
  });

  it('explains coded conflicts on an occurrence in the interface language', async () => {
    serveRule();
    recordActions(() =>
      HttpResponse.json(
        errorBody({
          code: 'CONFLICT',
          details: [
            {
              message: 'Only skipped occurrences can be reopened.',
              code: 'occurrence_not_skipped',
            },
          ],
        }),
        { status: 409 },
      ),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Rent');
    await openActions(user, 'October 31, 2026', 'Undo skip');
    expect(
      await screen.findByText('Only skipped items can be made due again. We’ve refreshed it.'),
    ).toBeInTheDocument();
    expect(screen.getByText('We couldn’t update this occurrence')).toBeInTheDocument();
  });

  it('pauses, skips the next occurrence and stops after confirmation, with the version', async () => {
    serveRule();
    const calls: string[] = [];
    server.use(
      http.post(`${API}/recurring-rules/:id/:action`, ({ request, params }) => {
        calls.push(`${String(params.action)}${new URL(request.url).search}`);
        return HttpResponse.json(envelope(makeRule()));
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Rent');
    await user.click(screen.getByRole('button', { name: 'Pause' }));
    expect(
      await screen.findByText('Paused. Nothing new is scheduled until you resume.'),
    ).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Skip next' }));
    const skip = await screen.findByRole('dialog', { name: 'Skip the next occurrence?' });
    expect(
      within(skip).getByText(/Nothing will be recorded on November 30, 2026/),
    ).toBeInTheDocument();
    await user.click(within(skip).getByRole('button', { name: 'Skip next' }));
    expect(await screen.findByText('Next occurrence skipped')).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Stop' }));
    const stop = await screen.findByRole('dialog', { name: 'Stop this recurring item?' });
    await user.click(within(stop).getByRole('button', { name: 'Stop' }));
    expect(await screen.findByText('Recurring item stopped')).toBeInTheDocument();
    expect(calls).toEqual(['pause?version=3', 'skip-next?version=3', 'stop?version=3']);
  });

  it('explains an ended schedule that cannot resume', async () => {
    serveRule(makeRuleDetail({ status: 'paused' }));
    server.use(
      http.post(`${API}/recurring-rules/:id/resume`, () =>
        HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            details: [
              {
                message: 'This schedule has ended; edit it to set new dates.',
                code: 'schedule_ended',
              },
            ],
          }),
          { status: 409 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Rent');
    await user.click(screen.getByRole('button', { name: 'Resume' }));
    expect(
      await screen.findByText(
        'This schedule has ended. Edit it to set new dates before resuming it.',
      ),
    ).toBeInTheDocument();
  });

  it('deletes an unused item and returns to the list, or keeps history when it was used', async () => {
    serveRule();
    let outcome: 'deleted' | 'ended' = 'ended';
    server.use(
      http.delete(`${API}/recurring-rules/:id`, () => HttpResponse.json(envelope({ outcome }))),
      http.get(`${API}/recurring-rules`, () => HttpResponse.json(envelope([]))),
    );
    const user = userEvent.setup();
    const { router } = renderRoute(path, { user: signedIn() });
    await findPageHeading('Rent');
    await user.click(screen.getByRole('button', { name: 'Delete' }));
    let dialog = await screen.findByRole('dialog', { name: 'Delete this recurring item?' });
    await user.click(within(dialog).getByRole('button', { name: 'Delete' }));
    expect(
      await screen.findByText('Recurring item stopped. Its history is kept.'),
    ).toBeInTheDocument();
    expect(router.state.location.pathname).toBe(path);

    outcome = 'deleted';
    await user.click(screen.getByRole('button', { name: 'Delete' }));
    dialog = await screen.findByRole('dialog', { name: 'Delete this recurring item?' });
    await user.click(within(dialog).getByRole('button', { name: 'Delete' }));
    await findPageHeading('Recurring');
    expect(router.state.location.pathname).toBe('/planning/recurring');
    expect(screen.getByText('Recurring item deleted')).toBeInTheDocument();
  });

  it('explains a rule that is in use and cannot be deleted', async () => {
    serveRule();
    server.use(
      http.delete(`${API}/recurring-rules/:id`, () =>
        HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            details: [
              { message: 'This rule could not be deleted; stop it instead.', code: 'rule_in_use' },
            ],
          }),
          { status: 409 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Rent');
    await user.click(screen.getByRole('button', { name: 'Delete' }));
    const dialog = await screen.findByRole('dialog', { name: 'Delete this recurring item?' });
    await user.click(within(dialog).getByRole('button', { name: 'Delete' }));
    expect(
      await within(dialog).findByText(
        'This item is in use, so it can’t be deleted. Stop it instead; its history is kept.',
      ),
    ).toBeInTheDocument();
  });

  it('is read-only for others and points bills to their page', async () => {
    serveRule(makeRuleDetail({ owned: false }));
    const first = renderRoute(path, { user: signedIn() });
    await findPageHeading('Rent');
    expect(
      screen.getByText('Only the person who added this item can change it.'),
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Pause' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /^Actions for/ })).not.toBeInTheDocument();
    first.unmount();

    serveRule(
      makeRuleDetail({
        id: BILL_RULE_ID,
        kind: 'bill',
        name: 'Electricity',
        bill_id: BILL_ID,
        occurrences: [makeOccurrence()],
      }),
    );
    renderRoute(`/planning/recurring/${BILL_RULE_ID}`, { user: signedIn() });
    await findPageHeading('Electricity');
    expect(screen.getByRole('link', { name: 'Open the bill' })).toHaveAttribute(
      'href',
      `/planning/bills/${BILL_ID}`,
    );
    expect(screen.queryByRole('link', { name: 'Edit' })).not.toBeInTheDocument();
  });

  it('shows not found and error states', async () => {
    server.use(
      http.get(`${API}/recurring-rules/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    const first = renderRoute(path, { user: signedIn() });
    expect(await screen.findByText('Recurring item not found')).toBeInTheDocument();
    first.unmount();

    server.use(
      http.get(`${API}/recurring-rules/:id`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-rule' }), {
          status: 500,
        }),
      ),
    );
    renderRoute(path, { user: signedIn() });
    expect(await screen.findByText('We couldn’t load this recurring item')).toBeInTheDocument();
    expect(screen.getByText('req-rule')).toBeInTheDocument();
  });
});
