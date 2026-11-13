import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { helpGuideIds, helpGuidePath } from '@/shared/help/guides';
import { createTranslator } from '@/shared/i18n/translate';
import { expectNoAxeViolations } from '@/tests/axe';
import { makeUser } from '@/tests/fixtures';
import { findPageHeading, renderRoute } from '@/tests/render';
import { guideSections } from '../guides/content';
import { searchGuides } from '../guides/search';

const signedIn = () => makeUser({ onboarding_completed: true });

describe('help guides', () => {
  it('has text for every block of every guide in English and Hindi', () => {
    const en = createTranslator('en', 'en');
    const hi = createTranslator('hi', 'hi-IN');
    for (const id of helpGuideIds) {
      expect(guideSections[id].length, id).toBeGreaterThan(0);
      for (const t of [en, hi]) {
        expect(t(`helpGuides.${id}.title`)).not.toBe('');
        for (const section of guideSections[id]) {
          expect(t(section.title)).not.toBe('');
          for (const block of section.blocks) expect(t(block.key), block.key).not.toBe('');
        }
      }
      // Hindi is a translation, not the English fallback.
      expect(hi(`helpGuides.${id}.title`)).not.toBe(en(`helpGuides.${id}.title`));
    }
  });

  it('searches guide text in the interface language, every word anywhere', () => {
    const en = createTranslator('en', 'en');
    expect(searchGuides('rollover', en, 'en')).toEqual(['budgets']);
    expect(searchGuides('RECOVERY codes', en, 'en')).toContain('twoStep');
    expect(searchGuides('', en, 'en')).toHaveLength(helpGuideIds.length);
    expect(searchGuides('zzz-nothing', en, 'en')).toEqual([]);
    const hi = createTranslator('hi', 'hi-IN');
    expect(searchGuides('रोलओवर', hi, 'hi-IN')).toEqual(['budgets']);
  });

  it('lists guides by topic and filters them as you type, announcing the count', async () => {
    const user = userEvent.setup();
    renderRoute(helpGuidesPathFor(), { user: signedIn() });
    await findPageHeading('Guides and how-tos');
    expect(screen.getByRole('region', { name: 'Troubleshooting' })).toBeInTheDocument();
    await user.type(screen.getByRole('searchbox', { name: 'Search the guides' }), 'pace');
    expect(await screen.findByRole('heading', { name: /guides? found/ })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'How budgets are calculated' })).toHaveAttribute(
      'href',
      '/help/guides/budgets',
    );
    await waitFor(() => {
      expect(screen.getByTestId('announcer-polite')).toHaveTextContent(/found/);
    });
    await user.clear(screen.getByRole('searchbox', { name: 'Search the guides' }));
    await user.type(screen.getByRole('searchbox', { name: 'Search the guides' }), 'qwertyuiop');
    expect(
      await screen.findByRole('heading', { name: /No guide matches “qwertyuiop”/ }),
    ).toBeInTheDocument();
    await expectNoAxeViolations();
  });

  it('shows a guide with its contents, the screen it is about and no status link by default', async () => {
    renderRoute(helpGuidePath('budgets'), { user: signedIn() });
    await findPageHeading('How budgets are calculated');
    const contents = screen.getByRole('navigation', { name: 'On this page' });
    expect(within(contents).getByRole('link', { name: 'Pace and projection' })).toHaveAttribute(
      'href',
      '#pace',
    );
    expect(screen.getByRole('heading', { level: 2, name: 'Rollover' })).toBeInTheDocument();
    expect(screen.getByText(/On track: within 10% of the even pace\./)).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Go to budgets' })).toHaveAttribute('href', '/budgets');
    expect(screen.getByRole('link', { name: 'All guides' })).toHaveAttribute(
      'href',
      '/help/guides',
    );
    expect(screen.queryByRole('link', { name: /Service status/ })).not.toBeInTheDocument();
    await expectNoAxeViolations();
  });

  it('says so for a guide that does not exist', async () => {
    renderRoute('/help/guides/not-a-guide', { user: signedIn() });
    expect(
      await screen.findByRole('heading', { name: 'This guide doesn’t exist. It may have moved.' }),
    ).toBeInTheDocument();
  });

  it('renders the guide in Hindi', async () => {
    const { AppProviders } = await import('@/app/providers/AppProviders');
    const { routes } = await import('@/app/router/routes');
    const { createMemoryRouter, RouterProvider } = await import('react-router');
    const { render } = await import('@testing-library/react');
    const { createTestQueryClient } = await import('@/tests/render');
    const { testBackend } = await import('@/tests/msw/backend');
    const { CSRF_COOKIE } = await import('@/shared/api/csrf');
    testBackend.user = signedIn();
    document.cookie = `${CSRF_COOKIE}=csrf-cookie-token; path=/`;
    const router = createMemoryRouter(routes, { initialEntries: [helpGuidePath('noBank')] });
    render(
      <AppProviders queryClient={createTestQueryClient()} language="hi">
        <RouterProvider router={router} />
      </AppProviders>,
    );
    expect(
      await screen.findByRole('heading', { level: 1, name: 'मुझे अपना बैंक क्यों नहीं दिखता?' }),
    ).toBeInTheDocument();
  });
});

describe('status page setting', () => {
  it('accepts only an absolute https URL', async () => {
    const { httpsUrl } = await import('@/shared/config/env');
    expect(httpsUrl(' https://status.montra.example/ ')).toBe('https://status.montra.example/');
    expect(httpsUrl('http://status.montra.example/')).toBeNull();
    expect(httpsUrl('status.montra.example')).toBeNull();
    expect(httpsUrl('  ')).toBeNull();
    expect(httpsUrl(undefined)).toBeNull();
  });
});

function helpGuidesPathFor() {
  return '/help/guides';
}
