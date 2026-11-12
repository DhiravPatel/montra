import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it, vi } from 'vitest';
import { CSRF_COOKIE } from '@/shared/api/csrf';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { makeSummary } from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

type User = ReturnType<typeof userEvent.setup>;

async function submitCredentials(
  user: User,
  email = 'asha@example.com',
  password = 'quiet-harbor-71',
) {
  await user.type(screen.getByLabelText('Email'), email);
  await user.type(screen.getByLabelText('Password'), password);
  await user.click(screen.getByRole('button', { name: 'Sign in' }));
}

/** What the browser has after the API set session cookies. */
function signInServerSide() {
  testBackend.user = makeUser();
  document.cookie = `${CSRF_COOKIE}=csrf-cookie-token; path=/`;
}

describe('SignInPage', () => {
  it('validates fields before calling the API', async () => {
    const login = vi.fn();
    server.use(http.post(`${API}/auth/login`, login));
    const user = userEvent.setup();
    renderRoute('/sign-in');
    await findPageHeading('Sign in');

    await user.click(screen.getByRole('button', { name: 'Sign in' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Email')).toHaveAccessibleDescription(
        /Enter your email address\./,
      );
    });
    expect(screen.getByLabelText('Password')).toHaveAccessibleDescription(/Enter your password\./);
    expect(login).not.toHaveBeenCalled();
  });

  it('shows a generic message for wrong credentials', async () => {
    server.use(
      http.post(`${API}/auth/login`, () =>
        HttpResponse.json(
          errorBody({ code: 'UNAUTHENTICATED', message: 'Invalid email or password.' }),
          {
            status: 401,
          },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/sign-in');
    await findPageHeading('Sign in');
    await submitCredentials(user);

    expect(await screen.findByText('The email or password is incorrect.')).toBeInTheDocument();
    expect(screen.getByLabelText('Password')).toHaveValue('');
  });

  it('offers to resend the verification email when the address is not verified', async () => {
    let resentTo: unknown = null;
    server.use(
      http.post(`${API}/auth/login`, () =>
        HttpResponse.json(
          errorBody({
            code: 'EMAIL_NOT_VERIFIED',
            message: 'Verify your email address to sign in.',
          }),
          {
            status: 403,
          },
        ),
      ),
      http.post(`${API}/auth/email/resend`, async ({ request }) => {
        resentTo = ((await request.json()) as { email: string }).email;
        return HttpResponse.json(envelope({ status: 'accepted', message: 'ok' }), { status: 202 });
      }),
    );
    const user = userEvent.setup();
    renderRoute('/sign-in');
    await findPageHeading('Sign in');
    await submitCredentials(user);

    expect(await screen.findByText('Verify your email to sign in')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Resend verification email' }));
    expect(
      await screen.findByText('If your account still needs verifying, a new link is on its way.'),
    ).toBeInTheDocument();
    expect(resentTo).toBe('asha@example.com');
    expect(screen.getByRole('button', { name: /You can resend in/ })).toHaveAttribute(
      'aria-disabled',
      'true',
    );
  });

  it('uses Retry-After when sign-in is rate limited', async () => {
    const login = vi.fn(() =>
      HttpResponse.json(errorBody({ code: 'RATE_LIMITED', message: 'Too many requests.' }), {
        status: 429,
        headers: { 'Retry-After': '30' },
      }),
    );
    server.use(http.post(`${API}/auth/login`, login));
    const user = userEvent.setup();
    renderRoute('/sign-in');
    await findPageHeading('Sign in');
    await submitCredentials(user);

    expect(
      await screen.findByText('Too many attempts. Try again in 30 seconds.'),
    ).toBeInTheDocument();
    expect(screen.getByText(/You can try again in (30|29) seconds\./)).toBeInTheDocument();

    // A second attempt inside the window is held back on the client.
    await user.type(screen.getByLabelText('Password'), 'quiet-harbor-71');
    await user.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(login).toHaveBeenCalledTimes(1);
  });

  it('explains login throttling without a Retry-After and links to password reset', async () => {
    server.use(
      http.post(`${API}/auth/login`, () =>
        HttpResponse.json(
          errorBody({ code: 'LOGIN_THROTTLED', message: 'Too many failed sign-in attempts.' }),
          {
            status: 429,
          },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/sign-in');
    await findPageHeading('Sign in');
    await submitCredentials(user);

    expect(await screen.findByText('Too many failed attempts')).toBeInTheDocument();
    expect(screen.getAllByRole('link', { name: 'Forgot your password?' }).length).toBeGreaterThan(
      0,
    );
  });

  it('shows how long to wait when login is throttled (Retry-After) and holds back retries', async () => {
    const login = vi.fn(() =>
      HttpResponse.json(
        errorBody({ code: 'LOGIN_THROTTLED', message: 'Too many failed sign-in attempts.' }),
        {
          status: 429,
          headers: { 'Retry-After': '900' },
        },
      ),
    );
    server.use(http.post(`${API}/auth/login`, login));
    const user = userEvent.setup();
    renderRoute('/sign-in');
    await findPageHeading('Sign in');
    await submitCredentials(user);

    expect(await screen.findByText('Too many failed attempts')).toBeInTheDocument();
    expect(
      screen.getByText('Try again in 15 minutes, or reset your password.'),
    ).toBeInTheDocument();
    expect(screen.getByText('You can try again in 15 minutes.')).toBeInTheDocument();

    await user.type(screen.getByLabelText('Password'), 'quiet-harbor-71');
    await user.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(login).toHaveBeenCalledTimes(1);
  });

  it('signs in a new account and starts the optional setup', async () => {
    server.use(
      http.post(`${API}/auth/login`, () => {
        signInServerSide();
        return HttpResponse.json(
          envelope({ status: 'authenticated', user: makeUser(), csrf_token: 'csrf-1' }),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/sign-in');
    await findPageHeading('Sign in');
    await submitCredentials(user);

    expect(await findPageHeading('Set up Montra')).toBeInTheDocument();
    expect(
      await screen.findByRole('heading', { level: 2, name: 'Welcome to Montra' }),
    ).toBeInTheDocument();
  });

  it('signs in a returning user and lands on Home', async () => {
    server.use(
      http.post(`${API}/auth/login`, () => {
        signInServerSide();
        testBackend.user = makeUser({ onboarding_completed: true });
        return HttpResponse.json(
          envelope({ status: 'authenticated', user: testBackend.user, csrf_token: 'csrf-1' }),
        );
      }),
      http.get(`${API}/dashboard/summary`, () => HttpResponse.json(envelope(makeSummary()))),
    );
    const user = userEvent.setup();
    renderRoute('/sign-in');
    await findPageHeading('Sign in');
    await submitCredentials(user);

    expect(await findPageHeading('Home')).toBeInTheDocument();
    expect(screen.getByText('Hello, Asha Rao. Here’s your money at a glance.')).toBeInTheDocument();
  });

  it('reports blocked cookies when the session does not stick after login', async () => {
    server.use(
      http.post(`${API}/auth/login`, () =>
        HttpResponse.json(
          envelope({ status: 'authenticated', user: makeUser(), csrf_token: 'csrf-1' }),
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/sign-in');
    await findPageHeading('Sign in');
    await submitCredentials(user);
    expect(await screen.findByText(/didn’t keep Montra’s sign-in cookie/)).toBeInTheDocument();
  });
});

describe('two-step verification at sign-in', () => {
  function mfaLogin() {
    return http.post(`${API}/auth/login`, () =>
      HttpResponse.json(envelope({ status: 'mfa_required', mfa_token: 'challenge-token-123' })),
    );
  }

  it('asks for the authenticator code and completes sign-in', async () => {
    let verifyBody: unknown = null;
    server.use(
      mfaLogin(),
      http.post(`${API}/auth/mfa/verify`, async ({ request }) => {
        verifyBody = await request.json();
        signInServerSide();
        return HttpResponse.json(
          envelope({ status: 'authenticated', user: makeUser(), csrf_token: 'csrf-2' }),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/sign-in');
    await findPageHeading('Sign in');
    await submitCredentials(user);

    const heading = await findPageHeading('Two-step verification');
    await waitFor(() => {
      expect(heading).toHaveFocus();
    });
    await user.type(screen.getByLabelText('Verification code'), '123 456');
    await user.click(screen.getByRole('button', { name: 'Verify' }));

    expect(await findPageHeading('Set up Montra')).toBeInTheDocument();
    expect(verifyBody).toEqual({ mfa_token: 'challenge-token-123', code: '123456' });
  });

  it('rejects malformed codes on the client', async () => {
    const verify = vi.fn();
    server.use(mfaLogin(), http.post(`${API}/auth/mfa/verify`, verify));
    const user = userEvent.setup();
    renderRoute('/sign-in');
    await findPageHeading('Sign in');
    await submitCredentials(user);
    await findPageHeading('Two-step verification');

    await user.type(screen.getByLabelText('Verification code'), '12ab');
    await user.click(screen.getByRole('button', { name: 'Verify' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Verification code')).toHaveAccessibleDescription(
        /Enter the 6-digit code from your authenticator app\./,
      );
    });
    expect(verify).not.toHaveBeenCalled();
  });

  it('keeps the challenge on a wrong code (MFA_CODE_INVALID) and supports recovery codes', async () => {
    const bodies: unknown[] = [];
    server.use(
      mfaLogin(),
      http.post(`${API}/auth/mfa/verify`, async ({ request }) => {
        bodies.push(await request.json());
        return HttpResponse.json(
          errorBody({ code: 'MFA_CODE_INVALID', message: 'The verification code is incorrect.' }),
          {
            status: 401,
          },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/sign-in');
    await findPageHeading('Sign in');
    await submitCredentials(user);
    await findPageHeading('Two-step verification');

    await user.type(screen.getByLabelText('Verification code'), '000000');
    await user.click(screen.getByRole('button', { name: 'Verify' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Verification code')).toHaveAccessibleDescription(
        /That code didn’t work\. Check your authenticator app/,
      );
    });
    // Still the same challenge: no restart offered as the fix.
    expect(screen.queryByText('This sign-in attempt has expired')).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Use a recovery code instead' }));
    const recovery = screen.getByLabelText('Recovery code');
    await waitFor(() => {
      expect(recovery).toHaveFocus();
    });
    await user.type(recovery, 'abcde-fghij');
    await user.click(screen.getByRole('button', { name: 'Verify' }));
    await waitFor(() => {
      expect(recovery).toHaveAccessibleDescription(
        /That recovery code didn’t work or was already used\./,
      );
    });
    expect(bodies).toEqual([
      { mfa_token: 'challenge-token-123', code: '000000' },
      { mfa_token: 'challenge-token-123', recovery_code: 'abcde-fghij' },
    ]);
  });

  it('ends the attempt on MFA_CHALLENGE_EXPIRED and offers only a fresh sign-in', async () => {
    server.use(
      mfaLogin(),
      http.post(`${API}/auth/mfa/verify`, () =>
        HttpResponse.json(
          errorBody({
            code: 'MFA_CHALLENGE_EXPIRED',
            message: 'This sign-in attempt has expired.',
          }),
          {
            status: 401,
          },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/sign-in');
    await findPageHeading('Sign in');
    await submitCredentials(user);
    await findPageHeading('Two-step verification');

    await user.type(screen.getByLabelText('Verification code'), '123456');
    await user.click(screen.getByRole('button', { name: 'Verify' }));

    expect(await screen.findByText('This sign-in attempt has expired')).toBeInTheDocument();
    expect(screen.queryByLabelText('Verification code')).not.toBeInTheDocument();
    const again = screen.getByRole('button', { name: 'Sign in again' });
    await waitFor(() => {
      expect(again).toHaveFocus();
    });
    await user.click(again);
    expect(await findPageHeading('Sign in')).toBeInTheDocument();
    expect(screen.getByLabelText('Email')).toBeInTheDocument();
  });

  it('can start over from the code step', async () => {
    server.use(mfaLogin());
    const user = userEvent.setup();
    renderRoute('/sign-in');
    await findPageHeading('Sign in');
    await submitCredentials(user);
    await findPageHeading('Two-step verification');

    await user.click(screen.getByRole('button', { name: 'Start over' }));
    expect(await findPageHeading('Sign in')).toBeInTheDocument();
    expect(screen.getByLabelText('Email')).toBeInTheDocument();
  });
});
