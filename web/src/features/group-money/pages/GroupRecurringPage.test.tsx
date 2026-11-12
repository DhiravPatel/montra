import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { money } from '@/tests/financeFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  EXPENSE_ID,
  ME,
  MEERA,
  MONEY_GROUP,
  OCCURRENCE_NEXT,
  RAVI,
  RULE_ID,
  makeExpenseDetail,
  makeGroupWithFormerMember,
  makeMoneyGroup,
  makeOccurrence,
  makeRecurring,
  serveMoneyGroup,
} from '@/tests/groupMoneyFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import type { GroupRecurring } from '../types';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

const PATH = `/groups/${MONEY_GROUP}/recurring`;

function serveRecurring(initial: GroupRecurring[]) {
  const state = { list: initial, reads: 0 };
  server.use(
    http.get(`${API}/groups/:id/recurring-expenses`, () => {
      state.reads += 1;
      return HttpResponse.json(envelope(state.list));
    }),
  );
  return state;
}

function withRule(list: GroupRecurring[], update: (rule: GroupRecurring) => GroupRecurring) {
  return list.map((item) => (item.rule.id === RULE_ID ? update(item) : item));
}

describe('GroupRecurringPage', () => {
  it('lists recurring shared expenses with their schedule, split and dates', async () => {
    serveMoneyGroup();
    serveRecurring([makeRecurring()]);
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Recurring expenses');
    const card = await screen.findByRole('region', { name: 'Rent' });
    expect(within(card).getByText('Active')).toBeInTheDocument();
    expect(within(card).getByText('Added by a member')).toBeInTheDocument();
    expect(within(card).getAllByText('₹30,000.00').length).toBeGreaterThanOrEqual(1);
    expect(within(card).getByText('Every month on day 5')).toBeInTheDocument();
    expect(within(card).getByText('No end date')).toBeInTheDocument();
    expect(within(card).getByText('Equally · You, Meera Rao, Ravi Kumar')).toBeInTheDocument();
    expect(within(card).getByText('Whoever adds it')).toBeInTheDocument();
    const dates = within(card).getByRole('region', { name: 'Dates' });
    expect(within(dates).getAllByText('Upcoming')).toHaveLength(2);
    expect(within(dates).getAllByRole('button', { name: /^Add the expense for/ })).toHaveLength(2);
  });

  it('adds an occurrence with an Idempotency-Key and skips another after confirming', async () => {
    serveMoneyGroup();
    const state = serveRecurring([makeRecurring()]);
    const keys: (string | null)[] = [];
    let skipped = '';
    server.use(
      http.post(
        `${API}/groups/:id/recurring-expenses/:ruleId/occurrences/:occurrenceId/add`,
        ({ params, request }) => {
          keys.push(request.headers.get('Idempotency-Key'));
          state.list = withRule(state.list, (rule) => ({
            ...rule,
            occurrences: rule.occurrences.map((occurrence) =>
              occurrence.id === params.occurrenceId
                ? { ...occurrence, status: 'posted', group_expense_id: EXPENSE_ID }
                : occurrence,
            ),
          }));
          return HttpResponse.json(
            envelope(makeExpenseDetail({ description: 'Rent', amount: money('30000.00') })),
            { status: 201 },
          );
        },
      ),
      http.post(
        `${API}/groups/:id/recurring-expenses/:ruleId/occurrences/:occurrenceId/skip`,
        ({ params }) => {
          skipped = String(params.occurrenceId);
          state.list = withRule(state.list, (rule) => ({
            ...rule,
            occurrences: rule.occurrences.map((occurrence) =>
              occurrence.id === params.occurrenceId
                ? { ...occurrence, status: 'skipped' }
                : occurrence,
            ),
          }));
          return HttpResponse.json(envelope(state.list[0]));
        },
      ),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Recurring expenses');
    const dates = await screen.findByRole('region', { name: 'Dates' });
    const addButtons = within(dates).getAllByRole('button', { name: /^Add the expense for/ });
    // The due one is listed last (newest first).
    await user.click(addButtons[1]!);
    expect(await screen.findByText('Expense added')).toBeInTheDocument();
    expect(keys).toHaveLength(1);
    expect(keys[0]).toMatch(/^web-/);
    expect(await within(dates).findByRole('link', { name: 'View expense' })).toHaveAttribute(
      'href',
      `/groups/${MONEY_GROUP}/expenses/${EXPENSE_ID}`,
    );

    await user.click(within(dates).getByRole('button', { name: /^Skip the expense for/ }));
    const dialog = await screen.findByRole('dialog', { name: 'Skip this one?' });
    expect(within(dialog).getByText(/won’t be added. This can’t be undone./)).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Skip it' }));
    expect(await within(dates).findAllByText('Skipped')).toHaveLength(1);
    expect(skipped).toBe(OCCURRENCE_NEXT);
  });

  it('pauses, resumes and stops after confirmation', async () => {
    serveMoneyGroup();
    const state = serveRecurring([makeRecurring()]);
    const actions: string[] = [];
    server.use(
      http.post(`${API}/groups/:id/recurring-expenses/:ruleId/:action`, ({ params }) => {
        const action = String(params.action);
        actions.push(action);
        const status = action === 'pause' ? 'paused' : action === 'resume' ? 'active' : 'ended';
        state.list = withRule(state.list, (rule) => ({
          ...rule,
          rule: { ...rule.rule, status, version: rule.rule.version + 1 },
          occurrences: action === 'resume' ? rule.occurrences : [],
        }));
        return HttpResponse.json(envelope(state.list[0]));
      }),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Recurring expenses');
    const card = await screen.findByRole('region', { name: 'Rent' });
    await user.click(within(card).getByRole('button', { name: 'Pause' }));
    expect(await within(card).findByText('Paused')).toBeInTheDocument();
    await user.click(await within(card).findByRole('button', { name: 'Resume' }));
    expect(await screen.findByText('Resumed')).toBeInTheDocument();

    await user.click(await within(card).findByRole('button', { name: 'Stop' }));
    const dialog = await screen.findByRole('dialog', { name: 'Stop this recurring expense?' });
    expect(within(dialog).getByText(/No more expenses will be added for Rent/)).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Stop it' }));
    expect(await screen.findByText('Stopped')).toBeInTheDocument();
    expect(actions).toEqual(['pause', 'resume', 'stop']);
    expect(await within(card).findByText('Ended')).toBeInTheDocument();
    expect(within(card).queryByRole('button', { name: 'Pause' })).not.toBeInTheDocument();
  });

  it('creates a recurring expense with a schedule and split', async () => {
    serveMoneyGroup();
    const state = serveRecurring([]);
    let body: Record<string, unknown> | null = null;
    let key: string | null = null;
    server.use(
      http.post(`${API}/groups/:id/recurring-expenses`, async ({ request }) => {
        body = (await request.json()) as Record<string, unknown>;
        key = request.headers.get('Idempotency-Key');
        const created = makeRecurring({
          rule: {
            ...makeRecurring().rule,
            id: 'r2r2r2r2-0000-4000-8000-000000000002',
            name: 'Internet',
            amount: money('700.00'),
          },
          occurrences: [],
        });
        state.list = [created];
        return HttpResponse.json(envelope(created), { status: 201 });
      }),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Recurring expenses');
    expect(await screen.findByText('No recurring shared expenses yet')).toBeInTheDocument();
    await user.click(screen.getAllByRole('button', { name: 'New recurring expense' })[0]!);
    const dialog = await screen.findByRole('dialog', { name: 'New recurring expense' });
    await user.click(within(dialog).getByRole('button', { name: 'Create' }));
    expect(within(dialog).getByLabelText('Name')).toHaveAccessibleDescription(/Enter a name./);

    await user.type(within(dialog).getByLabelText('Name'), 'Internet');
    await user.type(within(dialog).getByLabelText('Amount each time'), '700');
    await user.click(within(dialog).getByRole('radio', { name: 'Shares' }));
    await user.type(within(dialog).getByLabelText('Shares for You (Asha Rao)'), '2');
    await user.type(within(dialog).getByLabelText('Shares for Meera Rao (@meera)'), '1');
    await user.click(within(dialog).getByRole('checkbox', { name: 'Ravi Kumar (@ravi)' }));
    await user.click(within(dialog).getByRole('checkbox', { name: /Add it automatically/ }));
    await user.click(within(dialog).getByRole('button', { name: 'Create' }));

    expect(await screen.findByText('Recurring expense created')).toBeInTheDocument();
    expect(key).toMatch(/^web-[0-9a-f-]{36}$/);
    expect(body).toMatchObject({
      name: 'Internet',
      amount: '700.00',
      auto_add: true,
      split_method: 'shares',
      participants: [
        { user_id: ME, value: '2' },
        { user_id: MEERA, value: '1' },
      ],
      frequency: 'monthly',
      start_date: todayInTimeZone('Asia/Kolkata'),
      local_time: '09:00',
      reminder_days_before: [1],
    });
    expect(body).not.toHaveProperty('payers');
    expect(await screen.findByRole('region', { name: 'Internet' })).toBeInTheDocument();
  });

  it('edits with the version and starts again from the latest after a conflict', async () => {
    serveMoneyGroup();
    const state = serveRecurring([makeRecurring()]);
    const bodies: Record<string, unknown>[] = [];
    server.use(
      http.patch(`${API}/groups/:id/recurring-expenses/:ruleId`, async ({ request }) => {
        const body = (await request.json()) as Record<string, unknown>;
        bodies.push(body);
        if (bodies.length === 1) {
          state.list = withRule(state.list, (rule) => ({
            ...rule,
            rule: { ...rule.rule, name: 'Flat rent', version: 2 },
          }));
          return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
        }
        state.list = withRule(state.list, (rule) => ({
          ...rule,
          rule: {
            ...rule.rule,
            name: String(body.name),
            amount: money(String(body.amount)),
            version: 3,
          },
        }));
        return HttpResponse.json(envelope(state.list[0]));
      }),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Recurring expenses');
    const card = await screen.findByRole('region', { name: 'Rent' });
    await user.click(within(card).getByRole('button', { name: 'Edit' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit recurring expense' });
    expect(
      within(dialog).getByText(
        'The schedule can’t change. To change it, stop this one and create a new one.',
      ),
    ).toBeInTheDocument();
    const amount = within(dialog).getByLabelText('Amount each time');
    await user.clear(amount);
    await user.type(amount, '32000');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));

    expect(await within(dialog).findByText('This was changed somewhere else')).toBeInTheDocument();
    await waitFor(() => {
      expect(within(dialog).getByLabelText('Name')).toHaveValue('Flat rent');
    });
    await user.clear(within(dialog).getByLabelText('Amount each time'));
    await user.type(within(dialog).getByLabelText('Amount each time'), '32000');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Recurring expense saved')).toBeInTheDocument();
    expect(bodies[0]).toMatchObject({ name: 'Rent', amount: '32000.00', version: 1 });
    expect(bodies[1]).toEqual({
      name: 'Flat rent',
      amount: '32000.00',
      auto_add: false,
      split_method: 'equal',
      participants: [{ user_id: ME }, { user_id: MEERA }, { user_id: RAVI }],
      category_key: 'housing_rent',
      version: 2,
    });
  });

  it('shows the rule read-only to members who did not set it up', async () => {
    serveMoneyGroup(makeMoneyGroup({ my_role: 'member' }));
    serveRecurring([makeRecurring({ created_by: MEERA })]);
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Recurring expenses');
    const card = await screen.findByRole('region', { name: 'Rent' });
    for (const name of ['Edit', 'Pause', 'Stop']) {
      expect(within(card).queryByRole('button', { name })).not.toBeInTheDocument();
    }
    expect(
      within(card).queryByRole('button', { name: /^Add the expense for/ }),
    ).not.toBeInTheDocument();
    expect(
      within(card).getByText('Ask Meera Rao or a group admin to add or skip a due one.'),
    ).toBeInTheDocument();
  });

  it('shows a recoverable error', async () => {
    serveMoneyGroup();
    server.use(
      http.get(`${API}/groups/:id/recurring-expenses`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-rec' }), {
          status: 500,
        }),
      ),
    );
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Recurring expenses');
    expect(await screen.findByText('We couldn’t load the recurring expenses')).toBeInTheDocument();
    expect(screen.getByText('req-rec')).toBeInTheDocument();
  });

  it('names the person who left when an occurrence cannot be added, and follows a handled one', async () => {
    serveMoneyGroup(makeGroupWithFormerMember());
    const state = serveRecurring([makeRecurring()]);
    let adds = 0;
    server.use(
      http.post(
        `${API}/groups/:id/recurring-expenses/:ruleId/occurrences/:occurrenceId/add`,
        () => {
          adds += 1;
          if (adds === 1) {
            return HttpResponse.json(
              errorBody({
                code: 'DOMAIN_RULE_VIOLATION',
                details: [
                  {
                    message:
                      'Someone who shares or pays this recurring expense is no longer a member.',
                    code: 'recurring_member_inactive',
                    params: { user_id: RAVI },
                  },
                ],
              }),
              { status: 422 },
            );
          }
          state.list = withRule(state.list, (rule) => ({
            ...rule,
            occurrences: rule.occurrences.map((occurrence) =>
              occurrence.id === OCCURRENCE_NEXT ? { ...occurrence, status: 'skipped' } : occurrence,
            ),
          }));
          return HttpResponse.json(
            errorBody({
              code: 'CONFLICT',
              details: [
                {
                  message: 'This occurrence was already added or skipped.',
                  code: 'occurrence_already_handled',
                  params: { status: 'skipped' },
                },
              ],
            }),
            { status: 409 },
          );
        },
      ),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Recurring expenses');
    const dates = await screen.findByRole('region', { name: 'Dates' });
    await user.click(within(dates).getAllByRole('button', { name: /^Add the expense for/ })[0]!);
    expect(
      await screen.findByText(
        'Ravi Kumar is no longer a member of this group. Edit who shares or pays it, then add it.',
      ),
    ).toBeInTheDocument();

    // Skipped somewhere else meanwhile: the list is reloaded and says so.
    const reads = state.reads;
    await user.click(within(dates).getAllByRole('button', { name: /^Add the expense for/ })[0]!);
    expect(await screen.findByText('This one was already skipped.')).toBeInTheDocument();
    await waitFor(() => {
      expect(state.reads).toBeGreaterThan(reads);
    });
    expect(await within(dates).findByText('Skipped')).toBeInTheDocument();
  });

  it('explains a stopped schedule that cannot resume', async () => {
    serveMoneyGroup();
    serveRecurring([
      makeRecurring({
        rule: { ...makeRecurring().rule, status: 'paused' },
        occurrences: [makeOccurrence({ status: 'skipped' })],
      }),
    ]);
    server.use(
      http.post(`${API}/groups/:id/recurring-expenses/:ruleId/resume`, () =>
        HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            details: [{ message: 'This schedule has ended.', code: 'schedule_ended' }],
          }),
          { status: 409 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Recurring expenses');
    await user.click(await screen.findByRole('button', { name: 'Resume' }));
    expect(
      await screen.findByText(
        'This recurring expense has stopped. Create a new one to start again.',
      ),
    ).toBeInTheDocument();
  });
});
