import { keepPreviousData, useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData, apiEnvelope } from '@/shared/api/request';
import { financeKeys } from '@/shared/finance/keys';
import type {
  Category,
  CategoryInput,
  CategoryMergeInput,
  CategoryMergeResult,
  CategoryPatch,
  CategoryRule,
  CategoryRuleApplyInput,
  CategoryRuleInput,
  CategoryRulePreview,
  CategoryRulePreviewRequest,
  CategoryRuleUpdate,
  Merchant,
  MerchantAliasInput,
  MerchantAliasRemoveInput,
  MerchantDetail,
  MerchantMergeInput,
  MerchantMergePreviewInput,
  MerchantMergeResult,
  MerchantPatch,
  MerchantStatusFilter,
  Tag,
  TagBody,
  TagPatch,
} from '@/shared/finance/types';

/*
 * Organize endpoints: categories, categorization rules, tags and merchants
 * (spec §4.5–4.7). None of them takes an Idempotency-Key in the contract;
 * edits send the record's `version` (409 VERSION_CONFLICT when stale).
 */

function path(id: string) {
  return { params: { path: { id } } };
}

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

export const categoriesApi = {
  /** One category in any status (also merged ones, with merged_into_id). */
  get: (id: string, signal?: AbortSignal): Promise<Category> =>
    apiData(api.GET('/categories/{id}', { ...path(id), ...signalOption(signal) })),
  create: (body: CategoryInput): Promise<Category> => apiData(api.POST('/categories', { body })),
  /** Only the fields sent change; `clear_color` / `color: ""` and `icon: ""` remove them. */
  update: (id: string, body: CategoryPatch): Promise<Category> =>
    apiData(api.PATCH('/categories/{id}', { ...path(id), body })),
  archive: (id: string): Promise<Category> =>
    apiData(api.POST('/categories/{id}/archive', path(id))),
  restore: (id: string): Promise<Category> =>
    apiData(api.POST('/categories/{id}/restore', path(id))),
  /** 409 category_in_use (with the reference counts) when records still use it. */
  remove: (id: string) => apiData(api.DELETE('/categories/{id}', path(id))),
  /** With `preview: true` nothing changes; `affected` counts what would move. */
  merge: (body: CategoryMergeInput): Promise<CategoryMergeResult> =>
    apiData(api.POST('/categories/merge', { body })),
};

export const rulesApi = {
  list: (signal?: AbortSignal): Promise<CategoryRule[]> =>
    apiData(api.GET('/category-rules', signalOption(signal))),
  /** One rule (to reload it after a version conflict). */
  get: (id: string, signal?: AbortSignal): Promise<CategoryRule> =>
    apiData(api.GET('/category-rules/{id}', { ...path(id), ...signalOption(signal) })),
  create: (body: CategoryRuleInput): Promise<CategoryRule> =>
    apiData(api.POST('/category-rules', { body })),
  /** Replaces the rule as a whole; `version` detects a concurrent edit. */
  replace: (id: string, body: CategoryRuleUpdate): Promise<CategoryRule> =>
    apiData(api.PUT('/category-rules/{id}', { ...path(id), body })),
  remove: (id: string) => apiData(api.DELETE('/category-rules/{id}', path(id))),
  preview: (body: CategoryRulePreviewRequest): Promise<CategoryRulePreview> =>
    apiData(api.POST('/category-rules/preview', { body })),
  /** Recategorizes existing transactions with a saved rule (audited by the API). */
  applySaved: (id: string, body: CategoryRuleApplyInput): Promise<CategoryRulePreview> =>
    apiData(api.POST('/category-rules/{id}/apply', { ...path(id), body })),
};

export const tagsApi = {
  /** One tag with its usage (to reload it after a version conflict). */
  get: (id: string, signal?: AbortSignal): Promise<Tag> =>
    apiData(api.GET('/tags/{id}', { ...path(id), ...signalOption(signal) })),
  create: (body: TagBody): Promise<Tag> => apiData(api.POST('/tags', { body })),
  /** Only the fields sent change; `clear_color` removes the color. */
  update: (id: string, body: TagPatch): Promise<Tag> =>
    apiData(api.PATCH('/tags/{id}', { ...path(id), body })),
  remove: (id: string) => apiData(api.DELETE('/tags/{id}', path(id))),
};

/** Merchants per page on the merchants screens (the API allows 1–100, default 50). */
export const MERCHANT_PAGE_SIZE = 50;

export interface MerchantPage {
  items: Merchant[];
  nextCursor: string | null;
}

export interface MerchantListQuery {
  /** Search text (names and other names); kept in memory, never in the URL. */
  q: string;
  status: MerchantStatusFilter;
}

export const merchantsApi = {
  list: (
    query: MerchantListQuery & { cursor?: string },
    signal?: AbortSignal,
  ): Promise<MerchantPage> =>
    apiEnvelope(
      api.GET('/merchants', {
        params: {
          query: {
            status: query.status,
            limit: MERCHANT_PAGE_SIZE,
            ...(query.q ? { q: query.q } : {}),
            ...(query.cursor ? { cursor: query.cursor } : {}),
          },
        },
        ...signalOption(signal),
      }),
    ).then((envelope) => ({
      items: envelope.data,
      nextCursor: envelope.meta.next_cursor ?? null,
    })),
  update: (id: string, body: MerchantPatch): Promise<MerchantDetail> =>
    apiData(api.PATCH('/merchants/{id}', { ...path(id), body })),
  addAlias: (body: MerchantAliasInput): Promise<MerchantDetail> =>
    apiData(api.POST('/merchants/aliases', { body })),
  removeAlias: (body: MerchantAliasRemoveInput): Promise<MerchantDetail> =>
    apiData(api.POST('/merchants/aliases/remove', { body })),
  /** Counts what a merge would move; nothing changes. */
  mergePreview: (body: MerchantMergePreviewInput): Promise<MerchantMergeResult> =>
    apiData(api.POST('/merchants/merge/preview', { body })),
  merge: (body: MerchantMergeInput): Promise<MerchantDetail> =>
    apiData(api.POST('/merchants/merge', { body })),
};

export function useCategoryRules() {
  return useQuery({
    queryKey: financeKeys.categoryRules(),
    queryFn: ({ signal }) => rulesApi.list(signal),
  });
}

/**
 * Merchants for a search text and status, in cursor pages ("Load more").
 * The search text and cursor stay in memory, never in the URL.
 */
export function useMerchantList(search: string, status: MerchantStatusFilter, enabled = true) {
  const q = search.trim().slice(0, 100);
  return useInfiniteQuery({
    queryKey: financeKeys.merchantList({ q, status }),
    queryFn: ({ pageParam, signal }) =>
      merchantsApi.list({ q, status, ...(pageParam ? { cursor: pageParam } : {}) }, signal),
    initialPageParam: '',
    getNextPageParam: (last) => last.nextCursor ?? undefined,
    placeholderData: keepPreviousData,
    enabled,
  });
}
