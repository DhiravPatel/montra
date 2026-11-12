import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { formatDateTime } from '@/shared/formatting/dates';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  LINK_INVITATION_ID,
  LINK_TOKEN,
  ME,
  TRIP_ID,
  groupReadHandlers,
  makeJoinRequest,
  makePreview,
  makeTripDetail,
} from '@/tests/groupsFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

/** The shared link puts the token in the fragment; the page reads window.location. */
function openLink(path = `/groups/join#token=${LINK_TOKEN}`) {
  window.history.replaceState(null, '', path);
  return renderRoute(path, { user: signedIn() });
}

function previewWith(preview = makePreview(), bodies: unknown[] = []) {
  return http.post(`${API}/group-invitations/preview`, async ({ request }) => {
    bodies.push(await request.json());
    return HttpResponse.json(envelope(preview));
  });
}

describe('GroupJoinPage', () => {
  it('previews the group from the fragment token, clears the fragment and joins', async () => {
    const previews: unknown[] = [];
    const accepts: unknown[] = [];
    const joined = makeTripDetail({ my_role: 'member' });
    const reads = groupReadHandlers(joined);
    server.use(
      previewWith(makePreview(), previews),
      http.post(`${API}/group-invitations/accept`, async ({ request }) => {
        accepts.push(await request.json());
        return HttpResponse.json(envelope(joined));
      }),
      ...reads.handlers,
    );
    const user = userEvent.setup();
    const { router } = openLink();
    await findPageHeading('Join a group');

    expect(
      await screen.findByRole('heading', { name: 'You’re invited to join Goa trip' }),
    ).toBeInTheDocument();
    const expires = formatDateTime(new Date('2026-11-12T09:00:00Z'), 'en-US', 'Asia/Kolkata');
    expect(
      screen.getByText(`Trip · 4 members · invitation expires ${expires}`.replace(/\s+/g, ' ')),
    ).toBeInTheDocument();
    expect(screen.getByText('Invited by Meera Rao (@meera)')).toBeInTheDocument();
    expect(screen.getByText(/members see your name and username/)).toBeInTheDocument();
    // No approval needed: nothing about admins.
    expect(screen.queryByText('The admins approve new members')).not.toBeInTheDocument();
    // The token was sent in the body only and is gone from the address bar.
    expect(previews).toEqual([{ token: LINK_TOKEN }]);
    expect(window.location.hash).toBe('');
    expect(window.location.pathname).toBe('/groups/join');
    expect(document.title).toBe('Join a group · Montra');

    await user.click(screen.getByRole('button', { name: 'Join group' }));
    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/groups/${TRIP_ID}`);
    });
    expect(accepts).toEqual([{ token: LINK_TOKEN }]);
    expect(await screen.findByText('You joined Goa trip')).toBeInTheDocument();
    expect(router.state.location.hash).not.toContain(LINK_TOKEN);
  });

  it('explains an expired invitation kindly, without a join button', async () => {
    server.use(previewWith(makePreview({ status: 'expired' })));
    openLink();
    await findPageHeading('Join a group');
    expect(await screen.findByText('This invitation has expired')).toBeInTheDocument();
    expect(
      screen.getByText(
        'The invitation to Goa trip is no longer valid. Ask a member for a new link.',
      ),
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Join group' })).not.toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'All groups' })).toHaveAttribute('href', '/groups');
  });

  it('explains used and cancelled invitations', async () => {
    server.use(previewWith(makePreview({ status: 'accepted' })));
    openLink();
    expect(await screen.findByText('This invitation was already used')).toBeInTheDocument();
  });

  it('explains a cancelled invitation', async () => {
    server.use(previewWith(makePreview({ status: 'revoked' })));
    openLink();
    expect(await screen.findByText('This invitation was cancelled')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Join group' })).not.toBeInTheDocument();
  });

  it('explains a link that does not work and lets the user paste another', async () => {
    const previews: unknown[] = [];
    let first = true;
    server.use(
      http.post(`${API}/group-invitations/preview`, async ({ request }) => {
        previews.push(await request.json());
        if (first) {
          first = false;
          return HttpResponse.json(
            errorBody({ code: 'GONE', message: 'This invitation link is not valid.' }),
            { status: 410 },
          );
        }
        return HttpResponse.json(envelope(makePreview()));
      }),
    );
    const user = userEvent.setup();
    openLink();
    expect(await screen.findByText('This invitation link doesn’t work')).toBeInTheDocument();

    const field = screen.getByLabelText('Invitation link');
    await user.type(field, 'https://example.com/groups/join');
    await user.click(screen.getByRole('button', { name: 'Check invitation' }));
    expect(field).toHaveAccessibleDescription(/doesn’t look like a complete invitation link/);

    const other = 'AnotherTokenFromAFriend_0123456789-x';
    await user.clear(field);
    await user.type(field, `http://localhost:5173/groups/join#token=${other}`);
    await user.click(screen.getByRole('button', { name: 'Check invitation' }));
    expect(
      await screen.findByRole('heading', { name: 'You’re invited to join Goa trip' }),
    ).toBeInTheDocument();
    expect(previews).toEqual([{ token: LINK_TOKEN }, { token: other }]);
  });

  it('asks for the link when the page opens without one (e.g. after signing in)', async () => {
    const previews: unknown[] = [];
    server.use(previewWith(makePreview(), previews));
    const user = userEvent.setup();
    openLink('/groups/join');
    await findPageHeading('Join a group');
    expect(await screen.findByText('No invitation link found')).toBeInTheDocument();
    expect(previews).toEqual([]);

    await user.type(
      screen.getByLabelText('Invitation link'),
      `http://localhost:5173/groups/join#token=${LINK_TOKEN}`,
    );
    await user.click(screen.getByRole('button', { name: 'Check invitation' }));
    expect(
      await screen.findByRole('heading', { name: 'You’re invited to join Goa trip' }),
    ).toBeInTheDocument();
    expect(previews).toEqual([{ token: LINK_TOKEN }]);
  });

  it('handles an invitation that runs out between preview and join', async () => {
    server.use(
      previewWith(),
      http.post(`${API}/group-invitations/accept`, () =>
        HttpResponse.json(
          errorBody({ code: 'GONE', message: 'This invitation has expired or was already used.' }),
          { status: 410 },
        ),
      ),
    );
    const user = userEvent.setup();
    openLink();
    await user.click(await screen.findByRole('button', { name: 'Join group' }));
    const title = await screen.findByText('This invitation was already used');
    const alert = title.closest('[role="alert"]');
    expect(alert).toHaveTextContent(
      'It expired or was used up just now. Ask a member for a new link.',
    );
    expect(screen.queryByRole('button', { name: 'Join group' })).not.toBeInTheDocument();
  });

  it('explains that the admins approve new members and shows the pending request', async () => {
    const accepts: unknown[] = [];
    server.use(
      previewWith(makePreview({ requires_approval: true })),
      http.post(`${API}/group-invitations/accept`, async ({ request }) => {
        accepts.push(await request.json());
        // 202: a join request for the admins instead of the group.
        return HttpResponse.json(
          envelope(
            makeJoinRequest({
              id: 'f4f4f4f4-6666-4666-8666-000000000011',
              group_id: TRIP_ID,
              user_id: ME,
              display_name: 'Asha Rao',
              message: undefined,
              invitation_id: LINK_INVITATION_ID,
            }),
          ),
          { status: 202 },
        );
      }),
    );
    const user = userEvent.setup();
    const { router } = openLink();
    expect(await screen.findByText('The admins approve new members')).toBeInTheDocument();
    expect(
      screen.getByText(/the group’s owner and admins see your name and decide/),
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Join group' })).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Ask to join' }));
    const body = await screen.findByText(
      'The admins of Goa trip will see your request. You’ll get a notification when they answer.',
    );
    const sent = body.closest('[role="status"]');
    expect(sent).not.toBeNull();
    expect(sent).toHaveTextContent('Request sent');
    expect(accepts).toEqual([{ token: LINK_TOKEN }]);
    expect(screen.queryByRole('button', { name: 'Ask to join' })).not.toBeInTheDocument();
    expect(
      within(sent as HTMLElement).getByRole('link', { name: 'Go to your groups' }),
    ).toHaveAttribute('href', '/groups');
    // No group to open yet.
    expect(router.state.location.pathname).toBe('/groups/join');
  });

  it('tells members they are already in the group before they accept', async () => {
    const accepts: unknown[] = [];
    server.use(
      previewWith(makePreview({ already_member: true })),
      http.post(`${API}/group-invitations/accept`, async ({ request }) => {
        accepts.push(await request.json());
        return HttpResponse.json(envelope(makeTripDetail()));
      }),
    );
    openLink();
    expect(await screen.findByText('You’re already a member')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Open the group' })).toHaveAttribute(
      'href',
      `/groups/${TRIP_ID}`,
    );
    expect(screen.queryByRole('button', { name: 'Join group' })).not.toBeInTheDocument();
    expect(accepts).toEqual([]);
  });

  it('tells members they are already in the group (coded 409)', async () => {
    server.use(
      previewWith(),
      http.post(`${API}/group-invitations/accept`, () =>
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
    );
    const user = userEvent.setup();
    openLink();
    await user.click(await screen.findByRole('button', { name: 'Join group' }));
    expect(await screen.findByText('You’re already a member')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Open the group' })).toHaveAttribute(
      'href',
      `/groups/${TRIP_ID}`,
    );
    expect(screen.queryByRole('button', { name: 'Join group' })).not.toBeInTheDocument();
  });

  it('explains a join request that is already waiting (coded 409)', async () => {
    server.use(
      previewWith(makePreview({ requires_approval: true })),
      http.post(`${API}/group-invitations/accept`, () =>
        HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            message: 'Your request to join is already waiting for the admins.',
            details: [
              {
                code: 'join_request_pending',
                message: 'Your request to join is already waiting for the admins.',
              },
            ],
          }),
          { status: 409 },
        ),
      ),
    );
    const user = userEvent.setup();
    openLink();
    await user.click(await screen.findByRole('button', { name: 'Ask to join' }));
    expect(await screen.findByText('Your request is already waiting')).toBeInTheDocument();
    expect(
      screen.getByText('You already asked to join Goa trip. The admins haven’t answered yet.'),
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Ask to join' })).not.toBeInTheDocument();
  });

  it('falls back to a general sentence for a conflict without a code', async () => {
    server.use(
      previewWith(),
      http.post(`${API}/group-invitations/accept`, () =>
        HttpResponse.json(errorBody({ code: 'CONFLICT', message: 'You are already a member.' }), {
          status: 409,
        }),
      ),
    );
    const user = userEvent.setup();
    openLink();
    await user.click(await screen.findByRole('button', { name: 'Join group' }));
    expect(
      await screen.findByText(
        'You’re already a member, or your request is already waiting for an admin.',
      ),
    ).toBeInTheDocument();
  });

  it('offers a retry when the preview fails', async () => {
    let calls = 0;
    server.use(
      http.post(`${API}/group-invitations/preview`, () => {
        calls += 1;
        if (calls === 1) {
          return HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 });
        }
        return HttpResponse.json(envelope(makePreview()));
      }),
    );
    const user = userEvent.setup();
    openLink();
    expect(await screen.findByText('We couldn’t check this invitation')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(
      await screen.findByRole('heading', { name: 'You’re invited to join Goa trip' }),
    ).toBeInTheDocument();
  });

  it('shows a permission message when the API refuses the preview', async () => {
    server.use(
      http.post(`${API}/group-invitations/preview`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    openLink();
    await findPageHeading('Join a group');
    expect(
      await within(screen.getByRole('main')).findByText('You don’t have access to this'),
    ).toBeInTheDocument();
  });
});
