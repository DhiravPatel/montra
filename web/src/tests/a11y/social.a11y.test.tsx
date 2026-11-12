import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { expectNoAxeViolations } from '@/tests/axe';
import {
  COMMUNITY_ID,
  OTHER_COMMUNITY_ID,
  makeCommunity,
  serveCommunity,
} from '@/tests/communitiesFixtures';
import { makeAccount, money } from '@/tests/financeFixtures';
import { API, envelope, makeUser } from '@/tests/fixtures';
import {
  MONEY_GROUP,
  makeBalances as makeMoneyBalances,
  makeSettlement,
  makeSuggestions,
  serveMoneyGroup,
} from '@/tests/groupMoneyFixtures';
import {
  ME,
  SETTLEMENT_ID,
  TRIP_ID,
  groupReadHandlers,
  makeActivity,
  makeActivityPage,
  makeBalances,
  makeGroupDTO,
  makeMe,
  makeMember,
  makeTripDetail,
} from '@/tests/groupsFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import {
  makeNotification,
  notificationPage,
  securityNotification,
  serveUnreadCount,
  supportReplyNotification,
} from '@/tests/notificationsFixtures';
import { findPageHeading, renderRoute } from '@/tests/render';

const signedIn = () => makeUser({ onboarding_completed: true });

function serveCommunityLists() {
  server.use(
    http.get(`${API}/communities`, ({ request }) => {
      const mine = new URL(request.url).searchParams.get('mine') === 'true';
      return HttpResponse.json(
        envelope(
          mine
            ? [
                makeCommunity({ my_role: 'owner' }),
                makeCommunity({
                  id: OTHER_COMMUNITY_ID,
                  slug: 'salary-circle',
                  name: 'Salary Circle',
                  description: undefined,
                  visibility: 'private',
                  topics: ['careers'],
                  my_status: 'pending',
                  my_role: 'none',
                  member_count: 4,
                }),
              ]
            : [
                makeCommunity(),
                makeCommunity({
                  id: 'c0c0c0c0-1111-4111-8111-000000000009',
                  slug: 'debt-free',
                  name: 'Debt Free India',
                  description: 'Paying off loans together',
                  topics: ['debt', 'loans'],
                  my_status: 'none',
                  my_role: 'none',
                  member_count: 1,
                }),
              ],
        ),
      );
    }),
    http.get(`${API}/community-invitations`, () => HttpResponse.json(envelope([]))),
  );
}

describe('axe: social pages', () => {
  it('groups list', async () => {
    testBackend.groups = [
      makeGroupDTO({ my_net: money('1250.00') }),
      makeGroupDTO({
        id: TRIP_ID,
        name: 'Goa trip',
        group_type: 'trip',
        my_role: 'member',
        member_count: 4,
        start_date: '2026-12-20',
        end_date: '2026-12-24',
        destination: 'Goa',
        my_net: money('-300.50'),
      }),
    ];
    server.use(http.get(`${API}/group-invitations`, () => HttpResponse.json(envelope([]))));
    renderRoute('/groups', { user: signedIn() });
    await findPageHeading('Groups');
    const list = await screen.findByRole('region', { name: 'Your groups' });
    await within(list).findByRole('link', { name: 'Goa trip' });
    await expectNoAxeViolations();
  });

  it('groups list, empty', async () => {
    server.use(http.get(`${API}/group-invitations`, () => HttpResponse.json(envelope([]))));
    renderRoute('/groups', { user: signedIn() });
    await findPageHeading('Groups');
    await screen.findByText(/no groups/i);
    await expectNoAxeViolations();
  });

  it('group detail', async () => {
    const trip = makeTripDetail({
      member_count: 2,
      members: [makeMe(), makeMember({ role: 'admin' })],
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
      ]),
    });
    server.use(...reads.handlers);
    renderRoute(`/groups/${TRIP_ID}`, { user: signedIn() });
    await findPageHeading('Goa trip');
    await screen.findByRole('navigation', { name: 'Quick actions' });
    await within(screen.getByRole('region', { name: 'Recent activity' })).findByRole('link', {
      name: 'Meera Rao added an expense: Groceries',
    });
    await expectNoAxeViolations();
  });

  it('group expense form', async () => {
    testBackend.accounts = [makeAccount()];
    serveMoneyGroup();
    renderRoute(`/groups/${MONEY_GROUP}/expenses/new`, { user: signedIn() });
    await findPageHeading('Add a shared expense');
    await screen.findByLabelText('Description');
    await expectNoAxeViolations();
  });

  it('group expense form with field errors', async () => {
    testBackend.accounts = [makeAccount()];
    serveMoneyGroup();
    const user = userEvent.setup();
    renderRoute(`/groups/${MONEY_GROUP}/expenses/new`, { user: signedIn() });
    await findPageHeading('Add a shared expense');
    const description = await screen.findByLabelText('Description');
    await user.click(screen.getByRole('button', { name: 'Add expense' }));
    await waitFor(() => {
      expect(description).toHaveAttribute('aria-invalid', 'true');
    });
    await expectNoAxeViolations();
  });

  it('group balances with suggested payments', async () => {
    serveMoneyGroup();
    server.use(
      http.get(`${API}/groups/:id/balances`, () =>
        HttpResponse.json(envelope(makeMoneyBalances())),
      ),
      http.get(`${API}/groups/:id/settlement-suggestions`, () =>
        HttpResponse.json(envelope(makeSuggestions())),
      ),
      http.get(`${API}/groups/:id/settlements`, () =>
        HttpResponse.json(envelope([makeSettlement()])),
      ),
    );
    renderRoute(`/groups/${MONEY_GROUP}/balances`, { user: signedIn() });
    await findPageHeading('Balances');
    const suggestions = await screen.findByRole('region', { name: 'Suggested payments' });
    // WCAG 2.5.3: each name starts with the visible label. axe's
    // label-content-name-mismatch needs a real layout, so the e2e run checks it too.
    const buttons = await within(suggestions).findAllByRole('button', {
      name: /^Record this payment: .+ to .+$/,
    });
    for (const button of buttons) expect(button).toHaveTextContent(/^Record this payment$/);
    await expectNoAxeViolations();
  });

  it('communities list', async () => {
    serveCommunityLists();
    renderRoute('/communities', { user: signedIn() });
    await findPageHeading('Communities');
    const mine = screen.getByRole('region', { name: 'Your communities' });
    await within(mine).findByRole('link', { name: 'Frugal Living' });
    const discover = screen.getByRole('region', { name: 'Find communities' });
    await within(discover).findByRole('link', { name: 'Debt Free India' });
    await expectNoAxeViolations();
  });

  it('community page with posts', async () => {
    serveCommunity();
    renderRoute(`/communities/${COMMUNITY_ID}`, { user: signedIn() });
    await findPageHeading('Frugal Living');
    const feed = screen.getByRole('region', { name: 'Posts' });
    await within(feed).findByRole('link', { name: 'How I paid off my bike loan' });
    await expectNoAxeViolations();
  });

  it('notifications', async () => {
    serveUnreadCount(2);
    server.use(
      http.get(`${API}/notifications`, () =>
        HttpResponse.json(
          notificationPage([
            makeNotification(),
            securityNotification(),
            supportReplyNotification(),
          ]),
        ),
      ),
    );
    renderRoute('/notifications', { user: signedIn() });
    await findPageHeading('Notifications');
    await within(screen.getByRole('main')).findByRole('link', {
      name: 'Emergency fund reached 50%',
    });
    await expectNoAxeViolations();
  });
});
