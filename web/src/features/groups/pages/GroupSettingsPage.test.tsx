import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import type { GroupDetail, GroupInvitation, JoinRequest } from '@/features/groups/types';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  FRIEND_ID,
  GROUP_ID,
  GROUP_MEMBER_ID,
  LINK_INVITATION_ID,
  LINK_TOKEN,
  ME,
  REQUEST_ID,
  makeGroupDetailFull,
  makeInvitation,
  makeJoinRequest,
  makeLinkInvitation,
  makeMember,
  meeraPerson,
  mePerson,
} from '@/tests/groupsFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import { makeFriend } from '@/tests/sharingFixtures';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

function region(name: string) {
  return screen.getByRole('region', { name });
}

/**
 * Read handlers for the settings page. `state` lets a test change what
 * later reads return (after a write or a conflict).
 */
function serveSettings(
  group: GroupDetail = makeGroupDetailFull(),
  {
    invitations = [] as GroupInvitation[],
    requests = [] as JoinRequest[],
  }: { invitations?: GroupInvitation[]; requests?: JoinRequest[] } = {},
) {
  const state = { group, invitations, requests, invitationQueries: [] as string[] };
  server.use(
    http.get(`${API}/groups/:id`, () => HttpResponse.json(envelope(state.group))),
    http.get(`${API}/groups/:id/invitations`, ({ request }) => {
      state.invitationQueries.push(new URL(request.url).search);
      return HttpResponse.json(envelope(state.invitations));
    }),
    http.get(`${API}/groups/:id/join-requests`, () => HttpResponse.json(envelope(state.requests))),
  );
  return state;
}

async function openSettings(groupId = GROUP_ID, name = 'Group settings') {
  const user = userEvent.setup();
  const result = renderRoute(`/groups/${groupId}/settings`, { user: signedIn() });
  await findPageHeading(name);
  return { user, ...result };
}

describe('GroupSettingsPage: owner', () => {
  it('shows every section an owner can use', async () => {
    serveSettings(makeGroupDetailFull(), { requests: [makeJoinRequest()] });
    await openSettings();
    expect(document.title).toBe('Group settings · Montra');
    expect(screen.getByText('Your role: Owner')).toBeInTheDocument();
    expect(await within(region('Group details')).findByLabelText('Group name')).toHaveValue('Home');
    expect(region('Your notifications')).toBeInTheDocument();
    expect(
      within(region('Members')).getByRole('button', { name: 'Make admin: Meera Rao' }),
    ).toBeInTheDocument();
    expect(region('Invitations')).toBeInTheDocument();
    expect(await within(region('Requests to join')).findByText('Ravi Kumar')).toBeInTheDocument();
    expect(region('Ownership and status')).toBeInTheDocument();
    // The owner transfers ownership before leaving.
    const leave = region('Leave the group');
    expect(within(leave).getByRole('button', { name: 'Leave group' })).toBeDisabled();
    expect(
      within(leave).getByText(
        'As the owner, transfer ownership to another member before you leave.',
      ),
    ).toBeInTheDocument();
  });

  it('sends only the changed settings with the version it edited', async () => {
    let body: unknown = null;
    const state = serveSettings(
      makeGroupDetailFull({ description: 'Our flat', rules: 'Split groceries' }),
    );
    server.use(
      http.patch(`${API}/groups/:id`, async ({ request }) => {
        body = await request.json();
        const updated = makeGroupDetailFull({ name: 'Flat 4B', version: 4 });
        state.group = updated;
        return HttpResponse.json(envelope(updated));
      }),
    );
    const { user } = await openSettings();
    const details = region('Group details');
    const name = await within(details).findByLabelText('Group name');
    await user.clear(name);
    await user.type(name, 'Flat 4B');
    await user.click(within(details).getByLabelText('Simplify debts'));
    await user.click(within(details).getByRole('button', { name: 'Save changes' }));

    expect(await screen.findByText('Group updated')).toBeInTheDocument();
    expect(body).toEqual({ name: 'Flat 4B', simplify_debts: false, version: 3 });
  });

  it('clears a description with an empty string and skips saving when nothing changed', async () => {
    let body: unknown = null;
    let calls = 0;
    const state = serveSettings(makeGroupDetailFull({ description: 'Our flat' }));
    server.use(
      http.patch(`${API}/groups/:id`, async ({ request }) => {
        calls += 1;
        body = await request.json();
        state.group = makeGroupDetailFull({ version: 4 });
        return HttpResponse.json(envelope(state.group));
      }),
    );
    const { user } = await openSettings();
    const details = region('Group details');
    await within(details).findByLabelText('Group name');
    await user.click(within(details).getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('No changes to save')).toBeInTheDocument();
    expect(calls).toBe(0);

    await user.clear(within(details).getByLabelText(/^Description/));
    await user.click(within(details).getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('Group updated')).toBeInTheDocument();
    expect(body).toEqual({ description: '', version: 3 });
  });

  it('lets the owner turn join approval off and explains it', async () => {
    let body: unknown = null;
    const state = serveSettings();
    server.use(
      http.patch(`${API}/groups/:id`, async ({ request }) => {
        body = await request.json();
        state.group = makeGroupDetailFull({ require_join_approval: false, version: 4 });
        return HttpResponse.json(envelope(state.group));
      }),
    );
    const { user } = await openSettings();
    const details = region('Group details');
    const approval = await within(details).findByLabelText('Approve people who join with a link');
    expect(approval).toBeChecked();
    expect(approval).toHaveAccessibleDescription(/People invited by name always join right away\./);
    await user.click(approval);
    await user.click(within(details).getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('Group updated')).toBeInTheDocument();
    expect(body).toEqual({ require_join_approval: false, version: 3 });
  });

  it('reloads the group and keeps the form usable after a version conflict', async () => {
    const state = serveSettings();
    server.use(
      http.patch(`${API}/groups/:id`, () => {
        state.group = makeGroupDetailFull({ name: 'Renamed elsewhere', version: 4 });
        return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
      }),
    );
    const { user } = await openSettings();
    const details = region('Group details');
    const name = await within(details).findByLabelText('Group name');
    await user.clear(name);
    await user.type(name, 'Mine');
    await user.click(within(details).getByRole('button', { name: 'Save changes' }));

    expect(await screen.findByText('This was changed somewhere else')).toBeInTheDocument();
    await waitFor(() => {
      expect(within(region('Group details')).getByLabelText('Group name')).toHaveValue(
        'Renamed elsewhere',
      );
    });
  });

  it('explains that the currency is locked once money was added', async () => {
    serveSettings();
    server.use(
      http.patch(`${API}/groups/:id`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [{ code: 'currency_locked', message: 'The group currency cannot change.' }],
          }),
          { status: 422 },
        ),
      ),
    );
    const { user } = await openSettings();
    const details = region('Group details');
    await user.selectOptions(await within(details).findByLabelText('Group currency'), 'EUR');
    await user.click(within(details).getByRole('button', { name: 'Save changes' }));
    await waitFor(() => {
      expect(within(details).getByLabelText('Group currency')).toHaveAccessibleDescription(
        /The group currency can’t change after expenses, payments or recurring bills were added\./,
      );
    });
  });

  it('creates a one-time invitation link to copy, without keeping the token', async () => {
    let body: unknown = null;
    const state = serveSettings();
    server.use(
      http.post(`${API}/groups/:id/invitations`, async ({ request }) => {
        body = await request.json();
        state.invitations = [makeLinkInvitation({ use_count: 0 })];
        return HttpResponse.json(
          envelope(makeLinkInvitation({ use_count: 0, token: LINK_TOKEN })),
          {
            status: 201,
          },
        );
      }),
    );
    const { user, router } = await openSettings();
    const invitations = region('Invitations');
    expect(await within(invitations).findByText('No active invitations')).toBeInTheDocument();
    await user.selectOptions(within(invitations).getByLabelText('Expires after'), '14');
    await user.selectOptions(within(invitations).getByLabelText('Number of uses'), '5');
    await user.click(within(invitations).getByRole('button', { name: 'Create invitation link' }));

    const link = `http://localhost:5173/groups/join#token=${LINK_TOKEN}`;
    expect(await within(invitations).findByLabelText('Invitation link')).toHaveValue(link);
    expect(body).toEqual({ kind: 'link', expires_in_days: 14, max_uses: 5 });
    expect(within(invitations).getByText(/Montra shows this link only once/)).toBeInTheDocument();

    await user.click(within(invitations).getByRole('button', { name: 'Copy link' }));
    expect(await within(invitations).findByRole('button', { name: 'Copied' })).toBeInTheDocument();
    await expect(navigator.clipboard.readText()).resolves.toBe(link);

    // The list shows the new invitation (and who created it), never its token.
    expect(
      await within(invitations).findByText(/^Used 0 of 5 times · Invited by you · Created/),
    ).toBeInTheDocument();
    expect(router.state.location.hash).toBe('');
    expect(document.title).not.toContain(LINK_TOKEN);

    await user.click(within(invitations).getByRole('button', { name: 'Done' }));
    expect(within(invitations).queryByLabelText('Invitation link')).not.toBeInTheDocument();
    expect(document.body.innerHTML).not.toContain(LINK_TOKEN);
  });

  it('invites by exact username and explains unknown usernames', async () => {
    const bodies: unknown[] = [];
    serveSettings();
    server.use(
      http.post(`${API}/groups/:id/invitations`, async ({ request }) => {
        const body = (await request.json()) as { username?: string };
        bodies.push(body);
        if (body.username === 'nobody') {
          return HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 });
        }
        return HttpResponse.json(envelope(makeInvitation({ invitee_user_id: FRIEND_ID })), {
          status: 201,
        });
      }),
    );
    const { user } = await openSettings();
    const invitations = region('Invitations');
    await user.click(await within(invitations).findByRole('radio', { name: 'By username' }));
    const field = within(invitations).getByLabelText('Username');
    await user.type(field, '@nobody');
    await user.click(within(invitations).getByRole('button', { name: 'Send invitation' }));
    await waitFor(() => {
      expect(field).toHaveAccessibleDescription(/No one with that username can be invited/);
    });

    await user.clear(field);
    await user.type(field, 'Ravi');
    await user.click(within(invitations).getByRole('button', { name: 'Send invitation' }));
    expect(
      await screen.findByText('Invitation sent. They’ll join when they accept.'),
    ).toBeInTheDocument();
    expect(bodies).toEqual([
      { kind: 'username', expires_in_days: 7, username: 'nobody' },
      { kind: 'username', expires_in_days: 7, username: 'ravi' },
    ]);
  });

  it('cancels an invitation after confirming', async () => {
    let revoked = '';
    const state = serveSettings(makeGroupDetailFull(), { invitations: [makeLinkInvitation()] });
    server.use(
      http.delete(`${API}/groups/:id/invitations/:invitationId`, ({ params }) => {
        revoked = String(params.invitationId);
        state.invitations = [];
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const { user } = await openSettings();
    const invitations = region('Invitations');
    expect(
      await within(invitations).findByText(/^Used 2 of 5 times · Invited by you · Created/),
    ).toBeInTheDocument();
    await user.click(
      within(invitations).getByRole('button', { name: /^Cancel: Invitation link, Created/ }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Cancel this invitation?' });
    expect(dialog).toHaveTextContent('The link stops working right away.');
    await user.click(within(dialog).getByRole('button', { name: 'Cancel invitation' }));

    expect(await screen.findByText('Invitation cancelled')).toBeInTheDocument();
    expect(revoked).toBe(LINK_INVITATION_ID);
    expect(await within(invitations).findByText('No active invitations')).toBeInTheDocument();
  });

  it('shows who invited whom', async () => {
    serveSettings(makeGroupDetailFull(), {
      invitations: [
        makeInvitation({
          invitee_user_id: FRIEND_ID,
          invitee: { user_id: FRIEND_ID, display_name: 'Ravi Kumar', username: 'ravi' },
          invited_by: mePerson(),
        }),
        makeLinkInvitation({ invited_by: meeraPerson() }),
      ],
    });
    await openSettings();
    const invitations = region('Invitations');
    expect(await within(invitations).findByText('For Ravi Kumar (@ravi)')).toBeInTheDocument();
    expect(within(invitations).getByText(/^Invited by you · Created/)).toBeInTheDocument();
    expect(
      within(invitations).getByText(
        /^Used 2 of 5 times · Invited by Meera Rao \(@meera\) · Created/,
      ),
    ).toBeInTheDocument();
  });

  it('invites a friend by user ID, even one who cannot be found by username', async () => {
    const bodies: unknown[] = [];
    testBackend.people = [
      makeFriend(),
      makeFriend({
        user_id: '0f0f0f0f-1111-4111-8111-000000000001',
        display_name: 'No Handle',
        username: undefined,
      }),
      makeFriend({ user_id: GROUP_MEMBER_ID, display_name: 'Meera Rao', username: 'meera' }),
    ];
    serveSettings();
    server.use(
      http.post(`${API}/groups/:id/invitations`, async ({ request }) => {
        bodies.push(await request.json());
        return HttpResponse.json(envelope(makeInvitation({ invitee_user_id: FRIEND_ID })), {
          status: 201,
        });
      }),
    );
    const { user } = await openSettings();
    const invitations = region('Invitations');
    await user.click(await within(invitations).findByRole('radio', { name: 'A friend' }));
    const select = await within(invitations).findByLabelText('Friend');
    // Members already in the group are not offered; friends without a username are.
    expect(
      within(select)
        .getAllByRole('option')
        .map((option) => option.textContent),
    ).toEqual(['Choose a friend', 'No Handle', 'Ravi Kumar (@ravi)']);
    await user.click(within(invitations).getByRole('button', { name: 'Send invitation' }));
    expect(select).toHaveAccessibleDescription(/Choose a friend to invite\./);
    expect(bodies).toEqual([]);

    await user.selectOptions(select, '0f0f0f0f-1111-4111-8111-000000000001');
    await user.click(within(invitations).getByRole('button', { name: 'Send invitation' }));
    expect(
      await screen.findByText('Invitation sent. They’ll join when they accept.'),
    ).toBeInTheDocument();
    expect(bodies).toEqual([
      { kind: 'username', expires_in_days: 7, user_id: '0f0f0f0f-1111-4111-8111-000000000001' },
    ]);
  });

  it('explains a coded conflict when inviting someone who is already a member', async () => {
    serveSettings();
    server.use(
      http.post(`${API}/groups/:id/invitations`, () =>
        HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            message: 'This person is already a member.',
            details: [{ code: 'already_member', message: 'This person is already a member.' }],
          }),
          { status: 409 },
        ),
      ),
    );
    const { user } = await openSettings();
    const invitations = region('Invitations');
    await user.click(await within(invitations).findByRole('radio', { name: 'By username' }));
    await user.type(within(invitations).getByLabelText('Username'), 'meera');
    await user.click(within(invitations).getByRole('button', { name: 'Send invitation' }));
    expect(await within(invitations).findByRole('alert')).toHaveTextContent(
      'This person is already a member.',
    );
  });

  it('lists past invitations on request', async () => {
    const state = serveSettings(makeGroupDetailFull(), {
      invitations: [makeLinkInvitation({ status: 'revoked' })],
    });
    const { user } = await openSettings();
    const invitations = region('Invitations');
    await user.click(await within(invitations).findByLabelText('Show past invitations'));
    expect(await within(invitations).findByText('Cancelled')).toBeInTheDocument();
    expect(state.invitationQueries).toContain('?include_inactive=true');
  });

  it('changes a member’s role', async () => {
    let body: unknown = null;
    const state = serveSettings();
    server.use(
      http.patch(`${API}/groups/:id/members/:userId`, async ({ request, params }) => {
        expect(params.userId).toBe(GROUP_MEMBER_ID);
        body = await request.json();
        state.group = makeGroupDetailFull({
          members: [makeGroupDetailFull().members[0]!, makeMember({ role: 'admin' })],
        });
        return HttpResponse.json(envelope(state.group));
      }),
    );
    const { user } = await openSettings();
    const members = region('Members');
    await user.click(within(members).getByRole('button', { name: 'Make admin: Meera Rao' }));
    expect(await screen.findByText('Meera Rao is now an admin')).toBeInTheDocument();
    expect(body).toEqual({ role: 'admin' });
    expect(
      await within(members).findByRole('button', {
        name: 'Make member: Meera Rao',
      }),
    ).toBeInTheDocument();
  });

  it('shows the API’s permission answer for a role change and reloads the group', async () => {
    let reads = 0;
    server.use(
      http.get(`${API}/groups/:id`, () => {
        reads += 1;
        // Someone else made the user a plain member in the meantime.
        return HttpResponse.json(
          envelope(
            reads === 1
              ? makeGroupDetailFull({ my_role: 'admin' })
              : makeGroupDetailFull({ my_role: 'member' }),
          ),
        );
      }),
      http.get(`${API}/groups/:id/invitations`, () => HttpResponse.json(envelope([]))),
      http.get(`${API}/groups/:id/join-requests`, () => HttpResponse.json(envelope([]))),
      http.patch(`${API}/groups/:id/members/:userId`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    const { user } = await openSettings();
    await user.click(
      within(region('Members')).getByRole('button', { name: 'Make admin: Meera Rao' }),
    );
    expect(await screen.findByText('We couldn’t change the role')).toBeInTheDocument();
    expect(
      screen.getByText(
        'You don’t have permission to do that in this group. Your role may have changed.',
      ),
    ).toBeInTheDocument();
    await waitFor(() => {
      expect(
        within(region('Members')).queryByRole('button', { name: 'Make admin: Meera Rao' }),
      ).not.toBeInTheDocument();
    });
  });

  it('removes a member after explaining that an open balance stays in the group', async () => {
    let removed = '';
    serveSettings();
    server.use(
      http.delete(`${API}/groups/:id/members/:userId`, ({ params }) => {
        removed = String(params.userId);
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const { user } = await openSettings();
    await user.click(within(region('Members')).getByRole('button', { name: 'Remove: Meera Rao' }));
    const dialog = await screen.findByRole('dialog', { name: 'Remove Meera Rao?' });
    // Removal is allowed with an open balance; the dialog says what happens to it.
    expect(dialog).toHaveTextContent('Their past expenses stay in the balances');
    expect(dialog).toHaveTextContent(
      'their balance stays in the balances and suggested payments. Anyone can record a settlement with them, and an admin can confirm a payment made to them on their behalf.',
    );
    await user.click(within(dialog).getByRole('button', { name: 'Remove from group' }));
    expect(await screen.findByText('Meera Rao was removed from the group')).toBeInTheDocument();
    expect(removed).toBe(GROUP_MEMBER_ID);
  });

  it('adds a friend by user ID, including friends without a username', async () => {
    let body: unknown = null;
    testBackend.people = [
      makeFriend(),
      makeFriend({
        user_id: '0f0f0f0f-1111-4111-8111-000000000001',
        display_name: 'No Handle',
        username: undefined,
      }),
      makeFriend({ user_id: GROUP_MEMBER_ID, display_name: 'Meera Rao', username: 'meera' }),
    ];
    serveSettings();
    server.use(
      http.post(`${API}/groups/:id/members`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(envelope(makeInvitation({ invitee_user_id: FRIEND_ID })), {
          status: 201,
        });
      }),
    );
    const { user } = await openSettings();
    await user.click(within(region('Members')).getByRole('button', { name: 'Add a friend' }));
    const dialog = await screen.findByRole('dialog', { name: 'Add a friend to the group' });
    const select = await within(dialog).findByLabelText('Friend');
    // Members already in the group are not offered; friends without a username are.
    expect(
      within(select)
        .getAllByRole('option')
        .map((option) => option.textContent),
    ).toEqual(['Choose a friend', 'No Handle', 'Ravi Kumar (@ravi)']);
    expect(select).toHaveAccessibleDescription(/including friends who can’t be found by username/);
    await user.selectOptions(select, FRIEND_ID);
    await user.click(within(dialog).getByRole('button', { name: 'Send invitation' }));
    expect(
      await screen.findByText(
        'Invitation sent to Ravi Kumar (@ravi). They’ll join when they accept.',
      ),
    ).toBeInTheDocument();
    expect(body).toEqual({ user_id: FRIEND_ID });
  });

  it('approves and declines join requests', async () => {
    const decided: string[] = [];
    const state = serveSettings(makeGroupDetailFull(), {
      requests: [
        makeJoinRequest(),
        makeJoinRequest({
          id: 'f4f4f4f4-6666-4666-8666-000000000002',
          display_name: 'Kiran Das',
          message: undefined,
          invitation_id: LINK_INVITATION_ID,
        }),
      ],
    });
    server.use(
      http.post(`${API}/groups/:id/join-requests/:requestId/:action`, ({ params }) => {
        decided.push(`${String(params.action)}:${String(params.requestId)}`);
        state.requests = state.requests.filter((request) => request.id !== params.requestId);
        return HttpResponse.json(envelope(state.group));
      }),
    );
    const { user } = await openSettings();
    const requests = region('Requests to join');
    expect(
      await within(requests).findByText('Hi, it’s Ravi from the flat downstairs'),
    ).toBeInTheDocument();
    // A request made by accepting a link in a group that requires approval.
    expect(within(requests).getByText(/Came through an invitation link/)).toBeInTheDocument();
    await user.click(within(requests).getByRole('button', { name: 'Approve: Ravi Kumar' }));
    expect(await screen.findByText('Ravi Kumar joined the group')).toBeInTheDocument();
    await user.click(within(requests).getByRole('button', { name: 'Decline: Kiran Das' }));
    expect(await screen.findByText('Request from Kiran Das declined')).toBeInTheDocument();
    expect(decided).toEqual([
      `approve:${REQUEST_ID}`,
      'decline:f4f4f4f4-6666-4666-8666-000000000002',
    ]);
    expect(await within(requests).findByText('No requests waiting')).toBeInTheDocument();
  });

  it('transfers ownership after confirming', async () => {
    let body: unknown = null;
    const state = serveSettings();
    server.use(
      http.post(`${API}/groups/:id/transfer-ownership`, async ({ request }) => {
        body = await request.json();
        state.group = makeGroupDetailFull(
          {
            my_role: 'admin',
            members: [makeGroupDetailFull().members[0]!, makeMember({ role: 'owner' })],
          },
          { role: 'admin' },
        );
        state.group.members[0] = { ...state.group.members[0]!, role: 'admin' };
        return HttpResponse.json(envelope(state.group));
      }),
    );
    const { user } = await openSettings();
    const owner = region('Ownership and status');
    await user.click(within(owner).getByRole('button', { name: 'Transfer ownership' }));
    expect(within(owner).getByLabelText('New owner')).toHaveAccessibleDescription(
      /Choose who should own the group\./,
    );
    await user.selectOptions(within(owner).getByLabelText('New owner'), GROUP_MEMBER_ID);
    await user.click(within(owner).getByRole('button', { name: 'Transfer ownership' }));
    const dialog = await screen.findByRole('dialog', { name: 'Make Meera Rao the owner?' });
    expect(dialog).toHaveTextContent('You’ll become an admin');
    await user.click(within(dialog).getByRole('button', { name: 'Transfer ownership' }));

    expect(await screen.findByText('Meera Rao is now the owner')).toBeInTheDocument();
    expect(body).toEqual({ user_id: GROUP_MEMBER_ID });
    // Now an admin: the owner-only section is gone and leaving is possible.
    await waitFor(() => {
      expect(
        screen.queryByRole('region', { name: 'Ownership and status' }),
      ).not.toBeInTheDocument();
    });
    expect(screen.getByText('Your role: Admin')).toBeInTheDocument();
    expect(
      within(region('Leave the group')).getByRole('button', { name: 'Leave group' }),
    ).toBeEnabled();
  });

  it('archives after confirming, then restores', async () => {
    const calls: string[] = [];
    const state = serveSettings();
    server.use(
      http.post(`${API}/groups/:id/archive`, () => {
        calls.push('archive');
        state.group = makeGroupDetailFull({ status: 'archived', version: 4 });
        return HttpResponse.json(envelope(state.group));
      }),
      http.post(`${API}/groups/:id/restore`, () => {
        calls.push('restore');
        state.group = makeGroupDetailFull({ status: 'active', version: 5 });
        return HttpResponse.json(envelope(state.group));
      }),
    );
    const { user } = await openSettings();
    await user.click(
      within(region('Ownership and status')).getByRole('button', { name: 'Archive group' }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Archive Home?' });
    expect(dialog).toHaveTextContent('Its recurring bills are paused');
    await user.click(within(dialog).getByRole('button', { name: 'Archive group' }));
    expect(await screen.findByText('Group archived')).toBeInTheDocument();

    // Archived: read-only details and a restore action.
    expect(await screen.findByText('This group is archived')).toBeInTheDocument();
    expect(
      within(region('Group details')).getByText(
        'The group is archived. Restore it to change these settings.',
      ),
    ).toBeInTheDocument();
    expect(
      within(region('Your notifications')).getByRole('radio', { name: /^Important only/ }),
    ).toBeDisabled();
    await user.click(
      within(region('Ownership and status')).getByRole('button', { name: 'Restore group' }),
    );
    expect(await screen.findByText('Group restored')).toBeInTheDocument();
    expect(calls).toEqual(['archive', 'restore']);
    expect(await within(region('Group details')).findByLabelText('Group name')).toBeInTheDocument();
  });

  it('deletes the group after confirming and returns to the list', async () => {
    const seen: string[] = [];
    serveSettings();
    server.use(
      http.delete(`${API}/groups/:id`, ({ request }) => {
        seen.push(new URL(request.url).search);
        return HttpResponse.json(envelope(makeGroupDetailFull({ status: 'deleted' })));
      }),
      http.get(`${API}/group-invitations`, () => HttpResponse.json(envelope([]))),
    );
    const { user, router } = await openSettings();
    await user.click(
      within(region('Ownership and status')).getByRole('button', { name: 'Delete group' }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Delete Home?' });
    expect(dialog).toHaveTextContent('this can’t be undone');
    await user.click(within(dialog).getByRole('button', { name: 'Delete group' }));
    await waitFor(() => {
      expect(router.state.location.pathname).toBe('/groups');
    });
    expect(seen).toEqual(['?confirm=true']);
    expect(await screen.findByText('Group deleted')).toBeInTheDocument();
  });

  it('explains that open balances block deleting', async () => {
    serveSettings();
    server.use(
      http.delete(`${API}/groups/:id`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              { code: 'balances_open', message: 'Settle all balances before deleting the group.' },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const { user } = await openSettings();
    const owner = region('Ownership and status');
    await user.click(within(owner).getByRole('button', { name: 'Delete group' }));
    const dialog = await screen.findByRole('dialog', { name: 'Delete Home?' });
    await user.click(within(dialog).getByRole('button', { name: 'Delete group' }));
    expect(await within(owner).findByText('The group can’t be deleted yet')).toBeInTheDocument();
    expect(
      within(owner).getByText('Settle all balances before deleting the group.'),
    ).toBeInTheDocument();
    expect(within(owner).getByRole('link', { name: 'See balances and settle up' })).toHaveAttribute(
      'href',
      `/groups/${GROUP_ID}/balances`,
    );
  });

  it('saves your notification choice', async () => {
    let body: unknown = null;
    const state = serveSettings();
    server.use(
      http.patch(`${API}/groups/:id/members/:userId`, async ({ request, params }) => {
        expect(params.userId).toBe(ME);
        body = await request.json();
        state.group = makeGroupDetailFull({}, { notification_level: 'important' });
        return HttpResponse.json(envelope(state.group));
      }),
    );
    const { user } = await openSettings();
    const notifications = region('Your notifications');
    expect(within(notifications).getByRole('radio', { name: /^Everything/ })).toBeChecked();
    await user.click(within(notifications).getByRole('radio', { name: /^Important only/ }));
    await user.click(
      within(notifications).getByRole('button', { name: 'Save notification choice' }),
    );
    expect(await screen.findByText('Notification choice saved')).toBeInTheDocument();
    expect(body).toEqual({ notification_level: 'important' });
  });
});

describe('GroupSettingsPage: members and admins', () => {
  it('gives members a read-only view with their own controls', async () => {
    serveSettings(makeGroupDetailFull({ my_role: 'member', allow_member_invites: false }));
    await openSettings();
    expect(screen.getByText('Your role: Member')).toBeInTheDocument();
    const details = region('Group details');
    expect(
      within(details).getByText('Only the owner and admins can change these settings.'),
    ).toBeInTheDocument();
    expect(within(details).queryByLabelText('Group name')).not.toBeInTheDocument();
    expect(within(details).getByText('Household')).toBeInTheDocument();

    const members = region('Members');
    expect(within(members).queryByRole('button', { name: /Make/ })).not.toBeInTheDocument();
    expect(within(members).queryByRole('button', { name: /Remove/ })).not.toBeInTheDocument();
    expect(within(members).queryByRole('button', { name: 'Add a friend' })).not.toBeInTheDocument();
    expect(
      within(region('Invitations')).getByText(
        'In this group, only the owner and admins can invite people.',
      ),
    ).toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Requests to join' })).not.toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Ownership and status' })).not.toBeInTheDocument();
    expect(region('Your notifications')).toBeInTheDocument();
    expect(
      within(region('Leave the group')).getByRole('button', { name: 'Leave group' }),
    ).toBeEnabled();
  });

  it('lets admins manage members but not other admins or the owner', async () => {
    serveSettings(
      makeGroupDetailFull(
        {
          my_role: 'admin',
          members: [
            makeMember({
              user_id: FRIEND_ID,
              display_name: 'Ravi Kumar',
              username: 'ravi',
              role: 'owner',
            }),
            makeGroupDetailFull().members[0]!,
            makeMember(),
            makeMember({
              user_id: '0f0f0f0f-1111-4111-8111-000000000002',
              display_name: 'Dev Admin',
              username: 'dev',
              role: 'admin',
            }),
          ],
        },
        { role: 'admin' },
      ),
    );
    await openSettings();
    const members = region('Members');
    expect(within(members).getByRole('button', { name: 'Remove: Meera Rao' })).toBeInTheDocument();
    expect(
      within(members).getByRole('button', { name: 'Make admin: Meera Rao' }),
    ).toBeInTheDocument();
    expect(within(members).queryByRole('button', { name: /Ravi Kumar/ })).not.toBeInTheDocument();
    expect(within(members).queryByRole('button', { name: /Dev Admin/ })).not.toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Ownership and status' })).not.toBeInTheDocument();
  });

  it('leaves the group after confirming', async () => {
    let removed = '';
    serveSettings(makeGroupDetailFull({ my_role: 'member' }, { role: 'member' }));
    server.use(
      http.delete(`${API}/groups/:id/members/:userId`, ({ params }) => {
        removed = String(params.userId);
        return HttpResponse.json(envelope({ ok: true }));
      }),
      http.get(`${API}/group-invitations`, () => HttpResponse.json(envelope([]))),
    );
    const { user, router } = await openSettings();
    await user.click(
      within(region('Leave the group')).getByRole('button', { name: 'Leave group' }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Leave Home?' });
    expect(dialog).toHaveTextContent('someone will need to invite you again');
    await user.click(within(dialog).getByRole('button', { name: 'Leave group' }));
    await waitFor(() => {
      expect(router.state.location.pathname).toBe('/groups');
    });
    expect(removed).toBe(ME);
    expect(await screen.findByText('You left Home')).toBeInTheDocument();
  });

  it('explains that an open balance blocks leaving', async () => {
    serveSettings(makeGroupDetailFull({ my_role: 'member' }, { role: 'member' }));
    server.use(
      http.delete(`${API}/groups/:id/members/:userId`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              { code: 'balance_open', message: 'Settle your balance before leaving the group.' },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const { user } = await openSettings();
    const leave = region('Leave the group');
    await user.click(within(leave).getByRole('button', { name: 'Leave group' }));
    const dialog = await screen.findByRole('dialog', { name: 'Leave Home?' });
    await user.click(within(dialog).getByRole('button', { name: 'Leave group' }));
    expect(await within(leave).findByText('You can’t leave yet')).toBeInTheDocument();
    expect(
      within(leave).getByText('Settle your balance before leaving the group.'),
    ).toBeInTheDocument();
    expect(within(leave).getByRole('link', { name: 'See balances and settle up' })).toHaveAttribute(
      'href',
      `/groups/${GROUP_ID}/balances`,
    );
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  it('explains that the owner must transfer ownership first', async () => {
    let reads = 0;
    server.use(
      http.get(`${API}/groups/:id`, () => {
        reads += 1;
        // Ownership was transferred to the user in the meantime.
        return HttpResponse.json(
          envelope(
            reads === 1
              ? makeGroupDetailFull({ my_role: 'admin' }, { role: 'admin' })
              : makeGroupDetailFull({ my_role: 'owner' }),
          ),
        );
      }),
      http.get(`${API}/groups/:id/invitations`, () => HttpResponse.json(envelope([]))),
      http.get(`${API}/groups/:id/join-requests`, () => HttpResponse.json(envelope([]))),
      http.delete(`${API}/groups/:id/members/:userId`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                code: 'transfer_ownership_first',
                message: 'Transfer ownership before the owner leaves.',
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const { user } = await openSettings();
    const leave = region('Leave the group');
    await user.click(within(leave).getByRole('button', { name: 'Leave group' }));
    const dialog = await screen.findByRole('dialog', { name: 'Leave Home?' });
    await user.click(within(dialog).getByRole('button', { name: 'Leave group' }));
    expect(
      await within(leave).findByText('Transfer ownership to another member before you leave.'),
    ).toBeInTheDocument();
    expect(await screen.findByText('Your role: Owner')).toBeInTheDocument();
  });
});

describe('GroupSettingsPage: states', () => {
  it('explains a group that is not available', async () => {
    server.use(
      http.get(`${API}/groups/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    await openSettings();
    expect(await screen.findByText('This group isn’t available')).toBeInTheDocument();
  });

  it('shows a recoverable error', async () => {
    server.use(
      http.get(`${API}/groups/:id`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-set' }), {
          status: 500,
        }),
      ),
    );
    await openSettings();
    expect(await screen.findByText('We couldn’t load this group')).toBeInTheDocument();
    expect(screen.getByText('req-set')).toBeInTheDocument();
  });

  it('shows a permission message when the API refuses', async () => {
    server.use(
      http.get(`${API}/groups/:id`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    await openSettings();
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });

  it('shows empty invitation and request lists', async () => {
    serveSettings();
    await openSettings();
    expect(
      await within(region('Invitations')).findByText('No active invitations'),
    ).toBeInTheDocument();
    expect(
      await within(region('Requests to join')).findByText('No requests waiting'),
    ).toBeInTheDocument();
  });
});
