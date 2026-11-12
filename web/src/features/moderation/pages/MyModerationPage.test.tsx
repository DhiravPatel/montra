import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  ACTION_HIDE,
  APPEAL_ID,
  ACTION_REMOVE,
  ACTION_RESTRICT,
  ACTION_WARN,
  MOD_COMMUNITY_ID,
  MOD_POST_ID,
  REPORT_GROUP,
  daysAgo,
  daysAhead,
  makeAction,
  makeAppeal,
  makeReport,
  serveMyModeration,
} from '@/tests/moderationFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

function region(name: string) {
  return screen.getByRole('region', { name });
}

function item(title: string) {
  const heading = screen.getByRole('heading', { name: title });
  const li = heading.closest('li');
  if (!li) throw new Error(`no list item for ${title}`);
  return li;
}

describe('MyModerationPage', () => {
  it('shows your standing, the decisions about you and the reports you filed', async () => {
    serveMyModeration(
      [
        makeAction(),
        makeAction({
          id: ACTION_RESTRICT,
          action: 'restrict',
          target_type: 'profile',
          target_id: makeUser().id,
          community_id: undefined,
          reason: 'Impersonating a bank',
          expires_at: daysAhead(3),
          created_at: daysAgo(1),
        }),
        makeAction({
          id: ACTION_HIDE,
          action: 'hide',
          target_type: 'comment',
          reason: 'Hidden automatically after several reports; a moderator will review it.',
          reversed_at: daysAgo(3),
          appealable: false,
          created_at: daysAgo(5),
        }),
      ],
      [
        makeReport(),
        makeReport({
          id: REPORT_GROUP,
          target_type: 'group',
          reason: 'scam',
          details: undefined,
          status: 'dismissed',
          resolved_at: daysAgo(1),
        }),
      ],
    );
    renderRoute('/settings/moderation', { user: signedIn() });
    await findPageHeading('Moderation');

    const standing = await screen.findByRole('region', { name: 'Your standing' });
    expect(
      within(standing).getByText('Your account can’t post or comment in communities for now'),
    ).toBeInTheDocument();
    expect(within(standing).getByText(/^Until .+\.$/)).toBeInTheDocument();
    expect(within(standing).queryByText('You’re in good standing')).not.toBeInTheDocument();

    const decisions = region('Decisions about your content or account');
    expect(within(decisions).getByText(/within 30 days/)).toBeInTheDocument();
    const removed = item('Your post was removed');
    expect(within(removed).getByText('Advertising is not allowed')).toBeInTheDocument();
    expect(within(removed).getByText(/^In a community · /)).toBeInTheDocument();
    expect(within(removed).getByText('In effect')).toBeInTheDocument();
    expect(within(removed).getByRole('link', { name: 'View your post' })).toHaveAttribute(
      'href',
      `/posts/${MOD_POST_ID}`,
    );
    expect(within(removed).getByRole('link', { name: 'Open the community' })).toHaveAttribute(
      'href',
      `/communities/${MOD_COMMUNITY_ID}`,
    );
    expect(within(removed).getByText(/^You can ask for a review until .+\.$/)).toBeInTheDocument();
    expect(within(removed).getByRole('button', { name: 'Ask for a review' })).toBeInTheDocument();

    const restricted = item('Community posting paused for your account');
    expect(within(restricted).getByText(/^By the Montra team · /)).toBeInTheDocument();
    expect(within(restricted).getByText(/^Until /)).toBeInTheDocument();

    const hidden = item('Your comment was hidden');
    expect(within(hidden).getByText(/^Reversed on /)).toBeInTheDocument();
    expect(
      within(hidden).queryByRole('button', { name: 'Ask for a review' }),
    ).not.toBeInTheDocument();

    const reports = region('Reports you filed');
    expect(within(reports).getByText('Post · Spam')).toBeInTheDocument();
    expect(within(reports).getByText('Waiting for review')).toBeInTheDocument();
    expect(within(reports).getByText('Same link everywhere')).toBeInTheDocument();
    expect(within(reports).getByText('Group · Scam or fraud')).toBeInTheDocument();
    expect(within(reports).getByText('Reviewed, no action needed')).toBeInTheDocument();
    expect(within(reports).getByText(/Resolved /)).toBeInTheDocument();
  });

  it('shows the outcome of reviews on the decision and in your review requests', async () => {
    serveMyModeration(
      [
        makeAction({
          appeal: {
            id: APPEAL_ID,
            status: 'upheld',
            decision_note: 'The link was promotional.',
            created_at: daysAgo(2),
            decided_at: daysAgo(1),
          },
        }),
      ],
      [],
      [
        makeAppeal({
          status: 'upheld',
          decision_note: 'The link was promotional.',
          decided_at: daysAgo(1),
        }),
        makeAppeal({
          id: 'e4cf7b5c-0d6a-4e3f-9c7b-6a7f8e9d0c99',
          action_id: ACTION_WARN,
          action: { ...makeAppeal().action, id: ACTION_WARN, action: 'warn' },
          statement: 'I did not mean it.',
          status: 'overturned',
          decided_at: daysAgo(3),
        }),
      ],
    );
    renderRoute('/settings/moderation', { user: signedIn() });
    await findPageHeading('Moderation');
    const decisions = await screen.findByRole('region', {
      name: 'Decisions about your content or account',
    });
    const removed = within(decisions)
      .getByRole('heading', { name: 'Your post was removed' })
      .closest('li')!;
    expect(within(removed).getByText('Decision kept')).toBeInTheDocument();
    expect(within(removed).getByText(/the decision stays$/)).toBeInTheDocument();
    expect(within(removed).getByText('The link was promotional.')).toBeInTheDocument();
    expect(
      within(removed).queryByRole('button', { name: 'Ask for a review' }),
    ).not.toBeInTheDocument();

    const requests = await screen.findByRole('region', { name: 'Your review requests' });
    expect(within(requests).getByText('About: Your post was removed')).toBeInTheDocument();
    expect(within(requests).getByText('It was a free guide, not an advert.')).toBeInTheDocument();
    expect(within(requests).getByText('About: You received a warning')).toBeInTheDocument();
    expect(within(requests).getByText('Decision changed')).toBeInTheDocument();
    expect(within(requests).getByText(/the decision was reversed$/)).toBeInTheDocument();
  });

  it('shows calm empty states and good standing', async () => {
    serveMyModeration();
    renderRoute('/settings/moderation', { user: signedIn() });
    await findPageHeading('Moderation');
    expect(await screen.findByText('You’re in good standing')).toBeInTheDocument();
    expect(screen.getByText('Nothing limits your account right now.')).toBeInTheDocument();
    expect(
      screen.getByText('No moderation decisions have affected your posts, comments or account.'),
    ).toBeInTheDocument();
    expect(screen.getByText('No reports')).toBeInTheDocument();
  });

  it('counts community bans and lifts them when a later unban exists', async () => {
    serveMyModeration([
      makeAction({
        id: ACTION_RESTRICT,
        action: 'ban',
        target_type: 'member',
        created_at: daysAgo(4),
        reason: 'Repeated scams',
      }),
      makeAction({
        id: ACTION_WARN,
        action: 'unban',
        target_type: 'member',
        created_at: daysAgo(2),
        reason: undefined,
        appealable: false,
      }),
      makeAction({
        id: ACTION_HIDE,
        action: 'restrict',
        target_type: 'member',
        community_id: 'a1b2c3d4-0000-4000-8000-000000000001',
        expires_at: daysAhead(1),
        reason: 'Cool off',
      }),
    ]);
    renderRoute('/settings/moderation', { user: signedIn() });
    await findPageHeading('Moderation');
    const standing = await screen.findByRole('region', { name: 'Your standing' });
    expect(within(standing).getByText('Posting is paused in 1 community')).toBeInTheDocument();
    expect(within(standing).queryByText(/You’re banned from/)).not.toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'A community ban was lifted' })).toBeInTheDocument();
  });

  it('asks for a review within the window and shows it as waiting', async () => {
    const state = serveMyModeration([makeAction()]);
    let body: unknown = null;
    server.use(
      http.post(`${API}/moderation/actions/:id/appeals`, async ({ request, params }) => {
        expect(params.id).toBe(ACTION_REMOVE);
        body = await request.json();
        const created = makeAppeal({ created_at: new Date().toISOString() });
        // The API now lists the appeal on the action and in your appeals.
        state.actions = [
          makeAction({
            appeal: { id: created.id, status: 'open', created_at: created.created_at },
          }),
        ];
        state.appeals = [created];
        return HttpResponse.json(envelope(created), { status: 201 });
      }),
    );
    const user = userEvent.setup();
    renderRoute('/settings/moderation', { user: signedIn() });
    await findPageHeading('Moderation');
    await user.click(await screen.findByRole('button', { name: 'Ask for a review' }));
    const dialog = await screen.findByRole('dialog', { name: 'Ask for a review' });
    expect(within(dialog).getByText(/You can ask until .+\./)).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Send request' }));
    expect(
      within(dialog).getByLabelText('Why should this be reviewed?'),
    ).toHaveAccessibleDescription(/Tell us why you’re asking for a review\./);
    expect(body).toBeNull();

    await user.type(
      within(dialog).getByLabelText('Why should this be reviewed?'),
      '  It was a free guide.  ',
    );
    await user.click(within(dialog).getByRole('button', { name: 'Send request' }));

    expect(await screen.findByText('Your request for review was sent')).toBeInTheDocument();
    expect(body).toEqual({ statement: 'It was a free guide.' });
    const removed = within(region('Decisions about your content or account'))
      .getByRole('heading', { name: 'Your post was removed' })
      .closest('li')!;
    expect(await within(removed).findByText('Waiting for a decision')).toBeInTheDocument();
    expect(within(removed).getByText(/^Review requested on /)).toBeInTheDocument();
    expect(
      within(removed).queryByRole('button', { name: 'Ask for a review' }),
    ).not.toBeInTheDocument();
  });

  it('closes the review option after 30 days', async () => {
    serveMyModeration([makeAction({ created_at: daysAgo(40) })]);
    renderRoute('/settings/moderation', { user: signedIn() });
    await findPageHeading('Moderation');
    const removed = await screen.findByRole('heading', { name: 'Your post was removed' });
    const li = removed.closest('li')!;
    expect(
      within(li).getByText(/^The time to ask for a review ended on .+\.$/),
    ).toBeInTheDocument();
    expect(within(li).queryByRole('button', { name: 'Ask for a review' })).not.toBeInTheDocument();
  });

  it('explains the API’s answer when the window has passed or a review is already open', async () => {
    let calls = 0;
    const state = serveMyModeration([makeAction({ created_at: daysAgo(29) })]);
    server.use(
      http.post(`${API}/moderation/actions/:id/appeals`, () => {
        calls += 1;
        if (calls === 1) {
          return HttpResponse.json(
            errorBody({
              code: 'DOMAIN_RULE_VIOLATION',
              details: [
                { code: 'appeal_window_passed', message: 'Appeals must be made within 30 days.' },
              ],
            }),
            { status: 422 },
          );
        }
        state.actions = [
          makeAction({
            created_at: daysAgo(29),
            appeal: { id: APPEAL_ID, status: 'open', created_at: daysAgo(1) },
          }),
        ];
        return HttpResponse.json(
          errorBody({ code: 'CONFLICT', message: 'You already appealed this action.' }),
          {
            status: 409,
          },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/settings/moderation', { user: signedIn() });
    await findPageHeading('Moderation');
    await user.click(await screen.findByRole('button', { name: 'Ask for a review' }));
    const dialog = await screen.findByRole('dialog');
    await user.type(
      within(dialog).getByLabelText('Why should this be reviewed?'),
      'Please look again.',
    );
    await user.click(within(dialog).getByRole('button', { name: 'Send request' }));
    expect(
      await within(dialog).findByText('The 30-day window to ask for a review has passed.'),
    ).toBeInTheDocument();

    await user.click(within(dialog).getByRole('button', { name: 'Send request' }));
    expect(
      await screen.findByText('A review is already in progress for this decision.'),
    ).toBeInTheDocument();
    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    });
    const decisions = region('Decisions about your content or account');
    const li = within(decisions)
      .getByRole('heading', { name: 'Your post was removed' })
      .closest('li')!;
    expect(await within(li).findByText('Waiting for a decision')).toBeInTheDocument();
    expect(within(li).getByText(/^Review requested on /)).toBeInTheDocument();
  });

  it('shows a recoverable error and permission denied', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/me/moderation`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-mod' }), {
              status: 500,
            })
          : HttpResponse.json(envelope([]));
      }),
      http.get(`${API}/content-reports`, () => HttpResponse.json(envelope([]))),
      http.get(`${API}/me/moderation/appeals`, () => HttpResponse.json(envelope([]))),
    );
    const user = userEvent.setup();
    const first = renderRoute('/settings/moderation', { user: signedIn() });
    await findPageHeading('Moderation');
    expect(
      await screen.findByText('We couldn’t load decisions about your account'),
    ).toBeInTheDocument();
    expect(screen.getByText('req-mod')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByText('You’re in good standing')).toBeInTheDocument();
    first.unmount();

    server.use(
      http.get(`${API}/me/moderation`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/settings/moderation', { user: signedIn() });
    await findPageHeading('Moderation');
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });
});
