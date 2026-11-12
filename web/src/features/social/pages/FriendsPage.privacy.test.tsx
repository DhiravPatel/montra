import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, errorBody } from '@/tests/fixtures';
import { findPageHeading } from '@/tests/render';
import {
  createSocialState,
  makeOwnProfile,
  renderFriends,
  socialUser,
  writes,
} from '@/tests/socialFixtures';

const privacyPath = '/friends?tab=privacy';

describe('FriendsPage: username', () => {
  it('explains usernames when you have none and lets you choose one', async () => {
    const state = createSocialState({ profile: makeOwnProfile({ username: undefined }) });
    const user = userEvent.setup();
    renderFriends(state, { user: socialUser({ username: undefined }) });
    await findPageHeading('Friends');

    expect(await screen.findByText('You don’t have a username yet')).toBeInTheDocument();
    expect(
      screen.getByText(
        'Friends find each other on Montra by exact username. Choose one so people you know can send you a request.',
      ),
    ).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'View your profile' })).toHaveAttribute(
      'href',
      '/account',
    );

    await user.click(screen.getByRole('button', { name: 'Choose a username' }));
    expect(screen.getByRole('tab', { name: 'Privacy' })).toHaveAttribute('aria-selected', 'true');
    const field = await screen.findByRole('textbox', { name: 'Username' });
    await waitFor(() => {
      expect(field).toHaveFocus();
    });

    await user.type(field, '@Asha_Rao');
    await user.click(screen.getByRole('button', { name: 'Save username' }));
    expect(await screen.findByText('Your username is now @asha_rao')).toBeInTheDocument();
    expect(screen.getByText('Friends can find you by it.')).toBeInTheDocument();
    expect(writes(state)).toEqual([
      { method: 'PATCH', path: '/me', body: { username: 'asha_rao' } },
    ]);
    expect(await screen.findByText('Your username is @asha_rao.')).toBeInTheDocument();

    // The signed-in user is refreshed, so the reminder goes away everywhere.
    await user.click(screen.getByRole('tab', { name: 'Friends' }));
    await waitFor(() => {
      expect(screen.queryByText('You don’t have a username yet')).not.toBeInTheDocument();
    });
  });

  it('says when a username is taken', async () => {
    const state = createSocialState();
    const user = userEvent.setup();
    renderFriends(state, {
      path: privacyPath,
      overrides: [
        http.patch(`${API}/me`, () =>
          HttpResponse.json(
            errorBody({
              code: 'CONFLICT',
              message: 'That username is taken.',
              details: [{ field: 'body.username', message: 'That username is taken.' }],
            }),
            { status: 409 },
          ),
        ),
      ],
    });

    const field = await screen.findByRole('textbox', { name: 'Username' });
    expect(field).toHaveValue('asha');
    await user.clear(field);
    await user.type(field, 'ravi');
    await user.click(screen.getByRole('button', { name: 'Change username' }));
    await waitFor(() => {
      expect(field).toHaveAccessibleDescription(/That username is taken\. Try another one\./);
    });
    expect(field).toHaveFocus();
  });

  it('says when a username is not available (reserved)', async () => {
    const state = createSocialState();
    const user = userEvent.setup();
    renderFriends(state, {
      path: privacyPath,
      overrides: [
        http.patch(`${API}/me`, () =>
          HttpResponse.json(
            errorBody({
              code: 'VALIDATION_ERROR',
              details: [{ field: 'body.username', message: 'This username is reserved.' }],
            }),
            { status: 422 },
          ),
        ),
      ],
    });

    const field = await screen.findByRole('textbox', { name: 'Username' });
    await user.clear(field);
    await user.type(field, 'admin');
    await user.click(screen.getByRole('button', { name: 'Change username' }));
    await waitFor(() => {
      expect(field).toHaveAccessibleDescription(/That username isn’t available\./);
    });
  });

  it('checks the username format before saving', async () => {
    const state = createSocialState();
    const user = userEvent.setup();
    renderFriends(state, { path: privacyPath });

    const field = await screen.findByRole('textbox', { name: 'Username' });
    await user.clear(field);
    await user.type(field, 'Bad Name!');
    await user.click(screen.getByRole('button', { name: 'Change username' }));
    expect(field).toHaveAccessibleDescription(
      /Use 3 to 30 characters: lowercase letters, numbers, dots and underscores\./,
    );
    expect(writes(state)).toEqual([]);
  });
});

describe('FriendsPage: privacy settings', () => {
  it('shows who can find you and who can send requests, and saves changes', async () => {
    const state = createSocialState();
    const user = userEvent.setup();
    renderFriends(state, { path: privacyPath });

    // The settings card replaces its loading state once GET /me answers.
    const discoverable = await screen.findByRole('checkbox', {
      name: 'Let people find me by my username',
    });
    const card = screen.getByRole('region', { name: 'Who can find you' });
    expect(discoverable).toBeChecked();
    expect(discoverable).toHaveAccessibleDescription(
      /When on, people can find you by searching for your username, @asha\./,
    );
    // Already findable: no reminder about the hidden default.
    expect(discoverable).not.toHaveAccessibleDescription(/New accounts start hidden/);
    const policy = within(card).getByRole('group', { name: 'Who can send you friend requests' });
    expect(within(policy).getByRole('radio', { name: /^Everyone/ })).toBeChecked();
    expect(
      within(policy).getByText('Only people who share a friend with you.'),
    ).toBeInTheDocument();
    expect(
      within(card).getByText(/friends never see your transactions or balances/),
    ).toBeInTheDocument();

    await user.click(discoverable);
    await user.click(within(policy).getByRole('radio', { name: /^Friends of friends/ }));
    await user.click(within(card).getByRole('button', { name: 'Save privacy settings' }));

    expect(await screen.findByText('Privacy settings saved')).toBeInTheDocument();
    expect(writes(state)).toEqual([
      {
        method: 'PATCH',
        path: '/me',
        body: { discoverable_by_username: false, allow_friend_requests: 'friends_of_friends' },
      },
    ]);
    expect(state.profile.allow_friend_requests).toBe('friends_of_friends');
  });

  it('explains that new accounts start hidden until discovery is turned on', async () => {
    const state = createSocialState({
      profile: makeOwnProfile({ discoverable_by_username: false }),
    });
    renderFriends(state, { path: privacyPath });
    const discoverable = await screen.findByRole('checkbox', {
      name: 'Let people find me by my username',
    });
    expect(discoverable).not.toBeChecked();
    expect(discoverable).toHaveAccessibleDescription(
      /New accounts start hidden: until you turn this on, nobody can find you by username, even if they know it\./,
    );
  });

  it('notes that nobody can find you without a username', async () => {
    const state = createSocialState({ profile: makeOwnProfile({ username: undefined }) });
    renderFriends(state, { path: privacyPath, user: socialUser({ username: undefined }) });

    expect(
      await screen.findByRole('checkbox', { name: 'Let people find me by my username' }),
    ).toHaveAccessibleDescription(
      'You don’t have a username yet, so nobody can find you by search.',
    );
    // The reminder is not repeated on the tab that already explains it.
    expect(screen.queryByText('You don’t have a username yet')).not.toBeInTheDocument();
  });

  it('shows a recoverable error when settings cannot load', async () => {
    renderFriends(createSocialState(), {
      path: privacyPath,
      overrides: [
        http.get(`${API}/me`, () =>
          HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-me' }), {
            status: 500,
          }),
        ),
      ],
    });
    expect(await screen.findByText('We couldn’t load your privacy settings')).toBeInTheDocument();
    expect(screen.getByText('req-me')).toBeInTheDocument();
  });

  it('keeps your choices and explains when saving fails', async () => {
    const state = createSocialState();
    const user = userEvent.setup();
    renderFriends(state, {
      path: privacyPath,
      overrides: [
        http.patch(`${API}/me`, () =>
          HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 }),
        ),
      ],
    });

    await user.click(await screen.findByRole('radio', { name: /^Nobody/ }));
    const card = screen.getByRole('region', { name: 'Who can find you' });
    await user.click(within(card).getByRole('button', { name: 'Save privacy settings' }));
    expect(await within(card).findByRole('alert')).toHaveTextContent(
      'Montra is temporarily unavailable. Try again in a moment.',
    );
    expect(within(card).getByRole('radio', { name: /^Nobody/ })).toBeChecked();
  });
});
