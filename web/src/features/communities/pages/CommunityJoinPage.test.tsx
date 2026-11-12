import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import type { CommunityInvitationPreview } from '@/features/communities/types';
import {
  COMMUNITY_LINK_TOKEN,
  OTHER_COMMUNITY_ID,
  conflict,
  forbidden,
  makeCommunity,
  makeInvitationPreview,
  rateLimited,
  serveCommunity,
} from '@/tests/communitiesFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const joined = makeCommunity({
  id: OTHER_COMMUNITY_ID,
  slug: 'founders-circle',
  name: 'Founders Circle',
  visibility: 'invite_only',
});

/** The shared link puts the token in the fragment; the page reads window.location. */
async function openLink(path = `/communities/join#token=${COMMUNITY_LINK_TOKEN}`) {
  window.history.replaceState(null, '', path);
  const user = userEvent.setup();
  const result = renderRoute(path, { user: makeUser({ onboarding_completed: true }) });
  await findPageHeading('Join a community');
  return { user, ...result };
}

/** POST /community-invitations/preview: answers `respond` per token and records the bodies. */
function previewWith(
  respond: (token: string) => Response | CommunityInvitationPreview,
  bodies: unknown[] = [],
) {
  server.use(
    http.post(`${API}/community-invitations/preview`, async ({ request }) => {
      const body = (await request.json()) as { token: string };
      bodies.push(body);
      const answer = respond(body.token);
      return answer instanceof Response ? answer : HttpResponse.json(envelope(answer));
    }),
  );
  return bodies;
}

function acceptWith(respond: () => Response, bodies: unknown[] = []) {
  server.use(
    http.post(`${API}/community-invitations/accept`, async ({ request }) => {
      bodies.push(await request.json());
      return respond();
    }),
  );
  return bodies;
}

const gone = () =>
  HttpResponse.json(
    errorBody({ code: 'GONE', message: 'This invitation has expired or was already used.' }),
    { status: 410 },
  );

describe('CommunityJoinPage', () => {
  it('reads the token from the fragment, clears it, previews the community and joins when asked', async () => {
    serveCommunity(joined, { posts: [] });
    const previews = previewWith(() => makeInvitationPreview());
    const bodies = acceptWith(() => HttpResponse.json(envelope(joined)));
    const { user, router } = await openLink();

    // The fragment is gone from the address bar before anything is sent.
    expect(window.location.hash).toBe('');
    expect(window.location.pathname).toBe('/communities/join');
    expect(document.title).toBe('Join a community · Montra');

    // The preview names the community and who created the link (never the token in the address).
    expect(
      await screen.findByRole('heading', { name: 'You’re invited to join Founders Circle' }),
    ).toBeInTheDocument();
    expect(screen.getByText('7 members')).toBeInTheDocument();
    expect(screen.getByText('Divya Iyer')).toBeInTheDocument();
    expect(screen.getByText('@divya')).toBeInTheDocument();
    expect(screen.getByText('Link expires').nextElementSibling).toHaveTextContent(/2026/);
    expect(
      screen.getByText(/never see your accounts, balances or transactions/),
    ).toBeInTheDocument();
    expect(previews).toEqual([{ token: COMMUNITY_LINK_TOKEN }]);
    expect(bodies).toEqual([]);

    await user.click(screen.getByRole('button', { name: 'Join community' }));
    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/communities/${OTHER_COMMUNITY_ID}`);
    });
    expect(bodies).toEqual([{ token: COMMUNITY_LINK_TOKEN }]);
    expect(await screen.findByText('You joined Founders Circle')).toBeInTheDocument();
    expect(router.state.location.hash).not.toContain(COMMUNITY_LINK_TOKEN);
  });

  it('explains an unknown link kindly and previews a pasted one', async () => {
    serveCommunity(joined, { posts: [] });
    const other = 'AnotherCommunityToken_0123456789-x';
    const previews = previewWith((token) => (token === other ? makeInvitationPreview() : gone()));
    const bodies = acceptWith(() => HttpResponse.json(envelope(joined)));
    const { user, router } = await openLink();

    expect(await screen.findByText('This invitation link doesn’t work')).toBeInTheDocument();
    expect(
      screen.getByText(/each link works once\. Ask a moderator for a new one\./),
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Join community' })).not.toBeInTheDocument();

    await user.type(
      screen.getByLabelText('Invitation link'),
      `http://localhost:5173/communities/join#token=${other}`,
    );
    await user.click(screen.getByRole('button', { name: 'Use this link' }));
    await user.click(await screen.findByRole('button', { name: 'Join community' }));
    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/communities/${OTHER_COMMUNITY_ID}`);
    });
    expect(previews).toEqual([{ token: COMMUNITY_LINK_TOKEN }, { token: other }]);
    expect(bodies).toEqual([{ token: other }]);
  });

  it('says when a link was used, withdrawn or expired, as the preview reports', async () => {
    const statuses: CommunityInvitationPreview['status'][] = ['used', 'revoked', 'expired'];
    let index = 0;
    previewWith(() => makeInvitationPreview({ status: statuses[index] ?? 'expired' }));
    const bodies = acceptWith(() => HttpResponse.json(envelope(joined)));
    const first = await openLink();
    expect(await screen.findByText('This invitation link was already used')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Join community' })).not.toBeInTheDocument();
    first.unmount();

    index = 1;
    const second = await openLink();
    expect(await screen.findByText('This invitation was withdrawn')).toBeInTheDocument();
    expect(screen.getByText(/A moderator cancelled this link\./)).toBeInTheDocument();
    second.unmount();

    index = 2;
    await openLink();
    expect(await screen.findByText('This invitation link has expired')).toBeInTheDocument();
    expect(bodies).toEqual([]);
  });

  it('asks for the link when the page opens without one', async () => {
    const previews = previewWith(() => makeInvitationPreview());
    const { user } = await openLink('/communities/join');
    expect(screen.getByText('No invitation link found')).toBeInTheDocument();
    await user.type(
      screen.getByLabelText('Invitation link'),
      'https://montra.example/communities/join',
    );
    await user.click(screen.getByRole('button', { name: 'Use this link' }));
    expect(screen.getByLabelText('Invitation link')).toHaveAccessibleDescription(
      /doesn’t look like a complete invitation link/,
    );
    expect(previews).toEqual([]);
  });

  it('offers to open the community to people who are already members', async () => {
    previewWith(() => makeInvitationPreview({ already_member: true, member_count: 8 }));
    const bodies = acceptWith(() => HttpResponse.json(envelope(joined)));
    await openLink();
    expect(await screen.findByText('You’re already a member')).toBeInTheDocument();
    expect(screen.getByText('You’re already a member of Founders Circle.')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Open the community' })).toHaveAttribute(
      'href',
      `/communities/${OTHER_COMMUNITY_ID}`,
    );
    expect(screen.queryByRole('button', { name: 'Join community' })).not.toBeInTheDocument();
    expect(bodies).toEqual([]);
  });

  it('tells members they are already in when joining answers already_member', async () => {
    previewWith(() => makeInvitationPreview());
    acceptWith(() => conflict('already_member', 'You are already a member.'));
    const { user } = await openLink();
    await user.click(await screen.findByRole('button', { name: 'Join community' }));
    expect(await screen.findByText('You’re already a member')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Open the community' })).toHaveAttribute(
      'href',
      `/communities/${OTHER_COMMUNITY_ID}`,
    );
  });

  it('explains when a moderator banned the person', async () => {
    previewWith(() => makeInvitationPreview());
    acceptWith(() => forbidden());
    const { user } = await openLink();
    await user.click(await screen.findByRole('button', { name: 'Join community' }));
    expect(await screen.findByText('You can’t join this community')).toBeInTheDocument();
    expect(
      screen.getByRole('link', { name: 'See why and appeal in Settings → Moderation' }),
    ).toHaveAttribute('href', '/settings/moderation');
  });

  it('retries a failed preview and answers a rate limit on joining calmly', async () => {
    let previews = 0;
    previewWith(() => {
      previews += 1;
      return previews === 1
        ? HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 })
        : makeInvitationPreview();
    });
    acceptWith(() => rateLimited(2));
    const { user } = await openLink();
    expect(await screen.findByText('We couldn’t check this invitation')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    await user.click(await screen.findByRole('button', { name: 'Join community' }));
    expect(
      await screen.findByText('You’re going a little fast. Try again in 2 seconds.'),
    ).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Join community' })).toBeInTheDocument();
  });
});
