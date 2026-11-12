import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  CHALLENGE_GROUP,
  CHALLENGE_OPEN,
  CHALLENGE_PAST,
  CHALLENGE_PRIVATE,
  daysFromToday,
  makeChallenge,
  makeGroupChallenge,
  makeOpenChallenge,
  makeParticipation,
  serveChallengeLists,
} from '@/tests/challengesFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

function region(name: string) {
  return screen.getByRole('region', { name });
}

describe('ChallengesPage', () => {
  it('lists your challenges with progress in words, ones open to join, and past ones', async () => {
    const seen = serveChallengeLists({
      mine: [
        makeChallenge(),
        makeGroupChallenge(),
        makeChallenge({
          id: CHALLENGE_PAST,
          title: 'Grocery list month',
          challenge_type: 'grocery_budget',
          ended: true,
          starts_on: daysFromToday(-40),
          ends_on: daysFromToday(-10),
          me: makeParticipation({ status: 'completed', percent_complete: 100, progress_value: 7 }),
        }),
        // Left: shown under "Open to join" while it is open, not under yours.
        makeOpenChallenge({
          id: 'aa0a1b2c-3d4e-4f50-8a6b-7c8d9e0f1a2b',
          title: 'Old savings run',
          me: makeParticipation({ status: 'left' }),
        }),
      ],
      discover: [makeOpenChallenge()],
    });
    renderRoute('/challenges', { user: signedIn() });
    await findPageHeading('Challenges');

    const yours = await screen.findByRole('region', { name: 'Your challenges' });
    const cook = within(yours).getByRole('link', { name: 'Cook at home' });
    expect(cook).toHaveAttribute('href', `/challenges/${CHALLENGE_PRIVATE}`);
    expect(within(yours).getByRole('link', { name: 'No-spend weekends' })).toHaveAttribute(
      'href',
      `/challenges/${CHALLENGE_GROUP}`,
    );
    // Progress always has words, not only a bar.
    expect(within(yours).getByText('3 of 7 days')).toBeInTheDocument();
    expect(within(yours).getByText('42% of the target')).toBeInTheDocument();
    expect(within(yours).getByText('Best run: 2 of 5 days in a row')).toBeInTheDocument();
    expect(within(yours).getByRole('meter', { name: 'Progress in Cook at home' })).toHaveAttribute(
      'aria-valuetext',
      '3 of 7 days (42% of the target)',
    );
    expect(within(yours).getAllByText('Taking part')).toHaveLength(2);
    expect(within(yours).getByText('Just you')).toBeInTheDocument();
    expect(within(yours).queryByText('Old savings run')).not.toBeInTheDocument();

    const open = region('Open to join');
    expect(within(open).getByRole('link', { name: 'Trip fund' })).toHaveAttribute(
      'href',
      `/challenges/${CHALLENGE_OPEN}`,
    );
    expect(within(open).getByText('12 people taking part')).toBeInTheDocument();
    // Not joined: no progress meter.
    expect(within(open).queryByRole('meter')).not.toBeInTheDocument();

    const past = region('Past challenges');
    expect(within(past).getByText('Grocery list month')).toBeInTheDocument();
    expect(within(past).getByText('Ended')).toBeInTheDocument();
    expect(within(past).getByText('Target reached')).toBeInTheDocument();

    expect(seen.sort()).toEqual(['scope=discover&limit=50', 'scope=mine&limit=50']);
    expect(screen.getByRole('link', { name: 'New challenge' })).toHaveAttribute(
      'href',
      '/challenges/new',
    );
  });

  it('shows calm empty states with a way to start', async () => {
    serveChallengeLists();
    renderRoute('/challenges', { user: signedIn() });
    await findPageHeading('Challenges');
    expect(await screen.findByText('No challenges right now')).toBeInTheDocument();
    expect(screen.getByText('Nothing to join right now')).toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Past challenges' })).not.toBeInTheDocument();
    expect(screen.getAllByRole('link', { name: 'New challenge' })).toHaveLength(2);
  });

  it('shows a recoverable error for one list and keeps the other', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/challenges`, ({ request }) => {
        const scope = new URL(request.url).searchParams.get('scope');
        if (scope === 'mine') {
          calls += 1;
          if (calls === 1) {
            return HttpResponse.json(
              errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-chal' }),
              {
                status: 500,
              },
            );
          }
          return HttpResponse.json(envelope([makeChallenge()]));
        }
        return HttpResponse.json(envelope([makeOpenChallenge()]));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/challenges', { user: signedIn() });
    await findPageHeading('Challenges');
    expect(await screen.findByText('We couldn’t load your challenges')).toBeInTheDocument();
    expect(screen.getByText('req-chal')).toBeInTheDocument();
    expect(await screen.findByRole('link', { name: 'Trip fund' })).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByRole('link', { name: 'Cook at home' })).toBeInTheDocument();
  });

  it('loads more challenges a page at a time while the API reports more', async () => {
    const open = Array.from({ length: 3 }, (_, index) =>
      makeOpenChallenge({
        id: `bb0a1b2c-3d4e-4f50-8a6b-${String(index).padStart(12, '0')}`,
        title: `Open challenge ${index + 1}`,
      }),
    );
    const seen = serveChallengeLists({ discover: open }, 2);
    const user = userEvent.setup();
    renderRoute('/challenges', { user: signedIn() });
    await findPageHeading('Challenges');
    const discover = await screen.findByRole('region', { name: 'Open to join' });
    expect(
      await within(discover).findByRole('link', { name: 'Open challenge 2' }),
    ).toBeInTheDocument();
    expect(
      within(discover).queryByRole('link', { name: 'Open challenge 3' }),
    ).not.toBeInTheDocument();
    await user.click(within(discover).getByRole('button', { name: 'Load more challenges' }));
    expect(
      await within(discover).findByRole('link', { name: 'Open challenge 3' }),
    ).toBeInTheDocument();
    expect(
      within(discover).queryByRole('button', { name: 'Load more challenges' }),
    ).not.toBeInTheDocument();
    expect(seen.filter((query) => query.startsWith('scope=discover'))).toEqual([
      'scope=discover&limit=50',
      'scope=discover&limit=50&cursor=after-2',
    ]);
  });

  it('shows permission denied when the API refuses', async () => {
    server.use(
      http.get(`${API}/challenges`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/challenges', { user: signedIn() });
    await findPageHeading('Challenges');
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'New challenge' })).not.toBeInTheDocument();
  });
});
