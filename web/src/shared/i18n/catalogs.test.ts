import { describe, expect, it } from 'vitest';
import { lookupMessage, namespaceOf } from './catalogs';

describe('message catalogs', () => {
  it('maps a key to its namespace by prefix, with the first screen’s prefixes in core', () => {
    expect(namespaceOf('budgets.title')).toBe('budgets');
    expect(namespaceOf('helpContent.budgets.pace.1')).toBe('helpContent');
    expect(namespaceOf('common.cancel')).toBe('core');
    expect(namespaceOf('session.checking')).toBe('core');
    expect(namespaceOf('landing.hero.title')).toBe('core');
  });

  it('falls back to English for a key Hindi does not translate', () => {
    expect(lookupMessage('hi', 'common.cancel')).toBe('रद्द करें');
    expect(lookupMessage('hi', 'settings.sessions.title')).toBe(
      lookupMessage('en', 'settings.sessions.title'),
    );
  });
});
