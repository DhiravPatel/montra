import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { formatDateTime, formatLocalDateRange } from '@/shared/formatting/dates';
import { money } from '@/tests/financeFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  GROUP_ID,
  INVITATION_ID,
  TRIP_ID,
  groupReadHandlers,
  makeGroupDTO,
  makeGroupDetailFull,
  makeInvitation,
} from '@/tests/groupsFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

/** Testing Library collapses whitespace (Intl output may contain thin spaces). */
function text(value: string) {
  return value.replace(/\s+/g, ' ');
}

function noInvitations() {
  return http.get(`${API}/group-invitations`, () => HttpResponse.json(envelope([])));
}

describe('GroupsPage', () => {
  it('lists groups with their type, role, members, trip dates, status and your balance', async () => {
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
      makeGroupDTO({
        id: 'c1c1c1c1-3333-4333-8333-000000000009',
        name: 'Book club',
        group_type: 'friends',
        my_role: 'member',
      }),
    ];
    server.use(noInvitations());
    renderRoute('/groups', { user: signedIn() });
    await findPageHeading('Groups');

    const list = await screen.findByRole('region', { name: 'Your groups' });
    const items = within(list).getAllByRole('listitem');
    expect(items).toHaveLength(3);
    const [home, trip, club] = items as [HTMLElement, HTMLElement, HTMLElement];
    expect(within(home).getByRole('link', { name: 'Home' })).toHaveAttribute(
      'href',
      `/groups/${GROUP_ID}`,
    );
    expect(within(home).getByText('2 members')).toBeInTheDocument();
    expect(within(home).getByText('Household')).toBeInTheDocument();
    expect(within(home).getByText('Owner')).toBeInTheDocument();
    // The API's balance per group: words and an icon, never a bare sign.
    expect(within(home).getByText('You are owed ₹1,250.00')).toBeInTheDocument();
    expect(within(trip).getByText('You owe ₹300.50')).toBeInTheDocument();
    expect(within(club).getByText('Settled up')).toBeInTheDocument();

    expect(within(trip).getByRole('link', { name: 'Goa trip' })).toHaveAttribute(
      'href',
      `/groups/${TRIP_ID}`,
    );
    const dates = formatLocalDateRange('2026-12-20', '2026-12-24', 'en-US');
    expect(within(trip).getByText(text(`4 members · ${dates} · Goa`))).toBeInTheDocument();
    expect(within(trip).getByText('Trip')).toBeInTheDocument();
    expect(within(trip).getByText('Member')).toBeInTheDocument();
    // Nothing to answer: the invitations card stays hidden.
    expect(screen.queryByRole('region', { name: 'Invitations for you' })).not.toBeInTheDocument();
    expect(
      within(screen.getByRole('region', { name: 'Joining with a link' })).getByRole('link', {
        name: 'Paste an invitation link',
      }),
    ).toHaveAttribute('href', '/groups/join');
    expect(document.title).toBe('Groups · Montra');
  });

  it('asks the API for archived groups only when requested and marks them', async () => {
    const seen: string[] = [];
    server.use(
      noInvitations(),
      http.get(`${API}/groups`, ({ request }) => {
        const search = new URL(request.url).search;
        seen.push(search);
        return HttpResponse.json(
          envelope(
            search.includes('include_archived=true')
              ? [
                  makeGroupDTO(),
                  makeGroupDTO({ id: TRIP_ID, name: 'Old flat', status: 'archived' }),
                ]
              : [makeGroupDTO()],
          ),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/groups', { user: signedIn() });
    await findPageHeading('Groups');
    const list = screen.getByRole('region', { name: 'Your groups' });
    await within(list).findByRole('link', { name: 'Home' });
    expect(within(list).queryByText('Archived')).not.toBeInTheDocument();

    await user.click(screen.getByLabelText('Show archived groups'));
    expect(await within(list).findByRole('link', { name: 'Old flat' })).toBeInTheDocument();
    expect(within(list).getByText('Archived')).toBeInTheDocument();
    expect(seen).toEqual(['', '?include_archived=true']);
  });

  it('shows a first-use empty state with a way to create a group', async () => {
    server.use(noInvitations());
    renderRoute('/groups', { user: signedIn() });
    await findPageHeading('Groups');
    expect(await screen.findByText('No groups yet')).toBeInTheDocument();
    const create = screen.getAllByRole('link', { name: 'Create group' });
    expect(create.length).toBeGreaterThan(0);
    for (const link of create) expect(link).toHaveAttribute('href', '/groups/new');
  });

  it('shows a recoverable error with the support reference', async () => {
    server.use(
      noInvitations(),
      http.get(`${API}/groups`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-groups' }), {
          status: 500,
        }),
      ),
    );
    renderRoute('/groups', { user: signedIn() });
    await findPageHeading('Groups');
    expect(await screen.findByText('We couldn’t load your groups')).toBeInTheDocument();
    expect(screen.getByText('req-groups')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Try again' })).toBeInTheDocument();
  });

  it('shows a permission message when the API refuses', async () => {
    server.use(
      noInvitations(),
      http.get(`${API}/groups`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/groups', { user: signedIn() });
    await findPageHeading('Groups');
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });
});

describe('GroupsPage invitations', () => {
  it('accepts an invitation and opens the group', async () => {
    let accepted = false;
    const joined = makeGroupDetailFull({ my_role: 'member' });
    const reads = groupReadHandlers(joined);
    server.use(
      http.get(`${API}/group-invitations`, () =>
        HttpResponse.json(envelope(accepted ? [] : [makeInvitation()])),
      ),
      http.post(`${API}/group-invitations/:id/accept`, ({ params }) => {
        expect(params.id).toBe(INVITATION_ID);
        accepted = true;
        return HttpResponse.json(envelope(joined));
      }),
      ...reads.handlers,
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/groups', { user: signedIn() });
    await findPageHeading('Groups');

    const card = await screen.findByRole('region', { name: 'Invitations for you' });
    expect(within(card).getByText('Invitation to join Home')).toBeInTheDocument();
    expect(within(card).getByText('Invited by Meera Rao (@meera)')).toBeInTheDocument();
    const expires = formatDateTime(new Date('2026-11-12T09:00:00Z'), 'en-US', 'Asia/Kolkata');
    expect(within(card).getByText(text(`Expires ${expires}`))).toBeInTheDocument();

    await user.click(within(card).getByRole('button', { name: 'Join: Home' }));
    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/groups/${GROUP_ID}`);
    });
    expect(await screen.findByText('You joined Home')).toBeInTheDocument();
    expect(accepted).toBe(true);
  });

  it('declines an invitation after confirming', async () => {
    let declined = false;
    server.use(
      http.get(`${API}/group-invitations`, () =>
        HttpResponse.json(envelope(declined ? [] : [makeInvitation()])),
      ),
      http.post(`${API}/group-invitations/:id/decline`, () => {
        declined = true;
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/groups', { user: signedIn() });
    await findPageHeading('Groups');
    await user.click(await screen.findByRole('button', { name: 'Decline: Home' }));
    const dialog = await screen.findByRole('dialog', { name: 'Decline this invitation?' });
    expect(dialog).toHaveTextContent('You won’t join Home.');
    await user.click(within(dialog).getByRole('button', { name: 'Decline invitation' }));

    expect(await screen.findByText('Invitation declined')).toBeInTheDocument();
    expect(declined).toBe(true);
    await waitFor(() => {
      expect(screen.queryByRole('region', { name: 'Invitations for you' })).not.toBeInTheDocument();
    });
  });

  it('explains an invitation that expired before it was accepted', async () => {
    let gone = false;
    server.use(
      http.get(`${API}/group-invitations`, () =>
        HttpResponse.json(envelope(gone ? [] : [makeInvitation()])),
      ),
      http.post(`${API}/group-invitations/:id/accept`, () => {
        gone = true;
        return HttpResponse.json(
          errorBody({ code: 'GONE', message: 'This invitation has expired or was already used.' }),
          { status: 410 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/groups', { user: signedIn() });
    await findPageHeading('Groups');
    await user.click(await screen.findByRole('button', { name: 'Join: Home' }));
    expect(await screen.findByText('We couldn’t add you to the group')).toBeInTheDocument();
    expect(
      screen.getByText('This invitation has expired or is no longer available.'),
    ).toBeInTheDocument();
    await waitFor(() => {
      expect(screen.queryByRole('region', { name: 'Invitations for you' })).not.toBeInTheDocument();
    });
  });

  it('explains a coded conflict when the invitation was already answered', async () => {
    let gone = false;
    server.use(
      http.get(`${API}/group-invitations`, () =>
        HttpResponse.json(envelope(gone ? [] : [makeInvitation()])),
      ),
      http.post(`${API}/group-invitations/:id/accept`, () => {
        gone = true;
        return HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            message: 'This invitation was already accepted.',
            details: [
              {
                code: 'invitation_used',
                message: 'This invitation was already accepted.',
                params: { status: 'accepted' },
              },
            ],
          }),
          { status: 409 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/groups', { user: signedIn() });
    await findPageHeading('Groups');
    await user.click(await screen.findByRole('button', { name: 'Join: Home' }));
    expect(
      await screen.findByText('This invitation was already used, declined, cancelled or expired.'),
    ).toBeInTheDocument();
    await waitFor(() => {
      expect(screen.queryByRole('region', { name: 'Invitations for you' })).not.toBeInTheDocument();
    });
  });

  it('opens the group when the API says you are already a member', async () => {
    const reads = groupReadHandlers(makeGroupDetailFull({ my_role: 'member' }));
    server.use(
      http.get(`${API}/group-invitations`, () => HttpResponse.json(envelope([makeInvitation()]))),
      http.post(`${API}/group-invitations/:id/accept`, () =>
        HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            message: 'You are already a member of this group.',
            details: [
              { code: 'already_member', message: 'You are already a member of this group.' },
            ],
          }),
          { status: 409 },
        ),
      ),
      ...reads.handlers,
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/groups', { user: signedIn() });
    await user.click(await screen.findByRole('button', { name: 'Join: Home' }));
    expect(await screen.findByText('You’re already a member of this group')).toBeInTheDocument();
    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/groups/${GROUP_ID}`);
    });
  });

  it('shows an error when invitations cannot be loaded, without hiding the groups', async () => {
    testBackend.groups = [makeGroupDTO()];
    server.use(
      http.get(`${API}/group-invitations`, () =>
        HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 }),
      ),
    );
    renderRoute('/groups', { user: signedIn() });
    await findPageHeading('Groups');
    expect(await screen.findByText('We couldn’t load your invitations')).toBeInTheDocument();
    const list = screen.getByRole('region', { name: 'Your groups' });
    expect(await within(list).findByRole('link', { name: 'Home' })).toBeInTheDocument();
  });
});
