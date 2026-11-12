import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const TOKEN = 'resetTokenAbcdefghijklmnopqrstuvwxyz0123456';

function openLink() {
  window.history.replaceState(null, '', `/reset-password#token=${TOKEN}`);
  return renderRoute(`/reset-password#token=${TOKEN}`);
}

async function submit(
  user: ReturnType<typeof userEvent.setup>,
  password: string,
  confirm = password,
) {
  await user.type(screen.getByLabelText('New password'), password);
  await user.type(screen.getByLabelText('Confirm new password'), confirm);
  await user.click(screen.getByRole('button', { name: 'Save new password' }));
}

describe('ResetPasswordPage', () => {
  it.each(['body.new_password', 'body.password'])(
    'maps the API policy error (%s) to the new password field',
    async (field) => {
      server.use(
        http.post(`${API}/auth/password/reset`, () =>
          HttpResponse.json(
            errorBody({
              code: 'VALIDATION_ERROR',
              details: [{ field, message: 'Password needs more variety of characters.' }],
            }),
            { status: 422 },
          ),
        ),
      );
      const user = userEvent.setup();
      openLink();
      await findPageHeading('Choose a new password');
      expect(window.location.hash).toBe('');

      await submit(user, 'river-stone-42');
      await waitFor(() => {
        expect(screen.getByLabelText('New password')).toHaveAccessibleDescription(
          /Password needs more variety/,
        );
      });
    },
  );

  it('checks that both passwords match', async () => {
    const user = userEvent.setup();
    openLink();
    await findPageHeading('Choose a new password');
    await submit(user, 'river-stone-42', 'river-stone-43');
    await waitFor(() => {
      expect(screen.getByLabelText('Confirm new password')).toHaveAccessibleDescription(
        /The passwords don’t match\./,
      );
    });
  });

  it('confirms success and sends the token with the new password', async () => {
    let body: unknown = null;
    server.use(
      http.post(`${API}/auth/password/reset`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = userEvent.setup();
    openLink();
    await findPageHeading('Choose a new password');
    await submit(user, 'river-stone-42');

    expect(await screen.findByText('Your password has been reset')).toBeInTheDocument();
    expect(body).toEqual({ token: TOKEN, new_password: 'river-stone-42' });
  });

  it('shows the expired-link state for GONE', async () => {
    server.use(
      http.post(`${API}/auth/password/reset`, () =>
        HttpResponse.json(
          errorBody({ code: 'GONE', message: 'This reset link is invalid or has expired.' }),
          {
            status: 410,
          },
        ),
      ),
    );
    const user = userEvent.setup();
    openLink();
    await findPageHeading('Choose a new password');
    await submit(user, 'river-stone-42');
    expect(
      await screen.findByText('This reset link has expired or was already used'),
    ).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Get a new reset link' })).toHaveAttribute(
      'href',
      '/forgot-password',
    );
  });
});
