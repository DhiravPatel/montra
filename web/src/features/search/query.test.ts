import { describe, expect, it } from 'vitest';
import { isSearchable, normalizeQuery, queryLength, readSearchState } from './query';

describe('search query helpers', () => {
  it('normalizes whitespace like the API', () => {
    expect(normalizeQuery('  Blue   Tokai ')).toBe('Blue Tokai');
    expect(normalizeQuery('rent\t\nmay')).toBe('rent may');
    expect(normalizeQuery('   ')).toBe('');
  });

  it('counts characters as code points and checks the 2 to 100 limit', () => {
    expect(queryLength('ab')).toBe(2);
    expect(queryLength('😀a')).toBe(2);
    expect(isSearchable('a')).toBe(false);
    expect(isSearchable('😀a')).toBe(true);
    expect(isSearchable('x'.repeat(100))).toBe(true);
    expect(isSearchable('x'.repeat(101))).toBe(false);
  });

  it('reads history state defensively', () => {
    expect(readSearchState(null)).toEqual({});
    expect(readSearchState('q')).toEqual({});
    expect(readSearchState({ q: 7, scope: 'everything', save: 'yes', focus: 1 })).toEqual({});
    expect(readSearchState({ q: 'rent', scope: 'goals', save: true, focus: true })).toEqual({
      q: 'rent',
      scope: 'goals',
      save: true,
      focus: true,
    });
  });
});
