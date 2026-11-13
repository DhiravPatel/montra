import { describe, expect, it } from 'vitest';
import {
  fromSavedSearch,
  isSearchable,
  normalizeQuery,
  queryLength,
  readSearchState,
  toSavedSearch,
} from './query';

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

describe('saved searches', () => {
  it('saves the GET /search query once the text can be searched', () => {
    expect(toSavedSearch(' a ', 'all', 'relevance')).toBeNull();
    expect(toSavedSearch('  blue   tokai ', 'merchants', 'name')).toEqual({
      q: 'blue tokai',
      scope: 'merchants',
      sort: 'name',
    });
  });

  it('reads saved searches defensively', () => {
    expect(fromSavedSearch({ q: 'rent', scope: 'bills', sort: 'recent' })).toEqual({
      value: { q: 'rent', scope: 'bills', sort: 'recent' },
      partial: false,
    });
    expect(fromSavedSearch({ q: 'rent', scope: 'planets', extra: true })).toEqual({
      value: { q: 'rent', scope: 'all', sort: 'relevance' },
      partial: true,
    });
    expect(fromSavedSearch({ q: 'x' })).toBeNull();
    expect(fromSavedSearch({ scope: 'all' })).toBeNull();
  });
});
