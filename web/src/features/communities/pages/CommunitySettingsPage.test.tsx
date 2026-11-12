import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import type { CommunityInvitation, CommunityMember } from '@/features/communities/types';
import {
  COMMUNITY_ID,
  COMMUNITY_LINK_TOKEN,
  MEMBER_ID,
  PENDING_ID,
  conflict,
  makeCommunity,
  makeCommunityInvitation,
  makeCommunityMember,
  makeInviter,
  makeMemberList,
  notFound,
  serveCommunity,
} from '@/tests/communitiesFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const ME = makeUser().id;

function region(name: string) {
  return screen.getByRole('region', { name });
}

/** The signed-in user as the owner (or another role) in the members list. */
function membersWithMe(role: CommunityMember['role'] = 'owner'): CommunityMember[] {
  return [
    makeCommunityMember({ user_id: ME, display_name: 'Asha Rao', username: 'asha', role }),
    ...makeMemberList().filter((member) => member.role !== 'owner' || role !== 'owner'),
  ];
}

const requester = makeCommunityMember({
  user_id: PENDING_ID,
  display_name: 'Ravi Kumar',
  username: 'ravi',
  status: 'pending',
  joined_at: '2026-11-04T08:00:00Z',
});

interface SettingsState extends ReturnType<typeof serveCommunity> {
  /** GET /communities/{id}/invitations; the queries received (`?include_inactive=true` or ''). */
  invitations: CommunityInvitation[];
  invitationQueries: string[];
}

function serveSettings(
  role: 'owner' | 'moderator' | 'member' = 'owner',
  pending = [requester],
  invitations: CommunityInvitation[] = [],
): SettingsState {
  const list = membersWithMe(role === 'member' ? 'member' : role);
  // The handlers read the same object serveCommunity returned: extend it, never copy it.
  const state = serveCommunity(makeCommunity({ my_role: role, visibility: 'private' }), {
    members: { active: list, pending, '': [...list, ...pending] },
    posts: [],
  }) as SettingsState;
  state.invitations = invitations;
  state.invitationQueries = [];
  server.use(
    http.get(`${API}/communities/:id/invitations`, ({ request }) => {
      const url = new URL(request.url);
      state.invitationQueries.push(url.search);
      const all = url.searchParams.get('include_inactive') === 'true';
      return HttpResponse.json(
        envelope(state.invitations.filter((item) => all || item.status === 'active')),
      );
    }),
  );
  return state;
}

async function openSettings(heading = 'Community settings') {
  const user = userEvent.setup();
  const result = renderRoute(`/communities/${COMMUNITY_ID}/settings`, {
    user: makeUser({ onboarding_completed: true }),
  });
  await findPageHeading(heading);
  return { user, ...result };
}

describe('CommunitySettingsPage', () => {
  it('is only for the owner and moderators', async () => {
    serveSettings('member');
    await openSettings();
    expect(
      screen.getByText('Only the owner and moderators can change this community’s settings.'),
    ).toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Community details' })).not.toBeInTheDocument();
  });

  it('saves only the changed details, with the version, and clears text with an empty string', async () => {
    const bodies: unknown[] = [];
    const state = serveSettings();
    server.use(
      http.patch(`${API}/communities/:id`, async ({ request }) => {
        bodies.push(await request.json());
        state.community = makeCommunity({
          my_role: 'owner',
          visibility: 'public',
          name: 'Frugal Folks',
          description: undefined,
          version: 2,
        });
        return HttpResponse.json(envelope(state.community));
      }),
    );
    const { user } = await openSettings();
    expect(document.title).toBe('Community settings · Montra');
    const details = region('Community details');
    expect(
      within(details).getByText('Web address: frugal-living (it can’t change).'),
    ).toBeInTheDocument();

    // Nothing changed: nothing is sent.
    await user.click(within(details).getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('Nothing to save: no details changed')).toBeInTheDocument();
    expect(bodies).toEqual([]);

    const name = within(details).getByLabelText('Name');
    await user.clear(name);
    await user.type(name, 'Frugal Folks');
    await user.clear(within(details).getByLabelText(/Description/));
    await user.click(within(details).getByRole('radio', { name: /^Public/ }));
    await user.click(within(details).getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('Community updated')).toBeInTheDocument();
    expect(bodies).toEqual([
      { version: 1, name: 'Frugal Folks', description: '', visibility: 'public' },
    ]);
    // The form restarts from the saved community.
    expect(within(details).getByLabelText('Name')).toHaveValue('Frugal Folks');
    expect(within(details).getByLabelText(/Description/)).toHaveValue('');
  });

  it('reloads the community and restarts the form when someone else saved first', async () => {
    let patches = 0;
    const state = serveSettings();
    server.use(
      http.patch(`${API}/communities/:id`, () => {
        patches += 1;
        state.community = makeCommunity({
          my_role: 'owner',
          visibility: 'private',
          name: 'Frugal Friends',
          version: 5,
        });
        return HttpResponse.json(
          errorBody({ code: 'VERSION_CONFLICT', message: 'This record was changed.' }),
          { status: 409 },
        );
      }),
    );
    const { user } = await openSettings();
    const details = region('Community details');
    const name = within(details).getByLabelText('Name');
    await user.clear(name);
    await user.type(name, 'Frugal Folks');
    await user.click(within(details).getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('This was changed somewhere else')).toBeInTheDocument();
    expect(
      screen.getByText(/Someone else saved changes to this community in the meantime\./),
    ).toBeInTheDocument();
    // The latest community is loaded and the form starts again from it.
    await waitFor(() => {
      expect(within(region('Community details')).getByLabelText('Name')).toHaveValue(
        'Frugal Friends',
      );
    });
    expect(patches).toBe(1);
  });

  it('lets moderators edit details but not who can join or roles', async () => {
    serveSettings('moderator');
    await openSettings();
    const details = region('Community details');
    expect(within(details).getByRole('radio', { name: /^Private/ })).toBeDisabled();
    expect(
      within(details).getByText('Only the owner can change who can join.'),
    ).toBeInTheDocument();
    const members = region('Members');
    expect(await within(members).findByText('Meera Rao')).toBeInTheDocument();
    expect(within(members).queryByRole('button', { name: /moderator/ })).not.toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Ownership and status' })).not.toBeInTheDocument();
  });

  it('makes a member a moderator after confirming', async () => {
    let body: unknown = null;
    let target = '';
    serveSettings();
    server.use(
      http.patch(`${API}/communities/:id/members/:userId`, async ({ request, params }) => {
        body = await request.json();
        target = String(params.userId);
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const { user } = await openSettings();
    const members = region('Members');
    await user.click(
      await within(members).findByRole('button', { name: 'Make Meera Rao a moderator' }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Make Meera Rao a moderator?' });
    expect(
      within(dialog).getByText(/Their actions are recorded in the moderation log\./),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Make moderator' }));
    expect(await screen.findByText('Meera Rao is now a moderator')).toBeInTheDocument();
    expect(body).toEqual({ role: 'moderator' });
    expect(target).toBe(MEMBER_ID);
  });

  it('approves and declines join requests', async () => {
    const decisions: string[] = [];
    const state = serveSettings('owner', [
      requester,
      makeCommunityMember({
        user_id: 'd1d1d1d1-2222-4222-8222-000000000009',
        display_name: 'Kiran Das',
        username: 'kiran',
        status: 'pending',
      }),
    ]);
    server.use(
      http.post(`${API}/communities/:id/members/:userId/approve`, ({ params }) => {
        decisions.push(`approve:${String(params.userId)}`);
        state.members.pending = state.members.pending!.filter(
          (member) => member.user_id !== params.userId,
        );
        return HttpResponse.json(envelope({ ok: true }));
      }),
      http.post(`${API}/communities/:id/members/:userId/reject`, ({ params }) => {
        decisions.push(`reject:${String(params.userId)}`);
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const { user } = await openSettings();
    const requests = region('Requests to join');
    await user.click(await within(requests).findByRole('button', { name: 'Approve Ravi Kumar' }));
    expect(await screen.findByText('Ravi Kumar joined the community')).toBeInTheDocument();
    await user.click(within(requests).getByRole('button', { name: 'Decline Kiran Das' }));
    expect(await screen.findByText('Declined Kiran Das’s request')).toBeInTheDocument();
    expect(decisions).toEqual([
      `approve:${PENDING_ID}`,
      'reject:d1d1d1d1-2222-4222-8222-000000000009',
    ]);
  });

  it('shows an empty request list', async () => {
    serveSettings('owner', []);
    await openSettings();
    expect(
      await within(region('Requests to join')).findByText('No requests waiting'),
    ).toBeInTheDocument();
  });

  it('creates a one-time invitation link to copy', async () => {
    let body: unknown = null;
    serveSettings();
    server.use(
      http.post(`${API}/communities/:id/invitations`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(
          envelope(
            makeCommunityInvitation({
              community_id: COMMUNITY_ID,
              kind: 'link',
              invitee: undefined,
              invitee_user_id: undefined,
              token: COMMUNITY_LINK_TOKEN,
              expires_at: '2026-11-19T09:00:00Z',
            }),
          ),
          { status: 201 },
        );
      }),
    );
    const { user } = await openSettings();
    const invite = region('Invite people');
    await user.selectOptions(within(invite).getByLabelText('Expires after'), '14');
    await user.click(within(invite).getByRole('button', { name: 'Create invitation link' }));

    const link = `http://localhost:5173/communities/join#token=${COMMUNITY_LINK_TOKEN}`;
    expect(await within(invite).findByLabelText('Invitation link')).toHaveValue(link);
    expect(body).toEqual({ expires_in_days: 14 });
    expect(within(invite).getByText(/Montra shows this link only once/)).toBeInTheDocument();
    expect(within(invite).getByRole('button', { name: 'Copy link' })).toBeInTheDocument();
    // The page never puts the token in its own address.
    expect(window.location.href).not.toContain(COMMUNITY_LINK_TOKEN);

    await user.click(within(invite).getByRole('button', { name: 'Done' }));
    expect(
      within(invite).queryByRole('textbox', { name: 'Invitation link' }),
    ).not.toBeInTheDocument();
    expect(screen.queryByDisplayValue(link)).not.toBeInTheDocument();
  });

  it('shows the join link the API sends with a new invitation link', async () => {
    const shareUrl = `https://app.montra.example/communities/join#token=${COMMUNITY_LINK_TOKEN}`;
    serveSettings();
    server.use(
      http.post(`${API}/communities/:id/invitations`, () =>
        HttpResponse.json(
          envelope(
            makeCommunityInvitation({
              community_id: COMMUNITY_ID,
              kind: 'link',
              invitee: undefined,
              invitee_user_id: undefined,
              token: COMMUNITY_LINK_TOKEN,
              share_url: shareUrl,
              expires_at: '2026-11-19T09:00:00Z',
            }),
          ),
          { status: 201 },
        ),
      ),
    );
    const { user } = await openSettings();
    const invite = region('Invite people');
    await user.click(within(invite).getByRole('button', { name: 'Create invitation link' }));
    expect(await within(invite).findByLabelText('Invitation link')).toHaveValue(shareUrl);
  });

  it('invites by username', async () => {
    const bodies: unknown[] = [];
    let calls = 0;
    serveSettings();
    server.use(
      http.post(`${API}/communities/:id/invitations`, async ({ request }) => {
        bodies.push(await request.json());
        calls += 1;
        if (calls === 1) return notFound('user');
        return HttpResponse.json(
          envelope(
            makeCommunityInvitation({ community_id: COMMUNITY_ID, invitee_user_id: MEMBER_ID }),
          ),
          { status: 201 },
        );
      }),
    );
    const { user } = await openSettings();
    const invite = region('Invite people');
    await user.click(within(invite).getByRole('radio', { name: 'By username' }));
    await user.type(within(invite).getByLabelText('Username'), 'no way');
    await user.click(within(invite).getByRole('button', { name: 'Send invitation' }));
    expect(within(invite).getByLabelText('Username')).toHaveAccessibleDescription(
      /Usernames have 3 to 30 lowercase letters/,
    );
    await user.clear(within(invite).getByLabelText('Username'));
    await user.type(within(invite).getByLabelText('Username'), '@Ghost');
    await user.click(within(invite).getByRole('button', { name: 'Send invitation' }));
    await waitFor(() => {
      expect(within(invite).getByLabelText('Username')).toHaveAccessibleDescription(
        /We couldn’t find anyone with that username/,
      );
    });
    await user.clear(within(invite).getByLabelText('Username'));
    await user.type(within(invite).getByLabelText('Username'), 'ravi');
    await user.click(within(invite).getByRole('button', { name: 'Send invitation' }));
    expect(await screen.findByText('Invitation sent to @ravi')).toBeInTheDocument();
    expect(bodies).toEqual([
      { expires_in_days: 7, username: 'ghost' },
      { expires_in_days: 7, username: 'ravi' },
    ]);
  });

  it('lists the invitations sent, including inactive ones on request, and withdraws one', async () => {
    const revoked: string[] = [];
    let revokes = 0;
    const state = serveSettings(
      'owner',
      [requester],
      [
        makeCommunityInvitation({
          id: 'b5b5b5b5-6666-4666-8666-000000000011',
          community_id: COMMUNITY_ID,
          invitee: { user_id: PENDING_ID, display_name: 'Ravi Kumar', username: 'ravi' },
          invited_by: makeInviter({ user_id: ME, display_name: 'Asha Rao', username: 'asha' }),
          created_at: '2026-11-04T09:00:00Z',
        }),
        makeCommunityInvitation({
          id: 'b5b5b5b5-6666-4666-8666-000000000012',
          community_id: COMMUNITY_ID,
          kind: 'link',
          invitee: undefined,
          invitee_user_id: undefined,
          created_at: '2026-11-03T09:00:00Z',
        }),
        makeCommunityInvitation({
          id: 'b5b5b5b5-6666-4666-8666-000000000013',
          community_id: COMMUNITY_ID,
          status: 'declined',
          invitee: { user_id: MEMBER_ID, display_name: 'Meera Rao', username: 'meera' },
          created_at: '2026-11-02T09:00:00Z',
        }),
      ],
    );
    server.use(
      http.delete(`${API}/communities/:id/invitations/:invitationId`, ({ params }) => {
        revokes += 1;
        revoked.push(String(params.invitationId));
        if (revokes === 1) {
          state.invitations = state.invitations.map((item) =>
            item.id === params.invitationId ? { ...item, status: 'revoked' } : item,
          );
          return HttpResponse.json(envelope({ ok: true }));
        }
        return conflict('invitation_inactive', 'This invitation is no longer active.', {
          status: 'used',
        });
      }),
    );
    const { user } = await openSettings();
    const invite = region('Invite people');
    const sent = await within(invite).findByRole('heading', { name: 'Invitations sent' });
    expect(sent).toBeInTheDocument();
    expect(within(invite).getByText('Ravi Kumar')).toBeInTheDocument();
    expect(within(invite).getByText(/Sent by you · Created /)).toBeInTheDocument();
    expect(within(invite).getByText('Shareable link')).toBeInTheDocument();
    expect(within(invite).getByText(/Sent by Divya Iyer \(@divya\)/)).toBeInTheDocument();
    expect(within(invite).getAllByText('Active')).toHaveLength(2);
    // Inactive ones only on request.
    expect(within(invite).queryByText('Meera Rao')).not.toBeInTheDocument();
    await user.click(
      within(invite).getByLabelText('Show accepted, declined, withdrawn and expired too'),
    );
    expect(await within(invite).findByText('Meera Rao')).toBeInTheDocument();
    expect(within(invite).getByText('Declined')).toBeInTheDocument();
    expect(state.invitationQueries).toEqual(['', '?include_inactive=true']);
    expect(
      within(invite).queryByRole('button', { name: 'Withdraw the invitation to Meera Rao' }),
    ).not.toBeInTheDocument();

    await user.click(
      within(invite).getByRole('button', { name: 'Withdraw the invitation to Ravi Kumar' }),
    );
    const dialog = await screen.findByRole('dialog', {
      name: 'Withdraw the invitation to Ravi Kumar?',
    });
    expect(
      within(dialog).getByText(
        'The invitation stops working right away. You can send a new one later.',
      ),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Withdraw invitation' }));
    expect(await screen.findByText('Invitation withdrawn')).toBeInTheDocument();
    expect(await within(invite).findByText('Withdrawn')).toBeInTheDocument();

    // Already used elsewhere: the API's 409 is explained and the list refreshed.
    await user.click(within(invite).getByRole('button', { name: 'Withdraw this invitation link' }));
    await user.click(
      within(await screen.findByRole('dialog')).getByRole('button', {
        name: 'Withdraw invitation',
      }),
    );
    expect(await screen.findByText('This invitation was no longer active')).toBeInTheDocument();
    expect(revoked).toEqual([
      'b5b5b5b5-6666-4666-8666-000000000011',
      'b5b5b5b5-6666-4666-8666-000000000012',
    ]);
  });

  it('transfers ownership after confirming', async () => {
    let body: unknown = null;
    const state = serveSettings();
    server.use(
      http.post(`${API}/communities/:id/transfer-ownership`, async ({ request }) => {
        body = await request.json();
        state.community = makeCommunity({ my_role: 'moderator', visibility: 'private' });
        return HttpResponse.json(envelope(state.community));
      }),
    );
    const { user } = await openSettings();
    const owner = region('Ownership and status');
    await user.click(await within(owner).findByRole('button', { name: 'Transfer ownership' }));
    expect(within(owner).getByLabelText('New owner')).toHaveAccessibleDescription(
      /Choose who becomes the owner\./,
    );
    await user.selectOptions(await within(owner).findByLabelText('New owner'), MEMBER_ID);
    await user.click(within(owner).getByRole('button', { name: 'Transfer ownership' }));
    const dialog = await screen.findByRole('dialog', { name: 'Make Meera Rao the owner?' });
    expect(within(dialog).getByText(/You’ll become a moderator\./)).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Transfer ownership' }));
    expect(await screen.findByText('Meera Rao is now the owner')).toBeInTheDocument();
    expect(body).toEqual({ user_id: MEMBER_ID });
    await waitFor(() => {
      expect(
        screen.queryByRole('region', { name: 'Ownership and status' }),
      ).not.toBeInTheDocument();
    });
  });

  it('archives after confirming and can restore', async () => {
    const calls: string[] = [];
    const state = serveSettings();
    server.use(
      http.post(`${API}/communities/:id/archive`, () => {
        calls.push('archive');
        state.community = makeCommunity({
          my_role: 'owner',
          status: 'archived',
          visibility: 'private',
        });
        return HttpResponse.json(envelope(state.community));
      }),
      http.post(`${API}/communities/:id/restore`, () => {
        calls.push('restore');
        state.community = makeCommunity({ my_role: 'owner', visibility: 'private' });
        return HttpResponse.json(envelope(state.community));
      }),
    );
    const { user } = await openSettings();
    await user.click(
      within(region('Ownership and status')).getByRole('button', { name: 'Archive community' }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Archive Frugal Living?' });
    await user.click(within(dialog).getByRole('button', { name: 'Archive community' }));
    expect(await screen.findByText('Community archived')).toBeInTheDocument();
    expect(await screen.findByText('This community is archived')).toBeInTheDocument();
    expect(within(region('Invite people')).getByText(/Invitations are paused/)).toBeInTheDocument();
    await user.click(
      within(region('Ownership and status')).getByRole('button', { name: 'Restore community' }),
    );
    expect(await screen.findByText('Community restored')).toBeInTheDocument();
    expect(calls).toEqual(['archive', 'restore']);
  });
});
