import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, errorBody } from '@/tests/fixtures';
import { findPageHeading } from '@/tests/render';
import {
  MEERA_ID,
  REQUEST_IN_ID,
  choosePersonAction,
  createSocialState,
  makeIncomingRequest,
  makePerson,
  renderFriends,
  socialUser,
  writes,
} from '@/tests/socialFixtures';

const findPath = '/friends?tab=find';

async function search(user: ReturnType<typeof userEvent.setup>, username: string) {
  const field = await screen.findByRole('textbox', { name: 'Username' });
  await user.clear(field);
  await user.type(field, username);
  await user.click(screen.getByRole('button', { name: 'Search' }));
}

function announced() {
  return screen.getByTestId('announcer-polite');
}

describe('FriendsPage: find people', () => {
  it('finds someone by exact username, announces it, and sends a request with a note', async () => {
    const state = createSocialState({ people: [makePerson()] });
    const user = userEvent.setup();
    renderFriends(state, { path: findPath });
    await findPageHeading('Friends');

    await search(user, ' @Meera_S ');
    const result = await screen.findByRole('article', { name: 'Search result: Meera Shah' });
    expect(within(result).getByText('@meera_s')).toBeInTheDocument();
    await waitFor(() => {
      expect(announced()).toHaveTextContent('Found Meera Shah, @meera_s.');
    });
    expect(state.calls[0]).toEqual({ method: 'GET', path: '/users/search?q=meera_s', body: null });

    await user.type(within(result).getByRole('textbox', { name: /Add a note/ }), 'From the trek');
    await user.click(
      within(result).getByRole('button', { name: 'Send friend request to Meera Shah' }),
    );

    expect(await screen.findByText('Friend request sent to Meera Shah')).toBeInTheDocument();
    expect(await within(result).findByText('Request sent')).toBeInTheDocument();
    expect(
      within(result).getByRole('button', { name: 'Cancel request to Meera Shah' }),
    ).toBeInTheDocument();
    expect(writes(state)).toEqual([
      {
        method: 'POST',
        path: '/friend-requests',
        body: { user_id: MEERA_ID, message: 'From the trek' },
      },
    ]);
    // The page title never carries names or usernames.
    expect(document.title).toBe('Friends · Montra');
  });

  it('finds nobody for a partial username and explains that only the exact one works', async () => {
    // The API matches exact usernames only: "meera" does not find @meera_s.
    const state = createSocialState({ people: [makePerson()] });
    const user = userEvent.setup();
    renderFriends(state, { path: findPath });
    expect(
      await screen.findByText(
        'People are found only by their exact username: a partial username finds no one. Montra shows only people who chose to be findable, and never shows anyone’s money.',
      ),
    ).toBeInTheDocument();

    await search(user, 'meera');
    expect(await screen.findByText('No one found with the username @meera')).toBeInTheDocument();
    expect(screen.queryByText('Meera Shah')).not.toBeInTheDocument();
    expect(
      screen.getByText(
        'Only the exact username finds someone, so check the spelling. Some people choose not to appear in search, and new accounts stay hidden until they turn it on.',
      ),
    ).toBeInTheDocument();
    expect(
      screen.getByText('You can also share your username, @asha, so they can find you.'),
    ).toBeInTheDocument();
    await waitFor(() => {
      expect(announced()).toHaveTextContent('No one found with the username @meera');
    });
  });

  it('checks the username before searching', async () => {
    const state = createSocialState();
    const user = userEvent.setup();
    renderFriends(state, { path: findPath });

    await user.click(await screen.findByRole('button', { name: 'Search' }));
    const field = screen.getByRole('textbox', { name: 'Username' });
    expect(field).toHaveAccessibleDescription(/Enter a username\./);
    expect(field).toHaveFocus();

    await search(user, 'a b');
    expect(field).toHaveAccessibleDescription(
      /Usernames have 3 to 30 characters: lowercase letters, numbers, dots and underscores\./,
    );
    expect(field).toHaveAttribute('aria-invalid', 'true');
    expect(state.calls).toEqual([]);
  });

  it('recognises your own username without searching', async () => {
    const state = createSocialState();
    const user = userEvent.setup();
    renderFriends(state, { path: findPath, user: socialUser({ username: 'asha' }) });

    await search(user, '@ASHA');
    expect(await screen.findByText('That’s your own username')).toBeInTheDocument();
    expect(state.calls).toEqual([]);
  });

  it('explains politely when someone is not accepting friend requests', async () => {
    const state = createSocialState({ people: [makePerson()] });
    const user = userEvent.setup();
    renderFriends(state, {
      path: findPath,
      overrides: [
        http.post(`${API}/friend-requests`, () =>
          HttpResponse.json(
            errorBody({
              code: 'DOMAIN_RULE_VIOLATION',
              message: 'This person is not accepting friend requests.',
              details: [
                {
                  message: 'This person is not accepting friend requests.',
                  code: 'requests_closed',
                },
              ],
            }),
            { status: 422 },
          ),
        ),
      ],
    });

    await search(user, 'meera_s');
    const result = await screen.findByRole('article', { name: 'Search result: Meera Shah' });
    await user.click(
      within(result).getByRole('button', { name: 'Send friend request to Meera Shah' }),
    );
    expect(await within(result).findByRole('alert')).toHaveTextContent(
      'Meera Shah isn’t accepting friend requests right now.',
    );
  });

  it('explains coded conflicts: already friends, or a request already waiting', async () => {
    const state = createSocialState({ people: [makePerson()] });
    let code = 'already_friends';
    const user = userEvent.setup();
    renderFriends(state, {
      path: findPath,
      overrides: [
        http.post(`${API}/friend-requests`, () =>
          HttpResponse.json(
            errorBody({
              code: 'CONFLICT',
              message: 'Conflict.',
              details: [{ message: 'Conflict.', code }],
            }),
            { status: 409 },
          ),
        ),
      ],
    });

    await search(user, 'meera_s');
    const result = await screen.findByRole('article', { name: 'Search result: Meera Shah' });
    await user.click(
      within(result).getByRole('button', { name: 'Send friend request to Meera Shah' }),
    );
    expect(await within(result).findByRole('alert')).toHaveTextContent(
      'You and Meera Shah are already friends.',
    );

    code = 'request_pending';
    await user.click(
      within(result).getByRole('button', { name: 'Send friend request to Meera Shah' }),
    );
    await waitFor(() => {
      expect(within(result).getByRole('alert')).toHaveTextContent(
        'You already sent Meera Shah a request. You’ll become friends when they accept.',
      );
    });
  });

  it('explains when the person can no longer be found', async () => {
    const state = createSocialState({ people: [makePerson()] });
    const user = userEvent.setup();
    renderFriends(state, {
      path: findPath,
      overrides: [
        http.post(`${API}/friend-requests`, () =>
          HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
        ),
      ],
    });

    await search(user, 'meera_s');
    const result = await screen.findByRole('article', { name: 'Search result: Meera Shah' });
    await user.click(
      within(result).getByRole('button', { name: 'Send friend request to Meera Shah' }),
    );
    expect(await within(result).findByRole('alert')).toHaveTextContent(
      'We couldn’t send a request to Meera Shah. They may have changed their username or stopped being findable.',
    );
  });

  it('accepts their request from the search result when they already asked you', async () => {
    const kabir = makeIncomingRequest().from;
    const state = createSocialState({
      people: [{ ...kabir, connection: 'request_received' }],
      requests: [makeIncomingRequest()],
    });
    const user = userEvent.setup();
    renderFriends(state, { path: findPath });

    await search(user, 'kabir');
    const result = await screen.findByRole('article', { name: 'Search result: Kabir Singh' });
    expect(within(result).getByText('Sent you a request')).toBeInTheDocument();
    await user.click(
      within(result).getByRole('button', { name: 'Accept request from Kabir Singh' }),
    );

    expect(await screen.findByText('You’re now friends with Kabir Singh')).toBeInTheDocument();
    expect(
      await within(result).findByText('You and Kabir Singh are already friends.'),
    ).toBeInTheDocument();
    expect(writes(state)).toEqual([
      { method: 'POST', path: `/friend-requests/${REQUEST_IN_ID}/accept`, body: null },
    ]);
  });

  it('blocks someone found by search, after which they disappear', async () => {
    const state = createSocialState({ people: [makePerson()] });
    const user = userEvent.setup();
    renderFriends(state, { path: findPath });

    await search(user, 'meera_s');
    await screen.findByRole('article', { name: 'Search result: Meera Shah' });
    await choosePersonAction(user, 'Meera Shah', 'Block');
    const dialog = await screen.findByRole('dialog', { name: 'Block Meera Shah?' });
    await user.click(within(dialog).getByRole('button', { name: 'Block' }));

    expect(await screen.findByText('You blocked @meera_s')).toBeInTheDocument();
    expect(screen.queryByRole('article')).not.toBeInTheDocument();
    expect(writes(state)).toEqual([
      { method: 'POST', path: `/users/${MEERA_ID}/block`, body: null },
    ]);
  });

  it('shows a calm error when searching is limited for a moment', async () => {
    const state = createSocialState({ people: [makePerson()] });
    const user = userEvent.setup();
    renderFriends(state, {
      path: findPath,
      overrides: [
        http.get(`${API}/users/search`, () =>
          HttpResponse.json(errorBody({ code: 'RATE_LIMITED' }), {
            status: 429,
            headers: { 'Retry-After': '2' },
          }),
        ),
      ],
    });

    await search(user, 'meera_s');
    expect(await screen.findByText('We couldn’t search right now')).toBeInTheDocument();
    expect(screen.getByText(/Too many attempts\. Try again in/)).toBeInTheDocument();
  });

  it('explains at the field when the API wants a longer username (query_too_short)', async () => {
    const state = createSocialState({ people: [makePerson()] });
    const searched: string[] = [];
    const user = userEvent.setup();
    renderFriends(state, {
      path: findPath,
      overrides: [
        http.get(`${API}/users/search`, ({ request }) => {
          searched.push(new URL(request.url).searchParams.get('q') ?? '');
          return HttpResponse.json(
            errorBody({
              code: 'VALIDATION_ERROR',
              details: [
                {
                  field: 'query.q',
                  message: 'Enter the full username (at least 4 characters).',
                  code: 'query_too_short',
                  params: { min: '4' },
                },
              ],
            }),
            { status: 422 },
          );
        }),
      ],
    });

    await search(user, 'mee');
    const field = screen.getByRole('textbox', { name: 'Username' });
    await waitFor(() => {
      expect(field).toHaveAccessibleDescription(
        /Enter the full username \(at least 4 characters\)\./,
      );
    });
    expect(field).toHaveFocus();
    expect(searched).toEqual(['mee']);
    expect(screen.queryByText('We couldn’t search right now')).not.toBeInTheDocument();
  });
});
