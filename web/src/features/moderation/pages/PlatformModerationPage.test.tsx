import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  ACTION_REMOVE,
  daysAgo,
  ACTION_WARN,
  ACTION_HIDE,
  ACTION_RESTRICT,
  APPEAL_ID,
  MOD_POST_ID,
  REPORTED_USER_ID,
  REPORT_GROUP,
  REPORT_POST,
  REPORT_PROFILE,
  daysAhead,
  makeAction,
  makeAppeal,
  makeReport,
  makeStaff,
  serveStaffActions,
  serveStaffQueues,
} from '@/tests/moderationFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function region(name: string) {
  return screen.getByRole('region', { name });
}

function reportItem(title: string) {
  const heading = within(region('Reports')).getByRole('heading', { name: title });
  const li = heading.closest('li');
  if (!li) throw new Error(`no list item for ${title}`);
  return li;
}

const profileReport = () =>
  makeReport({
    id: REPORT_PROFILE,
    target_type: 'profile',
    target_id: REPORTED_USER_ID,
    community_id: undefined,
    reason: 'impersonation',
    details: 'Pretends to be a bank',
  });

const escalatedPost = () =>
  makeReport({
    id: REPORT_POST,
    status: 'escalated',
    preview: 'Buy my course — limited offer',
    open_reports: 3,
    details: undefined,
  });

describe('PlatformModerationPage', () => {
  it('shows the queue and open appeals as the API returns them, and explains the audit', async () => {
    const asked = serveStaffQueues(
      {
        open: [
          profileReport(),
          escalatedPost(),
          makeReport({
            id: REPORT_GROUP,
            target_type: 'group',
            community_id: undefined,
            reason: 'scam',
            details: undefined,
          }),
        ],
        actioned: [
          makeReport({
            id: 'c0c0c0c0-1111-4111-8111-000000000001',
            status: 'actioned',
            resolved_at: '2026-11-04T10:00:00Z',
          }),
        ],
      },
      [makeAppeal()],
    );
    const user = userEvent.setup();
    renderRoute('/staff/moderation', { user: makeStaff() });
    await findPageHeading('Platform moderation');
    expect(screen.getByText('Every action is audited')).toBeInTheDocument();

    const profile = await waitFor(() => reportItem('Profile · Impersonation'));
    expect(within(profile).getByText('Pretends to be a bank')).toBeInTheDocument();
    expect(within(profile).getByText(/^Reported to the Montra team · /)).toBeInTheDocument();
    expect(within(profile).getByText(REPORTED_USER_ID)).toBeInTheDocument();
    expect(within(profile).getByRole('button', { name: 'Take action' })).toBeInTheDocument();

    const post = reportItem('Post · Spam');
    expect(within(post).getByText('Passed to the Montra team')).toBeInTheDocument();
    expect(within(post).getByText('Buy my course — limited offer')).toBeInTheDocument();
    expect(within(post).getByText('3 open reports about this')).toBeInTheDocument();
    expect(within(post).getByText(/^Escalated by community moderators · /)).toBeInTheDocument();

    const group = reportItem('Group · Scam or fraud');
    expect(within(group).getByText(/Group reports can only be dismissed here/)).toBeInTheDocument();
    expect(within(group).getByRole('button', { name: 'Take action' })).toBeInTheDocument();

    const appeals = region('Open appeals');
    expect(within(appeals).getByText('Appeal of a community decision')).toBeInTheDocument();
    expect(within(appeals).getByText('Against: Remove · Post')).toBeInTheDocument();
    expect(within(appeals).getByText('It was a free guide, not an advert.')).toBeInTheDocument();
    expect(within(appeals).getByText(ACTION_REMOVE)).toBeInTheDocument();

    await user.selectOptions(screen.getByLabelText('Show'), 'actioned');
    await waitFor(() => {
      expect(within(reportItem('Post · Spam')).getByText('Action taken')).toBeInTheDocument();
    });
    expect(within(reportItem('Post · Spam')).getByText(/· Resolved /)).toBeInTheDocument();
    expect(
      within(region('Reports')).queryByRole('button', { name: 'Take action' }),
    ).not.toBeInTheDocument();
    expect(asked).toEqual(['open', 'actioned']);
  });

  it('takes an action on a report only after a confirmed summary', async () => {
    let calls = 0;
    serveStaffQueues({ open: [profileReport()] });
    const listed = serveStaffActions();
    let body: unknown = null;
    server.use(
      http.post(`${API}/moderation/actions`, async ({ request }) => {
        body = await request.json();
        listed.actions = [
          makeAction({
            id: ACTION_RESTRICT,
            action: 'restrict',
            target_type: 'profile',
            target_id: REPORTED_USER_ID,
            community_id: undefined,
            reason: 'Impersonating a bank',
            expires_at: daysAhead(3),
          }),
        ];
        return HttpResponse.json(
          envelope(
            makeAction({
              id: ACTION_RESTRICT,
              action: 'restrict',
              target_type: 'profile',
              target_id: REPORTED_USER_ID,
              target_user_id: REPORTED_USER_ID,
              community_id: undefined,
              moderator_id: makeStaff().id,
              report_id: REPORT_PROFILE,
              reason: 'Impersonating a bank',
              expires_at: daysAhead(3),
            }),
          ),
        );
      }),
      http.get(`${API}/moderation/reports`, () => {
        calls += 1;
        return HttpResponse.json(envelope(calls === 1 ? [profileReport()] : []));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/staff/moderation', { user: makeStaff() });
    await findPageHeading('Platform moderation');
    await user.click(
      await within(await waitFor(() => reportItem('Profile · Impersonation'))).findByRole(
        'button',
        { name: 'Take action' },
      ),
    );

    const dialog = await screen.findByRole('dialog', { name: 'Act on this report' });
    expect(within(dialog).getByText(REPORTED_USER_ID)).toBeInTheDocument();
    await user.selectOptions(within(dialog).getByLabelText('Action'), 'restrict');
    await user.click(within(dialog).getByRole('button', { name: 'Review action' }));
    await waitFor(() => {
      expect(within(dialog).getByLabelText('Reason')).toHaveAccessibleDescription(
        /Give a reason\. The person affected will see it\./,
      );
    });
    expect(within(dialog).getByLabelText('How long')).toHaveAccessibleDescription(
      /Choose how long the restriction lasts\./,
    );
    await user.type(within(dialog).getByLabelText('Reason'), 'Impersonating a bank');
    await user.selectOptions(within(dialog).getByLabelText('How long'), '72');
    await user.click(within(dialog).getByRole('button', { name: 'Review action' }));

    // The summary step: nothing is sent until it is confirmed.
    expect(
      await within(dialog).findByRole('heading', { name: 'Check before you confirm' }),
    ).toHaveFocus();
    expect(within(dialog).getByText('Restrict from communities')).toBeInTheDocument();
    expect(within(dialog).getByText('3 days')).toBeInTheDocument();
    expect(
      within(dialog).getByText(/The person affected sees the reason, not your name\./),
    ).toBeInTheDocument();
    expect(body).toBeNull();
    await user.click(within(dialog).getByRole('button', { name: 'Confirm action' }));

    expect(await screen.findByText('Action recorded')).toBeInTheDocument();
    expect(body).toEqual({
      action: 'restrict',
      target_type: 'profile',
      target_id: REPORTED_USER_ID,
      reason: 'Impersonating a bank',
      report_id: REPORT_PROFILE,
      duration_hours: 72,
    });
    // The queue and the platform action list are refreshed from the API.
    expect(await within(region('Reports')).findByText('No reports here')).toBeInTheDocument();
    const list = region('Platform actions');
    expect(
      await within(list).findByText('Restrict from communities · Profile'),
    ).toBeInTheDocument();
    expect(
      within(list).getByRole('button', { name: 'Reverse: Restrict from communities · Profile' }),
    ).toBeInTheDocument();
  });

  it('starts a new action by ID and returns to the form on API field errors', async () => {
    serveStaffQueues();
    let calls = 0;
    server.use(
      http.post(`${API}/moderation/actions`, () => {
        calls += 1;
        return HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [
              {
                field: 'body.reason',
                message: 'Give the reason in plain text (up to 500 characters).',
              },
            ],
          }),
          { status: 422 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/staff/moderation', { user: makeStaff() });
    await findPageHeading('Platform moderation');
    await user.click(screen.getByRole('button', { name: 'New action' }));
    const dialog = await screen.findByRole('dialog', { name: 'Take an action' });
    await user.selectOptions(within(dialog).getByLabelText('What to act on'), 'post');
    await user.type(within(dialog).getByLabelText('ID'), 'not-an-id');
    await user.selectOptions(within(dialog).getByLabelText('Action'), 'lock');
    await user.click(within(dialog).getByRole('button', { name: 'Review action' }));
    await waitFor(() => {
      expect(within(dialog).getByLabelText('ID')).toHaveAccessibleDescription(
        /Enter a valid ID \(a UUID\)\./,
      );
    });
    await user.clear(within(dialog).getByLabelText('ID'));
    await user.type(within(dialog).getByLabelText('ID'), MOD_POST_ID);
    await user.type(within(dialog).getByLabelText(/^Reason/), 'Thread went off topic');
    await user.click(within(dialog).getByRole('button', { name: 'Review action' }));
    await user.click(await within(dialog).findByRole('button', { name: 'Confirm action' }));

    await waitFor(() => {
      expect(within(dialog).getByLabelText(/^Reason/)).toHaveAccessibleDescription(
        /Give the reason in plain text \(up to 500 characters\)\./,
      );
    });
    expect(within(dialog).getByLabelText(/^Reason/)).toHaveFocus();
    expect(calls).toBe(1);
  });

  it('reverses an action after confirming, with an optional note', async () => {
    serveStaffQueues();
    let body: unknown = null;
    let reversedId = '';
    server.use(
      http.post(`${API}/moderation/actions/:id/reverse`, async ({ request, params }) => {
        reversedId = String(params.id);
        body = await request.json();
        return HttpResponse.json(
          envelope(
            makeAction({
              id: String(params.id),
              action: 'ban',
              target_type: 'profile',
              community_id: undefined,
              reversed_at: new Date().toISOString(),
              appealable: false,
            }),
          ),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/staff/moderation', { user: makeStaff() });
    await findPageHeading('Platform moderation');
    const visit = region('Platform actions');
    expect(await within(visit).findByText('No actions match')).toBeInTheDocument();
    await user.click(
      within(visit).getByRole('button', { name: 'Reverse another action by its ID' }),
    );
    await user.type(within(visit).getByLabelText('Action ID'), 'x');
    await user.click(within(visit).getByRole('button', { name: 'Continue' }));
    expect(within(visit).getByLabelText('Action ID')).toHaveAccessibleDescription(
      /Enter a valid action ID/,
    );
    await user.clear(within(visit).getByLabelText('Action ID'));
    await user.type(within(visit).getByLabelText('Action ID'), ACTION_RESTRICT);
    await user.click(within(visit).getByRole('button', { name: 'Continue' }));

    const dialog = await screen.findByRole('dialog', { name: 'Reverse this action?' });
    expect(within(dialog).getByText(ACTION_RESTRICT)).toBeInTheDocument();
    expect(
      within(dialog).getByText('This is recorded in the audit log with your account.'),
    ).toBeInTheDocument();
    await user.type(
      within(dialog).getByLabelText(/^Note for the audit log/),
      'Lifted early after review',
    );
    await user.click(within(dialog).getByRole('button', { name: 'Reverse action' }));

    expect(await screen.findByText('Action reversed')).toBeInTheDocument();
    expect(reversedId).toBe(ACTION_RESTRICT);
    expect(body).toEqual({ note: 'Lifted early after review' });
  });

  it('lists platform actions with filters and more pages, and reverses one from the list', async () => {
    serveStaffQueues();
    const listed = serveStaffActions(
      [
        makeAction({
          id: ACTION_RESTRICT,
          action: 'restrict',
          target_type: 'profile',
          target_id: REPORTED_USER_ID,
          target_user_id: REPORTED_USER_ID,
          community_id: undefined,
          reason: 'Impersonating a bank',
          expires_at: daysAhead(3),
          appeal: { id: APPEAL_ID, status: 'open', created_at: daysAgo(1) },
        }),
        makeAction({
          id: ACTION_WARN,
          action: 'warn',
          target_type: 'community',
          community_id: undefined,
          reversed_at: daysAgo(1),
        }),
        makeAction({
          id: REPORT_GROUP,
          action: 'dismiss_report',
          target_type: 'group',
          community_id: undefined,
          reason: undefined,
        }),
      ],
      2,
    );
    let reversed = '';
    server.use(
      http.post(`${API}/moderation/actions/:id/reverse`, ({ params }) => {
        reversed = String(params.id);
        return HttpResponse.json(
          envelope(makeAction({ id: String(params.id), reversed_at: daysAgo(0) })),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/staff/moderation', { user: makeStaff() });
    await findPageHeading('Platform moderation');
    const list = region('Platform actions');
    expect(
      await within(list).findByText('Restrict from communities · Profile'),
    ).toBeInTheDocument();
    expect(within(list).getByText('Appeal: Waiting for a decision')).toBeInTheDocument();
    expect(within(list).getByText('Impersonating a bank')).toBeInTheDocument();
    expect(within(list).getByText(/^Reversed /)).toBeInTheDocument();
    expect(within(list).queryByText(/· Group$/)).not.toBeInTheDocument();
    await user.click(within(list).getByRole('button', { name: 'Load more actions' }));
    expect(await within(list).findByText(/· Group$/)).toBeInTheDocument();
    expect(
      within(list).queryByRole('button', { name: 'Load more actions' }),
    ).not.toBeInTheDocument();

    // Filters go to the API (IDs are checked first).
    await user.selectOptions(within(list).getByLabelText('Status'), 'active');
    await user.selectOptions(within(list).getByLabelText('What to act on'), 'profile');
    await user.type(within(list).getByLabelText(/^Person ID/), 'nope');
    await user.click(within(list).getByRole('button', { name: 'Show actions' }));
    expect(within(list).getByLabelText(/^Person ID/)).toHaveAccessibleDescription(
      /Enter a valid ID \(a UUID\)\./,
    );
    await user.clear(within(list).getByLabelText(/^Person ID/));
    await user.type(within(list).getByLabelText(/^Person ID/), REPORTED_USER_ID);
    await user.click(within(list).getByRole('button', { name: 'Show actions' }));
    await waitFor(() => {
      expect(listed.queries.at(-1)).toBe(
        `status=active&target_type=profile&target_user_id=${REPORTED_USER_ID}&limit=50`,
      );
    });
    expect(listed.queries.slice(0, 2)).toEqual(['limit=50', 'limit=50&cursor=after-2']);

    await user.click(
      await within(list).findByRole('button', {
        name: 'Reverse: Restrict from communities · Profile',
      }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Reverse this action?' });
    await user.click(within(dialog).getByRole('button', { name: 'Reverse action' }));
    expect(await screen.findByText('Action reversed')).toBeInTheDocument();
    expect(reversed).toBe(ACTION_RESTRICT);
  });

  it('dismisses a group report: the only action a reported group takes', async () => {
    serveStaffQueues({
      open: [
        makeReport({
          id: REPORT_GROUP,
          target_type: 'group',
          community_id: undefined,
          reason: 'scam',
          details: undefined,
        }),
      ],
    });
    let body: unknown = null;
    server.use(
      http.post(`${API}/moderation/actions`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(
          envelope(
            makeAction({
              action: 'dismiss_report',
              target_type: 'group',
              community_id: undefined,
              report_id: REPORT_GROUP,
            }),
          ),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/staff/moderation', { user: makeStaff() });
    await findPageHeading('Platform moderation');
    const group = await waitFor(() => reportItem('Group · Scam or fraud'));
    await user.click(within(group).getByRole('button', { name: 'Take action' }));
    const dialog = await screen.findByRole('dialog', { name: 'Act on this report' });
    const options = within(within(dialog).getByLabelText('Action')).getAllByRole('option');
    expect(options.map((option) => option.textContent)).toEqual([
      'Choose an action',
      'Dismiss the report',
    ]);
    await user.selectOptions(within(dialog).getByLabelText('Action'), 'dismiss_report');
    await user.click(within(dialog).getByRole('button', { name: 'Review action' }));
    await user.click(await within(dialog).findByRole('button', { name: 'Confirm action' }));
    expect(await screen.findByText('Action recorded')).toBeInTheDocument();
    expect(body).toEqual({
      action: 'dismiss_report',
      target_type: 'group',
      target_id: makeReport().target_id,
      report_id: REPORT_GROUP,
    });
  });

  it('links a reported comment to its post and shows the reported person', async () => {
    serveStaffQueues({
      escalated: [
        makeReport({
          target_type: 'comment',
          target_id: ACTION_HIDE,
          post_id: MOD_POST_ID,
          target_user_id: REPORTED_USER_ID,
          status: 'escalated',
        }),
      ],
    });
    const user = userEvent.setup();
    renderRoute('/staff/moderation', { user: makeStaff() });
    await findPageHeading('Platform moderation');
    await user.selectOptions(screen.getByLabelText('Show'), 'escalated');
    const comment = await waitFor(() => reportItem('Comment · Spam'));
    expect(within(comment).getByRole('link', { name: 'Open the post' })).toHaveAttribute(
      'href',
      `/posts/${MOD_POST_ID}`,
    );
    expect(within(comment).getByText(REPORTED_USER_ID)).toBeInTheDocument();
  });

  it('decides an appeal in two steps and shows the API’s other-moderator rule', async () => {
    let appeals = [makeAppeal()];
    serveStaffActions();
    server.use(
      http.get(`${API}/moderation/reports`, () => HttpResponse.json(envelope([]))),
      http.get(`${API}/moderation/appeals`, () => HttpResponse.json(envelope(appeals))),
    );
    let calls = 0;
    let body: unknown = null;
    server.use(
      http.post(`${API}/moderation/appeals/:id/decide`, async ({ request, params }) => {
        expect(params.id).toBe(APPEAL_ID);
        calls += 1;
        body = await request.json();
        if (calls === 1) {
          return HttpResponse.json(
            errorBody({
              code: 'DOMAIN_RULE_VIOLATION',
              details: [
                {
                  code: 'appeal_needs_other_moderator',
                  message: 'Another moderator must review an appeal against your action.',
                },
              ],
            }),
            { status: 422 },
          );
        }
        appeals = [];
        return HttpResponse.json(
          envelope(
            makeAppeal({
              status: 'overturned',
              decided_at: new Date().toISOString(),
              decision_note: 'Guide was free',
            }),
          ),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/staff/moderation', { user: makeStaff() });
    await findPageHeading('Platform moderation');
    await user.click(await within(region('Open appeals')).findByRole('button', { name: 'Decide' }));
    const dialog = await screen.findByRole('dialog', { name: 'Decide this appeal' });
    expect(within(dialog).getByText('It was a free guide, not an advert.')).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Review decision' }));
    expect(within(dialog).getByText('Choose a decision.')).toBeInTheDocument();

    await user.click(within(dialog).getByRole('radio', { name: /Overturn the decision/ }));
    await user.type(within(dialog).getByLabelText(/^Decision note/), 'Guide was free');
    await user.click(within(dialog).getByRole('button', { name: 'Review decision' }));
    expect(
      await within(dialog).findByText(/Overturning reverses the original action\./),
    ).toBeInTheDocument();
    expect(calls).toBe(0);
    await user.click(within(dialog).getByRole('button', { name: 'Confirm decision' }));
    expect(
      await within(dialog).findByText(
        'An appeal against your own action must be reviewed by someone else.',
      ),
    ).toBeInTheDocument();

    await user.click(within(dialog).getByRole('button', { name: 'Confirm decision' }));
    expect(
      await screen.findByText('Decision overturned and the action reversed'),
    ).toBeInTheDocument();
    expect(body).toEqual({ decision: 'overturned', note: 'Guide was free' });
    expect(await within(region('Open appeals')).findByText('No open appeals')).toBeInTheDocument();
  });

  it('shows permission denied when the API refuses a non-staff account', async () => {
    server.use(
      http.get(`${API}/moderation/reports`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
      http.get(`${API}/moderation/appeals`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/staff/moderation', { user: makeUser({ onboarding_completed: true }) });
    await findPageHeading('Platform moderation');
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
    expect(
      screen.getByText('Platform moderation is for Montra support and admin staff.'),
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'New action' })).not.toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Reports' })).not.toBeInTheDocument();
  });

  it('shows empty queues and a recoverable error', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/moderation/reports`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-queue' }), {
              status: 500,
            })
          : HttpResponse.json(envelope([]));
      }),
      http.get(`${API}/moderation/appeals`, () => HttpResponse.json(envelope([]))),
    );
    serveStaffActions();
    const user = userEvent.setup();
    renderRoute('/staff/moderation', { user: makeStaff() });
    await findPageHeading('Platform moderation');
    expect(await screen.findByText('We couldn’t load the report queue')).toBeInTheDocument();
    expect(screen.getByText('req-queue')).toBeInTheDocument();
    expect(await screen.findByText('No open appeals')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByText('No reports here')).toBeInTheDocument();
  });
});
