import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { sharingKeys } from '@/shared/finance/keys';
import { API, envelope, errorBody } from '@/tests/fixtures';
import { findPageHeading } from '@/tests/render';
import { FRIEND_ID } from '@/tests/sharingFixtures';
import {
  KABIR_ID,
  choosePersonAction,
  createSocialState,
  makeBlocked,
  makeFriend,
  makeIncomingRequest,
  makeMuted,
  makeOutgoingRequest,
  renderFriends,
  writes,
} from '@/tests/socialFixtures';

describe('FriendsPage: friends', () => {
  it('lists friends with their usernames and counts requests waiting for you', async () => {
    const state = createSocialState({
      friends: [makeFriend()],
      requests: [makeIncomingRequest(), makeOutgoingRequest()],
    });
    renderFriends(state);
    await findPageHeading('Friends');

    const list = await screen.findByRole('region', { name: 'Your friends' });
    expect(await within(list).findByText('Ravi Kumar')).toBeInTheDocument();
    expect(within(list).getByText('@ravi')).toBeInTheDocument();
    expect(within(list).getByText('1 friend')).toBeInTheDocument();
    // Only incoming requests count; the tab name says so for screen readers.
    expect(await screen.findByRole('tab', { name: 'Requests, 1 waiting' })).toBeInTheDocument();
    // Names never reach the tab title.
    expect(document.title).toBe('Friends · Montra');
  });

  it('shows a first-use empty state that leads to Find people', async () => {
    const user = userEvent.setup();
    renderFriends(createSocialState());
    await findPageHeading('Friends');
    expect(await screen.findByText('No friends yet')).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Find people' }));
    expect(screen.getByRole('tab', { name: 'Find people' })).toHaveAttribute(
      'aria-selected',
      'true',
    );
    expect(await screen.findByRole('search', { name: 'Find people by username' })).toBeVisible();
  });

  it('shows a recoverable error with the request reference', async () => {
    const state = createSocialState({ friends: [makeFriend()] });
    let failures = 0;
    const user = userEvent.setup();
    renderFriends(state, {
      overrides: [
        http.get(`${API}/connections`, () => {
          failures += 1;
          if (failures === 1) {
            return HttpResponse.json(
              errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-friends' }),
              { status: 500 },
            );
          }
          return HttpResponse.json(envelope(state.friends));
        }),
      ],
    });
    await findPageHeading('Friends');

    expect(await screen.findByText('We couldn’t load your friends')).toBeInTheDocument();
    expect(screen.getByText('req-friends')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByText('Ravi Kumar')).toBeInTheDocument();
  });

  it('shows a permission message when the API refuses', async () => {
    renderFriends(createSocialState(), {
      overrides: [
        http.get(`${API}/connections`, () =>
          HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
        ),
      ],
    });
    await findPageHeading('Friends');
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });

  it('removes a friend after explaining what removal means, and refreshes friend pickers', async () => {
    const state = createSocialState({ friends: [makeFriend()] });
    const user = userEvent.setup();
    const { queryClient } = renderFriends(state);
    await findPageHeading('Friends');
    queryClient.setQueryData(sharingKeys.connections(), [makeFriend()]);

    await user.click(await screen.findByRole('button', { name: 'Remove Ravi Kumar from friends' }));
    const dialog = await screen.findByRole('dialog', {
      name: 'Remove Ravi Kumar from your friends?',
    });
    expect(dialog).toHaveTextContent('Anything you already share, and groups you’re both in, stay');
    expect(dialog).toHaveTextContent('Montra doesn’t tell them');
    expect(writes(state)).toEqual([]);

    await user.click(within(dialog).getByRole('button', { name: 'Remove friend' }));
    expect(await screen.findByText('Removed Ravi Kumar from your friends')).toBeInTheDocument();
    expect(await screen.findByText('No friends yet')).toBeInTheDocument();
    expect(writes(state)).toEqual([
      { method: 'DELETE', path: `/connections/${FRIEND_ID}`, body: null },
    ]);
    expect(queryClient.getQueryState(sharingKeys.connections())?.isInvalidated).toBe(true);
  });

  it('keeps the friend when removal is cancelled', async () => {
    const state = createSocialState({ friends: [makeFriend()] });
    const user = userEvent.setup();
    renderFriends(state);
    await user.click(await screen.findByRole('button', { name: 'Remove Ravi Kumar from friends' }));
    const dialog = await screen.findByRole('dialog');
    await user.click(within(dialog).getByRole('button', { name: 'Cancel' }));
    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    });
    expect(screen.getByText('Ravi Kumar')).toBeInTheDocument();
    expect(writes(state)).toEqual([]);
  });

  it('blocks a friend after confirming the effect, then unblocks them from Blocked & muted', async () => {
    const state = createSocialState({ friends: [makeFriend()] });
    const user = userEvent.setup();
    renderFriends(state);
    await findPageHeading('Friends');

    await choosePersonAction(user, 'Ravi Kumar', 'Block');
    const dialog = await screen.findByRole('dialog', { name: 'Block Ravi Kumar?' });
    expect(dialog).toHaveTextContent('any friend requests between you are cancelled');
    expect(dialog).toHaveTextContent('they can’t find you or send you requests');
    expect(dialog).toHaveTextContent('Montra doesn’t tell them');
    await user.click(within(dialog).getByRole('button', { name: 'Block' }));

    expect(await screen.findByText('Ravi Kumar is blocked')).toBeInTheDocument();
    expect(await screen.findByText('No friends yet')).toBeInTheDocument();
    expect(writes(state)).toEqual([
      { method: 'POST', path: `/users/${FRIEND_ID}/block`, body: null },
    ]);

    await user.click(screen.getByRole('tab', { name: 'Blocked & muted' }));
    // The list comes from GET /blocks, with when the block was made.
    const blocked = await screen.findByRole('region', { name: 'Blocked people' });
    expect(await within(blocked).findByText('Ravi Kumar')).toBeInTheDocument();
    expect(within(blocked).getByText('Blocked November 5, 2026')).toBeInTheDocument();

    await user.click(within(blocked).getByRole('button', { name: 'Unblock Ravi Kumar' }));
    const confirm = await screen.findByRole('dialog', { name: 'Unblock Ravi Kumar?' });
    expect(confirm).toHaveTextContent('You won’t become friends again unless you both agree');
    await user.click(within(confirm).getByRole('button', { name: 'Unblock' }));

    expect(await screen.findByText('Ravi Kumar is unblocked')).toBeInTheDocument();
    expect(await within(blocked).findByText('You haven’t blocked anyone')).toBeInTheDocument();
    expect(writes(state).at(-1)).toEqual({
      method: 'DELETE',
      path: `/users/${FRIEND_ID}/block`,
      body: null,
    });
  });

  it('lists earlier blocks and mutes from the API, a page at a time', async () => {
    const state = createSocialState({
      blocks: [
        makeBlocked(),
        makeBlocked({
          user_id: KABIR_ID,
          display_name: 'Kabir Singh',
          username: 'kabir',
          created_at: '2026-10-20T08:00:00Z',
        }),
      ],
      mutes: [makeMuted()],
      pageSize: 1,
    });
    const user = userEvent.setup();
    renderFriends(state, { path: '/friends?tab=blocked' });
    await findPageHeading('Friends');

    const blocked = await screen.findByRole('region', { name: 'Blocked people' });
    expect(await within(blocked).findByText('Meera Shah')).toBeInTheDocument();
    expect(within(blocked).getByText('Blocked November 3, 2026')).toBeInTheDocument();
    expect(within(blocked).queryByText('Kabir Singh')).not.toBeInTheDocument();
    await user.click(within(blocked).getByRole('button', { name: 'Show more blocked people' }));
    expect(await within(blocked).findByText('Kabir Singh')).toBeInTheDocument();
    expect(
      within(blocked).queryByRole('button', { name: 'Show more blocked people' }),
    ).not.toBeInTheDocument();

    const muted = screen.getByRole('region', { name: 'Muted people' });
    expect(await within(muted).findByText('Ravi Kumar')).toBeInTheDocument();
    expect(within(muted).getByText('Muted November 2, 2026')).toBeInTheDocument();
    expect(
      within(muted).queryByRole('button', { name: 'Show more muted people' }),
    ).not.toBeInTheDocument();
    // Reads only: nothing was written.
    expect(writes(state)).toEqual([]);
  });

  it('shows recoverable errors for the block and mute lists', async () => {
    const state = createSocialState({ blocks: [makeBlocked()] });
    let muteFailures = 0;
    const user = userEvent.setup();
    renderFriends(state, {
      path: '/friends?tab=blocked',
      overrides: [
        http.get(`${API}/mutes`, () => {
          muteFailures += 1;
          if (muteFailures === 1) {
            return HttpResponse.json(
              errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-mutes' }),
              { status: 500 },
            );
          }
          return undefined; // fall through to the social backend
        }),
      ],
    });
    const muted = await screen.findByRole('region', { name: 'Muted people' });
    expect(
      await within(muted).findByText('We couldn’t load the people you muted'),
    ).toBeInTheDocument();
    expect(within(muted).getByText('req-mutes')).toBeInTheDocument();
    await user.click(within(muted).getByRole('button', { name: 'Try again' }));
    expect(await within(muted).findByText('You haven’t muted anyone')).toBeInTheDocument();
    expect(
      await within(screen.getByRole('region', { name: 'Blocked people' })).findByText('Meera Shah'),
    ).toBeInTheDocument();
  });

  it('shows a block failure inside the dialog and keeps it open', async () => {
    const state = createSocialState({ friends: [makeFriend()] });
    const user = userEvent.setup();
    renderFriends(state, {
      overrides: [
        http.post(`${API}/users/:userId/block`, () =>
          HttpResponse.json(errorBody({ code: 'RATE_LIMITED' }), {
            status: 429,
            headers: { 'Retry-After': '2' },
          }),
        ),
      ],
    });
    await choosePersonAction(user, 'Ravi Kumar', 'Block');
    const dialog = await screen.findByRole('dialog', { name: 'Block Ravi Kumar?' });
    await user.click(within(dialog).getByRole('button', { name: 'Block' }));
    expect(await within(dialog).findByRole('alert')).toHaveTextContent('Too many attempts');
    expect(screen.getByText('Ravi Kumar')).toBeInTheDocument();
  });

  it('mutes and unmutes a friend from their menu', async () => {
    const state = createSocialState({ friends: [makeFriend()] });
    const user = userEvent.setup();
    renderFriends(state);
    await findPageHeading('Friends');

    await choosePersonAction(user, 'Ravi Kumar', 'Mute notifications');
    expect(await screen.findByText('Muted Ravi Kumar')).toBeInTheDocument();
    expect(
      screen.getByText('You won’t get notifications from them. They aren’t told.'),
    ).toBeInTheDocument();
    const list = screen.getByRole('region', { name: 'Your friends' });
    expect(within(list).getByText('Muted')).toBeInTheDocument();

    // Now that the state is known, the menu offers only the opposite choice.
    await user.click(screen.getByRole('button', { name: 'More actions for Ravi Kumar' }));
    expect(screen.queryByRole('menuitem', { name: 'Mute notifications' })).not.toBeInTheDocument();
    await user.click(screen.getByRole('menuitem', { name: 'Unmute notifications' }));
    expect(
      await screen.findByText('Notifications from Ravi Kumar are on again'),
    ).toBeInTheDocument();
    expect(within(list).queryByText('Muted')).not.toBeInTheDocument();

    expect(writes(state)).toEqual([
      { method: 'POST', path: `/users/${FRIEND_ID}/mute`, body: { muted: true } },
      { method: 'POST', path: `/users/${FRIEND_ID}/mute`, body: { muted: false } },
    ]);
  });

  it('lists people you muted under Blocked & muted and unmutes them there', async () => {
    const state = createSocialState({ friends: [makeFriend()] });
    const user = userEvent.setup();
    renderFriends(state);
    await choosePersonAction(user, 'Ravi Kumar', 'Mute notifications');
    expect(await screen.findByText('Muted Ravi Kumar')).toBeInTheDocument();

    await user.click(screen.getByRole('tab', { name: 'Blocked & muted' }));
    const muted = await screen.findByRole('region', { name: 'Muted people' });
    expect(await within(muted).findByText('Ravi Kumar')).toBeInTheDocument();
    expect(within(muted).getByText('Muted November 5, 2026')).toBeInTheDocument();
    await user.click(
      within(muted).getByRole('button', { name: 'Unmute notifications from Ravi Kumar' }),
    );
    expect(await within(muted).findByText('You haven’t muted anyone')).toBeInTheDocument();
    expect(writes(state).at(-1)).toEqual({
      method: 'POST',
      path: `/users/${FRIEND_ID}/mute`,
      body: { muted: false },
    });
    // The friends list shows the change too (profiles carry `muted`).
    await user.click(screen.getByRole('tab', { name: 'Friends' }));
    const list = await screen.findByRole('region', { name: 'Your friends' });
    await within(list).findByText('Ravi Kumar');
    expect(within(list).queryByText('Muted')).not.toBeInTheDocument();
  });

  it('shows the muted badge from the profile the API returns', async () => {
    const state = createSocialState({
      friends: [makeFriend({ muted: true })],
      mutes: [makeMuted()],
    });
    const user = userEvent.setup();
    renderFriends(state);
    const list = await screen.findByRole('region', { name: 'Your friends' });
    expect(await within(list).findByText('Muted')).toBeInTheDocument();
    // Only the opposite choice is offered.
    await user.click(screen.getByRole('button', { name: 'More actions for Ravi Kumar' }));
    expect(screen.queryByRole('menuitem', { name: 'Mute notifications' })).not.toBeInTheDocument();
    expect(screen.getByRole('menuitem', { name: 'Unmute notifications' })).toBeInTheDocument();
  });
});

describe('FriendsPage: tabs', () => {
  it('moves between sections with the arrow, Home and End keys and keeps the tab in the URL', async () => {
    const user = userEvent.setup();
    const { router } = renderFriends(createSocialState());
    await findPageHeading('Friends');
    const friendsTab = screen.getByRole('tab', { name: 'Friends' });
    expect(friendsTab).toHaveAttribute('aria-selected', 'true');
    expect(screen.getByRole('tabpanel', { name: 'Friends' })).toBeInTheDocument();

    friendsTab.focus();
    await user.keyboard('{ArrowRight}');
    const requestsTab = screen.getByRole('tab', { name: 'Requests' });
    expect(requestsTab).toHaveFocus();
    expect(requestsTab).toHaveAttribute('aria-selected', 'true');
    expect(router.state.location.search).toBe('?tab=requests');
    expect(await screen.findByRole('tabpanel', { name: 'Requests' })).toBeInTheDocument();

    await user.keyboard('{End}');
    expect(screen.getByRole('tab', { name: 'Privacy' })).toHaveFocus();
    expect(router.state.location.search).toBe('?tab=privacy');
    await user.keyboard('{ArrowRight}');
    expect(friendsTab).toHaveFocus();
    await user.keyboard('{ArrowLeft}');
    expect(screen.getByRole('tab', { name: 'Privacy' })).toHaveFocus();
    await user.keyboard('{Home}');
    expect(friendsTab).toHaveFocus();
    expect(router.state.location.search).toBe('');
    // Only the selected tab is in the Tab order.
    expect(requestsTab).toHaveAttribute('tabindex', '-1');
  });

  it('opens the section named in the URL', async () => {
    renderFriends(createSocialState({ requests: [makeIncomingRequest()] }), {
      path: '/friends?tab=requests',
    });
    await findPageHeading('Friends');
    expect(await screen.findByRole('tab', { name: 'Requests, 1 waiting' })).toHaveAttribute(
      'aria-selected',
      'true',
    );
    expect(await screen.findByRole('region', { name: 'Requests for you' })).toBeInTheDocument();
  });
});
