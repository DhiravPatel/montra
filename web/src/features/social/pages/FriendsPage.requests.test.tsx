import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { delay, http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, errorBody } from '@/tests/fixtures';
import { findPageHeading } from '@/tests/render';
import {
  KABIR_ID,
  REQUEST_IN_ID,
  REQUEST_OUT_ID,
  choosePersonAction,
  createSocialState,
  makeIncomingRequest,
  makeOutgoingRequest,
  renderFriends,
  writes,
} from '@/tests/socialFixtures';

const requestsPath = '/friends?tab=requests';

describe('FriendsPage: requests', () => {
  it('shows who asked, when, and their note, separately from requests you sent', async () => {
    const state = createSocialState({
      requests: [makeIncomingRequest({ message: 'Hi from the trek!' }), makeOutgoingRequest()],
    });
    renderFriends(state, { path: requestsPath });
    await findPageHeading('Friends');

    const incoming = await screen.findByRole('region', { name: 'Requests for you' });
    expect(within(incoming).getByText('Kabir Singh')).toBeInTheDocument();
    expect(within(incoming).getByText('@kabir')).toBeInTheDocument();
    expect(within(incoming).getByText('Sent November 3, 2026')).toBeInTheDocument();
    expect(within(incoming).getByText('Hi from the trek!')).toBeInTheDocument();
    expect(within(incoming).queryByText('Meera Shah')).not.toBeInTheDocument();

    const outgoing = screen.getByRole('region', { name: 'Requests you sent' });
    expect(within(outgoing).getByText('Meera Shah')).toBeInTheDocument();
    expect(
      within(outgoing).getByRole('button', { name: 'Cancel request to Meera Shah' }),
    ).toBeInTheDocument();
  });

  it('accepts a request, says so, and lists the new friend', async () => {
    const state = createSocialState({ requests: [makeIncomingRequest()] });
    const user = userEvent.setup();
    renderFriends(state, { path: requestsPath });

    await user.click(
      await screen.findByRole('button', { name: 'Accept request from Kabir Singh' }),
    );
    expect(await screen.findByText('You’re now friends with Kabir Singh')).toBeInTheDocument();
    expect(await screen.findByText('No requests waiting')).toBeInTheDocument();
    expect(screen.getByRole('tab', { name: 'Requests' })).toBeInTheDocument();
    expect(writes(state)).toEqual([
      { method: 'POST', path: `/friend-requests/${REQUEST_IN_ID}/accept`, body: null },
    ]);

    await user.click(screen.getByRole('tab', { name: 'Friends' }));
    const friends = await screen.findByRole('region', { name: 'Your friends' });
    expect(await within(friends).findByText('Kabir Singh')).toBeInTheDocument();
  });

  it('declines a request', async () => {
    const state = createSocialState({ requests: [makeIncomingRequest()] });
    const user = userEvent.setup();
    renderFriends(state, { path: requestsPath });

    await user.click(
      await screen.findByRole('button', { name: 'Decline request from Kabir Singh' }),
    );
    expect(await screen.findByText('Declined the request from Kabir Singh')).toBeInTheDocument();
    expect(await screen.findByText('No requests waiting')).toBeInTheDocument();
    expect(writes(state)).toEqual([
      { method: 'POST', path: `/friend-requests/${REQUEST_IN_ID}/decline`, body: null },
    ]);
  });

  it('cancels a request you sent', async () => {
    const state = createSocialState({ requests: [makeOutgoingRequest()] });
    const user = userEvent.setup();
    renderFriends(state, { path: requestsPath });

    await user.click(await screen.findByRole('button', { name: 'Cancel request to Meera Shah' }));
    expect(await screen.findByText('Cancelled your request to Meera Shah')).toBeInTheDocument();
    expect(await screen.findByText('You haven’t sent any requests')).toBeInTheDocument();
    expect(writes(state)).toEqual([
      { method: 'POST', path: `/friend-requests/${REQUEST_OUT_ID}/cancel`, body: null },
    ]);
  });

  it('sends one answer even when the button is pressed twice', async () => {
    const state = createSocialState({ requests: [makeIncomingRequest()] });
    const user = userEvent.setup();
    renderFriends(state, {
      path: requestsPath,
      overrides: [
        http.post(`${API}/friend-requests/:id/accept`, async () => {
          await delay(100);
          return undefined; // fall through to the social backend
        }),
      ],
    });

    const accept = await screen.findByRole('button', { name: 'Accept request from Kabir Singh' });
    await user.click(accept);
    await user.click(accept);
    expect(accept).toHaveAttribute('aria-busy', 'true');
    expect(await screen.findByText('You’re now friends with Kabir Singh')).toBeInTheDocument();
    expect(writes(state)).toHaveLength(1);
  });

  it('explains when a request is no longer waiting and refreshes the list', async () => {
    const state = createSocialState({ requests: [makeIncomingRequest()] });
    const user = userEvent.setup();
    renderFriends(state, { path: requestsPath });
    await screen.findByText('Kabir Singh');
    // Kabir cancelled it in the meantime.
    state.requests = [];

    await user.click(screen.getByRole('button', { name: 'Accept request from Kabir Singh' }));
    expect(
      await screen.findByText(
        'This request is no longer waiting. It may have been answered or cancelled.',
      ),
    ).toBeInTheDocument();
    expect(await screen.findByText('No requests waiting')).toBeInTheDocument();
  });

  it('shows empty states for both lists', async () => {
    renderFriends(createSocialState(), { path: requestsPath });
    expect(await screen.findByText('No requests waiting')).toBeInTheDocument();
    expect(screen.getByText('You haven’t sent any requests')).toBeInTheDocument();
  });

  it('shows a recoverable error', async () => {
    renderFriends(createSocialState(), {
      path: requestsPath,
      overrides: [
        http.get(`${API}/friend-requests`, () =>
          HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE', request_id: 'req-fr' }), {
            status: 503,
          }),
        ),
      ],
    });
    expect(await screen.findByText('We couldn’t load your friend requests')).toBeInTheDocument();
    expect(screen.getByText('req-fr')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Try again' })).toBeInTheDocument();
  });

  it('blocks someone who sent a request, which also removes the request', async () => {
    const state = createSocialState({ requests: [makeIncomingRequest()] });
    const user = userEvent.setup();
    renderFriends(state, { path: requestsPath });

    await choosePersonAction(user, 'Kabir Singh', 'Block');
    const dialog = await screen.findByRole('dialog', { name: 'Block Kabir Singh?' });
    await user.click(within(dialog).getByRole('button', { name: 'Block' }));
    expect(await screen.findByText('Kabir Singh is blocked')).toBeInTheDocument();
    expect(await screen.findByText('No requests waiting')).toBeInTheDocument();
    expect(writes(state)).toEqual([
      { method: 'POST', path: `/users/${KABIR_ID}/block`, body: null },
    ]);
  });
});
