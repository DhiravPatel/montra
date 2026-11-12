import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeAll, describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

beforeAll(async () => {
  await import('./ContactPage');
});

async function fillContact(
  events: ReturnType<typeof userEvent.setup>,
  values: { kind?: string; email?: string; subject?: string; body?: string } = {},
) {
  await events.selectOptions(screen.getByLabelText('What is it about?'), values.kind ?? 'support');
  await events.type(
    screen.getByLabelText('Your email address'),
    values.email ?? 'ravi@example.com',
  );
  await events.type(screen.getByLabelText('Subject'), values.subject ?? 'Cannot sign in');
  await events.type(screen.getByLabelText('Message'), values.body ?? 'Locked out after travel.');
}

describe('ContactPage (public)', () => {
  it('sends a message while signed out and confirms calmly with a reference', async () => {
    const requests: { body: unknown; authorization: string | null }[] = [];
    server.use(
      http.post(`${API}/support/contact`, async ({ request }) => {
        requests.push({
          body: await request.json(),
          authorization: request.headers.get('Authorization'),
        });
        return HttpResponse.json(envelope({ reference: 'FF80C768' }), { status: 202 });
      }),
    );
    const events = userEvent.setup();
    renderRoute('/contact');
    await findPageHeading('Contact support');
    expect(screen.queryByText('You’re signed in')).not.toBeInTheDocument();
    // The public form has no feedback option (the API refuses it).
    expect(screen.queryByRole('option', { name: 'Feedback or idea' })).not.toBeInTheDocument();

    await fillContact(events);
    await events.click(screen.getByRole('button', { name: 'Send message' }));

    const heading = await screen.findByRole('heading', { name: 'Message received' });
    expect(heading).toHaveFocus();
    expect(
      screen.getByText('Thank you. We’ll reply to ravi@example.com as soon as we can.'),
    ).toBeInTheDocument();
    expect(screen.getByText('FF80C768')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Back to the home page' })).toHaveAttribute(
      'href',
      '/',
    );
    expect(requests).toHaveLength(1);
    expect(requests[0]?.body).toEqual({
      kind: 'support',
      contact_email: 'ravi@example.com',
      subject: 'Cannot sign in',
      body: 'Locked out after travel.',
    });
    expect(requests[0]?.authorization).toBeNull();
  });

  it('waits out a rate limit instead of failing again', async () => {
    let calls = 0;
    server.use(
      http.post(`${API}/support/contact`, () => {
        calls += 1;
        return HttpResponse.json(errorBody({ code: 'RATE_LIMITED' }), {
          status: 429,
          headers: { 'Retry-After': '30' },
        });
      }),
    );
    const events = userEvent.setup();
    renderRoute('/contact');
    await findPageHeading('Contact support');
    await fillContact(events);
    const submit = screen.getByRole('button', { name: 'Send message' });
    await events.click(submit);

    expect(await screen.findByText('Too many attempts. Try again in 30 seconds.')).toBeVisible();
    expect(screen.getByText(/You can send again in (30|29) seconds\./)).toBeInTheDocument();
    expect(submit).toHaveAttribute('aria-disabled', 'true');
    await events.click(submit);
    expect(calls).toBe(1);
  });

  it('explains the per-address daily cap and waits for Retry-After', async () => {
    let calls = 0;
    server.use(
      http.post(`${API}/support/contact`, () => {
        calls += 1;
        return HttpResponse.json(
          errorBody({
            code: 'RATE_LIMITED',
            details: [
              {
                message: 'You can send up to 10 messages a day.',
                code: 'daily_cap',
                params: { kind: 'contact messages', limit: '10', window_hours: '24' },
              },
            ],
          }),
          { status: 429, headers: { 'Retry-After': '7200' } },
        );
      }),
    );
    const events = userEvent.setup();
    renderRoute('/contact');
    await findPageHeading('Contact support');
    await fillContact(events);
    const submit = screen.getByRole('button', { name: 'Send message' });
    await events.click(submit);
    expect(
      await screen.findByText(
        'This email address can send up to 10 messages a day. You can send more in 2 hours. What you’ve already sent is safe.',
      ),
    ).toBeVisible();
    expect(submit).toHaveAttribute('aria-disabled', 'true');
    await events.click(submit);
    expect(calls).toBe(1);
  });

  it('checks the email address and keeps secrets out of the message', async () => {
    let calls = 0;
    server.use(
      http.post(`${API}/support/contact`, () => {
        calls += 1;
        return HttpResponse.json(envelope({ reference: 'FF80C768' }), { status: 202 });
      }),
    );
    const events = userEvent.setup();
    renderRoute('/contact');
    await findPageHeading('Contact support');
    await fillContact(events, { email: 'not-an-email', body: 'My OTP is 482913, please help.' });
    await events.click(screen.getByRole('button', { name: 'Send message' }));

    await waitFor(() => {
      expect(screen.getByLabelText('Your email address')).toHaveAccessibleDescription(
        /Enter a valid email address/,
      );
    });
    expect(screen.getByLabelText('Message')).toHaveAccessibleDescription(
      /Remove card numbers, PINs, OTPs or passwords\./,
    );
    expect(calls).toBe(0);
  });

  it('shows the API’s field problems in the user’s language', async () => {
    server.use(
      http.post(`${API}/support/contact`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [
              {
                field: 'body.contact_email',
                message: "expected string to be RFC 5322 email: mail: missing '@' or angle-addr",
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const events = userEvent.setup();
    renderRoute('/contact');
    await findPageHeading('Contact support');
    await fillContact(events, { email: 'ravi@example' });
    await events.click(screen.getByRole('button', { name: 'Send message' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Your email address')).toHaveAccessibleDescription(
        /Enter a valid email address, like name@example.com\./,
      );
    });
    expect(screen.queryByText(/RFC 5322/)).not.toBeInTheDocument();
  });

  it('points to email when the API asks for a security check this app cannot show', async () => {
    server.use(
      http.post(`${API}/support/contact`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [{ field: 'body.captcha_token', message: 'Complete the security check.' }],
          }),
          { status: 422 },
        ),
      ),
    );
    const events = userEvent.setup();
    renderRoute('/contact');
    await findPageHeading('Contact support');
    await fillContact(events);
    await events.click(screen.getByRole('button', { name: 'Send message' }));
    expect(
      await screen.findByText(
        'This form needs a security check that isn’t available here yet. Please email us at support@montra.example instead.',
      ),
    ).toBeVisible();
  });

  it('points signed-in people to Help & support, and offers the security inbox', async () => {
    const events = userEvent.setup();
    renderRoute('/contact', { user: makeUser({ onboarding_completed: true }) });
    await findPageHeading('Contact support');
    const notice = await screen.findByText('You’re signed in');
    expect(
      within(notice.closest('div')!.parentElement!).getByRole('link', {
        name: 'Go to Help & support',
      }),
    ).toHaveAttribute('href', '/help');
    await events.selectOptions(screen.getByLabelText('What is it about?'), 'security');
    expect(screen.getByRole('link', { name: 'security@montra.example' })).toHaveAttribute(
      'href',
      'mailto:security@montra.example',
    );
  });
});
