import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { delay, http, HttpResponse } from 'msw';
import { describe, expect, it, vi } from 'vitest';
import { API, envelope, errorBody, testCurrencies } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

async function fillValidForm(user: ReturnType<typeof userEvent.setup>) {
  await user.type(screen.getByLabelText('Display name'), 'Asha Rao');
  await user.type(screen.getByLabelText('Email'), 'asha@example.com');
  await user.type(screen.getByLabelText('New password'), 'quiet-harbor-71');
  const currency = screen.getByLabelText('Main currency');
  await waitFor(() => {
    expect(currency).toBeEnabled();
  });
  await user.selectOptions(currency, 'INR');
  await user.click(screen.getByLabelText(/I agree to the/));
  await user.click(screen.getByLabelText(/18 years of age or older/));
}

describe('SignUpPage', () => {
  it('validates every field before calling the API', async () => {
    const register = vi.fn(() =>
      HttpResponse.json(envelope({ status: 'accepted', message: 'ok' }), { status: 202 }),
    );
    server.use(http.post(`${API}/auth/register`, register));
    const user = userEvent.setup();
    renderRoute('/sign-up');
    await findPageHeading('Create your account');

    await user.click(screen.getByRole('button', { name: 'Create account' }));

    const email = screen.getByLabelText('Email');
    await waitFor(() => {
      expect(email).toHaveAttribute('aria-invalid', 'true');
    });
    expect(email).toHaveAccessibleDescription(/Enter your email address\./);
    expect(screen.getByLabelText('Display name')).toHaveAccessibleDescription(
      /Enter the name you’d like to use\./,
    );
    expect(screen.getByLabelText('New password')).toHaveAccessibleDescription(
      /Enter your password\./,
    );
    expect(
      screen.getByText('You need to accept the Terms of use and Privacy notice to continue.'),
    ).toBeInTheDocument();
    expect(
      screen.getByText('You must be at least 18 years old to use Montra.'),
    ).toBeInTheDocument();
    expect(register).not.toHaveBeenCalled();
  });

  it('applies the server password policy client-side, including the email rule', async () => {
    const user = userEvent.setup();
    renderRoute('/sign-up');
    await findPageHeading('Create your account');

    await user.type(screen.getByLabelText('Email'), 'ashwini@example.com');
    const password = screen.getByLabelText('New password');
    await user.type(password, 'short');
    await user.click(screen.getByRole('button', { name: 'Create account' }));
    await waitFor(() => {
      expect(password).toHaveAccessibleDescription(/Use at least 10 characters\./);
    });

    await user.clear(password);
    await user.type(password, 'ashwini-secret-1');
    await user.click(screen.getByRole('button', { name: 'Create account' }));
    await waitFor(() => {
      expect(password).toHaveAccessibleDescription(
        /Don’t include your email address in your password\./,
      );
    });

    await user.clear(password);
    await user.type(password, 'password123');
    await user.click(screen.getByRole('button', { name: 'Create account' }));
    await waitFor(() => {
      expect(password).toHaveAccessibleDescription(/This password is too common/);
    });
  });

  it('shows server field errors on the matching fields', async () => {
    server.use(
      http.post(`${API}/auth/register`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [
              { field: 'body.email', message: 'Enter a valid email address.' },
              {
                field: 'body.display_name',
                message: 'Enter a display name of 1 to 80 characters.',
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/sign-up');
    await findPageHeading('Create your account');
    await fillValidForm(user);
    await user.click(screen.getByRole('button', { name: 'Create account' }));

    const email = screen.getByLabelText('Email');
    await waitFor(() => {
      expect(email).toHaveAccessibleDescription(/Enter a valid email address\./);
    });
    expect(email).toHaveAttribute('aria-invalid', 'true');
    expect(screen.getByLabelText('Display name')).toHaveAccessibleDescription(
      /Enter a display name of 1 to 80/,
    );
  });

  it('explains when the terms version is outdated', async () => {
    server.use(
      http.post(`${API}/auth/register`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [{ field: 'body.terms_version', message: 'The terms have been updated.' }],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/sign-up');
    await findPageHeading('Create your account');
    await fillValidForm(user);
    await user.click(screen.getByRole('button', { name: 'Create account' }));
    const message = await screen.findByText(/Our terms have been updated\./);
    expect(message.closest('[role="alert"]')).not.toBeNull();
  });

  it('submits the agreed versions and detected settings, then asks the user to check their email', async () => {
    const captured: { body?: Record<string, unknown> } = {};
    server.use(
      http.post(`${API}/auth/register`, async ({ request }) => {
        captured.body = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(
          envelope({ status: 'accepted', message: 'Check your email to verify your account.' }),
          { status: 202 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/sign-up');
    await findPageHeading('Create your account');
    await fillValidForm(user);
    await user.click(screen.getByRole('button', { name: 'Create account' }));

    await findPageHeading('Check your email');
    expect(screen.getByText(/We’ve sent an email to asha@example.com/)).toBeInTheDocument();
    expect(captured.body).toMatchObject({
      display_name: 'Asha Rao',
      email: 'asha@example.com',
      password: 'quiet-harbor-71',
      currency: 'INR',
      accept_terms: true,
      confirm_adult: true,
      terms_version: '2026-11-01',
      privacy_version: '2026-11-01',
      locale: 'en-US',
    });
    expect(typeof captured.body?.timezone).toBe('string');
  });

  it('offers only selectable currencies from GET /currencies and suggests one from the locale', async () => {
    renderRoute('/sign-up');
    await findPageHeading('Create your account');
    const currency = screen.getByLabelText('Main currency');
    await waitFor(() => {
      expect(currency).toBeEnabled();
    });

    const offered = Array.from((currency as HTMLSelectElement).options).map(
      (option) => option.value,
    );
    const selectable = testCurrencies
      .filter((entry) => entry.selectable)
      .map((entry) => entry.code);
    expect([...offered].sort()).toEqual(['', ...selectable].sort());
    expect(offered).not.toContain('BGN'); // retired: replaced by EUR
    // jsdom's browser locale is en-US.
    await waitFor(() => {
      expect(currency).toHaveValue('USD');
    });
  });

  it('shows a loading state, then a retry when the currency list fails', async () => {
    let fail = true;
    server.use(
      http.get(`${API}/currencies`, async () => {
        await delay(50);
        return fail
          ? HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE', message: 'Down.' }), {
              status: 503,
            })
          : HttpResponse.json(envelope(testCurrencies));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/sign-up');
    await findPageHeading('Create your account');

    const currency = screen.getByLabelText('Main currency');
    expect(currency).toBeDisabled();
    expect(screen.getByRole('option', { name: 'Loading currencies…' })).toBeInTheDocument();

    expect(await screen.findByText('We couldn’t load the list of currencies.')).toBeInTheDocument();
    fail = false;
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    await waitFor(() => {
      expect(currency).toBeEnabled();
    });
    expect(screen.queryByText('We couldn’t load the list of currencies.')).not.toBeInTheDocument();
  });
});
