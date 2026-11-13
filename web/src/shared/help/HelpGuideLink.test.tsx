import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { I18nProvider } from '@/shared/i18n/I18nProvider';
import { guideIdFromSlug, helpGuideIds, helpGuidePath, helpGuideSlug } from './guides';
import { HelpGuideLink, ServiceStatusLink } from './HelpGuideLink';

describe('HelpGuideLink', () => {
  it('names the guide it opens and links to its section', () => {
    render(
      <I18nProvider language="en">
        <MemoryRouter>
          <HelpGuideLink guide="recurring" section="subscriptions" />
        </MemoryRouter>
      </I18nProvider>,
    );
    const link = screen.getByRole('link', {
      name: 'How this works: Recurring, bills and subscriptions',
    });
    expect(link).toHaveAttribute('href', '/help/guides/recurring#subscriptions');
    expect(link).toHaveTextContent('How this works');
  });

  it('renders no status link without a configured status page', () => {
    const { container } = render(
      <I18nProvider language="en">
        <ServiceStatusLink />
      </I18nProvider>,
    );
    expect(container).toBeEmptyDOMElement();
  });

  it('uses the same slugs as the mobile app and reads them back', () => {
    expect(helpGuideIds.map(helpGuideSlug)).toEqual([
      'getting-started',
      'no-bank',
      'balances',
      'budgets',
      'recurring',
      'goals',
      'group-balances',
      'imports',
      'reconciliation',
      'privacy',
      'two-step',
      'fair-use',
      'troubleshooting',
    ]);
    expect(guideIdFromSlug('two-step')).toBe('twoStep');
    expect(guideIdFromSlug('twoStep')).toBeNull();
    expect(helpGuidePath('fairUse')).toBe('/help/guides/fair-use');
  });
});
