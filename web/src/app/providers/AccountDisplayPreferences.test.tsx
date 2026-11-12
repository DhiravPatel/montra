import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, makeUser } from '@/tests/fixtures';
import { makePreferences } from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const signedIn = () => makeUser({ onboarding_completed: true });

describe('Account display preferences', () => {
  it('apply on every signed-in page and are removed after signing out', async () => {
    testBackend.preferences = makePreferences({
      reduced_motion: true,
      high_contrast: true,
      text_scale_percent: 150,
      theme: 'dark',
    });
    const root = document.documentElement;
    const { unmount } = renderRoute('/account', { user: signedIn() });
    await findPageHeading('Your account');
    await waitFor(() => {
      expect(root).toHaveAttribute('data-motion', 'reduce');
    });
    expect(root).toHaveAttribute('data-contrast', 'high');
    expect(root.style.fontSize).toBe('150%');
    expect(root).toHaveAttribute('data-theme', 'dark');
    // A copy for the first paint of the next visit (public/theme-init.js).
    // eslint-disable-next-line no-restricted-globals -- checking the audited preference store
    expect(localStorage.getItem('montra.display')).toBe('motion=reduce;contrast=high;scale=150');

    unmount();
    expect(root).not.toHaveAttribute('data-motion');
    expect(root).not.toHaveAttribute('data-contrast');
    expect(root.style.fontSize).toBe('');
    // eslint-disable-next-line no-restricted-globals -- checking the audited preference store
    expect(localStorage.getItem('montra.display')).toBeNull();
  });

  it('leave the defaults alone for the default preferences', async () => {
    renderRoute('/account', { user: signedIn() });
    await findPageHeading('Your account');
    const root = document.documentElement;
    expect(root).not.toHaveAttribute('data-motion');
    expect(root).not.toHaveAttribute('data-contrast');
    expect(root.style.fontSize).toBe('');
  });

  it('save a theme chosen from the display menu to the account', async () => {
    const bodies: unknown[] = [];
    server.use(
      http.patch(`${API}/me/preferences`, async ({ request }) => {
        const body = (await request.json()) as { theme: 'dark' };
        bodies.push(body);
        testBackend.preferences = { ...testBackend.preferences, ...body };
        return HttpResponse.json(envelope(testBackend.preferences));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/account', { user: signedIn() });
    await findPageHeading('Your account');
    await user.click(screen.getAllByRole('button', { name: 'Display and language' })[0]!);
    const menu = await screen.findByRole('menu', { name: 'Display and language' });
    await user.click(within(menu).getByRole('menuitemradio', { name: 'Dark' }));
    await waitFor(() => {
      expect(bodies).toEqual([{ theme: 'dark' }]);
    });
    expect(document.documentElement).toHaveAttribute('data-theme', 'dark');
  });

  it('keep the theme on the device only when signed out', async () => {
    const user = userEvent.setup();
    renderRoute('/sign-in');
    await findPageHeading(/sign in/i);
    await user.click(screen.getAllByRole('button', { name: 'Display and language' })[0]!);
    const menu = await screen.findByRole('menu', { name: 'Display and language' });
    // Any PATCH here would be an unhandled request and fail the test.
    await user.click(within(menu).getByRole('menuitemradio', { name: 'Dark' }));
    expect(document.documentElement).toHaveAttribute('data-theme', 'dark');
  });
});
