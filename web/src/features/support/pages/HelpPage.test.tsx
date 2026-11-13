import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeAll, describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import {
  REQUEST_ID,
  REQUEST_ID_2,
  dailyCapDetail,
  makeSupportRequest,
  referenceOf,
} from '@/tests/supportFixtures';

const user = () => makeUser({ onboarding_completed: true });

function serveRequests(lists: unknown[][]) {
  let calls = 0;
  server.use(
    http.get(`${API}/support/requests`, () => {
      const list = lists[Math.min(calls, lists.length - 1)];
      calls += 1;
      return HttpResponse.json(envelope(list));
    }),
  );
  return () => calls;
}

async function openHelp() {
  const events = userEvent.setup();
  renderRoute('/help', { user: user() });
  await findPageHeading('Help & support');
  return events;
}

async function fillForm(
  events: ReturnType<typeof userEvent.setup>,
  values: { kind: string; subject: string; body: string },
) {
  const form = screen.getByRole('region', { name: 'Contact support' });
  await events.selectOptions(within(form).getByLabelText('What is it about?'), values.kind);
  await events.type(within(form).getByLabelText('Subject'), values.subject);
  await events.type(within(form).getByLabelText('Message'), values.body);
  return form;
}

beforeAll(async () => {
  await import('./HelpPage');
});

describe('HelpPage', () => {
  it('lists the guides by topic and shows the user’s requests', async () => {
    serveRequests([
      [
        makeSupportRequest(),
        makeSupportRequest({
          id: REQUEST_ID_2,
          kind: 'privacy',
          subject: 'Delete old data',
          status: 'resolved',
        }),
      ],
    ]);
    await openHelp();

    const guides = screen.getByRole('region', { name: 'Guides' });
    const calculations = within(guides).getByRole('region', { name: 'How Montra calculates' });
    expect(
      within(calculations).getByRole('link', { name: 'How budgets are calculated' }),
    ).toHaveAttribute('href', '/help/guides/budgets');
    expect(within(guides).getByRole('link', { name: 'Why don’t I see my bank?' })).toHaveAttribute(
      'href',
      '/help/guides/no-bank',
    );
    expect(
      within(guides).getByRole('link', { name: 'Two-step verification and recovery' }),
    ).toHaveAttribute('href', '/help/guides/two-step');
    expect(within(guides).getByRole('link', { name: 'Search all guides' })).toHaveAttribute(
      'href',
      '/help/guides',
    );
    // No status page is configured in tests, so there is no status link at all.
    expect(within(guides).queryByRole('link', { name: /Service status/ })).not.toBeInTheDocument();

    const mine = screen.getByRole('region', { name: 'Your requests' });
    const items = await within(mine).findAllByRole('listitem');
    expect(items).toHaveLength(2);
    expect(within(items[0]!).getByRole('link', { name: 'Export button spins' })).toHaveAttribute(
      'href',
      `/help/requests/${REQUEST_ID}`,
    );
    expect(within(items[0]!).getByText('Open')).toBeInTheDocument();
    expect(
      within(items[0]!).getByText(
        `Something isn’t working · Reference ${referenceOf(REQUEST_ID)} · Sent November 4, 2026`,
      ),
    ).toBeInTheDocument();
    expect(within(items[1]!).getByText('Resolved')).toBeInTheDocument();
  });

  it('shows an empty state when there are no requests yet', async () => {
    serveRequests([[]]);
    await openHelp();
    const mine = screen.getByRole('region', { name: 'Your requests' });
    expect(await within(mine).findByText('No requests yet')).toBeInTheDocument();
  });

  it('offers a retry when the requests cannot be loaded', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/support/requests`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 })
          : HttpResponse.json(envelope([makeSupportRequest()]));
      }),
    );
    const events = await openHelp();
    const mine = screen.getByRole('region', { name: 'Your requests' });
    expect(await within(mine).findByText('We couldn’t load your requests')).toBeInTheDocument();
    await events.click(within(mine).getByRole('button', { name: 'Try again' }));
    expect(await within(mine).findByRole('link', { name: 'Export button spins' })).toBeVisible();
  });

  it('shows the permission state when the list is forbidden', async () => {
    server.use(
      http.get(`${API}/support/requests`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    await openHelp();
    const mine = screen.getByRole('region', { name: 'Your requests' });
    expect(await within(mine).findByText('You don’t have access to this')).toBeInTheDocument();
  });

  it('sends a request, shows its reference and refreshes the list', async () => {
    const listCalls = serveRequests([[], [makeSupportRequest()]]);
    let body: unknown = null;
    server.use(
      http.post(`${API}/support/requests`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(envelope(makeSupportRequest()), { status: 201 });
      }),
    );
    const events = await openHelp();
    const form = await fillForm(events, {
      kind: 'bug',
      subject: '  Export button spins ',
      body: 'The CSV export spins forever.',
    });
    expect(
      within(form).getByText(
        'Something looks wrong or doesn’t work as expected. Say what you did and what happened.',
      ),
    ).toBeInTheDocument();
    await events.click(within(form).getByRole('button', { name: 'Send request' }));

    expect(
      await within(form).findByText(
        `Your reference is ${referenceOf(REQUEST_ID)}. Replies from the support team appear on the request’s page.`,
      ),
    ).toBeInTheDocument();
    expect(within(form).getByRole('link', { name: 'View this request' })).toHaveAttribute(
      'href',
      `/help/requests/${REQUEST_ID}`,
    );
    expect(body).toEqual({
      kind: 'bug',
      subject: 'Export button spins',
      body: 'The CSV export spins forever.',
    });
    // The form is ready for another request.
    expect(within(form).getByLabelText('Subject')).toHaveValue('');
    const mine = screen.getByRole('region', { name: 'Your requests' });
    expect(await within(mine).findByRole('link', { name: 'Export button spins' })).toBeVisible();
    expect(listCalls()).toBe(2);
  });

  it('keeps card numbers and codes in the browser: nothing is sent', async () => {
    serveRequests([[]]);
    let posts = 0;
    server.use(
      http.post(`${API}/support/requests`, () => {
        posts += 1;
        return HttpResponse.json(envelope(makeSupportRequest()), { status: 201 });
      }),
    );
    const events = await openHelp();
    expect(
      screen.getByText('Never share passwords, PINs, OTPs or card numbers'),
    ).toBeInTheDocument();
    const form = await fillForm(events, {
      kind: 'support',
      subject: 'Card charged twice',
      body: 'My card 4111 1111 1111 1111 was charged twice.',
    });
    await events.click(within(form).getByRole('button', { name: 'Send request' }));

    const message = within(form).getByLabelText('Message');
    await waitFor(() => {
      expect(message).toHaveAccessibleDescription(
        /Remove card numbers, PINs, OTPs or passwords\. Montra support never needs them\./,
      );
    });
    expect(posts).toBe(0);
  });

  it('explains a refusal from the API in the user’s language', async () => {
    serveRequests([[]]);
    server.use(
      http.post(`${API}/support/requests`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [
              {
                field: 'body.body',
                message:
                  'Remove card numbers, PINs, OTPs or passwords. Montra support never needs them.',
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const events = await openHelp();
    const form = await fillForm(events, {
      kind: 'support',
      subject: 'Login trouble',
      body: 'My net banking pass is something.',
    });
    await events.click(within(form).getByRole('button', { name: 'Send request' }));
    const message = within(form).getByLabelText('Message');
    await waitFor(() => {
      expect(message).toHaveAccessibleDescription(/Montra couldn’t accept this message\./);
    });
  });

  it('explains the daily cap calmly, with when sending works again (Retry-After)', async () => {
    serveRequests([[]]);
    server.use(
      http.post(`${API}/support/requests`, () =>
        HttpResponse.json(
          errorBody({
            code: 'RATE_LIMITED',
            message: 'Too many requests. Please wait and try again.',
            details: [dailyCapDetail('support requests')],
          }),
          { status: 429, headers: { 'Retry-After': '86400' } },
        ),
      ),
    );
    const events = await openHelp();
    const form = await fillForm(events, {
      kind: 'feedback',
      subject: 'More charts',
      body: 'Please add more charts.',
    });
    await events.click(within(form).getByRole('button', { name: 'Send request' }));
    expect(
      await within(form).findByText(
        'You can send up to 10 support requests a day. You can send more in 24 hours. What you’ve already sent is safe.',
      ),
    ).toBeInTheDocument();
  });

  it('names the problem when the API refuses a secret in the message (contains_secret)', async () => {
    serveRequests([[]]);
    server.use(
      http.post(`${API}/support/requests`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [
              {
                field: 'body.body',
                code: 'contains_secret',
                message: 'Remove card numbers, PINs, OTPs or passwords.',
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const events = await openHelp();
    const form = await fillForm(events, {
      kind: 'support',
      subject: 'Card problem',
      body: 'My card ends in 42 and the payment failed.',
    });
    await events.click(within(form).getByRole('button', { name: 'Send request' }));
    await waitFor(() => {
      expect(within(form).getByLabelText('Message')).toHaveAccessibleDescription(
        /Remove card numbers, PINs, OTPs or passwords\. Montra support never needs them\./,
      );
    });
  });

  it('asks for a topic, a subject and a message before sending', async () => {
    serveRequests([[]]);
    const events = await openHelp();
    const form = screen.getByRole('region', { name: 'Contact support' });
    await events.click(within(form).getByRole('button', { name: 'Send request' }));
    await waitFor(() => {
      expect(within(form).getByLabelText('What is it about?')).toHaveAccessibleDescription(
        /Choose what your request is about\./,
      );
    });
    expect(within(form).getByLabelText('Subject')).toHaveAccessibleDescription(
      /Enter a subject of 3 to 160 characters\./,
    );
    expect(within(form).getByLabelText('Message')).toHaveAccessibleDescription(
      /Describe how we can help\./,
    );
  });
});
