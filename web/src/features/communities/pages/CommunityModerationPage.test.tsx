import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import type { Appeal, ModerationAction, Report } from '@/features/communities/types';
import {
  APPEAL_ID,
  COMMENT_ID,
  COMMUNITY_ID,
  MEMBER_ID,
  POST_ID,
  REPORT_ID,
  makeAppeal,
  makeAppealedAction,
  makeCommunity,
  makeCommunityMember,
  makeMemberList,
  makeModerationAction,
  makeReport,
  ruleViolation,
  serveCommunity,
} from '@/tests/communitiesFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const ME = makeUser().id;

function region(name: string) {
  return screen.getByRole('region', { name });
}

interface ModerationState {
  reports: Record<string, Report[]>;
  actions: ModerationAction[];
  appeals: Appeal[];
  reportQueries: string[];
}

interface ModerationOptions {
  reports?: Record<string, Report[]>;
  actions?: ModerationAction[];
  appeals?: Appeal[];
}

function serveModeration(
  role: 'owner' | 'moderator' | 'member' = 'moderator',
  {
    reports = { open: [makeReport()] },
    actions = [makeModerationAction()],
    appeals = [makeAppeal()],
  }: ModerationOptions = {},
) {
  const banned = makeCommunityMember({
    user_id: 'd1d1d1d1-2222-4222-8222-000000000007',
    display_name: 'Spammy Sam',
    username: 'sam',
    status: 'banned',
  });
  const list = [
    makeCommunityMember({ user_id: ME, display_name: 'Asha Rao', username: 'asha', role }),
    ...makeMemberList(),
  ];
  const community = serveCommunity(makeCommunity({ my_role: role }), {
    members: { active: list, banned: [banned], '': [...list, banned] },
    posts: [],
  });
  const state: ModerationState = { reports, actions, appeals, reportQueries: [] };
  server.use(
    http.get(`${API}/communities/:id/moderation/reports`, ({ request }) => {
      const status = new URL(request.url).searchParams.get('status') ?? 'open';
      state.reportQueries.push(status);
      return HttpResponse.json(envelope(state.reports[status] ?? []));
    }),
    http.get(`${API}/communities/:id/moderation/actions`, () =>
      HttpResponse.json(envelope(state.actions)),
    ),
    http.get(`${API}/communities/:id/moderation/appeals`, () =>
      HttpResponse.json(envelope(state.appeals)),
    ),
  );
  return { state, community };
}

async function openModeration(heading = 'Community moderation') {
  const user = userEvent.setup();
  const result = renderRoute(`/communities/${COMMUNITY_ID}/moderation`, {
    user: makeUser({ onboarding_completed: true }),
  });
  await findPageHeading(heading);
  return { user, ...result };
}

function actWith(bodies: unknown[], respond?: () => Response) {
  server.use(
    http.post(`${API}/communities/:id/moderation/actions`, async ({ request }) => {
      const body = (await request.json()) as { action: string };
      bodies.push(body);
      return (
        respond?.() ?? HttpResponse.json(envelope(makeModerationAction({ action: body.action })))
      );
    }),
  );
}

describe('CommunityModerationPage', () => {
  it('is only for the owner and moderators', async () => {
    serveModeration('member');
    await openModeration();
    expect(
      screen.getByText('Only the owner and moderators can moderate this community.'),
    ).toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Reports' })).not.toBeInTheDocument();
  });

  it('explains that actions are audited and shows reports as plain text', async () => {
    serveModeration();
    await openModeration();
    expect(document.title).toBe('Community moderation · Montra');
    expect(screen.getByText('Every action is recorded')).toBeInTheDocument();
    expect(
      screen.getByText(/never anyone’s accounts, balances or transactions/),
    ).toBeInTheDocument();
    const reports = region('Reports');
    expect(await within(reports).findByText('Post · Spam or advertising')).toBeInTheDocument();
    expect(within(reports).getByText('Buy my course — https://spam.example')).toBeInTheDocument();
    // Reported content never becomes a link.
    expect(within(reports).queryByRole('link', { name: /spam\.example/ })).not.toBeInTheDocument();
    expect(within(reports).getByText('Same link everywhere')).toBeInTheDocument();
    expect(within(reports).getByText(/2 open reports about this/)).toBeInTheDocument();
    expect(within(reports).getByText('Written by Meera Rao (@meera)')).toBeInTheDocument();
    expect(within(reports).getByRole('link', { name: 'Open post' })).toHaveAttribute(
      'href',
      `/posts/${POST_ID}`,
    );
  });

  it('links a reported comment to its post and refreshes that post after acting', async () => {
    const bodies: unknown[] = [];
    let postReads = 0;
    serveModeration('moderator', {
      reports: {
        open: [
          makeReport({
            id: 'b5b5b5b5-6666-4666-8666-000000000020',
            target_type: 'comment',
            target_id: COMMENT_ID,
            post_id: POST_ID,
            target_user_id: MEMBER_ID,
            preview: 'Congratulations! See https://example.org/tips',
            details: undefined,
            open_reports: 1,
          }),
        ],
      },
    });
    actWith(bodies);
    server.use(
      http.get(`${API}/posts/:id`, () => {
        postReads += 1;
        return HttpResponse.json(envelope({ ...makeReport(), comments: [] }));
      }),
    );
    const { user } = await openModeration();
    const reports = region('Reports');
    expect(await within(reports).findByText('Comment · Spam or advertising')).toBeInTheDocument();
    expect(within(reports).getByRole('link', { name: 'Open post' })).toHaveAttribute(
      'href',
      `/posts/${POST_ID}`,
    );
    expect(within(reports).getByText('Written by Meera Rao (@meera)')).toBeInTheDocument();
    await user.click(
      within(reports).getByRole('button', {
        name: 'Take action on Comment reported for Spam or advertising',
      }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Moderation action' });
    await user.click(within(dialog).getByRole('radio', { name: /^Dismiss/ }));
    await user.click(within(dialog).getByRole('button', { name: 'Review' }));
    await user.click(within(dialog).getByRole('button', { name: 'Confirm: Dismiss report' }));
    expect(await screen.findByText('Action recorded')).toBeInTheDocument();
    expect(bodies).toEqual([
      {
        action: 'dismiss_report',
        target_type: 'comment',
        target_id: COMMENT_ID,
        report_id: 'b5b5b5b5-6666-4666-8666-000000000020',
      },
    ]);
    expect(postReads).toBe(0);
  });

  it('resolves a report with a confirmed, audited action', async () => {
    const bodies: unknown[] = [];
    const { state } = serveModeration();
    actWith(bodies, () => {
      state.reports = { open: [] };
      return HttpResponse.json(envelope(makeModerationAction({ action: 'remove' })));
    });
    const { user } = await openModeration();
    const reports = region('Reports');
    await user.click(
      await within(reports).findByRole('button', {
        name: 'Take action on Post reported for Spam or advertising',
      }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Moderation action' });
    await user.click(within(dialog).getByRole('button', { name: 'Review' }));
    expect(within(dialog).getByText('Choose an action.')).toBeInTheDocument();
    await user.click(within(dialog).getByRole('radio', { name: /^Remove/ }));
    await user.click(within(dialog).getByRole('button', { name: 'Review' }));
    expect(within(dialog).getByLabelText(/^Reason/)).toHaveAccessibleDescription(
      /Give a reason\. The person affected will see it\./,
    );
    await user.type(within(dialog).getByLabelText(/^Reason/), 'Advertising is not allowed');
    await user.click(within(dialog).getByRole('button', { name: 'Review' }));

    expect(within(dialog).getByText('Advertising is not allowed')).toBeInTheDocument();
    expect(
      within(dialog).getByText(
        /The person affected is told what happened and why, and can appeal\./,
      ),
    ).toBeInTheDocument();
    expect(bodies).toEqual([]);
    await user.click(within(dialog).getByRole('button', { name: 'Confirm: Remove' }));
    expect(await screen.findByText('Action recorded')).toBeInTheDocument();
    expect(bodies).toEqual([
      {
        action: 'remove',
        target_type: 'post',
        target_id: POST_ID,
        reason: 'Advertising is not allowed',
        report_id: REPORT_ID,
      },
    ]);
    expect(await within(reports).findByText('No open reports')).toBeInTheDocument();
  });

  it('dismisses a report without a reason', async () => {
    const bodies: unknown[] = [];
    serveModeration();
    actWith(bodies);
    const { user } = await openModeration();
    await user.click(
      await within(region('Reports')).findByRole('button', {
        name: 'Take action on Post reported for Spam or advertising',
      }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Moderation action' });
    await user.click(within(dialog).getByRole('radio', { name: /^Dismiss report/ }));
    await user.click(within(dialog).getByRole('button', { name: 'Review' }));
    expect(
      within(dialog).getByText('This is recorded in the moderation log with your account.'),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Confirm: Dismiss report' }));
    await waitFor(() => {
      expect(bodies).toEqual([
        { action: 'dismiss_report', target_type: 'post', target_id: POST_ID, report_id: REPORT_ID },
      ]);
    });
  });

  it('filters reports by status and shows empty queues', async () => {
    const { state } = serveModeration('moderator', { reports: { open: [] } });
    const { user } = await openModeration();
    const reports = region('Reports');
    expect(await within(reports).findByText('No open reports')).toBeInTheDocument();
    await user.click(within(reports).getByRole('radio', { name: 'Dismissed' }));
    expect(await within(reports).findByText('Nothing here')).toBeInTheDocument();
    expect(state.reportQueries).toEqual(['open', 'dismissed']);
  });

  it('pauses a member’s posting for a chosen time', async () => {
    const bodies: unknown[] = [];
    serveModeration();
    actWith(bodies);
    const { user } = await openModeration();
    const members = region('Members');
    await user.click(await within(members).findByRole('button', { name: 'Moderate Meera Rao' }));
    // Moderators cannot act on the owner or another moderator.
    expect(
      within(members).queryByRole('button', { name: 'Moderate Owen Shah' }),
    ).not.toBeInTheDocument();
    expect(
      within(members).queryByRole('button', { name: 'Moderate Divya Iyer' }),
    ).not.toBeInTheDocument();
    const dialog = await screen.findByRole('dialog', { name: 'Moderation action' });
    await user.click(within(dialog).getByRole('radio', { name: /^Pause posting/ }));
    await user.type(within(dialog).getByLabelText(/^Reason/), 'Cool off for a day');
    await user.click(within(dialog).getByRole('button', { name: 'Review' }));
    expect(within(dialog).getByLabelText('How long')).toHaveAccessibleDescription(
      /Choose how long the restriction lasts\./,
    );
    await user.selectOptions(within(dialog).getByLabelText('How long'), '24');
    await user.click(within(dialog).getByRole('button', { name: 'Review' }));
    expect(within(dialog).getByText('1 day')).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Confirm: Pause posting' }));
    expect(await screen.findByText('Action recorded')).toBeInTheDocument();
    expect(bodies).toEqual([
      {
        action: 'restrict',
        target_type: 'member',
        target_id: MEMBER_ID,
        reason: 'Cool off for a day',
        duration_hours: 24,
      },
    ]);
  });

  it('lets banned members back in', async () => {
    const bodies: unknown[] = [];
    serveModeration();
    actWith(bodies);
    const { user } = await openModeration();
    const members = region('Members');
    await user.click(within(members).getByRole('radio', { name: 'Banned' }));
    await user.click(await within(members).findByRole('button', { name: 'Moderate Spammy Sam' }));
    const dialog = await screen.findByRole('dialog', { name: 'Moderation action' });
    await user.click(within(dialog).getByRole('radio', { name: /^Unban/ }));
    await user.click(within(dialog).getByRole('button', { name: 'Review' }));
    await user.click(within(dialog).getByRole('button', { name: 'Confirm: Unban' }));
    await waitFor(() => {
      expect(bodies).toEqual([
        {
          action: 'unban',
          target_type: 'member',
          target_id: 'd1d1d1d1-2222-4222-8222-000000000007',
        },
      ]);
    });
  });

  it('explains rules the API applies to an action', async () => {
    serveModeration();
    actWith([], () => ruleViolation('own_content'));
    const { user } = await openModeration();
    await user.click(
      await within(region('Reports')).findByRole('button', {
        name: 'Take action on Post reported for Spam or advertising',
      }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Moderation action' });
    await user.click(within(dialog).getByRole('radio', { name: /^Warn/ }));
    await user.type(within(dialog).getByLabelText(/^Reason/), 'Please read the rules');
    await user.click(within(dialog).getByRole('button', { name: 'Review' }));
    await user.click(within(dialog).getByRole('button', { name: 'Confirm: Warn' }));
    expect(
      await within(dialog).findByText(
        'Ask another moderator to act on your own content or account.',
      ),
    ).toBeInTheDocument();
  });

  it('shows the log with names and reverses an action after confirming', async () => {
    let body: unknown = null;
    const { state } = serveModeration('moderator', {
      actions: [
        makeModerationAction(),
        makeModerationAction({
          id: 'b5b5b5b5-6666-4666-8666-000000000010',
          moderator_id: undefined,
          action: 'hide',
          reason: 'Hidden automatically after several reports; a moderator will review it.',
        }),
      ],
    });
    server.use(
      http.post(`${API}/moderation/actions/:id/reverse`, async ({ request }) => {
        body = await request.json();
        state.actions = [
          makeModerationAction({ reversed_at: '2026-11-05T09:00:00Z', appealable: false }),
        ];
        return HttpResponse.json(envelope(state.actions[0]));
      }),
    );
    const { user } = await openModeration();
    const log = region('Moderation log');
    expect(await within(log).findAllByText('Removed · Post')).not.toHaveLength(0);
    expect(within(log).getByText(/By Divya Iyer \(@divya\)/)).toBeInTheDocument();
    expect(within(log).getByText(/Automatic, after several reports/)).toBeInTheDocument();
    expect(within(log).getAllByText('Affects Meera Rao (@meera)')).toHaveLength(2);
    expect(within(log).getByText('Reason: Advertising is not allowed')).toBeInTheDocument();

    await user.click(within(log).getAllByRole('button', { name: 'Reverse: Removed · Post' })[0]!);
    const dialog = await screen.findByRole('dialog', { name: 'Reverse “Removed”?' });
    expect(
      within(dialog).getByText(/Its record stays in the log, marked as reversed\./),
    ).toBeInTheDocument();
    await user.type(within(dialog).getByLabelText(/^Note/), 'Lifted early');
    await user.click(within(dialog).getByRole('button', { name: 'Reverse action' }));
    expect(await screen.findByText('Action reversed')).toBeInTheDocument();
    expect(body).toEqual({ note: 'Lifted early' });
    expect(await within(log).findByText(/^Reversed /)).toBeInTheDocument();
  });

  it('decides an appeal, and explains when another moderator must', async () => {
    const bodies: unknown[] = [];
    let calls = 0;
    serveModeration();
    server.use(
      http.post(`${API}/moderation/appeals/:id/decide`, async ({ request, params }) => {
        bodies.push({ id: params.id, ...((await request.json()) as object) });
        calls += 1;
        return calls === 1
          ? ruleViolation('appeal_needs_other_moderator')
          : HttpResponse.json(envelope(makeAppeal({ status: 'overturned' })));
      }),
    );
    const { user } = await openModeration();
    const appeals = region('Appeals');
    expect(await within(appeals).findByText('Appeal against: Removed · Post')).toBeInTheDocument();
    expect(within(appeals).getByText(/From Meera Rao \(@meera\)/)).toBeInTheDocument();
    expect(within(appeals).getByText('Reason: Advertising is not allowed')).toBeInTheDocument();
    expect(within(appeals).getByText('It was a free guide, not an advert.')).toBeInTheDocument();
    await user.click(within(appeals).getByRole('button', { name: 'Overturn the action' }));
    const dialog = await screen.findByRole('dialog', { name: 'Overturn this action?' });
    await user.click(within(dialog).getByRole('button', { name: 'Overturn the action' }));
    expect(
      await within(dialog).findByText(
        'Another moderator must review an appeal against your action.',
      ),
    ).toBeInTheDocument();
    await user.type(within(dialog).getByLabelText(/^Note/), 'Guide was free');
    await user.click(within(dialog).getByRole('button', { name: 'Overturn the action' }));
    expect(
      await screen.findByText('Appeal decided: the action was overturned'),
    ).toBeInTheDocument();
    expect(bodies).toEqual([
      { id: APPEAL_ID, decision: 'overturned' },
      { id: APPEAL_ID, decision: 'overturned', note: 'Guide was free' },
    ]);
  });

  it('hides appeal decisions on your own action', async () => {
    serveModeration('moderator', { actions: [makeModerationAction({ moderator_id: ME })] });
    await openModeration();
    const appeals = region('Appeals');
    expect(
      await within(appeals).findByText(/This appeal is about your action/),
    ).toBeInTheDocument();
    expect(
      within(appeals).queryByRole('button', { name: 'Keep the action' }),
    ).not.toBeInTheDocument();
  });

  it('describes an appeal from the action it carries, even when the log no longer lists it', async () => {
    serveModeration('moderator', {
      actions: [],
      appeals: [
        makeAppeal({
          action: makeAppealedAction({
            action: 'ban',
            target_type: 'member',
            target_id: MEMBER_ID,
            reason: 'Repeated spam',
            reversed_at: '2026-11-05T09:00:00Z',
          }),
        }),
      ],
    });
    await openModeration();
    const appeals = region('Appeals');
    expect(await within(appeals).findByText('Appeal against: Banned · Member')).toBeInTheDocument();
    expect(within(appeals).getByText('Reason: Repeated spam')).toBeInTheDocument();
    expect(within(appeals).getByText(/Reversed /)).toBeInTheDocument();
    expect(within(appeals).getByRole('button', { name: 'Keep the action' })).toBeInTheDocument();
  });

  it('shows the state of an appeal on the logged action', async () => {
    serveModeration('moderator', {
      actions: [
        makeModerationAction({
          appeal: {
            id: APPEAL_ID,
            status: 'upheld',
            decision_note: 'Rules were clear',
            created_at: '2026-11-04T14:00:00Z',
            decided_at: '2026-11-05T09:00:00Z',
          },
        }),
      ],
      appeals: [],
    });
    await openModeration();
    const log = region('Moderation log');
    expect(
      await within(log).findByText('Appeal: Action kept Note: Rules were clear'),
    ).toBeInTheDocument();
  });

  it('offers a retry when the queue fails', async () => {
    let calls = 0;
    serveModeration();
    server.use(
      http.get(`${API}/communities/:id/moderation/reports`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 })
          : HttpResponse.json(envelope([]));
      }),
    );
    const { user } = await openModeration();
    const reports = region('Reports');
    expect(await within(reports).findByText('We couldn’t load the reports')).toBeInTheDocument();
    await user.click(within(reports).getByRole('button', { name: 'Try again' }));
    expect(await within(reports).findByText('No open reports')).toBeInTheDocument();
  });
});
