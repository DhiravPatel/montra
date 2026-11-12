import { screen, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { makeUser } from '@/tests/fixtures';
import { findPageHeading, renderRoute } from '@/tests/render';

describe('AccountOverviewPage', () => {
  it('shows the user’s own account details', async () => {
    renderRoute('/account', { user: makeUser() });
    await findPageHeading('Your account');
    const preferences = screen.getByRole('region', { name: 'Preferences' });
    expect(within(preferences).getByText('Indian Rupee (INR)')).toBeInTheDocument();
    expect(within(preferences).queryByText('Retired')).not.toBeInTheDocument();
  });

  it('shows the @username with a link to change it in Friends → Privacy', async () => {
    renderRoute('/account', { user: makeUser({ username: 'asha_rao' }) });
    await findPageHeading('Your account');
    const profile = screen.getByRole('region', { name: 'Profile' });
    expect(within(profile).getByText('@asha_rao')).toBeInTheDocument();
    expect(within(profile).getByRole('link', { name: 'Change username' })).toHaveAttribute(
      'href',
      '/friends?tab=privacy',
    );
  });

  it('offers to choose a username when there is none', async () => {
    renderRoute('/account', { user: makeUser() });
    await findPageHeading('Your account');
    const profile = screen.getByRole('region', { name: 'Profile' });
    expect(
      within(profile).getByText('You don’t have a username yet, so friends can’t find you.'),
    ).toBeInTheDocument();
    expect(within(profile).getByRole('link', { name: 'Choose a username' })).toHaveAttribute(
      'href',
      '/friends?tab=privacy',
    );
  });

  it('marks a retired base currency and names its replacement', async () => {
    renderRoute('/account', {
      user: makeUser({ base_currency: 'BGN', locale: 'bg-BG', timezone: 'Europe/Sofia' }),
    });
    await findPageHeading('Your account');
    const preferences = screen.getByRole('region', { name: 'Preferences' });
    expect(await within(preferences).findByText('Retired')).toBeInTheDocument();
    expect(
      within(preferences).getByText(
        /BGN was replaced by EUR on .*2026\. Past records keep their original currency\./,
      ),
    ).toBeInTheDocument();
  });
});
