import { describe, expect, it } from 'vitest';
import { en } from './locales/en';
import { hi } from './locales/hi';

/** Feature areas whose strings must be translated (not just fall back to English). */
const TRANSLATED_PREFIXES = [
  'common.',
  'validation.amount',
  'charts.',
  'finance.',
  'categories.',
  'accounts.',
  'paymentMethods.',
  'transactions.',
  'transfers.',
  'dashboard.',
  'onboarding.',
  'nav.',
  // Round 2.
  'sharing.',
  'picker.',
  'organize.',
  'categoryRules.',
  'tags.',
  'merchants.',
  'budgets.',
  'planning.',
  'schedule.',
  'recurring.',
  'bills.',
  // Round 3 (more prefixes are added as their features land).
  'receipts.',
  'imports.',
  'reconciliation.',
  'analytics.',
  'reports.',
  'fx.',
  // Round 4.
  'groupNav.',
  'groups.',
  'social.',
  'groupMoney.',
  // Round 5.
  'communities.',
  'challenges.',
  'moderation.',
  'support.',
  'privacySettings.',
  'adminUsage.',
  'search.',
  'insights.',
  'notifications.',
  'integrations.',
  'calendar.',
  'subscriptions.',
  'goals.',
  // Round 6.
  'profileSettings.',
];

describe('Hindi catalog coverage', () => {
  it('translates every finance, dashboard and onboarding string', () => {
    const catalog: Readonly<Record<string, unknown>> = hi;
    const missing = Object.keys(en).filter(
      (key) => TRANSLATED_PREFIXES.some((prefix) => key.startsWith(prefix)) && !(key in catalog),
    );
    expect(missing).toEqual([]);
  });

  it('keeps the same plural forms and placeholders in both languages', () => {
    const catalog: Readonly<Record<string, unknown>> = hi;
    const placeholders = (value: unknown) =>
      [...JSON.stringify(value).matchAll(/\{(\w+)\}/g)].map((match) => match[1]).sort();
    for (const [key, english] of Object.entries(en)) {
      const hindi = catalog[key];
      if (hindi === undefined) continue;
      expect(typeof hindi, key).toBe(typeof english);
      expect(new Set(placeholders(hindi)), key).toEqual(new Set(placeholders(english)));
    }
  });
});
