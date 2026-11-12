import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  CHALLENGE_COMMUNITY_ID,
  CHALLENGE_GROUP,
  CHALLENGE_GROUP_ID,
  CHALLENGE_OPEN,
  CHALLENGE_PRIVATE,
  daysFromToday,
  makeChallenge,
  makeGroupChallenge,
  makeLeaderboardEntry,
  makeOpenChallenge,
  makeParticipation,
  serveChallenge,
  serveMyCommunities,
  testToday,
} from '@/tests/challengesFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import { makeGroup } from '@/tests/sharingFixtures';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

function region(name: string) {
  return screen.getByRole('region', { name });
}

describe('ChallengeDetailPage', () => {
  it('shows your private challenge with progress in words, streaks and milestones', async () => {
    serveChallenge(makeChallenge());
    renderRoute(`/challenges/${CHALLENGE_PRIVATE}`, { user: signedIn() });
    await findPageHeading('Cook at home');

    expect(screen.getByText('Open')).toBeInTheDocument();
    expect(screen.getAllByText('Taking part').length).toBeGreaterThan(0);
    const progress = region('Your progress');
    expect(
      within(progress).getByText('Only you can see this. Share it only if you want to.'),
    ).toBeInTheDocument();
    expect(within(progress).getByText('3 of 7 days')).toBeInTheDocument();
    expect(within(progress).getByText('42% of the target')).toBeInTheDocument();
    expect(within(progress).getByRole('meter')).toHaveAttribute('aria-valuenow', '42');
    expect(within(progress).getByText('Current streak').nextElementSibling).toHaveTextContent(
      '2 days',
    );
    expect(within(progress).getByText('Best streak').nextElementSibling).toHaveTextContent(
      '3 days',
    );
    const milestones = within(progress).getByRole('region', { name: 'Milestones' });
    expect(within(milestones).getByText('Joined')).toBeInTheDocument();
    expect(within(milestones).getByText('Halfway there')).toBeInTheDocument();
    expect(within(milestones).getAllByText('Not yet. Go at your own pace.')).toHaveLength(2);

    // Private: no leaderboard, no sharing choices.
    expect(screen.queryByRole('region', { name: 'Leaderboard' })).not.toBeInTheDocument();
    expect(
      within(region('Sharing')).getByText('Only you can see this challenge and your progress.'),
    ).toBeInTheDocument();
    const about = region('About this challenge');
    expect(within(about).getByText('Make dinner at home on weeknights.')).toBeInTheDocument();
    expect(within(about).getByText('Home-cooked dinner counts as done.')).toBeInTheDocument();
    expect(within(about).getByText('Days checked in')).toBeInTheDocument();
    expect(
      within(region('Manage')).getByRole('button', { name: 'Edit challenge' }),
    ).toBeInTheDocument();
  });

  it('records a check-in and shows the new progress from the API', async () => {
    serveChallenge(makeChallenge());
    let body: unknown = null;
    server.use(
      http.post(`${API}/challenges/:id/progress`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(
          envelope(
            makeChallenge({
              me: makeParticipation({
                progress_value: 4,
                percent_complete: 57,
                current_streak: 3,
                best_streak: 3,
              }),
            }),
          ),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/challenges/${CHALLENGE_PRIVATE}`, { user: signedIn() });
    await findPageHeading('Cook at home');
    const checkIn = region('Check in');
    expect(within(checkIn).getByLabelText('Day')).toHaveValue(testToday());
    expect(within(checkIn).getByRole('radio', { name: 'Done' })).toBeChecked();
    await user.type(within(checkIn).getByLabelText(/^Note/), 'Dal and rice');
    await user.click(within(checkIn).getByRole('button', { name: 'Save check-in' }));

    expect(await screen.findByText('Check-in saved')).toBeInTheDocument();
    expect(screen.getByText('4 of 7 days (57% of the target)')).toBeInTheDocument();
    expect(body).toEqual({ date: testToday(), value: 1, note: 'Dal and rice' });
    expect(within(region('Your progress')).getByText('4 of 7 days')).toBeInTheDocument();
  });

  it('corrects a day as not done and keeps days inside the challenge', async () => {
    serveChallenge(makeChallenge());
    let body: unknown = null;
    server.use(
      http.post(`${API}/challenges/:id/progress`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(
          envelope(
            makeChallenge({ me: makeParticipation({ progress_value: 2, percent_complete: 28 }) }),
          ),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/challenges/${CHALLENGE_PRIVATE}`, { user: signedIn() });
    await findPageHeading('Cook at home');
    const checkIn = region('Check in');
    const day = within(checkIn).getByLabelText('Day');
    await user.clear(day);
    await user.type(day, daysFromToday(-5));
    await user.click(within(checkIn).getByRole('button', { name: 'Save check-in' }));
    await waitFor(() => {
      expect(day).toHaveAccessibleDescription(/Choose a day from .+ to .+\./);
    });
    expect(body).toBeNull();

    await user.clear(day);
    await user.type(day, daysFromToday(-1));
    await user.click(within(checkIn).getByRole('radio', { name: 'Not done' }));
    await user.click(within(checkIn).getByRole('button', { name: 'Save check-in' }));
    expect(await screen.findByText('Check-in saved')).toBeInTheDocument();
    expect(body).toEqual({ date: daysFromToday(-1), value: 0 });
  });

  it('records a percentage and celebrates reaching the target calmly', async () => {
    const challenge = makeOpenChallenge({
      mine: false,
      me: makeParticipation({ progress_value: 40, percent_complete: 50 }),
    });
    serveChallenge(challenge);
    serveMyCommunities();
    let body: unknown = null;
    server.use(
      http.post(`${API}/challenges/:id/progress`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(
          envelope({
            ...challenge,
            me: makeParticipation({
              status: 'completed',
              progress_value: 80,
              percent_complete: 100,
              completed_at: '2026-11-05T05:00:00Z',
            }),
          }),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/challenges/${CHALLENGE_OPEN}`, { user: signedIn() });
    await findPageHeading('Trip fund');
    expect(within(region('Your progress')).getByText('40% of a 80% goal')).toBeInTheDocument();
    const amount = within(region('Check in')).getByLabelText('Your progress now (%)');
    await user.clear(amount);
    await user.type(amount, '80');
    await user.click(screen.getByRole('button', { name: 'Save check-in' }));

    expect(await screen.findByText('You reached your target. Nice work.')).toBeInTheDocument();
    expect(body).toEqual({ date: testToday(), value: 80 });
    expect(screen.getByText('You reached your target')).toBeInTheDocument();
    expect(screen.getAllByText('Target reached').length).toBeGreaterThan(0);
  });

  it('joins with opt-in sharing that starts off', async () => {
    const challenge = makeOpenChallenge();
    const state = serveChallenge(challenge);
    serveMyCommunities();
    let body: unknown = null;
    server.use(
      http.post(`${API}/challenges/:id/join`, async ({ request }) => {
        body = await request.json();
        state.challenge = {
          ...challenge,
          participant_count: 13,
          me: makeParticipation({
            progress_value: 0,
            percent_complete: 0,
            current_streak: 0,
            best_streak: 0,
            share_progress: true,
            show_on_leaderboard: true,
          }),
        };
        return HttpResponse.json(envelope(state.challenge));
      }),
      http.get(`${API}/challenges/:id/leaderboard`, () =>
        HttpResponse.json(
          envelope([
            makeLeaderboardEntry({
              rank: 1,
              display_name: 'Asha Rao',
              username: undefined,
              is_me: true,
              percent_complete: 0,
              completed: false,
              current_streak: 0,
            }),
          ]),
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(`/challenges/${CHALLENGE_OPEN}`, { user: signedIn() });
    await findPageHeading('Trip fund');
    expect(screen.queryByRole('region', { name: 'Your progress' })).not.toBeInTheDocument();
    expect(
      within(region('Leaderboard')).getByText(/People who join can choose to appear on it\./),
    ).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Join challenge' }));

    const dialog = await screen.findByRole('dialog', { name: 'Join this challenge' });
    const share = within(dialog).getByLabelText('Share my progress with people in this challenge');
    const board = within(dialog).getByLabelText('Show me on the leaderboard');
    expect(share).not.toBeChecked();
    expect(board).toBeDisabled();
    await user.click(share);
    await user.click(board);
    await user.click(within(dialog).getByRole('button', { name: 'Join' }));

    expect(await screen.findByText('You joined the challenge')).toBeInTheDocument();
    expect(body).toEqual({ share_progress: true, show_on_leaderboard: true });
    expect(await screen.findByRole('region', { name: 'Your progress' })).toBeInTheDocument();
    // Now on the leaderboard, so it is shown.
    expect(
      await screen.findByRole('table', { name: 'People who chose to appear on the leaderboard' }),
    ).toBeInTheDocument();
  });

  it('explains when you need to join the community first', async () => {
    serveChallenge(makeOpenChallenge());
    serveMyCommunities([]);
    server.use(
      http.post(`${API}/challenges/:id/join`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              { code: 'join_community_first', message: 'Join the community to take part.' },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(`/challenges/${CHALLENGE_OPEN}`, { user: signedIn() });
    await findPageHeading('Trip fund');
    await user.click(screen.getByRole('button', { name: 'Join challenge' }));
    const dialog = await screen.findByRole('dialog');
    await user.click(within(dialog).getByRole('button', { name: 'Join' }));
    expect(
      await within(dialog).findByText('Join the community first to take part.'),
    ).toBeInTheDocument();
    expect(within(dialog).getByRole('link', { name: 'Open the community' })).toHaveAttribute(
      'href',
      `/communities/${CHALLENGE_COMMUNITY_ID}`,
    );
  });

  it('leaves after confirming and offers to join again', async () => {
    // The challenge names its group (the DTO's `group`).
    const state = serveChallenge(
      makeGroupChallenge({ group: { id: CHALLENGE_GROUP_ID, name: 'Savers' } }),
    );
    let left = false;
    server.use(
      http.post(`${API}/challenges/:id/leave`, () => {
        left = true;
        state.challenge = makeGroupChallenge({
          participant_count: 3,
          me: makeParticipation({ status: 'left', show_on_leaderboard: false }),
        });
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/challenges/${CHALLENGE_GROUP}`, { user: signedIn() });
    await findPageHeading('No-spend weekends');
    expect(
      await within(region('About this challenge')).findByRole('link', { name: 'Savers' }),
    ).toHaveAttribute('href', `/groups/${CHALLENGE_GROUP_ID}`);
    await user.click(screen.getByRole('button', { name: 'Leave challenge' }));
    const dialog = await screen.findByRole('dialog', { name: 'Leave this challenge?' });
    expect(within(dialog).getByText(/You’ll be taken off the leaderboard\./)).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Leave challenge' }));

    expect(await screen.findByText('You left the challenge')).toBeInTheDocument();
    expect(left).toBe(true);
    expect(await screen.findByRole('button', { name: 'Join again' })).toBeInTheDocument();
    expect(
      screen.getByText('You left this challenge. Your check-ins are kept privately.'),
    ).toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Check in' })).not.toBeInTheDocument();
  });

  it('shows the leaderboard as the API returns it only while you appear on it', async () => {
    serveChallenge(
      makeGroupChallenge({
        me: makeParticipation({
          share_progress: true,
          show_on_leaderboard: true,
          progress_value: 2,
          percent_complete: 40,
        }),
      }),
    );
    server.use(
      http.get(`${API}/challenges/:id/leaderboard`, () =>
        HttpResponse.json(
          envelope([
            makeLeaderboardEntry(),
            makeLeaderboardEntry({
              rank: 2,
              display_name: 'Asha Rao',
              username: 'asha',
              percent_complete: 40,
              current_streak: 2,
              completed: false,
              is_me: true,
            }),
          ]),
        ),
      ),
    );
    renderRoute(`/challenges/${CHALLENGE_GROUP}`, { user: signedIn() });
    await findPageHeading('No-spend weekends');
    const table = await screen.findByRole('table', {
      name: 'People who chose to appear on the leaderboard',
    });
    const rows = within(table).getAllByRole('row');
    expect(rows).toHaveLength(3);
    expect(within(rows[1]!).getByText('Ravi Kumar')).toBeInTheDocument();
    expect(within(rows[1]!).getByText('100% of the target')).toBeInTheDocument();
    expect(within(rows[1]!).getByText('Target reached')).toBeInTheDocument();
    expect(within(rows[2]!).getByText('Asha Rao')).toBeInTheDocument();
    expect(within(rows[2]!).getByText('You')).toBeInTheDocument();
    expect(within(rows[2]!).getByText('2 days')).toBeInTheDocument();
  });

  it('does not ask for the leaderboard until you opt in, then saves your sharing', async () => {
    const challenge = makeGroupChallenge();
    serveChallenge(challenge);
    const boardRequests: string[] = [];
    let body: unknown = null;
    server.use(
      http.get(`${API}/challenges/:id/leaderboard`, ({ params }) => {
        boardRequests.push(String(params.id));
        return HttpResponse.json(
          envelope([makeLeaderboardEntry({ is_me: true, display_name: 'Asha Rao' })]),
        );
      }),
      http.patch(`${API}/challenges/:id/participation`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(
          envelope({
            ...challenge,
            me: { ...challenge.me!, share_progress: true, show_on_leaderboard: true },
          }),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/challenges/${CHALLENGE_GROUP}`, { user: signedIn() });
    await findPageHeading('No-spend weekends');
    expect(
      within(region('Leaderboard')).getByText(
        /The leaderboard is shown only to people who appear on it\./,
      ),
    ).toBeInTheDocument();
    expect(boardRequests).toEqual([]);

    const sharing = region('Sharing');
    expect(within(sharing).getByText('Your progress is private right now.')).toBeInTheDocument();
    const save = within(sharing).getByRole('button', { name: 'Save sharing' });
    expect(save).toBeDisabled();
    await user.click(
      within(sharing).getByLabelText('Share my progress with people in this challenge'),
    );
    await user.click(within(sharing).getByLabelText('Show me on the leaderboard'));
    await user.click(save);

    expect(await screen.findByText('Sharing updated')).toBeInTheDocument();
    expect(body).toEqual({ share_progress: true, show_on_leaderboard: true });
    expect(await screen.findByRole('table')).toBeInTheDocument();
    expect(boardRequests).toEqual([CHALLENGE_GROUP]);
    expect(
      within(region('Sharing')).getByText(
        'You’re sharing your percentage with people in this challenge.',
      ),
    ).toBeInTheDocument();
  });

  it('explains a missing leaderboard as the API reports it', async () => {
    serveChallenge(
      makeGroupChallenge({
        me: makeParticipation({ share_progress: true, show_on_leaderboard: true }),
      }),
    );
    server.use(
      http.get(`${API}/challenges/:id/leaderboard`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [{ code: 'no_leaderboard', message: 'This challenge has no leaderboard.' }],
          }),
          { status: 422 },
        ),
      ),
    );
    renderRoute(`/challenges/${CHALLENGE_GROUP}`, { user: signedIn() });
    await findPageHeading('No-spend weekends');
    expect(
      await screen.findByText('This challenge doesn’t have a leaderboard.'),
    ).toBeInTheDocument();
  });

  it('names the group from your groups for a challenge that carries only the ID', async () => {
    serveChallenge(makeGroupChallenge({ group: undefined }));
    testBackend.groups = [makeGroup({ id: CHALLENGE_GROUP_ID, name: 'Flatmates' })];
    renderRoute(`/challenges/${CHALLENGE_GROUP}`, { user: signedIn() });
    await findPageHeading('No-spend weekends');
    expect(
      await within(region('About this challenge')).findByRole('link', { name: 'Flatmates' }),
    ).toHaveAttribute('href', `/groups/${CHALLENGE_GROUP_ID}`);
  });

  it('explains in place when the API says you must opt in to see the leaderboard', async () => {
    serveChallenge(
      makeGroupChallenge({
        me: makeParticipation({ share_progress: true, show_on_leaderboard: true }),
      }),
    );
    server.use(
      http.get(`${API}/challenges/:id/leaderboard`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                code: 'leaderboard_opt_in_required',
                message: 'Join the challenge and choose to appear on the leaderboard to see it.',
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    renderRoute(`/challenges/${CHALLENGE_GROUP}`, { user: signedIn() });
    await findPageHeading('No-spend weekends');
    expect(
      await screen.findByText(/The leaderboard is shown only to people on it\./),
    ).toBeInTheDocument();
    expect(screen.queryByText('We couldn’t load the leaderboard')).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Try again' })).not.toBeInTheDocument();
  });

  it('edits the challenge, sending only what changed with the version', async () => {
    const state = serveChallenge(
      makeChallenge({
        visibility: 'group',
        group_id: CHALLENGE_GROUP_ID,
        leaderboard_enabled: true,
        version: 3,
      }),
    );
    let body: unknown = null;
    server.use(
      http.patch(`${API}/challenges/:id`, async ({ request }) => {
        body = await request.json();
        state.challenge = {
          ...state.challenge,
          title: 'Cook at home more',
          rules: undefined,
          ends_on: daysFromToday(20),
          version: 4,
        };
        return HttpResponse.json(envelope(state.challenge));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/challenges/${CHALLENGE_PRIVATE}`, { user: signedIn() });
    await findPageHeading('Cook at home');
    await user.click(screen.getByRole('button', { name: 'Edit challenge' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit challenge' });
    const ends = within(dialog).getByLabelText('Ends on');
    await user.clear(ends);
    await user.type(ends, daysFromToday(5));
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => {
      expect(ends).toHaveAccessibleDescription(/The end date can only move later\./);
    });

    await user.clear(ends);
    await user.type(ends, daysFromToday(20));
    const title = within(dialog).getByLabelText('Title');
    await user.clear(title);
    await user.type(title, 'Cook at home more');
    await user.clear(within(dialog).getByLabelText(/Rules/));
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));

    expect(await screen.findByText('Challenge updated')).toBeInTheDocument();
    // Only the changes, with the version; an emptied text is cleared with "".
    expect(body).toEqual({
      version: 3,
      title: 'Cook at home more',
      rules: '',
      ends_on: daysFromToday(20),
    });
    expect(await findPageHeading('Cook at home more')).toBeInTheDocument();
  });

  it('reloads and restarts the edit form when someone else saved first', async () => {
    const state = serveChallenge(makeChallenge({ version: 2 }));
    const bodies: unknown[] = [];
    server.use(
      http.patch(`${API}/challenges/:id`, async ({ request }) => {
        bodies.push(await request.json());
        state.challenge = { ...state.challenge, title: 'Cook at home daily', version: 5 };
        return HttpResponse.json(
          errorBody({ code: 'VERSION_CONFLICT', message: 'This record was changed.' }),
          { status: 409 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/challenges/${CHALLENGE_PRIVATE}`, { user: signedIn() });
    await findPageHeading('Cook at home');
    await user.click(screen.getByRole('button', { name: 'Edit challenge' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit challenge' });
    await user.type(within(dialog).getByLabelText(/Description/), ' Lunch too.');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(
      await within(dialog).findByText(/Someone saved changes to this challenge in the meantime\./),
    ).toBeInTheDocument();
    await waitFor(() => {
      expect(within(dialog).getByLabelText('Title')).toHaveValue('Cook at home daily');
    });
    expect(bodies).toEqual([
      { version: 2, description: 'Make dinner at home on weeknights. Lunch too.' },
    ]);
  });

  it('cancels the challenge only after confirming', async () => {
    serveChallenge(makeChallenge());
    let cancelled = 0;
    server.use(
      http.post(`${API}/challenges/:id/cancel`, () => {
        cancelled += 1;
        return HttpResponse.json(envelope(makeChallenge({ status: 'cancelled' })));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/challenges/${CHALLENGE_PRIVATE}`, { user: signedIn() });
    await findPageHeading('Cook at home');
    await user.click(within(region('Manage')).getByRole('button', { name: 'Cancel challenge' }));
    let dialog = await screen.findByRole('dialog', { name: 'Cancel this challenge?' });
    await user.click(within(dialog).getByRole('button', { name: 'Keep challenge' }));
    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    });
    expect(cancelled).toBe(0);

    await user.click(within(region('Manage')).getByRole('button', { name: 'Cancel challenge' }));
    dialog = await screen.findByRole('dialog', { name: 'Cancel this challenge?' });
    await user.click(within(dialog).getByRole('button', { name: 'Cancel challenge' }));
    expect(await screen.findByText('Challenge cancelled')).toBeInTheDocument();
    expect(cancelled).toBe(1);
    expect(screen.getByText('This challenge was cancelled')).toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Check in' })).not.toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Manage' })).not.toBeInTheDocument();
  });

  it('says when check-ins open for a challenge that has not started', async () => {
    serveChallenge(makeChallenge({ starts_on: daysFromToday(3), ends_on: daysFromToday(20) }));
    renderRoute(`/challenges/${CHALLENGE_PRIVATE}`, { user: signedIn() });
    await findPageHeading('Cook at home');
    expect(screen.getByText(/^Starts /)).toBeInTheDocument();
    expect(
      within(region('Check in')).getByText(/You can check in from then\./),
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Save check-in' })).not.toBeInTheDocument();
  });

  it('shows not found, error with retry, and permission states', async () => {
    serveChallenge(makeChallenge());
    const first = renderRoute(`/challenges/${CHALLENGE_GROUP}`, { user: signedIn() });
    expect(await screen.findByText('Challenge not found')).toBeInTheDocument();
    first.unmount();

    let calls = 0;
    server.use(
      http.get(`${API}/challenges/:id`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-detail' }), {
              status: 500,
            })
          : HttpResponse.json(envelope(makeChallenge()));
      }),
    );
    const user = userEvent.setup();
    const second = renderRoute(`/challenges/${CHALLENGE_PRIVATE}`, { user: signedIn() });
    expect(await screen.findByText('We couldn’t load this challenge')).toBeInTheDocument();
    expect(screen.getByText('req-detail')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    await findPageHeading('Cook at home');
    second.unmount();

    server.use(
      http.get(`${API}/challenges/:id`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute(`/challenges/${CHALLENGE_PRIVATE}`, { user: signedIn() });
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });
});
