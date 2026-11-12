import type { components, operations } from '@/shared/api/schema';

/** Search types generated from the OpenAPI contract (never hand-written). */
type Schemas = components['schemas'];

export type SearchResults = Schemas['Results'];
export type TransactionHit = Schemas['TransactionHit'];
export type NamedHit = Schemas['NamedHit'];
export type PostHit = Schemas['PostHit'];
export type UserHit = Schemas['UserHit'];
export type RecentSearch = Schemas['RecentDTO'];

type SearchQueryParams = NonNullable<operations['search']['parameters']['query']>;

/** `all` or one section (`''` means `all` to the API; this client always sends a value). */
export type SearchScope = Exclude<NonNullable<SearchQueryParams['scope']>, ''>;
export type SearchSection = Exclude<SearchScope, 'all'>;
/** Result order (`''` means `relevance` to the API; this client always sends a value). */
export type SearchSort = Exclude<NonNullable<SearchQueryParams['sort']>, ''>;
/** Sections whose hits are `{id, name, kind}` records. */
export type NamedSection = Exclude<SearchSection, 'transactions' | 'posts' | 'users'>;

/** One search request as this client sends it. */
export interface SearchRequest {
  q: string;
  scope: SearchScope;
  limit: number;
  sort: SearchSort;
  /** Remember the query in recent searches (only for searches the user submits). */
  save: boolean;
}
