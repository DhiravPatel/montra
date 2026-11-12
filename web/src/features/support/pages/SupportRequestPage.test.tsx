import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeAll, describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import type { SupportMessage } from '@/features/support/types';
import {
  REQUEST_ID,
  dailyCapDetail,
  makeStaffReply,
  makeSupportMessage,
  makeSupportRequest,
  referenceOf,
} from '@/tests/supportFixtures';

const path = `/help/requests/${REQUEST_ID}`;
const user = () => makeUser({ onboarding_completed: true });

/** GET /support/requests/{id}/messages answering `messages` (a test can change the list). */
function serveThread(messages: SupportMessage[] = []) {
  const state = { messages, reads: 0 };
  server.use(
    http.get(`${API}/support/requests/:id/messages`, () => {
      state.reads += 1;
      return HttpResponse.json(envelope(state.messages));
    }),
  );
  return state;
}

function serveRequest(overrides: Parameters<typeof makeSupportRequest>[0] = {}) {
  server.use(
    http.get(`${API}/support/requests/:id`, () =>
      HttpResponse.json(envelope(makeSupportRequest(overrides))),
    ),
  );
}

beforeAll(async () => {
  await import('./SupportRequestPage');
  await import('./HelpPage');
});

describe('SupportRequestPage', () => {
  it('shows the request, its status and the conversation with support', async () => {
    serveThread([makeSupportMessage(), makeStaffReply()]);
    server.use(
      http.get(`${API}/support/requests/:id`, ({ params }) =>
        HttpResponse.json(
          envelope(
            makeSupportRequest({
              id: String(params.id),
              status: 'in_progress',
              updated_at: '2026-11-04T12:30:00Z',
              message_count: 2,
              last_message_at: '2026-11-04T11:00:00Z',
            }),
          ),
        ),
      ),
    );
    renderRoute(path, { user: user() });
    await findPageHeading('Export button spins');
    expect(document.title).toBe('Support request · Montra');

    const status = screen.getByRole('region', { name: 'Status' });
    expect(within(status).getByText('In progress')).toBeInTheDocument();
    expect(
      within(status).getByText('Someone from the support team is looking into it.'),
    ).toBeInTheDocument();
    expect(within(status).getByText('Something isn’t working')).toBeInTheDocument();
    expect(within(status).getByText(referenceOf(REQUEST_ID))).toBeInTheDocument();
    expect(within(status).getByRole('button', { name: 'Copy reference' })).toBeInTheDocument();

    const message = screen.getByRole('region', { name: 'Your message' });
    expect(within(message).getByText(/The CSV export spins forever\./)).toBeInTheDocument();

    expect(within(status).getByText('Last message')).toBeInTheDocument();

    const thread = screen.getByRole('region', { name: 'Conversation' });
    const items = within(
      await within(thread).findByRole('list', { name: 'Messages' }),
    ).getAllByRole('listitem');
    expect(items).toHaveLength(2);
    expect(within(items[0]!).getByText('You')).toBeInTheDocument();
    expect(within(items[0]!).getByText('It happens with CSV only.')).toBeInTheDocument();
    expect(within(items[1]!).getByText('Montra support')).toBeInTheDocument();
    expect(
      within(items[1]!).getByText('Thanks. We found the problem and fixed it.'),
    ).toBeInTheDocument();
    expect(within(thread).getByLabelText('Add a message')).toBeInTheDocument();
    expect(screen.queryByText(/replies by email/)).not.toBeInTheDocument();
  });

  it('adds a message to the thread', async () => {
    const thread = serveThread([]);
    serveRequest();
    const bodies: unknown[] = [];
    server.use(
      http.post(`${API}/support/requests/:id/messages`, async ({ request, params }) => {
        expect(params.id).toBe(REQUEST_ID);
        const body = (await request.json()) as { body: string };
        bodies.push(body);
        const created = makeSupportMessage({ body: body.body });
        thread.messages = [created];
        return HttpResponse.json(envelope(created), { status: 201 });
      }),
    );
    const events = userEvent.setup();
    renderRoute(path, { user: user() });
    await findPageHeading('Export button spins');
    const region = screen.getByRole('region', { name: 'Conversation' });
    expect(await within(region).findByText('No messages yet')).toBeInTheDocument();
    await events.type(
      within(region).getByLabelText('Add a message'),
      '  It fails on Firefox too. ',
    );
    await events.click(within(region).getByRole('button', { name: 'Send message' }));

    expect(await screen.findByText('Message sent')).toBeInTheDocument();
    expect(await within(region).findByText('It fails on Firefox too.')).toBeInTheDocument();
    expect(within(region).getByLabelText('Add a message')).toHaveValue('');
    expect(bodies).toEqual([{ body: 'It fails on Firefox too.' }]);
  });

  it('keeps card numbers out before sending, and explains the API’s own refusal', async () => {
    serveThread([]);
    serveRequest();
    let posts = 0;
    server.use(
      http.post(`${API}/support/requests/:id/messages`, () => {
        posts += 1;
        return HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [{ field: 'body.body', code: 'contains_secret', message: 'Remove secrets.' }],
          }),
          { status: 422 },
        );
      }),
    );
    const events = userEvent.setup();
    renderRoute(path, { user: user() });
    await findPageHeading('Export button spins');
    const region = screen.getByRole('region', { name: 'Conversation' });
    const field = await within(region).findByLabelText('Add a message');
    await events.type(field, 'My card is 4111 1111 1111 1111');
    await events.click(within(region).getByRole('button', { name: 'Send message' }));
    await waitFor(() => {
      expect(field).toHaveAccessibleDescription(/Remove card numbers, PINs, OTPs or passwords\./);
    });
    expect(posts).toBe(0);

    await events.clear(field);
    await events.type(field, 'Something the server still refuses');
    await events.click(within(region).getByRole('button', { name: 'Send message' }));
    await waitFor(() => {
      expect(posts).toBe(1);
    });
    expect(field).toHaveAccessibleDescription(/Montra support never needs them\./);
  });

  it('explains the daily message cap and waits out Retry-After', async () => {
    serveThread([]);
    serveRequest();
    let posts = 0;
    server.use(
      http.post(`${API}/support/requests/:id/messages`, () => {
        posts += 1;
        return HttpResponse.json(
          errorBody({ code: 'RATE_LIMITED', details: [dailyCapDetail('support messages')] }),
          { status: 429, headers: { 'Retry-After': '3600' } },
        );
      }),
    );
    const events = userEvent.setup();
    renderRoute(path, { user: user() });
    await findPageHeading('Export button spins');
    const region = screen.getByRole('region', { name: 'Conversation' });
    await events.type(await within(region).findByLabelText('Add a message'), 'One more detail');
    const send = within(region).getByRole('button', { name: 'Send message' });
    await events.click(send);
    expect(
      await within(region).findByText(
        'You can send up to 10 messages a day in support conversations. You can send more in 60 minutes. What you’ve already sent is safe.',
      ),
    ).toBeInTheDocument();
    expect(send).toHaveAttribute('aria-disabled', 'true');
    await events.click(send);
    expect(posts).toBe(1);
  });

  it('takes no messages on a closed request, and handles one closed meanwhile', async () => {
    serveThread([makeStaffReply()]);
    serveRequest({ status: 'closed' });
    const first = renderRoute(path, { user: user() });
    await findPageHeading('Export button spins');
    const closed = screen.getByRole('region', { name: 'Conversation' });
    expect(
      await within(closed).findByText(
        'This request is closed, so it takes no new messages. If you still need help, send a follow-up.',
      ),
    ).toBeInTheDocument();
    expect(within(closed).queryByLabelText('Add a message')).not.toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Send a follow-up' })).toBeInTheDocument();
    first.unmount();

    let status: 'open' | 'closed' = 'open';
    serveThread([]);
    server.use(
      http.get(`${API}/support/requests/:id`, () =>
        HttpResponse.json(envelope(makeSupportRequest({ status }))),
      ),
      http.post(`${API}/support/requests/:id/messages`, () => {
        status = 'closed';
        return HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [{ code: 'request_closed', message: 'This request is closed.' }],
          }),
          { status: 422 },
        );
      }),
    );
    const events = userEvent.setup();
    renderRoute(path, { user: user() });
    await findPageHeading('Export button spins');
    const region = screen.getByRole('region', { name: 'Conversation' });
    await events.type(await within(region).findByLabelText('Add a message'), 'Hello again');
    await events.click(within(region).getByRole('button', { name: 'Send message' }));
    // The page reloads the request, which is now closed.
    expect(
      await within(region).findByText(
        'This request is closed, so it takes no new messages. If you still need help, send a follow-up.',
      ),
    ).toBeInTheDocument();
  });

  it('offers a retry when the conversation cannot be loaded', async () => {
    serveRequest();
    let calls = 0;
    server.use(
      http.get(`${API}/support/requests/:id/messages`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 })
          : HttpResponse.json(envelope([makeStaffReply()]));
      }),
    );
    const events = userEvent.setup();
    renderRoute(path, { user: user() });
    await findPageHeading('Export button spins');
    const region = screen.getByRole('region', { name: 'Conversation' });
    expect(
      await within(region).findByText('We couldn’t load the conversation'),
    ).toBeInTheDocument();
    await events.click(within(region).getByRole('button', { name: 'Try again' }));
    expect(
      await within(region).findByText('Thanks. We found the problem and fixed it.'),
    ).toBeInTheDocument();
  });

  it('starts a follow-up that quotes the reference', async () => {
    serveThread([]);
    server.use(
      http.get(`${API}/support/requests/:id`, () =>
        HttpResponse.json(envelope(makeSupportRequest({ status: 'resolved' }))),
      ),
      http.get(`${API}/support/requests`, () => HttpResponse.json(envelope([]))),
    );
    const events = userEvent.setup();
    const { router } = renderRoute(path, { user: user() });
    await findPageHeading('Export button spins');
    await events.click(screen.getByRole('link', { name: 'Send a follow-up' }));

    await findPageHeading('Help & support');
    // The reference travels in router state, never in the address.
    expect(router.state.location.search).toBe('');
    const form = screen.getByRole('region', { name: 'Contact support' });
    expect(within(form).getByLabelText('Subject')).toHaveValue(
      `Follow-up to request ${referenceOf(REQUEST_ID)}`,
    );
  });

  it('explains a request that does not exist (or belongs to someone else)', async () => {
    server.use(
      http.get(`${API}/support/requests/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    renderRoute(path, { user: user() });
    expect(await screen.findByText('We couldn’t find this request')).toBeInTheDocument();
    expect(screen.getAllByRole('link', { name: 'Back to help & support' })[0]).toHaveAttribute(
      'href',
      '/help',
    );
  });

  it('offers a retry when the request cannot be loaded', async () => {
    serveThread([]);
    let calls = 0;
    server.use(
      http.get(`${API}/support/requests/:id`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 })
          : HttpResponse.json(envelope(makeSupportRequest()));
      }),
    );
    const events = userEvent.setup();
    renderRoute(path, { user: user() });
    expect(await screen.findByText('We couldn’t load this request')).toBeInTheDocument();
    await events.click(screen.getByRole('button', { name: 'Try again' }));
    await findPageHeading('Export button spins');
  });

  it('shows the permission state on 403', async () => {
    server.use(
      http.get(`${API}/support/requests/:id`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute(path, { user: user() });
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });
});
