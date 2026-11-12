import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { API, envelope, errorBody } from '@/tests/fixtures';
import { makeUnsubscribeToken } from '@/tests/notificationsFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

/** Every URL the page requested (the token must never be in one). */
let requested: string[] = [];
const record = ({ request }: { request: Request }) => {
  requested.push(request.url);
};

beforeEach(() => {
  requested = [];
  server.events.on('request:start', record);
});

afterEach(() => {
  server.events.removeListener('request:start', record);
});

function openLink(path: string) {
  // The email link puts the token in the fragment; the page reads window.location.
  window.history.replaceState(null, '', path);
  return renderRoute(path);
}

function serveUnsubscribe(respond: () => Response) {
  const bodies: unknown[] = [];
  server.use(
    http.post(`${API}/notifications/unsubscribe`, async ({ request }) => {
      bodies.push(await request.json());
      return respond();
    }),
  );
  return bodies;
}

const main = () => within(screen.getByRole('main'));

describe('UnsubscribePage (signed out)', () => {
  it('confirms the category, posts the token once and clears it from the URL', async () => {
    const token = makeUnsubscribeToken('goal');
    const bodies = serveUnsubscribe(() =>
      HttpResponse.json(envelope({ category: 'goal', channel: 'email' })),
    );
    const user = userEvent.setup();
    openLink(`/unsubscribe#token=${token}`);
    await findPageHeading('Unsubscribe from emails');

    expect(main().getByText('Stop getting emails about Goals?')).toBeInTheDocument();
    expect(window.location.hash).toBe('');
    expect(window.location.pathname).toBe('/unsubscribe');
    // Nothing is sent until the person confirms.
    expect(bodies).toEqual([]);

    await user.click(main().getByRole('button', { name: 'Unsubscribe' }));
    expect(await main().findByText('You’re unsubscribed')).toBeInTheDocument();
    expect(main().getByText(/You won’t get emails about Goals any more/)).toBeInTheDocument();
    expect(
      main().getByText(/Security and account emails, like sign-in alerts/),
    ).toBeInTheDocument();
    expect(main().getByRole('link', { name: 'Manage notification settings' })).toHaveAttribute(
      'href',
      '/settings/notifications',
    );
    expect(bodies).toEqual([{ token }]);
    expect(requested.some((url) => url.includes(token) || url.includes('token='))).toBe(false);
    expect(document.title).not.toContain(token);
  });

  it('confirms again for a link that was already used (unsubscribing is idempotent)', async () => {
    const token = makeUnsubscribeToken('social');
    const bodies = serveUnsubscribe(() =>
      HttpResponse.json(envelope({ category: 'social', channel: 'email' })),
    );
    const user = userEvent.setup();
    openLink(`/unsubscribe#token=${token}`);
    await findPageHeading('Unsubscribe from emails');
    expect(main().getByText('Stop getting emails about Friends?')).toBeInTheDocument();
    await user.click(main().getByRole('button', { name: 'Unsubscribe' }));
    expect(await main().findByText('You’re unsubscribed')).toBeInTheDocument();
    expect(main().getByText(/You won’t get emails about Friends any more/)).toBeInTheDocument();
    expect(bodies).toHaveLength(1);
  });

  it('explains an invalid or expired link', async () => {
    const bodies = serveUnsubscribe(() =>
      HttpResponse.json(
        errorBody({ code: 'GONE', message: 'This unsubscribe link is invalid or has expired.' }),
        { status: 410 },
      ),
    );
    const user = userEvent.setup();
    openLink(`/unsubscribe#token=${makeUnsubscribeToken('goal')}`);
    await findPageHeading('Unsubscribe from emails');
    await user.click(main().getByRole('button', { name: 'Unsubscribe' }));
    expect(await main().findByText('This link has expired or isn’t valid')).toBeInTheDocument();
    expect(main().getByText(/Unsubscribe links work for 60 days/)).toBeInTheDocument();
    expect(main().queryByRole('button', { name: 'Unsubscribe' })).not.toBeInTheDocument();
    expect(bodies).toHaveLength(1);
  });

  it('explains that security and account emails cannot be turned off', async () => {
    serveUnsubscribe(() =>
      HttpResponse.json(
        errorBody({
          code: 'DOMAIN_RULE_VIOLATION',
          details: [
            {
              message: 'Security and account emails cannot be turned off.',
              code: 'always_on_category',
            },
          ],
        }),
        { status: 422 },
      ),
    );
    const user = userEvent.setup();
    openLink(`/unsubscribe#token=${makeUnsubscribeToken('security')}`);
    await findPageHeading('Unsubscribe from emails');
    await user.click(main().getByRole('button', { name: 'Unsubscribe' }));
    expect(await main().findByText('These emails can’t be turned off')).toBeInTheDocument();
  });

  it('keeps the button for a retry after a temporary failure', async () => {
    let fail = true;
    const bodies = serveUnsubscribe(() =>
      fail
        ? HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 })
        : HttpResponse.json(envelope({ category: 'budget', channel: 'email' })),
    );
    const user = userEvent.setup();
    openLink(`/unsubscribe#token=${makeUnsubscribeToken('budget')}`);
    await findPageHeading('Unsubscribe from emails');
    await user.click(main().getByRole('button', { name: 'Unsubscribe' }));
    expect(await main().findByText('We couldn’t unsubscribe you')).toBeInTheDocument();
    fail = false;
    await user.click(main().getByRole('button', { name: 'Unsubscribe' }));
    expect(await main().findByText('You’re unsubscribed')).toBeInTheDocument();
    expect(bodies).toHaveLength(2);
  });

  it('asks generically when the link names no known category', async () => {
    serveUnsubscribe(() => HttpResponse.json(envelope({ category: 'goal', channel: 'email' })));
    openLink('/unsubscribe#token=bm90LWEtcGF5bG9hZC10aGF0LXdlLWtub3c.c2lnbmF0dXJl');
    await findPageHeading('Unsubscribe from emails');
    expect(main().getByText('Stop getting this kind of email?')).toBeInTheDocument();
  });

  it('says the link is incomplete when there is no usable token', async () => {
    openLink('/unsubscribe#token=short');
    await findPageHeading('Unsubscribe from emails');
    expect(main().getByText('This link is incomplete')).toBeInTheDocument();
    expect(main().queryByRole('button', { name: 'Unsubscribe' })).not.toBeInTheDocument();
    expect(window.location.hash).toBe('');
    expect(requested.some((url) => url.includes('/notifications/unsubscribe'))).toBe(false);
  });
});
