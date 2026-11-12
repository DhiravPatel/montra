import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const TOKEN = 'omsxZuXILlPecLujyVNhHTxjRgbfiyU41OfSZ335QQ8';

function openLink(path: string) {
  // The email link puts the token in the fragment; the page reads window.location.
  window.history.replaceState(null, '', path);
  return renderRoute(path);
}

describe('VerifyEmailPage', () => {
  it('posts the fragment token once, clears it from the URL and confirms', async () => {
    const tokens: unknown[] = [];
    server.use(
      http.post(`${API}/auth/email/verify`, async ({ request }) => {
        tokens.push(await request.json());
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    openLink(`/verify-email#token=${TOKEN}`);
    await findPageHeading('Verify your email');

    expect(await screen.findByText('Your email is verified')).toBeInTheDocument();
    expect(tokens).toEqual([{ token: TOKEN }]);
    expect(window.location.hash).toBe('');
    expect(window.location.pathname).toBe('/verify-email');
    expect(within(screen.getByRole('main')).getByRole('link', { name: 'Sign in' })).toHaveAttribute(
      'href',
      '/sign-in',
    );
  });

  it('explains expired links and lets the user request a new one', async () => {
    let resendBody: unknown = null;
    server.use(
      http.post(`${API}/auth/email/verify`, () =>
        HttpResponse.json(
          errorBody({ code: 'GONE', message: 'This verification link is invalid or has expired.' }),
          {
            status: 410,
          },
        ),
      ),
      http.post(`${API}/auth/email/resend`, async ({ request }) => {
        resendBody = await request.json();
        return HttpResponse.json(envelope({ status: 'accepted', message: 'ok' }), { status: 202 });
      }),
    );
    const user = userEvent.setup();
    openLink(`/verify-email#token=${TOKEN}`);

    expect(
      await screen.findByText('This link has expired or was already used'),
    ).toBeInTheDocument();
    await user.type(screen.getByLabelText('Email'), 'asha@example.com');
    await user.click(screen.getByRole('button', { name: 'Send a new link' }));
    expect(
      await screen.findByText('If asha@example.com needs verifying, a new link is on its way.'),
    ).toBeInTheDocument();
    expect(resendBody).toEqual({ email: 'asha@example.com' });
  });

  it('handles a link without a token without calling the API', async () => {
    openLink('/verify-email');
    expect(await screen.findByText('This link is incomplete')).toBeInTheDocument();
  });

  it('offers a retry when the network fails', async () => {
    let attempts = 0;
    server.use(
      http.post(`${API}/auth/email/verify`, () => {
        attempts += 1;
        return attempts === 1 ? HttpResponse.error() : HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = userEvent.setup();
    openLink(`/verify-email#token=${TOKEN}`);

    expect(await screen.findByText('We couldn’t verify your email')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    await waitFor(() => {
      expect(screen.getByText('Your email is verified')).toBeInTheDocument();
    });
    expect(attempts).toBe(2);
  });
});
