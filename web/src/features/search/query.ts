import type { SearchResults, SearchScope, SearchSection, SearchSort } from './types';

/** The API's limits for `q` (characters after normalizing whitespace). */
export const SEARCH_MIN_LENGTH = 2;
export const SEARCH_MAX_LENGTH = 100;
/** Typing pauses this long before a search runs. */
export const SEARCH_DEBOUNCE_MS = 300;
/** Results per section when searching everything (the API default). */
export const ALL_SECTIONS_LIMIT = 5;
/** Results when searching one section (the API maximum). */
export const ONE_SECTION_LIMIT = 20;

/** Result sections in display order (the sections the API returns). */
export const SEARCH_SECTIONS = [
  'transactions',
  'accounts',
  'merchants',
  'categories',
  'budgets',
  'bills',
  'subscriptions',
  'recurring_rules',
  'goals',
  'groups',
  'posts',
  'users',
] as const satisfies readonly SearchSection[];

type MissingSections = Exclude<SearchSection, (typeof SEARCH_SECTIONS)[number]>;
/** Compile-time check: every section in the contract is listed above. */
export const searchSectionsAreListed: [MissingSections] extends [never] ? true : MissingSections =
  true;

/** Result orders the API offers (relevance is its default). */
export const SEARCH_SORTS = [
  'relevance',
  'name',
  'recent',
] as const satisfies readonly SearchSort[];

type MissingSorts = Exclude<SearchSort, (typeof SEARCH_SORTS)[number]>;
/** Compile-time check: every sort in the contract is listed above. */
export const searchSortsAreListed: [MissingSorts] extends [never] ? true : MissingSorts = true;

const SCOPES: readonly string[] = ['all', ...SEARCH_SECTIONS];

export function isSearchScope(value: unknown): value is SearchScope {
  return typeof value === 'string' && SCOPES.includes(value);
}

export function isSearchSort(value: unknown): value is SearchSort {
  return typeof value === 'string' && (SEARCH_SORTS as readonly string[]).includes(value);
}

/**
 * Mirrors the API's normalization: surrounding whitespace removed and runs
 * of whitespace inside collapsed to one space.
 */
export function normalizeQuery(text: string): string {
  return text.split(/\s+/u).filter(Boolean).join(' ');
}

/** Length in characters (Unicode code points), as the API counts it. */
export function queryLength(query: string): number {
  return query.match(/./gsu)?.length ?? 0;
}

/** Whether a normalized query can be sent (2 to 100 characters). */
export function isSearchable(query: string): boolean {
  const length = queryLength(query);
  return length >= SEARCH_MIN_LENGTH && length <= SEARCH_MAX_LENGTH;
}

export function limitFor(scope: SearchScope): number {
  return scope === 'all' ? ALL_SECTIONS_LIMIT : ONE_SECTION_LIMIT;
}

/** How many records a response lists (a count of results, not money). */
export function resultCount(results: SearchResults): number {
  return SEARCH_SECTIONS.reduce((sum, section) => sum + results[section].length, 0);
}

/**
 * The search kept in the history entry's state (never in the URL, document
 * title, logs or storage): Back and Forward restore it, a copied link does
 * not carry it, and it is not sent to any server as part of a page URL.
 */
export interface SearchLocationState {
  q?: string;
  scope?: SearchScope;
  sort?: SearchSort;
  /** Remember this search in recent searches (set when it was submitted). */
  save?: boolean;
  /** Move focus to the search field on arrival (search icon, "/" key). */
  focus?: boolean;
}

/** Reads untrusted history state defensively. */
export function readSearchState(state: unknown): SearchLocationState {
  if (typeof state !== 'object' || state === null) return {};
  const record = state as Record<string, unknown>;
  const result: SearchLocationState = {};
  if (typeof record.q === 'string') result.q = record.q.slice(0, SEARCH_MAX_LENGTH * 2);
  if (isSearchScope(record.scope)) result.scope = record.scope;
  if (isSearchSort(record.sort)) result.sort = record.sort;
  if (record.save === true) result.save = true;
  if (record.focus === true) result.focus = true;
  return result;
}
