import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import type { GroupActivity } from '@/features/groups/types';
import { formatLocalDateRange } from '@/shared/formatting/dates';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { money } from '@/tests/financeFixtures';
import {
  EXPENSE_ID,
  FORMER_ID,
  FRIEND_ID,
  GROUP_ID,
  GROUP_MEMBER_ID,
  ME,
  SETTLEMENT_ID,
  TRIP_ID,
  groupReadHandlers,
  makeActivity,
  makeActivityPage,
  makeBalances,
  makeGroupDetailFull,
  makeMember,
  makeMe,
  makeTripDetail,
} from '@/tests/groupsFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

function region(name: string) {
  return screen.getByRole('region', { name });
}

describe('GroupDetailPage', () => {
  it('shows the trip, your balance, members, quick links and activity', async () => {
    const trip = makeTripDetail({
      member_count: 2,
      members: [
        makeMe(),
        makeMember({ role: 'admin' }),
        makeMember({
          user_id: FORMER_ID,
          display_name: 'Kabir Shah',
          username: 'kabir',
          status: 'left',
          left_at: '2026-10-20T10:00:00Z',
        }),
      ],
    });
    const reads = groupReadHandlers(trip, {
      balances: makeBalances('1250.00'),
      activity: makeActivityPage([
        makeActivity(),
        makeActivity({
          actor_id: ME,
          kind: 'settlement_confirmed',
          entity_type: 'settlement',
          entity_id: SETTLEMENT_ID,
          summary: {},
        }),
        makeActivity({
          actor_id: ME,
          kind: 'member_role_changed',
          entity_type: 'group_member',
          entity_id: GROUP_MEMBER_ID,
          summary: { role: 'admin' },
        }),
        makeActivity({
          actor_id: FRIEND_ID,
          kind: 'join_requested',
          entity_type: 'group_join_request',
          entity_id: undefined,
          summary: {},
        }),
        makeActivity({
          actor_id: FORMER_ID,
          kind: 'member_left',
          entity_type: 'group_member',
          entity_id: FORMER_ID,
          summary: {},
        }),
        // A kind the API added after this client was built.
        makeActivity({
          kind: 'something_new' as GroupActivity['kind'],
          entity_type: 'group',
          summary: {},
        }),
      ]),
    });
    server.use(...reads.handlers);
    renderRoute(`/groups/${TRIP_ID}`, { user: signedIn() });
    await findPageHeading('Goa trip');

    // The tab title never names the group.
    expect(document.title).toBe('Group · Montra');
    const dates = formatLocalDateRange('2026-12-20', '2026-12-24', 'en-US').replace(/\s+/g, ' ');
    expect(screen.getByText(`2 members · ${dates} · Goa`)).toBeInTheDocument();
    expect(screen.getByRole('navigation', { name: 'Group pages' })).toBeInTheDocument();

    const quick = screen.getByRole('navigation', { name: 'Quick actions' });
    expect(within(quick).getByRole('link', { name: 'Add an expense' })).toHaveAttribute(
      'href',
      `/groups/${TRIP_ID}/expenses/new`,
    );
    expect(within(quick).getByRole('link', { name: 'Settle up' })).toHaveAttribute(
      'href',
      `/groups/${TRIP_ID}/balances`,
    );
    expect(within(quick).getByRole('link', { name: 'Recurring bills' })).toHaveAttribute(
      'href',
      `/groups/${TRIP_ID}/recurring`,
    );
    expect(within(quick).getByRole('link', { name: 'Reports' })).toHaveAttribute(
      'href',
      `/groups/${TRIP_ID}/reports`,
    );

    const balance = region('Your balance');
    expect(await within(balance).findByText('You are owed')).toBeInTheDocument();
    expect(within(balance).getByText('₹1,250.00')).toBeInTheDocument();
    expect(
      within(balance).getByRole('link', { name: 'See balances and settle up' }),
    ).toHaveAttribute('href', `/groups/${TRIP_ID}/balances`);

    const members = region('Members');
    expect(within(members).getByText('Asha Rao')).toBeInTheDocument();
    expect(within(members).getByText('(you)')).toBeInTheDocument();
    expect(within(members).getByText('Owner')).toBeInTheDocument();
    expect(within(members).getByText('Admin')).toBeInTheDocument();
    expect(within(members).queryByText('Kabir Shah')).not.toBeVisible();
    await userEvent.setup().click(within(members).getByRole('button', { name: '1 former member' }));
    expect(within(members).getByText('Kabir Shah')).toBeVisible();

    const about = region('About this group');
    expect(within(about).getByText(/reminds members the day before it starts/)).toBeInTheDocument();

    const activity = region('Recent activity');
    expect(
      await within(activity).findByRole('link', { name: 'Meera Rao added an expense: Groceries' }),
    ).toHaveAttribute('href', `/groups/${TRIP_ID}/expenses/${EXPENSE_ID}`);
    expect(within(activity).getByRole('link', { name: 'You confirmed a payment' })).toHaveAttribute(
      'href',
      `/groups/${TRIP_ID}/settlements/${SETTLEMENT_ID}`,
    );
    expect(within(activity).getByText('You made Meera Rao an admin')).toBeInTheDocument();
    expect(within(activity).getByText('Someone asked to join the group')).toBeInTheDocument();
    expect(within(activity).getByText('Kabir Shah left the group')).toBeInTheDocument();
    expect(within(activity).getByText('Meera Rao made a change')).toBeInTheDocument();
  });

  it('shows what you owe without a minus sign, and payments waiting for confirmation', async () => {
    const reads = groupReadHandlers(makeGroupDetailFull(), {
      balances: makeBalances('-300.50', { disputed_expenses: 2 }, { pending_out: money('100.00') }),
    });
    server.use(...reads.handlers);
    renderRoute(`/groups/${GROUP_ID}`, { user: signedIn() });
    await findPageHeading('Home');
    const balance = region('Your balance');
    expect(await within(balance).findByText('You owe')).toBeInTheDocument();
    expect(within(balance).getByText('₹300.50')).toBeInTheDocument();
    expect(
      within(balance).getByText('₹100.00 you reported paying is waiting for confirmation.'),
    ).toBeInTheDocument();
    expect(
      within(balance).getByText('2 disputed expenses still count until they’re resolved.'),
    ).toBeInTheDocument();
    // Households point to recurring bills.
    expect(
      within(region('About this group')).getByRole('link', { name: 'Set up recurring bills' }),
    ).toHaveAttribute('href', `/groups/${GROUP_ID}/recurring`);
  });

  it('says when you are settled up and when there is no activity yet', async () => {
    const reads = groupReadHandlers(makeGroupDetailFull(), {
      balances: makeBalances('0.00'),
      activity: makeActivityPage([]),
    });
    server.use(...reads.handlers);
    renderRoute(`/groups/${GROUP_ID}`, { user: signedIn() });
    await findPageHeading('Home');
    expect(await screen.findByText('You’re all settled up')).toBeInTheDocument();
    expect(await screen.findByText('No activity yet')).toBeInTheDocument();
  });

  it('pages into older activity', async () => {
    const queries: string[] = [];
    const reads = groupReadHandlers(makeGroupDetailFull());
    server.use(...reads.handlers);
    server.use(
      http.get(`${API}/groups/:id/activity`, ({ request }) => {
        const before = new URL(request.url).searchParams.get('before');
        queries.push(before ?? '');
        return HttpResponse.json(
          envelope(
            before === '41'
              ? makeActivityPage([
                  makeActivity({
                    id: 40,
                    kind: 'group_created',
                    entity_type: 'group',
                    actor_id: ME,
                    summary: {},
                  }),
                ])
              : makeActivityPage(
                  [makeActivity({ id: 41, kind: 'expense_deleted', summary: {} })],
                  41,
                ),
          ),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/groups/${GROUP_ID}`, { user: signedIn() });
    await findPageHeading('Home');
    const activity = region('Recent activity');
    expect(await within(activity).findByText('Meera Rao deleted an expense')).toBeInTheDocument();
    expect(within(activity).queryByText('You created the group')).not.toBeInTheDocument();

    await user.click(within(activity).getByRole('button', { name: 'Show older activity' }));
    expect(await within(activity).findByText('You created the group')).toBeInTheDocument();
    expect(queries).toEqual(['', '41']);
    expect(
      within(activity).queryByRole('button', { name: 'Show older activity' }),
    ).not.toBeInTheDocument();
  });

  it('keeps the loaded activity when an older page fails', async () => {
    const reads = groupReadHandlers(makeGroupDetailFull());
    server.use(...reads.handlers);
    server.use(
      http.get(`${API}/groups/:id/activity`, ({ request }) =>
        new URL(request.url).searchParams.has('before')
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 })
          : HttpResponse.json(
              envelope(
                makeActivityPage(
                  [makeActivity({ id: 41, kind: 'expense_deleted', summary: {} })],
                  41,
                ),
              ),
            ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(`/groups/${GROUP_ID}`, { user: signedIn() });
    await findPageHeading('Home');
    const activity = region('Recent activity');
    await user.click(await within(activity).findByRole('button', { name: 'Show older activity' }));
    expect(
      await within(activity).findByText('We couldn’t load older activity. Try again.'),
    ).toBeInTheDocument();
    expect(within(activity).getByText('Meera Rao deleted an expense')).toBeInTheDocument();
  });

  it('keeps an archived group readable without adding expenses', async () => {
    const reads = groupReadHandlers(makeGroupDetailFull({ status: 'archived' }));
    server.use(...reads.handlers);
    renderRoute(`/groups/${GROUP_ID}`, { user: signedIn() });
    await findPageHeading('Home');
    expect(screen.getByText('This group is archived')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Restore it in settings' })).toHaveAttribute(
      'href',
      `/groups/${GROUP_ID}/settings`,
    );
    const quick = screen.getByRole('navigation', { name: 'Quick actions' });
    expect(within(quick).queryByRole('link', { name: 'Add an expense' })).not.toBeInTheDocument();
    expect(within(quick).getByRole('link', { name: 'Settle up' })).toBeInTheDocument();
  });

  it('shows a balance error inside its card, leaving the rest of the page', async () => {
    const reads = groupReadHandlers(makeGroupDetailFull());
    server.use(...reads.handlers);
    server.use(
      http.get(`${API}/groups/:id/balances`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 }),
      ),
    );
    renderRoute(`/groups/${GROUP_ID}`, { user: signedIn() });
    await findPageHeading('Home');
    expect(
      await within(region('Your balance')).findByText('We couldn’t load your balance'),
    ).toBeInTheDocument();
    expect(region('Members')).toBeInTheDocument();
  });

  it('explains a group that is not available and lets you ask to join', async () => {
    let body: unknown = null;
    server.use(
      http.get(`${API}/groups/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND', message: 'The group was not found.' }), {
          status: 404,
        }),
      ),
      http.post(`${API}/groups/:id/join-requests`, async ({ request, params }) => {
        expect(params.id).toBe(GROUP_ID);
        body = await request.json();
        return HttpResponse.json(
          envelope({
            id: 'f4f4f4f4-6666-4666-8666-000000000009',
            user_id: ME,
            display_name: 'Asha Rao',
            message: 'Asha from flat 2',
            status: 'pending',
            created_at: '2026-11-05T10:00:00Z',
          }),
          { status: 201 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/groups/${GROUP_ID}`, { user: signedIn() });
    await findPageHeading('Group');
    expect(await screen.findByText('This group isn’t available')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Ask to join' }));
    const dialog = await screen.findByRole('dialog', { name: 'Ask to join this group' });
    await user.type(within(dialog).getByLabelText(/^Message to the admins/), 'Asha from flat 2');
    await user.click(within(dialog).getByRole('button', { name: 'Send request' }));
    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    });
    expect(body).toEqual({ message: 'Asha from flat 2' });
    expect(
      screen.getByText('You’ll get a notification when an admin approves it.'),
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Ask to join' })).not.toBeInTheDocument();
  });

  it('explains a join request that is already pending', async () => {
    server.use(
      http.get(`${API}/groups/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
      http.post(`${API}/groups/:id/join-requests`, () =>
        HttpResponse.json(
          errorBody({ code: 'CONFLICT', message: 'Your request is already pending.' }),
          { status: 409 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(`/groups/${GROUP_ID}`, { user: signedIn() });
    await user.click(await screen.findByRole('button', { name: 'Ask to join' }));
    const dialog = await screen.findByRole('dialog', { name: 'Ask to join this group' });
    await user.click(within(dialog).getByRole('button', { name: 'Send request' }));
    expect(
      await within(dialog).findByText(
        'You’re already a member, or your request is already waiting for an admin.',
      ),
    ).toBeInTheDocument();
  });

  it('shows a recoverable error', async () => {
    let calls = 0;
    const reads = groupReadHandlers(makeGroupDetailFull());
    server.use(...reads.handlers);
    server.use(
      http.get(`${API}/groups/:id`, () => {
        calls += 1;
        if (calls === 1) {
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-g1' }), {
            status: 500,
          });
        }
        return HttpResponse.json(envelope(makeGroupDetailFull()));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/groups/${GROUP_ID}`, { user: signedIn() });
    expect(await screen.findByText('We couldn’t load this group')).toBeInTheDocument();
    expect(screen.getByText('req-g1')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await findPageHeading('Home')).toBeInTheDocument();
  });

  it('shows a permission message when the API refuses', async () => {
    server.use(
      http.get(`${API}/groups/:id`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute(`/groups/${GROUP_ID}`, { user: signedIn() });
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });
});
