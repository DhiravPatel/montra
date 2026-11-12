import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeAll, describe, expect, it } from 'vitest';
import type { StaffRequest } from '@/features/support/types';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import {
  REQUEST_ID,
  SECURITY_REQUEST_ID,
  makeStaffRequest,
  makeSupportMessage,
  referenceOf,
} from '@/tests/supportFixtures';

const staff = () => makeUser({ onboarding_completed: true, platform_role: 'support' });

/** The queue as the API orders it: security and privacy first. */
function queue(): StaffRequest[] {
  return [
    makeStaffRequest({
      id: SECURITY_REQUEST_ID,
      kind: 'security',
      subject: 'Odd sign-in',
      body: 'I saw a sign-in I did not make.',
      created_at: '2026-11-04T10:00:00Z',
      updated_at: '2026-11-04T10:00:00Z',
    }),
    makeStaffRequest({
      signed_in: false,
      contact_email: 'locked.out@example.com',
      client_kind: undefined,
      app_version: undefined,
    }),
  ];
}

interface Recorded {
  queries: URL[];
  patches: { id: string; body: unknown }[];
}

function serveQueue(
  list: () => StaffRequest[] = queue,
  patch?: (id: string) => Response | Promise<Response>,
): Recorded {
  const recorded: Recorded = { queries: [], patches: [] };
  server.use(
    http.get(`${API}/support/queue`, ({ request }) => {
      recorded.queries.push(new URL(request.url));
      return HttpResponse.json(envelope(list()));
    }),
    http.patch(`${API}/support/queue/:id`, async ({ params, request }) => {
      const body = (await request.json()) as { status: StaffRequest['status'] };
      recorded.patches.push({ id: String(params.id), body });
      if (patch) return patch(String(params.id));
      const current = list().find((item) => item.id === params.id) ?? makeStaffRequest();
      return HttpResponse.json(envelope({ ...current, status: body.status }));
    }),
  );
  return recorded;
}

async function openQueue(path = '/staff/support') {
  const events = userEvent.setup();
  const view = renderRoute(path, { user: staff() });
  await findPageHeading('Support queue');
  return { events, ...view };
}

beforeAll(async () => {
  await import('./SupportQueuePage');
});

describe('SupportQueuePage', () => {
  it('lists the queue in the API’s order and explains that actions are audited', async () => {
    serveQueue();
    await openQueue();
    expect(screen.getByText('Actions here are audited')).toBeInTheDocument();

    const list = screen.getByRole('region', { name: 'Requests' });
    const items = await within(list).findAllByRole('listitem');
    expect(items).toHaveLength(2);
    expect(within(items[0]!).getByRole('heading', { name: 'Odd sign-in' })).toBeInTheDocument();
    expect(within(items[0]!).getByText('Security concern')).toBeInTheDocument();
    expect(within(items[0]!).getByText('A signed-in account')).toBeInTheDocument();
    expect(within(items[0]!).getByText('web 0.1.0')).toBeInTheDocument();

    expect(within(items[1]!).getByText('The public contact form')).toBeInTheDocument();
    const reply = within(items[1]!).getByRole('link', { name: 'locked.out@example.com' });
    expect(reply).toHaveAttribute(
      'href',
      `mailto:locked.out@example.com?subject=${encodeURIComponent(
        `Montra support: request ${referenceOf(REQUEST_ID)}`,
      )}`,
    );
    expect(within(list).getByText('2 requests')).toBeInTheDocument();
  });

  it('shows a message only when asked', async () => {
    serveQueue();
    const { events } = await openQueue();
    const list = screen.getByRole('region', { name: 'Requests' });
    const items = await within(list).findAllByRole('listitem');
    const message = within(items[0]!).getByText('I saw a sign-in I did not make.');
    expect(message).not.toBeVisible();
    await events.click(within(items[0]!).getByRole('button', { name: 'Show message' }));
    expect(message).toBeVisible();
  });

  it('changes a status (audited by the API) and refreshes the queue', async () => {
    let data = queue();
    const recorded = serveQueue(() => data);
    const { events } = await openQueue();
    const reference = referenceOf(SECURITY_REQUEST_ID);
    data = data.map((item) =>
      item.id === SECURITY_REQUEST_ID ? { ...item, status: 'in_progress' } : item,
    );
    await events.click(
      await screen.findByRole('button', { name: `Mark in progress: request ${reference}` }),
    );

    expect(await screen.findByText(`Request ${reference} is now “In progress”`)).toBeVisible();
    expect(recorded.patches).toEqual([
      { id: SECURITY_REQUEST_ID, body: { status: 'in_progress' } },
    ]);
    await waitFor(() => {
      expect(recorded.queries.length).toBeGreaterThanOrEqual(2);
    });
    expect(
      screen.queryByRole('button', { name: `Mark in progress: request ${reference}` }),
    ).not.toBeInTheDocument();
  });

  it('confirms before closing a request for good', async () => {
    const recorded = serveQueue();
    const { events } = await openQueue();
    const reference = referenceOf(REQUEST_ID);
    await events.click(await screen.findByRole('button', { name: `Close: request ${reference}` }));
    const dialog = await screen.findByRole('dialog', { name: 'Close this request?' });
    expect(
      within(dialog).getByText(
        `Request ${reference} will be closed for good: its status can’t be changed afterwards. The change is recorded in the audit log.`,
      ),
    ).toBeInTheDocument();
    expect(recorded.patches).toHaveLength(0);
    await events.click(within(dialog).getByRole('button', { name: 'Close request' }));

    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    });
    expect(recorded.patches).toEqual([{ id: REQUEST_ID, body: { status: 'closed' } }]);
    expect(await screen.findByText(`Request ${reference} is now “Closed”`)).toBeVisible();
  });

  it('explains when a request was already closed by someone else', async () => {
    serveQueue(queue, () =>
      HttpResponse.json(
        errorBody({
          code: 'DOMAIN_RULE_VIOLATION',
          details: [{ code: 'request_closed', message: 'This request is closed.' }],
        }),
        { status: 422 },
      ),
    );
    const { events } = await openQueue();
    const reference = referenceOf(REQUEST_ID);
    await events.click(await screen.findByRole('button', { name: `Close: request ${reference}` }));
    const dialog = await screen.findByRole('dialog', { name: 'Close this request?' });
    await events.click(within(dialog).getByRole('button', { name: 'Close request' }));
    expect(
      await within(dialog).findByText('This request is already closed, so it can’t be changed.'),
    ).toBeVisible();
  });

  it('filters by status and topic on the server and keeps the filters in the address', async () => {
    const recorded = serveQueue();
    const { events, router } = await openQueue();
    await screen.findAllByRole('listitem');
    await events.selectOptions(screen.getByLabelText(/^Status/), 'open');
    await events.selectOptions(screen.getByLabelText(/^Topic/), 'security');

    await waitFor(() => {
      const last = recorded.queries[recorded.queries.length - 1]!;
      expect(last.searchParams.get('status')).toBe('open');
      expect(last.searchParams.get('kind')).toBe('security');
    });
    expect(router.state.location.search).toBe('?status=open&kind=security');
  });

  it('says when no request matches the filters', async () => {
    serveQueue(() => []);
    await openQueue('/staff/support?status=closed');
    expect(await screen.findByText('No requests match these filters')).toBeInTheDocument();
  });

  it('says when the queue is empty', async () => {
    serveQueue(() => []);
    await openQueue();
    expect(await screen.findByText('The queue is empty')).toBeInTheDocument();
  });

  it('offers a retry when the queue cannot be loaded', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/support/queue`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 })
          : HttpResponse.json(envelope(queue()));
      }),
    );
    const { events } = await openQueue();
    expect(await screen.findByText('We couldn’t load the queue')).toBeInTheDocument();
    await events.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByRole('heading', { name: 'Odd sign-in' })).toBeInTheDocument();
  });

  it('shows the permission state to people without support access', async () => {
    server.use(
      http.get(`${API}/support/queue`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/staff/support', { user: makeUser({ onboarding_completed: true }) });
    await findPageHeading('Support queue');
    expect(await screen.findByText('This page is for the support team')).toBeInTheDocument();
  });

  it('shows a signed-in request’s conversation on demand and sends a staff reply', async () => {
    serveQueue();
    const posted: unknown[] = [];
    let reads = 0;
    server.use(
      http.get(`${API}/support/requests/:id/messages`, ({ params }) => {
        reads += 1;
        expect(params.id).toBe(SECURITY_REQUEST_ID);
        return HttpResponse.json(
          envelope([
            makeSupportMessage({
              request_id: SECURITY_REQUEST_ID,
              mine: false,
              body: 'It was from another city.',
            }),
          ]),
        );
      }),
      http.post(`${API}/support/requests/:id/messages`, async ({ request }) => {
        const body = (await request.json()) as { body: string };
        posted.push(body);
        return HttpResponse.json(
          envelope(
            makeSupportMessage({
              id: '9f8e7d6c-5b4a-4c3d-8e2f-1a0b9c8d7e6f',
              request_id: SECURITY_REQUEST_ID,
              author_role: 'staff',
              mine: true,
              body: body.body,
            }),
          ),
          { status: 201 },
        );
      }),
    );
    const events = userEvent.setup();
    renderRoute('/staff/support', { user: staff() });
    await findPageHeading('Support queue');
    const item = (await screen.findByRole('heading', { name: 'Odd sign-in' })).closest('li')!;
    // Nothing is fetched until the conversation is opened.
    expect(reads).toBe(0);
    await events.click(
      within(item).getByRole('button', { name: 'Show conversation (0 messages)' }),
    );
    expect(await within(item).findByText('It was from another city.')).toBeInTheDocument();
    expect(within(item).getByText('Person who asked')).toBeInTheDocument();
    expect(within(item).getByText(/gets a notification without its text/)).toBeInTheDocument();

    await events.type(within(item).getByLabelText('Reply'), 'We signed out that session.');
    await events.click(within(item).getByRole('button', { name: 'Send reply' }));
    expect(await within(item).findByText('We signed out that session.')).toBeInTheDocument();
    expect(within(item).getByText('You (support team)')).toBeInTheDocument();
    expect(posted).toEqual([{ body: 'We signed out that session.' }]);

    // A contact-form request has no account to reply to in Montra.
    const contact = screen.getByRole('heading', { name: 'Export button spins' }).closest('li')!;
    expect(
      within(contact).getByText('Sent from the public contact form: reply by email.'),
    ).toBeInTheDocument();
    expect(within(contact).queryByRole('button', { name: /Show conversation/ })).toBeNull();
  });
});
