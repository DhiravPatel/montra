import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import {
  COMMENT_ID,
  COMMUNITY_ID,
  MEMBER_ID,
  OPTION_A,
  OPTION_B,
  POLL_POST_ID,
  POST_ID,
  REPLY_ID,
  makeAuthor,
  makeComment,
  makeCommunity,
  makePoll,
  makePollPost,
  makePost,
  makePostDetail,
  dailyCapped,
  reactionsAnswer,
  rateLimited,
  serveCommunity,
  servePost,
} from '@/tests/communitiesFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const ME = makeUser().id;

async function openPost(
  id: string = POST_ID,
  heading: string | RegExp = 'How I paid off my bike loan',
) {
  const user = userEvent.setup();
  const result = renderRoute(`/posts/${id}`, { user: makeUser({ onboarding_completed: true }) });
  await findPageHeading(heading);
  return { user, ...result };
}

function comments() {
  return screen.getByRole('region', { name: /comments?$/ });
}

describe('PostPage', () => {
  it('shows the post as text with safe links, mentions and threaded comments', async () => {
    servePost(
      makePostDetail({
        body: 'Paid it off <script>alert(1)</script>\nthanks @asha!\n\nGuide: https://example.org/payoff. Not a link: javascript:alert(1)',
      }),
    );
    await openPost();
    expect(document.title).toBe('Community post · Montra');
    expect(screen.getByRole('link', { name: 'Back to Frugal Living' })).toHaveAttribute(
      'href',
      `/communities/${COMMUNITY_ID}`,
    );
    const article = screen.getByRole('article', { name: 'Post' });
    expect(
      within(article).getByText(/Paid it off <script>alert\(1\)<\/script>/),
    ).toBeInTheDocument();
    expect(document.querySelector('script')).toBeNull();
    expect(within(article).getByText('@asha')).toHaveClass('font-semibold');
    const link = within(article).getByRole('link', { name: /https:\/\/example\.org\/payoff/ });
    expect(link).toHaveAttribute('href', 'https://example.org/payoff');
    expect(link).toHaveAttribute('rel', 'noopener noreferrer nofollow');
    expect(within(article).queryByRole('link', { name: /javascript/ })).not.toBeInTheDocument();
    expect(within(article).getByText('Personal experience')).toBeInTheDocument();

    const thread = comments();
    expect(within(thread).getByRole('heading', { name: '2 comments' })).toBeInTheDocument();
    const first = within(thread).getByRole('article', { name: 'Comment by Divya Iyer' });
    expect(within(first).getByRole('link', { name: /example\.org\/tips/ })).toHaveAttribute(
      'rel',
      'noopener noreferrer nofollow',
    );
    const replies = within(thread).getByRole('list', { name: 'Replies to Divya Iyer' });
    expect(
      within(replies).getByRole('article', { name: 'Comment by Meera Rao' }),
    ).toHaveTextContent('Thank you!');
  });

  it('lets the author edit the post', async () => {
    let body: unknown = null;
    servePost(makePostDetail({ mine: true }));
    server.use(
      http.patch(`${API}/posts/:id`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(
          envelope(
            makePost({
              mine: true,
              title: 'Paid off my bike loan!',
              edited_at: '2026-11-05T09:00:00Z',
            }),
          ),
        );
      }),
    );
    const { user } = await openPost();
    await user.click(screen.getByRole('button', { name: 'Edit post' }));
    const title = screen.getByLabelText('Title');
    expect(title).toHaveFocus();
    await user.clear(title);
    await user.type(title, 'Paid off my bike loan!');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    expect(await screen.findByText('Post updated')).toBeInTheDocument();
    expect(await findPageHeading('Paid off my bike loan!')).toBeInTheDocument();
    expect(body).toEqual({
      title: 'Paid off my bike loan!',
      body: 'I paid a little extra each month.\n\nThanks @asha for the idea! Guide: https://example.org/payoff.',
      label: 'personal_experience',
    });
  });

  it('deletes the author’s post after confirming and returns to the community', async () => {
    let deleted = 0;
    servePost(makePostDetail({ mine: true }));
    serveCommunity(makeCommunity(), { posts: [] });
    server.use(
      http.delete(`${API}/posts/:id`, () => {
        deleted += 1;
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const { user, router } = await openPost();
    await user.click(screen.getByRole('button', { name: 'Delete post' }));
    const dialog = await screen.findByRole('dialog', { name: 'Delete this post?' });
    await user.click(within(dialog).getByRole('button', { name: 'Delete post' }));
    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/communities/${COMMUNITY_ID}`);
    });
    expect(deleted).toBe(1);
    expect(await screen.findByText('Post deleted')).toBeInTheDocument();
  });

  it('adds a comment and a reply', async () => {
    const bodies: unknown[] = [];
    const state = servePost();
    server.use(
      http.post(`${API}/posts/:id/comments`, async ({ request }) => {
        bodies.push(await request.json());
        return HttpResponse.json(envelope(makeComment({ id: 'new', mine: true })), { status: 201 });
      }),
    );
    const { user } = await openPost();
    const thread = comments();
    await user.click(within(thread).getByRole('button', { name: 'Post comment' }));
    expect(within(thread).getByLabelText('Add a comment')).toHaveAccessibleDescription(
      /Write something first\./,
    );
    await user.type(within(thread).getByLabelText('Add a comment'), 'Well done!');
    await user.click(within(thread).getByRole('button', { name: 'Post comment' }));
    expect(await screen.findByText('Comment posted')).toBeInTheDocument();
    await waitFor(() => {
      expect(state.reads).toBeGreaterThan(1);
    });

    await user.click(within(thread).getByRole('button', { name: 'Reply to Divya Iyer' }));
    const reply = within(thread).getByLabelText('Your reply to Divya Iyer');
    expect(reply).toHaveFocus();
    await user.type(reply, 'Agreed');
    await user.click(within(thread).getByRole('button', { name: 'Post reply' }));
    expect(await screen.findByText('Reply posted')).toBeInTheDocument();
    expect(bodies).toEqual([
      { body: 'Well done!' },
      { body: 'Agreed', parent_comment_id: COMMENT_ID },
    ]);
  });

  it('edits and deletes your own comment', async () => {
    let edited: unknown = null;
    let deleted = '';
    const mine = makeComment({
      id: REPLY_ID,
      author: makeAuthor({ user_id: ME, display_name: 'Asha Rao' }),
      body: 'First try',
      mine: true,
    });
    servePost(makePostDetail({}, [mine]));
    server.use(
      http.patch(`${API}/comments/:id`, async ({ request }) => {
        edited = await request.json();
        return HttpResponse.json(
          envelope({ ...mine, body: 'Second try', edited_at: '2026-11-05T09:00:00Z' }),
        );
      }),
      http.delete(`${API}/comments/:id`, ({ params }) => {
        deleted = String(params.id);
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const { user } = await openPost();
    const thread = comments();
    await user.click(within(thread).getByRole('button', { name: 'Edit your comment' }));
    const field = within(thread).getByLabelText('Edit your comment');
    await user.clear(field);
    await user.type(field, 'Second try');
    await user.click(within(thread).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Comment updated')).toBeInTheDocument();
    expect(within(thread).getByText('Second try')).toBeInTheDocument();
    expect(edited).toEqual({ body: 'Second try' });

    await user.click(within(thread).getByRole('button', { name: 'Delete your comment' }));
    const dialog = await screen.findByRole('dialog', { name: 'Delete your comment?' });
    await user.click(within(dialog).getByRole('button', { name: 'Delete comment' }));
    expect(await screen.findByText('Comment deleted')).toBeInTheDocument();
    expect(deleted).toBe(REPLY_ID);
  });

  it('toggles a reaction on a comment from the API’s answer', async () => {
    servePost();
    server.use(
      http.post(`${API}/comments/:id/reactions`, () =>
        HttpResponse.json(envelope(reactionsAnswer({ support: 2 }, ['support']))),
      ),
    );
    const { user } = await openPost();
    const first = within(comments()).getByRole('article', { name: 'Comment by Divya Iyer' });
    await user.click(within(first).getByRole('button', { name: 'Support: 1 reaction' }));
    expect(
      await within(first).findByRole('button', { name: 'Support: 2 reactions' }),
    ).toHaveAttribute('aria-pressed', 'true');
  });

  it('votes in a poll and can change the vote', async () => {
    const bodies: unknown[] = [];
    servePost(makePostDetail(makePollPost(), []));
    server.use(
      http.post(`${API}/posts/:id/poll/votes`, async ({ request }) => {
        const body = (await request.json()) as { option_ids: string[] };
        bodies.push(body);
        return HttpResponse.json(
          envelope(
            makePoll({
              my_votes: body.option_ids,
              options: [
                {
                  id: OPTION_A,
                  label: 'Avalanche',
                  votes: body.option_ids.includes(OPTION_A) ? 4 : 3,
                },
                {
                  id: OPTION_B,
                  label: 'Snowball',
                  votes: body.option_ids.includes(OPTION_B) ? 2 : 1,
                },
              ],
              total_votes: 5,
            }),
          ),
        );
      }),
    );
    const { user } = await openPost(POLL_POST_ID, 'Which payoff method?');
    const poll = screen.getByRole('group', { name: 'Avalanche or snowball?' });
    expect(within(poll).getByText('3 votes (75%)')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Vote' }));
    expect(await screen.findByText('Choose an answer.')).toBeInTheDocument();
    await user.click(within(poll).getByRole('radio', { name: 'Snowball' }));
    await user.click(screen.getByRole('button', { name: 'Vote' }));
    expect(await screen.findByText('Vote saved')).toBeInTheDocument();
    expect(await screen.findByText('2 votes (40%)')).toBeInTheDocument();
    expect(screen.getByText('Your vote')).toBeInTheDocument();
    await user.click(screen.getByRole('radio', { name: 'Avalanche' }));
    await user.click(screen.getByRole('button', { name: 'Change vote' }));
    await waitFor(() => {
      expect(bodies).toEqual([{ option_ids: [OPTION_B] }, { option_ids: [OPTION_A] }]);
    });
  });

  it('reports a post with details, and says so when it was already reported', async () => {
    const bodies: unknown[] = [];
    let calls = 0;
    servePost();
    server.use(
      http.post(`${API}/posts/:id/reports`, async ({ request }) => {
        bodies.push(await request.json());
        calls += 1;
        return calls === 1
          ? HttpResponse.json(envelope({}), { status: 201 })
          : HttpResponse.json(errorBody({ code: 'CONFLICT' }), { status: 409 });
      }),
    );
    const { user } = await openPost();
    await user.click(screen.getByRole('button', { name: 'Report post' }));
    let dialog = await screen.findByRole('dialog', { name: 'Report this post' });
    await user.click(within(dialog).getByRole('radio', { name: 'Scam or fraud' }));
    await user.type(within(dialog).getByLabelText(/Details/), 'Asks people to send money');
    await user.click(within(dialog).getByRole('button', { name: 'Send report' }));
    expect(await screen.findByText('Thanks for reporting')).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Report post' }));
    dialog = await screen.findByRole('dialog', { name: 'Report this post' });
    await user.click(within(dialog).getByRole('radio', { name: 'Scam or fraud' }));
    await user.click(within(dialog).getByRole('button', { name: 'Send report' }));
    expect(
      await screen.findByText('You already reported this. Moderators will review it.'),
    ).toBeInTheDocument();
    expect(bodies).toEqual([
      { reason: 'scam', details: 'Asks people to send money' },
      { reason: 'scam' },
    ]);
  });

  it('reports a comment through content reports', async () => {
    let body: unknown = null;
    servePost();
    server.use(
      http.post(`${API}/content-reports`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(envelope({}), { status: 201 });
      }),
    );
    const { user } = await openPost();
    await user.click(
      within(comments()).getByRole('button', { name: 'Report comment by Divya Iyer' }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Report this comment' });
    await user.click(within(dialog).getByRole('radio', { name: 'Harassment or bullying' }));
    await user.click(within(dialog).getByRole('button', { name: 'Send report' }));
    expect(await screen.findByText('Thanks for reporting')).toBeInTheDocument();
    expect(body).toEqual({ target_type: 'comment', target_id: COMMENT_ID, reason: 'harassment' });
  });

  it('shows moderation states the API returns', async () => {
    servePost(
      makePostDetail({ mine: true, status: 'hidden', removed_reason: 'Off topic' }, [
        makeComment({ status: 'removed', body: '' }),
      ]),
    );
    const { unmount } = await openPost();
    expect(screen.getByText('This post is hidden')).toBeInTheDocument();
    expect(screen.getByText('Reason: Off topic')).toBeInTheDocument();
    expect(screen.getByText('This comment was removed')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Edit post' })).not.toBeInTheDocument();
    unmount();

    servePost(makePostDetail({ status: 'deleted', body: '' }, []));
    await openPost(POST_ID, 'Deleted post');
    expect(screen.getByText('The author deleted this post.')).toBeInTheDocument();
  });

  it('explains a post it cannot show', async () => {
    servePost();
    await openPost(MEMBER_ID, 'Community post');
    expect(screen.getByText('This post isn’t available')).toBeInTheDocument();
  });

  it('asks visitors to join before commenting', async () => {
    servePost(makePostDetail(), makeCommunity({ my_status: 'none', my_role: 'none' }));
    await openPost();
    const thread = comments();
    expect(await within(thread).findByText(/Join the community to comment\./)).toBeInTheDocument();
    expect(within(thread).queryByLabelText('Add a comment')).not.toBeInTheDocument();
    expect(
      within(thread).queryByRole('button', { name: 'Reply to Divya Iyer' }),
    ).not.toBeInTheDocument();
  });

  it('answers comment limits calmly, with the daily cap when the API names it', async () => {
    let calls = 0;
    servePost();
    server.use(
      http.post(`${API}/posts/:id/comments`, () => {
        calls += 1;
        return calls === 1 ? rateLimited() : dailyCapped('comments', 300, 7200);
      }),
    );
    const { user } = await openPost();
    await user.type(within(comments()).getByLabelText('Add a comment'), 'Hello');
    await user.click(within(comments()).getByRole('button', { name: 'Post comment' }));
    expect(
      await screen.findByText('You’ve reached today’s limit for this. You can try again later.'),
    ).toBeInTheDocument();
    await user.click(within(comments()).getByRole('button', { name: 'Post comment' }));
    expect(
      await screen.findByText(
        'You’ve reached today’s limit of 300 comments. You can try again in 2 hours.',
      ),
    ).toBeInTheDocument();
  });

  it('lets moderators act on a comment after confirming', async () => {
    let body: unknown = null;
    servePost(makePostDetail(), makeCommunity({ my_role: 'moderator' }));
    server.use(
      http.post(`${API}/communities/:id/moderation/actions`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(envelope({ id: 'a', action: 'hide' }));
      }),
    );
    const { user } = await openPost();
    await user.click(
      within(comments()).getByRole('button', { name: 'Moderate comment by Divya Iyer' }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Moderation action' });
    await user.click(within(dialog).getByRole('radio', { name: /^Hide/ }));
    await user.click(within(dialog).getByRole('button', { name: 'Review' }));
    expect(within(dialog).getByLabelText(/^Reason/)).toHaveAccessibleDescription(
      /Give a reason\. The person affected will see it\./,
    );
    await user.type(within(dialog).getByLabelText(/^Reason/), 'Please keep it on topic');
    await user.click(within(dialog).getByRole('button', { name: 'Review' }));
    expect(
      within(dialog).getByText(/recorded in the moderation log with your account/),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Confirm: Hide' }));
    expect(await screen.findByText('Action recorded')).toBeInTheDocument();
    expect(body).toEqual({
      action: 'hide',
      target_type: 'comment',
      target_id: COMMENT_ID,
      reason: 'Please keep it on topic',
    });
  });
});
