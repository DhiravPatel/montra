import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { API, envelope, makeUser } from '@/tests/fixtures';
import { makeSummary } from '@/tests/financeFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

describe('route guards and app shell', () => {
  it('sends anonymous visitors from protected pages to sign-in, then back after signing in', async () => {
    const { router } = renderRoute('/settings/security');
    await findPageHeading('Sign in');
    expect(router.state.location.pathname).toBe('/sign-in');
    expect(router.state.location.state).toEqual({ from: '/settings/security' });
  });

  it('keeps the one-time token of an invitation link through sign-in, only for invitation pages', async () => {
    const join = renderRoute('/groups/join#token=abc123');
    await findPageHeading('Sign in');
    expect(join.router.state.location.state).toEqual({ from: '/groups/join#token=abc123' });
    join.unmount();
    const other = renderRoute('/settings/security#section');
    await findPageHeading('Sign in');
    expect(other.router.state.location.state).toEqual({ from: '/settings/security' });
  });

  it('sends a signed-in new user from sign-in to the optional setup', async () => {
    const { router } = renderRoute('/sign-in', { user: makeUser() });
    await findPageHeading('Set up Montra');
    expect(router.state.location.pathname).toBe('/onboarding');
  });

  it('sends a signed-in returning user from sign-in to Home', async () => {
    server.use(
      http.get(`${API}/dashboard/summary`, () => HttpResponse.json(envelope(makeSummary()))),
    );
    const { router } = renderRoute('/sign-in', { user: makeUser({ onboarding_completed: true }) });
    await findPageHeading('Home');
    expect(router.state.location.pathname).toBe('/dashboard');
  });

  it('shows only navigation for screens that exist', async () => {
    const user = userEvent.setup();
    renderRoute('/account', { user: makeUser() });
    await findPageHeading('Your account');
    const [sidebar, bottomBar] = screen.getAllByRole('navigation', { name: 'Main', hidden: true });
    const labels = (nav: HTMLElement) =>
      within(nav)
        .getAllByRole('link', { hidden: true })
        .map((link) => link.textContent);
    expect(labels(sidebar!)).toEqual([
      'Home',
      'Transactions',
      'Accounts',
      'Receipts',
      'Imports',
      'Budgets',
      'Bills & recurring',
      'Subscriptions',
      'Goals',
      'Groups',
      'Friends',
      'Communities',
      'Challenges',
      'Insights',
      'Analytics',
      'Reports',
      'Categories',
      'Profile',
      'Preferences',
      'Security',
      'Exchange rates',
      'Notifications',
      'Privacy & data',
      'Integrations',
      'Help & support',
    ]);
    // Small screens: four tabs plus a "More" menu with the rest.
    expect(labels(bottomBar!)).toEqual(['Home', 'Transactions', 'Budgets', 'Goals']);
    await user.click(within(bottomBar!).getByRole('button', { name: 'More', hidden: true }));
    const menu = await screen.findByRole('menu');
    expect(
      within(menu)
        .getAllByRole('menuitem')
        .map((item) => item.textContent),
    ).toEqual([
      'Accounts',
      'Receipts',
      'Imports',
      'Bills & recurring',
      'Subscriptions',
      'Groups',
      'Friends',
      'Communities',
      'Challenges',
      'Insights',
      'Analytics',
      'Reports',
      'Categories',
      'Profile',
      'Preferences',
      'Security',
      'Exchange rates',
      'Notifications',
      'Privacy & data',
      'Integrations',
      'Help & support',
    ]);
  });

  it('shows staff tools only to staff roles', async () => {
    renderRoute('/account', {
      user: makeUser({ onboarding_completed: true, platform_role: 'support' }),
    });
    await findPageHeading('Your account');
    const [sidebar] = screen.getAllByRole('navigation', { name: 'Main', hidden: true });
    const names = within(sidebar!)
      .getAllByRole('link', { hidden: true })
      .map((link) => link.textContent);
    expect(names).toContain('Support queue');
    expect(names).toContain('Moderation');
    expect(names).not.toContain('Usage');
  });

  it('signs out from the account menu and shows a notice on sign-in', async () => {
    const user = userEvent.setup();
    renderRoute('/account', { user: makeUser() });
    await findPageHeading('Your account');

    const [menuButton] = screen.getAllByRole('button', { name: 'Account menu' });
    await user.click(menuButton!);
    await user.click(await screen.findByRole('menuitem', { name: 'Sign out' }));

    await findPageHeading('Sign in');
    expect(screen.getByText('You’ve signed out.')).toBeInTheDocument();
  });

  it('keeps document titles free of personal data', async () => {
    renderRoute('/account', {
      user: makeUser({ display_name: 'Asha Rao', email: 'asha@example.com' }),
    });
    await findPageHeading('Your account');
    await waitFor(() => {
      expect(document.title).toBe('Your account · Montra');
    });
    expect(document.title).not.toMatch(/Asha|example\.com/);
  });
});
