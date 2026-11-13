import { screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import type * as EnvModule from '@/shared/config/env';
import { makeUser } from '@/tests/fixtures';
import { findPageHeading, renderRoute } from '@/tests/render';
import { helpGuidePath } from './guides';

vi.mock('@/shared/config/env', async (importOriginal) => {
  const actual = await importOriginal<typeof EnvModule>();
  return {
    ...actual,
    appConfig: { ...actual.appConfig, statusPageUrl: 'https://status.montra.example/' },
  };
});

describe('service status link (status page configured)', () => {
  it('links to the status page from the troubleshooting guide and the guide list', async () => {
    const user = makeUser({ onboarding_completed: true });
    renderRoute(helpGuidePath('troubleshooting'), { user });
    await findPageHeading('Troubleshooting sign-in, sync and notifications');
    const link = screen.getByRole('link', { name: /Service status/ });
    expect(link).toHaveAttribute('href', 'https://status.montra.example/');
    expect(link).toHaveAttribute('target', '_blank');
    expect(link).toHaveAttribute('rel', 'noopener noreferrer');
  });

  it('is not shown on other guides', async () => {
    renderRoute(helpGuidePath('budgets'), { user: makeUser({ onboarding_completed: true }) });
    await findPageHeading('How budgets are calculated');
    expect(screen.queryByRole('link', { name: /Service status/ })).not.toBeInTheDocument();
  });
});
