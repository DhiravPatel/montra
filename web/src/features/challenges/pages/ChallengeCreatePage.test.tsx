import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  CHALLENGE_COMMUNITY_ID,
  CHALLENGE_GROUP,
  CHALLENGE_GROUP_ID,
  CHALLENGE_PRIVATE,
  daysFromToday,
  makeChallenge,
  makeCommunity,
  makeGroupChallenge,
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

async function fillBasics(user: ReturnType<typeof userEvent.setup>, endsOn = daysFromToday(20)) {
  await user.type(await screen.findByLabelText('Title'), 'Cook at home');
  await user.selectOptions(screen.getByLabelText('Type'), 'meal_planning');
  await user.type(screen.getByLabelText('Target'), '7');
  await user.type(screen.getByLabelText('Ends on'), endsOn);
}

describe('ChallengeCreatePage', () => {
  it('checks the form before calling the API', async () => {
    const user = userEvent.setup();
    renderRoute('/challenges/new', { user: signedIn() });
    await findPageHeading('New challenge');
    // Private by default, starting today.
    expect(screen.getByRole('radio', { name: /Just you/ })).toBeChecked();
    expect(screen.getByLabelText('Starts on')).toHaveValue(testToday());

    await user.clear(screen.getByLabelText('Starts on'));
    await user.type(screen.getByLabelText('Starts on'), daysFromToday(-10));
    await user.type(screen.getByLabelText('Title'), 'Hi');
    await user.selectOptions(screen.getByLabelText('Type'), 'custom');
    await user.click(screen.getByRole('radio', { name: /Percentage/ }));
    await user.type(screen.getByLabelText('Target'), '150');
    await user.type(screen.getByLabelText('Ends on'), daysFromToday(-1));
    await user.click(screen.getByRole('button', { name: 'Create challenge' }));

    await waitFor(() => {
      expect(screen.getByLabelText('Title')).toHaveAccessibleDescription(
        /Use at least 3 characters\./,
      );
    });
    expect(screen.getByLabelText('Target')).toHaveAccessibleDescription(
      /Enter a whole number from 1 to 100\./,
    );
    expect(screen.getByLabelText('Ends on')).toHaveAccessibleDescription(
      /This end date has already passed\./,
    );

    await user.clear(screen.getByLabelText('Ends on'));
    await user.type(screen.getByLabelText('Ends on'), daysFromToday(400));
    await user.click(screen.getByRole('button', { name: 'Create challenge' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Ends on')).toHaveAccessibleDescription(
        /Choose an end date within a year of the start\./,
      );
    });
  });

  it('creates a private challenge and opens it', async () => {
    let body: unknown = null;
    server.use(
      http.post(`${API}/challenges`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(
          envelope(
            makeChallenge({ me: makeParticipation({ progress_value: 0, percent_complete: 0 }) }),
          ),
          {
            status: 201,
          },
        );
      }),
    );
    serveChallenge(makeChallenge());
    const user = userEvent.setup();
    const { router } = renderRoute('/challenges/new', { user: signedIn() });
    await findPageHeading('New challenge');
    await fillBasics(user);
    await user.type(screen.getByLabelText(/^Rules/), 'Home-cooked dinner counts.');
    // No leaderboard or sharing for a private challenge.
    expect(screen.queryByLabelText('Add an opt-in leaderboard')).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Create challenge' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/challenges/${CHALLENGE_PRIVATE}`);
    });
    expect(body).toEqual({
      title: 'Cook at home',
      challenge_type: 'meal_planning',
      metric: 'days',
      target_value: 7,
      starts_on: testToday(),
      ends_on: daysFromToday(20),
      visibility: 'private',
      leaderboard_enabled: false,
      rules: 'Home-cooked dinner counts.',
    });
    expect(await screen.findByText('Challenge created')).toBeInTheDocument();
  });

  it('creates a group challenge with a leaderboard, then saves your opt-in sharing', async () => {
    testBackend.groups = [makeGroup({ id: CHALLENGE_GROUP_ID, name: 'Savers' })];
    const created = makeGroupChallenge({
      mine: true,
      me: makeParticipation({ progress_value: 0, percent_complete: 0 }),
    });
    let body: unknown = null;
    let sharing: unknown = null;
    server.use(
      http.post(`${API}/challenges`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(envelope(created), { status: 201 });
      }),
      http.patch(`${API}/challenges/:id/participation`, async ({ request, params }) => {
        expect(params.id).toBe(CHALLENGE_GROUP);
        sharing = await request.json();
        return HttpResponse.json(
          envelope({
            ...created,
            me: { ...created.me!, share_progress: true, show_on_leaderboard: true },
          }),
        );
      }),
    );
    serveChallenge(created);
    const user = userEvent.setup();
    const { router } = renderRoute('/challenges/new', { user: signedIn() });
    await findPageHeading('New challenge');
    await fillBasics(user);
    await user.click(screen.getByRole('radio', { name: /Days in a row/ }));
    await user.click(screen.getByRole('radio', { name: /A group/ }));
    await user.selectOptions(await screen.findByLabelText('Group'), CHALLENGE_GROUP_ID);
    await user.click(screen.getByLabelText('Add an opt-in leaderboard'));
    // The leaderboard opt-in waits for sharing.
    expect(
      screen.getByText('To appear on the leaderboard, share your progress first.'),
    ).toBeInTheDocument();
    await user.click(screen.getByLabelText('Share my progress with people in this challenge'));
    await user.click(screen.getByLabelText('Show me on the leaderboard'));
    await user.click(screen.getByRole('button', { name: 'Create challenge' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/challenges/${CHALLENGE_GROUP}`);
    });
    expect(body).toMatchObject({
      metric: 'streak',
      visibility: 'group',
      group_id: CHALLENGE_GROUP_ID,
      leaderboard_enabled: true,
    });
    expect(body).not.toHaveProperty('community_id');
    expect(sharing).toEqual({ share_progress: true, show_on_leaderboard: true });
  });

  it('offers your communities for a community challenge and keeps the challenge when sharing fails', async () => {
    serveMyCommunities([
      makeCommunity(),
      makeCommunity({
        id: 'b1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
        name: 'Pending one',
        my_status: 'pending',
      }),
    ]);
    let body: unknown = null;
    server.use(
      http.post(`${API}/challenges`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(
          envelope(
            makeChallenge({ visibility: 'community', community_id: CHALLENGE_COMMUNITY_ID }),
          ),
          {
            status: 201,
          },
        );
      }),
      http.patch(`${API}/challenges/:id/participation`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 }),
      ),
    );
    serveChallenge(
      makeChallenge({ visibility: 'community', community_id: CHALLENGE_COMMUNITY_ID }),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/challenges/new', { user: signedIn() });
    await findPageHeading('New challenge');
    await fillBasics(user);
    await user.click(screen.getByRole('radio', { name: /A community/ }));
    const select = await screen.findByLabelText('Community');
    await waitFor(() => {
      expect(screen.getByRole('option', { name: 'Frugal Living' })).toBeInTheDocument();
    });
    // Only active memberships can host a challenge.
    expect(screen.queryByRole('option', { name: 'Pending one' })).not.toBeInTheDocument();
    await user.selectOptions(select, CHALLENGE_COMMUNITY_ID);
    await user.click(screen.getByLabelText('Share my progress with people in this challenge'));
    await user.click(screen.getByRole('button', { name: 'Create challenge' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/challenges/${CHALLENGE_PRIVATE}`);
    });
    expect(body).toMatchObject({
      visibility: 'community',
      community_id: CHALLENGE_COMMUNITY_ID,
      leaderboard_enabled: false,
    });
    expect(await screen.findByText(/Your sharing choice wasn’t saved\./)).toBeInTheDocument();
  });

  it('starts a challenge for the group in the link', async () => {
    testBackend.groups = [makeGroup({ id: CHALLENGE_GROUP_ID, name: 'Savers' })];
    renderRoute(`/challenges/new?group_id=${CHALLENGE_GROUP_ID}`, { user: signedIn() });
    await findPageHeading('New challenge');
    expect(screen.getByRole('radio', { name: /A group/ })).toBeChecked();
    await waitFor(() => {
      expect(screen.getByLabelText('Group')).toHaveValue(CHALLENGE_GROUP_ID);
    });
  });

  it('says when you have no groups to share with, and when the API refuses', async () => {
    server.use(
      http.post(`${API}/challenges`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/challenges/new', { user: signedIn() });
    await findPageHeading('New challenge');
    await fillBasics(user);
    await user.click(screen.getByRole('radio', { name: /A group/ }));
    await waitFor(() => {
      expect(screen.getByLabelText('Group')).toHaveAccessibleDescription(
        'You’re not in any active groups yet.',
      );
    });
    await user.click(screen.getByRole('radio', { name: /Just you/ }));
    await user.click(screen.getByRole('button', { name: 'Create challenge' }));
    expect(await screen.findByText('You don’t have permission to do that.')).toBeInTheDocument();
  });

  it('shows API field errors on the form and the daily limit in words', async () => {
    let calls = 0;
    server.use(
      http.post(`${API}/challenges`, () => {
        calls += 1;
        if (calls === 1) {
          return HttpResponse.json(
            errorBody({
              code: 'VALIDATION_ERROR',
              details: [
                { field: 'body.ends_on', message: 'End on or after the start, within a year.' },
              ],
            }),
            { status: 422 },
          );
        }
        if (calls === 2) {
          return HttpResponse.json(errorBody({ code: 'RATE_LIMITED' }), { status: 429 });
        }
        if (calls === 3) {
          return HttpResponse.json(
            errorBody({
              code: 'VALIDATION_ERROR',
              details: [
                {
                  field: 'body.title',
                  message: 'expected length <= 120',
                  code: 'too_long',
                  params: { max: '120' },
                },
              ],
            }),
            { status: 422 },
          );
        }
        return HttpResponse.json(
          errorBody({
            code: 'RATE_LIMITED',
            details: [
              {
                message: 'Daily limit reached.',
                code: 'daily_cap',
                params: { resource: 'challenges', limit: '10', retry_at: '2099-01-01T00:00:00Z' },
              },
            ],
          }),
          { status: 429, headers: { 'Retry-After': '10800' } },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/challenges/new', { user: signedIn() });
    await findPageHeading('New challenge');
    await fillBasics(user);
    await user.click(screen.getByRole('button', { name: 'Create challenge' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Ends on')).toHaveAccessibleDescription(
        /End on or after the start, within a year\./,
      );
    });
    await user.click(screen.getByRole('button', { name: 'Create challenge' }));
    expect(
      await screen.findByText(
        'You’ve started a lot of challenges today. You can create another one tomorrow.',
      ),
    ).toBeInTheDocument();
    // Coded field problems are shown in the interface language with their values.
    await user.click(screen.getByRole('button', { name: 'Create challenge' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Title')).toHaveAccessibleDescription(
        /Use 120 characters or fewer\./,
      );
    });
    // The daily cap says when it opens again (Retry-After).
    await user.click(screen.getByRole('button', { name: 'Create challenge' }));
    expect(
      await screen.findByText(
        'You’ve reached today’s limit of 10 new challenges. You can try again in 3 hours.',
      ),
    ).toBeInTheDocument();
  });
});
