import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import type { Post } from '@/features/communities/types';
import {
  COMMUNITY_ID,
  COMMUNITY_SLUG,
  MEMBER_ID,
  POST_ID,
  dailyCapped,
  forbidden,
  makeCommunity,
  makePost,
  reactionsAnswer,
  ruleViolation,
  serveCommunity,
} from '@/tests/communitiesFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

async function openCommunity(
  ref: string = COMMUNITY_ID,
  heading = 'Frugal Living',
  account = signedIn(),
) {
  const user = userEvent.setup();
  const result = renderRoute(`/communities/${ref}`, { user: account });
  await findPageHeading(heading);
  return { user, ...result };
}

function feed() {
  return screen.getByRole('region', { name: 'Posts' });
}

describe('CommunityPage', () => {
  it('shows the community, its moderators and posts (by URL name too)', async () => {
    const state = serveCommunity();
    await openCommunity(COMMUNITY_SLUG);
    expect(document.title).toBe('Community · Montra');
    expect(screen.getAllByText('12 members').length).toBeGreaterThan(0);
    expect(screen.getAllByText('Public').length).toBeGreaterThan(0);

    const about = screen.getByRole('region', { name: 'About' });
    const link = within(about).getByRole('link', { name: /https:\/\/example\.org\/guide/ });
    expect(link).toHaveAttribute('href', 'https://example.org/guide');
    expect(link).toHaveAttribute('rel', 'noopener noreferrer nofollow');
    expect(link).toHaveAttribute('target', '_blank');
    expect(within(about).getByText('Be kind. No selling.')).toBeInTheDocument();
    expect(
      within(about).getByText(/never see your accounts, balances or transactions/),
    ).toBeInTheDocument();

    const moderators = screen.getByRole('region', { name: 'Moderators' });
    expect(await within(moderators).findByText('Owen Shah')).toBeInTheDocument();
    expect(within(moderators).getByText('Divya Iyer')).toBeInTheDocument();
    // Plain members are not listed as moderators.
    expect(within(moderators).queryByText('Meera Rao')).not.toBeInTheDocument();

    const post = await within(feed()).findByRole('link', { name: 'How I paid off my bike loan' });
    expect(post).toHaveAttribute('href', `/posts/${POST_ID}`);
    expect(within(feed()).getAllByText('Personal experience').length).toBeGreaterThan(0);
    expect(within(feed()).getByText('Poll: Avalanche or snowball? · 4 votes')).toBeInTheDocument();
    // Feed excerpts keep addresses as text and mark mentions.
    expect(
      within(feed()).queryByRole('link', { name: /example\.org\/payoff/ }),
    ).not.toBeInTheDocument();
    expect(within(feed()).getByText('@asha')).toBeInTheDocument();
    expect(state.feedQueries[0]).toBe('?sort=new&limit=20');
    // Members only: no settings or moderation tabs.
    expect(screen.queryByRole('navigation', { name: 'Community pages' })).not.toBeInTheDocument();
  });

  it('joins a public community', async () => {
    const state = serveCommunity(makeCommunity({ my_status: 'none', my_role: 'none' }));
    server.use(
      http.post(`${API}/communities/:id/join`, () => {
        state.community = makeCommunity({ member_count: 13 });
        return HttpResponse.json(envelope(state.community));
      }),
    );
    const { user } = await openCommunity();
    expect(screen.queryByRole('button', { name: 'Write a post' })).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Join community' }));
    expect(await screen.findByText('You joined Frugal Living')).toBeInTheDocument();
    expect(await screen.findByRole('button', { name: 'Write a post' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Leave community' })).toBeInTheDocument();
  });

  it('asks to join a private community, then waits for approval', async () => {
    const state = serveCommunity(
      makeCommunity({ visibility: 'private', my_status: 'none', my_role: 'none' }),
    );
    state.feedResponse = forbidden;
    let left = 0;
    server.use(
      http.post(`${API}/communities/:id/join`, () => {
        state.community = makeCommunity({
          visibility: 'private',
          my_status: 'pending',
          my_role: 'none',
        });
        return HttpResponse.json(envelope(state.community));
      }),
      http.post(`${API}/communities/:id/leave`, () => {
        left += 1;
        state.community = makeCommunity({
          visibility: 'private',
          my_status: 'left',
          my_role: 'none',
        });
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const { user } = await openCommunity();
    expect(await within(feed()).findByText('Posts are for members')).toBeInTheDocument();
    expect(
      within(feed()).getByText('Join this community to read and write posts.'),
    ).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Ask to join' }));
    expect(await screen.findByText('Request sent')).toBeInTheDocument();
    expect(await screen.findByText('Your request is waiting')).toBeInTheDocument();
    expect(screen.getAllByText('Request pending').length).toBeGreaterThan(0);
    expect(
      await within(feed()).findByText(
        'You’ll see the posts once a moderator approves your request.',
      ),
    ).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Cancel request' }));
    const dialog = await screen.findByRole('dialog', { name: 'Cancel your request to join?' });
    await user.click(within(dialog).getByRole('button', { name: 'Cancel request' }));
    expect(await screen.findByText('Request cancelled')).toBeInTheDocument();
    expect(left).toBe(1);
    expect(await screen.findByRole('button', { name: 'Ask to join' })).toBeInTheDocument();
  });

  it('leaves after confirming', async () => {
    const state = serveCommunity();
    let left = 0;
    server.use(
      http.post(`${API}/communities/:id/leave`, () => {
        left += 1;
        state.community = makeCommunity({ my_status: 'left', my_role: 'none' });
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const { user } = await openCommunity();
    await user.click(screen.getByRole('button', { name: 'Leave community' }));
    const dialog = await screen.findByRole('dialog', { name: 'Leave Frugal Living?' });
    expect(within(dialog).getByText(/You can join again at any time\./)).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Leave community' }));
    expect(await screen.findByText('You left Frugal Living')).toBeInTheDocument();
    expect(left).toBe(1);
    expect(await screen.findByRole('button', { name: 'Join community' })).toBeInTheDocument();
  });

  it('gives the owner the settings and moderation tabs and no leave button', async () => {
    serveCommunity(makeCommunity({ my_role: 'owner' }));
    await openCommunity();
    const tabs = screen.getByRole('navigation', { name: 'Community pages' });
    expect(within(tabs).getByRole('link', { name: 'Settings' })).toHaveAttribute(
      'href',
      `/communities/${COMMUNITY_ID}/settings`,
    );
    expect(within(tabs).getByRole('link', { name: 'Moderation' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Leave community' })).not.toBeInTheDocument();
  });

  it('gives Montra staff the moderation tabs when the API says they may moderate', async () => {
    serveCommunity(makeCommunity({ my_role: 'none', my_status: 'none', can_moderate: true }), {
      posts: [],
    });
    await openCommunity(
      COMMUNITY_ID,
      'Frugal Living',
      makeUser({ onboarding_completed: true, platform_role: 'support' }),
    );
    const tabs = screen.getByRole('navigation', { name: 'Community pages' });
    expect(within(tabs).getByRole('link', { name: 'Moderation' })).toBeInTheDocument();
    // Not a member: no composer, but a way to join.
    expect(screen.queryByRole('button', { name: 'Write a post' })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Join community' })).toBeInTheDocument();
  });

  it('keeps the moderation tabs from members the API does not let moderate', async () => {
    serveCommunity(makeCommunity({ my_role: 'member', can_moderate: false }), { posts: [] });
    await openCommunity();
    expect(screen.queryByRole('navigation', { name: 'Community pages' })).not.toBeInTheDocument();
  });

  it('explains a community it cannot find', async () => {
    server.use(
      http.get(`${API}/communities/:ref`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    await openCommunity('nowhere', 'Community');
    expect(screen.getByText('We can’t find this community')).toBeInTheDocument();
    expect(screen.getAllByRole('link', { name: 'All communities' })[0]).toHaveAttribute(
      'href',
      '/communities',
    );
  });

  it('retries after an error and shows permission answers', async () => {
    let calls = 0;
    const state = serveCommunity();
    server.use(
      http.get(`${API}/communities/:ref`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 })
          : HttpResponse.json(envelope(state.community));
      }),
    );
    const { user } = await openCommunity(COMMUNITY_ID, 'Community');
    expect(screen.getByText('We couldn’t load this community')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await findPageHeading('Frugal Living')).toBeInTheDocument();
  });

  it('shows a permission message when the API refuses', async () => {
    server.use(http.get(`${API}/communities/:ref`, () => forbidden()));
    await openCommunity(COMMUNITY_ID, 'Community');
    expect(screen.getByText('You don’t have access to this')).toBeInTheDocument();
  });

  it('shows an empty feed', async () => {
    serveCommunity(makeCommunity(), { posts: [] });
    await openCommunity();
    expect(await within(feed()).findByText('No posts yet')).toBeInTheDocument();
  });

  it('writes a discussion post', async () => {
    let body: unknown = null;
    const state = serveCommunity(makeCommunity(), { posts: [] });
    server.use(
      http.post(`${API}/communities/:id/posts`, async ({ request }) => {
        body = await request.json();
        const post = makePost({ title: 'Cooking at home saved me', mine: true });
        state.posts = [post];
        return HttpResponse.json(envelope(post), { status: 201 });
      }),
    );
    const { user } = await openCommunity();
    await user.click(screen.getByRole('button', { name: 'Write a post' }));
    expect(screen.getByLabelText('Title')).toHaveFocus();
    expect(
      screen.getByText(
        /Never post card numbers, CVVs, PINs, OTPs, passwords, account numbers or balances\./,
      ),
    ).toBeInTheDocument();
    await user.type(screen.getByLabelText('Title'), 'Cooking at home saved me');
    await user.type(screen.getByLabelText(/Details/), 'Meal prep on Sundays.');
    await user.click(screen.getByRole('button', { name: 'Post' }));

    expect(await screen.findByText('Posted')).toBeInTheDocument();
    expect(body).toEqual({
      kind: 'discussion',
      title: 'Cooking at home saved me',
      body: 'Meal prep on Sundays.',
    });
    expect(
      await within(feed()).findByRole('link', { name: 'Cooking at home saved me' }),
    ).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Write a post' })).toBeInTheDocument();
  });

  it('writes a poll with a closing time', async () => {
    let body: Record<string, unknown> | null = null;
    serveCommunity(makeCommunity(), { posts: [] });
    server.use(
      http.post(`${API}/communities/:id/posts`, async ({ request }) => {
        body = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(envelope(makePost()), { status: 201 });
      }),
    );
    const { user } = await openCommunity();
    await user.click(screen.getByRole('button', { name: 'Write a post' }));
    await user.click(screen.getByRole('radio', { name: 'Poll' }));
    await user.type(screen.getByLabelText('Title'), 'Which method?');
    await user.type(screen.getByLabelText('Poll question'), 'Avalanche or snowball?');
    await user.type(screen.getByLabelText('Answer 1'), 'Avalanche');
    await user.type(screen.getByLabelText('Answer 2'), 'avalanche');
    await user.click(screen.getByRole('button', { name: 'Post' }));
    expect(await screen.findByText('Each answer must be different.')).toBeInTheDocument();
    expect(body).toBeNull();

    await user.clear(screen.getByLabelText('Answer 2'));
    await user.type(screen.getByLabelText('Answer 2'), 'Snowball');
    await user.click(screen.getByRole('button', { name: 'Add an answer' }));
    await user.type(screen.getByLabelText('Answer 3'), 'Neither');
    await user.click(
      screen.getByRole('checkbox', { name: 'People can choose more than one answer' }),
    );
    await user.selectOptions(screen.getByLabelText('Voting closes'), '7');
    const before = Date.now();
    await user.click(screen.getByRole('button', { name: 'Post' }));
    expect(await screen.findByText('Posted')).toBeInTheDocument();

    const poll = (body as unknown as { poll: { closes_at: string } }).poll;
    expect(body).toEqual({
      kind: 'poll',
      title: 'Which method?',
      poll: {
        question: 'Avalanche or snowball?',
        options: ['Avalanche', 'Snowball', 'Neither'],
        allow_multiple: true,
        closes_at: poll.closes_at,
      },
    });
    const closes = new Date(poll.closes_at).getTime();
    expect(closes).toBeGreaterThanOrEqual(before + 7 * 86_400_000 - 1000);
  });

  it('stops payment secrets and non-https links before sending', async () => {
    let calls = 0;
    serveCommunity(makeCommunity(), { posts: [] });
    server.use(
      http.post(`${API}/communities/:id/posts`, () => {
        calls += 1;
        return HttpResponse.json(envelope(makePost()), { status: 201 });
      }),
    );
    const { user } = await openCommunity();
    await user.click(screen.getByRole('button', { name: 'Write a post' }));
    await user.type(screen.getByLabelText('Title'), 'Help please');
    await user.type(screen.getByLabelText(/Details/), 'My OTP is 123456');
    await user.click(screen.getByRole('button', { name: 'Post' }));
    expect(screen.getByLabelText(/Details/)).toHaveAccessibleDescription(
      /Never share card numbers, CVVs, PINs, OTPs or passwords\./,
    );

    await user.click(screen.getByRole('radio', { name: 'Resource' }));
    await user.clear(screen.getByLabelText(/Details/));
    await user.type(screen.getByLabelText('Link'), 'http://insecure.example');
    await user.click(screen.getByRole('button', { name: 'Post' }));
    expect(screen.getByLabelText('Link')).toHaveAccessibleDescription(
      /Use a public link that starts with https:\/\/\./,
    );
    expect(calls).toBe(0);
  });

  it('explains rules the API applies to new accounts', async () => {
    serveCommunity(makeCommunity(), { posts: [] });
    server.use(http.post(`${API}/communities/:id/posts`, () => ruleViolation('new_account_links')));
    const { user } = await openCommunity();
    await user.click(screen.getByRole('button', { name: 'Write a post' }));
    await user.click(screen.getByRole('radio', { name: 'Resource' }));
    await user.type(screen.getByLabelText('Title'), 'Useful guide');
    await user.type(screen.getByLabelText('Link'), 'https://rbi.org.in');
    await user.click(screen.getByRole('button', { name: 'Post' }));
    expect(
      await screen.findByText('New accounts can share links after their first day.'),
    ).toBeInTheDocument();
  });

  it('toggles a reaction on a post, showing the counts and your reactions the API answers', async () => {
    const calls: string[] = [];
    serveCommunity(makeCommunity(), { posts: [makePost()] });
    server.use(
      http.post(`${API}/posts/:id/reactions`, async ({ request }) => {
        calls.push(`add:${((await request.json()) as { kind: string }).kind}`);
        // The API is the source of truth: it also knows about a reaction added elsewhere.
        return HttpResponse.json(
          envelope(reactionsAnswer({ helpful: 4, like: 1 }, ['helpful', 'like'])),
        );
      }),
      http.delete(`${API}/posts/:id/reactions/:kind`, ({ params }) => {
        calls.push(`remove:${String(params.kind)}`);
        return HttpResponse.json(envelope(reactionsAnswer({ helpful: 3, like: 1 }, ['like'])));
      }),
    );
    const { user } = await openCommunity();
    const helpful = await within(feed()).findByRole('button', { name: 'Helpful: 3 reactions' });
    expect(helpful).toHaveAttribute('aria-pressed', 'false');
    await user.click(helpful);
    const pressed = await within(feed()).findByRole('button', { name: 'Helpful: 4 reactions' });
    expect(pressed).toHaveAttribute('aria-pressed', 'true');
    expect(within(feed()).getByRole('button', { name: 'Like: 1 reaction' })).toHaveAttribute(
      'aria-pressed',
      'true',
    );
    await user.click(pressed);
    expect(
      await within(feed()).findByRole('button', { name: 'Helpful: 3 reactions' }),
    ).toHaveAttribute('aria-pressed', 'false');
    expect(within(feed()).getByRole('button', { name: 'Like: 1 reaction' })).toHaveAttribute(
      'aria-pressed',
      'true',
    );
    expect(calls).toEqual(['add:helpful', 'remove:helpful']);
  });

  it('pages through the feed', async () => {
    const posts: Post[] = Array.from({ length: 25 }, (_, index) =>
      makePost({
        id: `e2e2e2e2-3333-4333-8333-${String(index + 100).padStart(12, '0')}`,
        title: `Post number ${index + 1}`,
      }),
    );
    const state = serveCommunity(makeCommunity(), { posts });
    const { user } = await openCommunity();
    await within(feed()).findByRole('link', { name: 'Post number 20' });
    expect(within(feed()).queryByRole('link', { name: 'Post number 21' })).not.toBeInTheDocument();
    await user.click(within(feed()).getByRole('button', { name: 'Show more posts' }));
    expect(await within(feed()).findByRole('link', { name: 'Post number 25' })).toBeInTheDocument();
    expect(state.feedQueries).toEqual(['?sort=new&limit=20', '?sort=new&limit=20&cursor=after-20']);
    expect(
      within(feed()).queryByRole('button', { name: 'Show more posts' }),
    ).not.toBeInTheDocument();
  });

  it('explains a posting pause and an archived community', async () => {
    serveCommunity(makeCommunity({ restricted_until: '2099-01-01T10:00:00Z' }));
    const { unmount } = await openCommunity();
    expect(screen.getByText(/You can’t post or comment here until/)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Write a post' })).not.toBeInTheDocument();
    unmount();

    serveCommunity(makeCommunity({ status: 'archived' }));
    await openCommunity();
    expect(screen.getByText('This community is archived')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Write a post' })).not.toBeInTheDocument();
  });

  it('reports a post from the feed', async () => {
    let body: unknown = null;
    serveCommunity(makeCommunity(), {
      posts: [makePost({ author: { user_id: MEMBER_ID, display_name: 'Meera Rao' } })],
    });
    server.use(
      http.post(`${API}/posts/:id/reports`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(envelope({}), { status: 201 });
      }),
    );
    const { user } = await openCommunity();
    await user.click(
      await within(feed()).findByRole('button', {
        name: 'Report post: How I paid off my bike loan',
      }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Report this post' });
    await user.click(within(dialog).getByRole('button', { name: 'Send report' }));
    expect(within(dialog).getByText('Choose a reason.')).toBeInTheDocument();
    await user.click(within(dialog).getByRole('radio', { name: 'Spam or advertising' }));
    await user.click(within(dialog).getByRole('button', { name: 'Send report' }));
    expect(await screen.findByText('Thanks for reporting')).toBeInTheDocument();
    expect(body).toEqual({ reason: 'spam' });
  });

  it('explains a daily cap with when to try again', async () => {
    serveCommunity(makeCommunity(), { posts: [] });
    server.use(http.post(`${API}/communities/:id/posts`, () => dailyCapped('posts', 20, 3600)));
    const { user } = await openCommunity();
    await user.click(screen.getByRole('button', { name: 'Write a post' }));
    await user.type(screen.getByLabelText('Title'), 'One post too many');
    await user.click(screen.getByRole('button', { name: 'Post' }));
    expect(
      await screen.findByText(
        'You’ve reached today’s limit of 20 posts. You can try again in 60 minutes.',
      ),
    ).toBeInTheDocument();
  });

  it('answers a rate limit on a reaction calmly', async () => {
    serveCommunity(makeCommunity(), { posts: [makePost()] });
    server.use(
      http.post(`${API}/posts/:id/reactions`, () =>
        HttpResponse.json(errorBody({ code: 'RATE_LIMITED' }), {
          status: 429,
          headers: { 'Retry-After': '1' },
        }),
      ),
    );
    const { user } = await openCommunity();
    await user.click(await within(feed()).findByRole('button', { name: 'Like: 0 reactions' }));
    expect(
      await screen.findByText('You’re going a little fast. Try again in 1 second.'),
    ).toBeInTheDocument();
  });
});
