import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { delay, http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeSession, makeUser } from '@/tests/fixtures';
import { currentSession, testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const otherSession = makeSession({
  id: 'b9b9b9b9-0000-4000-8000-000000000001',
  device_name: 'Firefox on Linux',
});

async function openSecurityPage() {
  const view = renderRoute('/settings/security', { user: makeUser() });
  await findPageHeading('Security');
  const card = screen.getByRole('region', { name: 'Signed-in devices' });
  return { ...view, card };
}

describe('SessionsCard', () => {
  it('shows a labelled loading state', async () => {
    server.use(
      http.get(`${API}/me/sessions`, async () => {
        await delay('infinite');
        return HttpResponse.json(envelope([]));
      }),
    );
    const { card } = await openSecurityPage();
    expect(within(card).getByText('Loading your devices…')).toBeInTheDocument();
  });

  it('shows a recoverable error with the request reference, then recovers on retry', async () => {
    let fail = true;
    server.use(
      http.get(`${API}/me/sessions`, () =>
        fail
          ? HttpResponse.json(
              errorBody({
                code: 'INTERNAL_ERROR',
                message: 'An unexpected error occurred.',
                request_id: 'req-err-1',
              }),
              {
                status: 500,
              },
            )
          : HttpResponse.json(envelope([currentSession()])),
      ),
    );
    const user = userEvent.setup();
    const { card } = await openSecurityPage();

    expect(await within(card).findByText('We couldn’t load your devices')).toBeInTheDocument();
    expect(
      within(card).getByText('Something went wrong on our side. Try again in a moment.'),
    ).toBeInTheDocument();
    expect(within(card).getByText('req-err-1')).toBeInTheDocument();

    fail = false;
    await user.click(within(card).getByRole('button', { name: 'Try again' }));
    expect(await within(card).findByText('Chrome on macOS')).toBeInTheDocument();
  });

  it('shows an empty state', async () => {
    testBackend.sessions = [];
    const { card } = await openSecurityPage();
    expect(await within(card).findByText('No signed-in devices')).toBeInTheDocument();
  });

  it('shows a permission-denied state for FORBIDDEN', async () => {
    server.use(
      http.get(`${API}/me/sessions`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN', message: 'No.' }), { status: 403 }),
      ),
    );
    const { card } = await openSecurityPage();
    expect(await within(card).findByText('You don’t have access to this')).toBeInTheDocument();
  });

  it('lists devices with the current one first and marked as this device', async () => {
    testBackend.sessions = [otherSession, currentSession()];
    const { card } = await openSecurityPage();

    const items = await within(card).findAllByRole('listitem');
    expect(items).toHaveLength(2);
    expect(items[0]).toHaveTextContent('Chrome on macOS');
    expect(within(items[0]!).getByText('This device')).toBeInTheDocument();
    expect(items[1]).toHaveTextContent('Firefox on Linux');
    expect(within(items[1]!).queryByText('This device')).not.toBeInTheDocument();
  });

  it('signs out another device after confirmation and refreshes the list', async () => {
    testBackend.sessions = [currentSession(), otherSession];
    let revokedId: string | null = null;
    let csrf: string | null = null;
    server.use(
      http.delete(`${API}/me/sessions/:sessionId`, ({ params, request }) => {
        revokedId = String(params.sessionId);
        csrf = request.headers.get('X-CSRF-Token');
        testBackend.sessions = [currentSession()];
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = userEvent.setup();
    const { card } = await openSecurityPage();

    await user.click(
      await within(card).findByRole('button', { name: 'Sign out: Firefox on Linux' }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Sign out this device?' });
    expect(
      within(dialog).getByText(
        'Firefox on Linux will be signed out and will need to sign in again.',
      ),
    ).toBeInTheDocument();
    // Destructive dialogs focus Cancel first.
    expect(within(dialog).getByRole('button', { name: 'Cancel' })).toHaveFocus();

    await user.click(within(dialog).getByRole('button', { name: 'Sign out' }));

    expect(await screen.findByText('Signed out Firefox on Linux')).toBeInTheDocument();
    await waitFor(() => {
      expect(within(card).queryByText('Firefox on Linux')).not.toBeInTheDocument();
    });
    expect(revokedId).toBe(otherSession.id);
    expect(csrf).toBe('csrf-cookie-token');
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  it('keeps the dialog open with an error when revoking fails', async () => {
    testBackend.sessions = [currentSession(), otherSession];
    server.use(
      http.delete(`${API}/me/sessions/:sessionId`, () =>
        HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE', message: 'Down.' }), {
          status: 503,
        }),
      ),
    );
    const user = userEvent.setup();
    const { card } = await openSecurityPage();

    await user.click(
      await within(card).findByRole('button', { name: 'Sign out: Firefox on Linux' }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Sign out this device?' });
    await user.click(within(dialog).getByRole('button', { name: 'Sign out' }));
    expect(
      await within(dialog).findByText('Montra is temporarily unavailable. Try again in a moment.'),
    ).toBeInTheDocument();
  });
});

describe('re-authentication for sensitive actions', () => {
  it('asks for the password on REAUTH_REQUIRED, then retries two-step setup', async () => {
    let reauthenticated = false;
    let reauthBody: unknown = null;
    server.use(
      http.post(`${API}/me/mfa/totp/setup`, () =>
        reauthenticated
          ? HttpResponse.json(
              envelope({
                secret: 'JBSWY3DPEHPK3PXP',
                otpauth_uri:
                  'otpauth://totp/Montra:asha%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=Montra',
              }),
            )
          : HttpResponse.json(
              errorBody({ code: 'REAUTH_REQUIRED', message: 'Confirm your password to continue.' }),
              {
                status: 401,
              },
            ),
      ),
      http.post(`${API}/auth/reauthenticate`, async ({ request }) => {
        reauthBody = await request.json();
        reauthenticated = true;
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = userEvent.setup();
    await openSecurityPage();

    await user.click(screen.getByRole('button', { name: 'Set up two-step verification' }));
    const dialog = await screen.findByRole('dialog', { name: 'Confirm it’s you' });
    await user.type(within(dialog).getByLabelText('Password'), 'quiet-harbor-71');
    await user.click(within(dialog).getByRole('button', { name: 'Confirm' }));

    expect(
      await screen.findByRole('img', {
        name: 'QR code for adding Montra to your authenticator app',
      }),
    ).toBeInTheDocument();
    expect(screen.getByText('JBSW Y3DP EHPK 3PXP')).toBeInTheDocument();
    expect(reauthBody).toEqual({ password: 'quiet-harbor-71' });
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  it('shows a field error when the re-authentication password is wrong', async () => {
    server.use(
      http.post(`${API}/me/mfa/totp/setup`, () =>
        HttpResponse.json(
          errorBody({ code: 'REAUTH_REQUIRED', message: 'Confirm your password to continue.' }),
          {
            status: 401,
          },
        ),
      ),
      http.post(`${API}/auth/reauthenticate`, () =>
        HttpResponse.json(
          errorBody({ code: 'REAUTH_REQUIRED', message: 'The password is incorrect.' }),
          { status: 401 },
        ),
      ),
    );
    const user = userEvent.setup();
    await openSecurityPage();

    await user.click(screen.getByRole('button', { name: 'Set up two-step verification' }));
    const dialog = await screen.findByRole('dialog', { name: 'Confirm it’s you' });
    const password = within(dialog).getByLabelText('Password');
    await user.type(password, 'not-my-password');
    await user.click(within(dialog).getByRole('button', { name: 'Confirm' }));
    await waitFor(() => {
      expect(password).toHaveAccessibleDescription(/That password is incorrect\./);
    });
  });

  it('accepts a recovery code instead of an authenticator code', async () => {
    let reauthenticated = false;
    let reauthBody: unknown = null;
    server.use(
      http.post(`${API}/me/mfa/recovery-codes`, () =>
        reauthenticated
          ? HttpResponse.json(envelope({ recovery_codes: ['aaaaa-bbbbb', 'ccccc-ddddd'] }))
          : HttpResponse.json(
              errorBody({ code: 'REAUTH_REQUIRED', message: 'Confirm your password to continue.' }),
              {
                status: 401,
              },
            ),
      ),
      http.post(`${API}/auth/reauthenticate`, async ({ request }) => {
        reauthBody = await request.json();
        reauthenticated = true;
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/settings/security', { user: makeUser({ mfa_enabled: true }) });
    await findPageHeading('Security');

    await user.click(screen.getByRole('button', { name: 'Get new recovery codes' }));
    const confirm = await screen.findByRole('dialog', { name: 'Get new recovery codes?' });
    await user.click(within(confirm).getByRole('button', { name: 'Get new codes' }));

    const reauth = await screen.findByRole('dialog', { name: 'Confirm it’s you' });
    expect(within(reauth).getByLabelText('Authenticator code')).toBeInTheDocument();
    await user.click(within(reauth).getByRole('button', { name: 'Use a recovery code instead' }));
    await user.type(within(reauth).getByLabelText('Password'), 'quiet-harbor-71');
    await user.type(within(reauth).getByLabelText('Recovery code'), 'zzzzz-yyyyy');
    await user.click(within(reauth).getByRole('button', { name: 'Confirm' }));

    expect(await screen.findByText('aaaaa-bbbbb')).toBeInTheDocument();
    expect(reauthBody).toEqual({ password: 'quiet-harbor-71', recovery_code: 'zzzzz-yyyyy' });
  });

  it('shows a field error for a rejected recovery code', async () => {
    server.use(
      http.post(`${API}/me/mfa/recovery-codes`, () =>
        HttpResponse.json(
          errorBody({ code: 'REAUTH_REQUIRED', message: 'Confirm your password to continue.' }),
          {
            status: 401,
          },
        ),
      ),
      http.post(`${API}/auth/reauthenticate`, () =>
        HttpResponse.json(
          errorBody({
            code: 'MFA_REQUIRED',
            message: 'Enter a valid verification code or an unused recovery code.',
          }),
          {
            status: 401,
          },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/settings/security', { user: makeUser({ mfa_enabled: true }) });
    await findPageHeading('Security');

    await user.click(screen.getByRole('button', { name: 'Get new recovery codes' }));
    const confirm = await screen.findByRole('dialog', { name: 'Get new recovery codes?' });
    await user.click(within(confirm).getByRole('button', { name: 'Get new codes' }));
    const reauth = await screen.findByRole('dialog', { name: 'Confirm it’s you' });
    await user.click(within(reauth).getByRole('button', { name: 'Use a recovery code instead' }));
    await user.type(within(reauth).getByLabelText('Password'), 'quiet-harbor-71');
    const recovery = within(reauth).getByLabelText('Recovery code');
    await user.type(recovery, 'used0-used0');
    await user.click(within(reauth).getByRole('button', { name: 'Confirm' }));
    await waitFor(() => {
      expect(recovery).toHaveAccessibleDescription(
        /That recovery code didn’t work or was already used\./,
      );
    });
  });
});
