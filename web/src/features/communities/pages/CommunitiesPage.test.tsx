import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import type { Community, CommunityInvitation } from '@/features/communities/types';
import {
  COMMUNITY_ID,
  INVITATION_ID,
  OTHER_COMMUNITY_ID,
  conflict,
  forbidden,
  makeCommunity,
  makeCommunityInvitation,
  serveCommunity,
} from '@/tests/communitiesFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

function region(name: string) {
  return screen.getByRole('region', { name });
}

const pending = makeCommunity({
  id: OTHER_COMMUNITY_ID,
  slug: 'salary-circle',
  name: 'Salary Circle',
  description: undefined,
  visibility: 'private',
  topics: ['careers'],
  my_status: 'pending',
  my_role: 'none',
  member_count: 4,
});
const discoverable = makeCommunity({
  id: 'c0c0c0c0-1111-4111-8111-000000000009',
  slug: 'debt-free',
  name: 'Debt Free India',
  description: 'Paying off loans together',
  topics: ['debt', 'loans'],
  my_status: 'none',
  my_role: 'none',
  member_count: 1,
});

interface ListOptions {
  mine?: Community[];
  discover?: (query: URLSearchParams) => Community[];
  invitations?: CommunityInvitation[];
}

/** Serves the lists: `?mine=true` returns `mine`; other queries go through `discover`. */
function serveLists({
  mine = [makeCommunity({ my_role: 'owner' }), pending],
  discover = () => [makeCommunity(), discoverable],
  invitations = [],
}: ListOptions = {}) {
  const queries: string[] = [];
  server.use(
    http.get(`${API}/communities`, ({ request }) => {
      const params = new URL(request.url).searchParams;
      if (params.get('mine') === 'true') return HttpResponse.json(envelope(mine));
      queries.push(params.toString());
      return HttpResponse.json(envelope(discover(params)));
    }),
    http.get(`${API}/community-invitations`, () => HttpResponse.json(envelope(invitations))),
  );
  return queries;
}

async function openList() {
  const user = userEvent.setup();
  const result = renderRoute('/communities', { user: signedIn() });
  await findPageHeading('Communities');
  return { user, ...result };
}

describe('CommunitiesPage', () => {
  it('lists your communities and discovery with membership badges, linking by ID', async () => {
    serveLists();
    await openList();
    expect(document.title).toBe('Communities · Montra');
    expect(screen.getByText(/never your accounts, balances or transactions/)).toBeInTheDocument();

    const mine = region('Your communities');
    const frugal = await within(mine).findByRole('link', { name: 'Frugal Living' });
    expect(frugal).toHaveAttribute('href', `/communities/${COMMUNITY_ID}`);
    expect(within(mine).getByText('Owner')).toBeInTheDocument();
    expect(within(mine).getByText('Request pending')).toBeInTheDocument();
    expect(within(mine).getByText('Private')).toBeInTheDocument();

    const discover = region('Find communities');
    expect(
      await within(discover).findByRole('link', { name: 'Debt Free India' }),
    ).toBeInTheDocument();
    expect(within(discover).getByText('1 member')).toBeInTheDocument();
    // Descriptions are plain text excerpts: addresses are not links in lists.
    expect(within(discover).queryByRole('link', { name: /example\.org/ })).not.toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Create a community' })).toHaveAttribute(
      'href',
      '/communities/new',
    );
    expect(screen.getByRole('link', { name: 'Paste an invitation link' })).toHaveAttribute(
      'href',
      '/communities/join',
    );
    // No invitations: the card stays hidden.
    expect(screen.queryByRole('region', { name: 'Invitations for you' })).not.toBeInTheDocument();
  });

  it('searches by name and filters by a topic', async () => {
    const queries = serveLists({
      discover: (params) => {
        if (params.size === 0) return [makeCommunity(), discoverable];
        return params.get('topic') === 'loans' ? [discoverable] : [];
      },
    });
    const { user } = await openList();
    const discover = region('Find communities');
    await within(discover).findByRole('link', { name: 'Debt Free India' });

    await user.type(within(discover).getByLabelText('Search by name or description'), 'zzz');
    expect(await within(discover).findByText('No communities match')).toBeInTheDocument();
    expect(queries).toContain('q=zzz');
    await user.click(within(discover).getAllByRole('button', { name: 'Clear search' })[0]!);

    await user.click(
      await within(discover).findByRole('button', { name: 'Show communities about loans' }),
    );
    await waitFor(() => {
      expect(queries).toContain('topic=loans');
    });
    expect(within(discover).getByLabelText('Topic')).toHaveValue('loans');
  });

  it('accepts an invitation and opens the community', async () => {
    const joined = makeCommunity({
      id: OTHER_COMMUNITY_ID,
      name: 'Founders Circle',
      visibility: 'invite_only',
    });
    serveLists({ invitations: [makeCommunityInvitation()] });
    serveCommunity(joined, { posts: [] });
    let accepted = '';
    server.use(
      http.post(`${API}/community-invitations/:id/accept`, ({ params }) => {
        accepted = String(params.id);
        return HttpResponse.json(envelope(joined));
      }),
    );
    const { user, router } = await openList();
    const invitations = await screen.findByRole('region', { name: 'Invitations for you' });
    expect(within(invitations).getByText('Join Founders Circle')).toBeInTheDocument();
    expect(within(invitations).getByText('Invited by Divya Iyer (@divya)')).toBeInTheDocument();
    await user.click(within(invitations).getByRole('button', { name: 'Join Founders Circle' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/communities/${OTHER_COMMUNITY_ID}`);
    });
    expect(accepted).toBe(INVITATION_ID);
    expect(await screen.findByText('You joined Founders Circle')).toBeInTheDocument();
  });

  it('declines an invitation, and says when it was already answered', async () => {
    const declined: string[] = [];
    let calls = 0;
    const invitations = [
      makeCommunityInvitation(),
      makeCommunityInvitation({
        id: 'b5b5b5b5-6666-4666-8666-000000000002',
        community_name: 'Salary Circle',
      }),
    ];
    server.use(
      http.get(`${API}/communities`, () => HttpResponse.json(envelope([]))),
      http.get(`${API}/community-invitations`, () =>
        HttpResponse.json(envelope(invitations.filter((item) => !declined.includes(item.id)))),
      ),
      http.post(`${API}/community-invitations/:id/decline`, ({ params }) => {
        calls += 1;
        if (calls === 1) {
          declined.push(String(params.id));
          return HttpResponse.json(envelope({ ok: true }));
        }
        declined.push(String(params.id));
        return conflict('invitation_used', 'This invitation was already declined.', {
          status: 'declined',
        });
      }),
    );
    const { user } = await openList();
    const region = await screen.findByRole('region', { name: 'Invitations for you' });
    await user.click(
      within(region).getByRole('button', { name: 'Decline the invitation to Founders Circle' }),
    );
    expect(await screen.findByText('Invitation declined')).toBeInTheDocument();
    await waitFor(() => {
      expect(within(region).queryByText('Join Founders Circle')).not.toBeInTheDocument();
    });
    await user.click(
      within(region).getByRole('button', { name: 'Decline the invitation to Salary Circle' }),
    );
    expect(await screen.findByText('This invitation was already answered')).toBeInTheDocument();
    expect(declined).toEqual([INVITATION_ID, 'b5b5b5b5-6666-4666-8666-000000000002']);
    await waitFor(() => {
      expect(screen.queryByRole('region', { name: 'Invitations for you' })).not.toBeInTheDocument();
    });
  });

  it('explains an invitation that expired', async () => {
    serveLists({ invitations: [makeCommunityInvitation()] });
    server.use(
      http.post(`${API}/community-invitations/:id/accept`, () =>
        HttpResponse.json(errorBody({ code: 'GONE' }), { status: 410 }),
      ),
    );
    const { user } = await openList();
    await user.click(await screen.findByRole('button', { name: 'Join Founders Circle' }));
    expect(
      await screen.findByText('This invitation expired or was withdrawn.'),
    ).toBeInTheDocument();
  });

  it('shows empty states with a way to create a community', async () => {
    serveLists({ mine: [], discover: () => [] });
    await openList();
    expect(await screen.findByText('You haven’t joined a community yet')).toBeInTheDocument();
    expect(await screen.findByText('No communities yet')).toBeInTheDocument();
    expect(
      within(region('Find communities')).getByRole('link', { name: 'Create a community' }),
    ).toHaveAttribute('href', '/communities/new');
  });

  it('offers a retry when discovery fails', async () => {
    let calls = 0;
    serveLists({
      discover: () => {
        calls += 1;
        return [discoverable];
      },
    });
    server.use(
      http.get(`${API}/communities`, ({ request }) => {
        if (new URL(request.url).searchParams.get('mine') === 'true') {
          return HttpResponse.json(envelope([]));
        }
        calls += 1;
        if (calls === 1) {
          return HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 });
        }
        return HttpResponse.json(envelope([discoverable]));
      }),
    );
    const { user } = await openList();
    const discover = region('Find communities');
    expect(await within(discover).findByText('We couldn’t load communities')).toBeInTheDocument();
    await user.click(within(discover).getByRole('button', { name: 'Try again' }));
    expect(
      await within(discover).findByRole('link', { name: 'Debt Free India' }),
    ).toBeInTheDocument();
  });

  it('shows a permission message when the API refuses', async () => {
    serveLists();
    server.use(http.get(`${API}/communities`, () => forbidden()));
    await openList();
    expect(
      await within(region('Find communities')).findByText('You don’t have access to this'),
    ).toBeInTheDocument();
  });
});
