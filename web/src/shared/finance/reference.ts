import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import { financeKeys, preferencesQueryKey } from './keys';
import type { Account, Category, Merchant, PaymentMethod, Preferences, Tag } from './types';

/*
 * Reference data shared by pickers and screens: the user's accounts,
 * categories, tags, merchants, payment methods and preferences. Lists are
 * never null (empty lists are `[]`).
 */

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

export const referenceApi = {
  listAccounts: (includeArchived: boolean, signal?: AbortSignal): Promise<Account[]> =>
    apiData(
      api.GET('/accounts', {
        params: { query: includeArchived ? { include_archived: true } : {} },
        ...signalOption(signal),
      }),
    ),
  listCategories: (includeArchived: boolean, signal?: AbortSignal): Promise<Category[]> =>
    apiData(
      api.GET('/categories', {
        params: { query: includeArchived ? { include_archived: true } : {} },
        ...signalOption(signal),
      }),
    ),
  listTags: (signal?: AbortSignal): Promise<Tag[]> =>
    apiData(api.GET('/tags', signalOption(signal))),
  searchMerchants: (q: string, signal?: AbortSignal): Promise<Merchant[]> =>
    apiData(
      api.GET('/merchants', {
        params: { query: q ? { q, limit: 20 } : { limit: 20 } },
        ...signalOption(signal),
      }),
    ),
  listPaymentMethods: (includeArchived: boolean, signal?: AbortSignal): Promise<PaymentMethod[]> =>
    apiData(
      api.GET('/payment-methods', {
        params: { query: includeArchived ? { include_archived: true } : {} },
        ...signalOption(signal),
      }),
    ),
  getPreferences: (signal?: AbortSignal): Promise<Preferences> =>
    apiData(api.GET('/me/preferences', signalOption(signal))),
};

export function useAccounts(includeArchived = false) {
  return useQuery({
    queryKey: financeKeys.accounts(includeArchived),
    queryFn: ({ signal }) => referenceApi.listAccounts(includeArchived, signal),
  });
}

export function useCategories(includeArchived = false) {
  return useQuery({
    queryKey: financeKeys.categories(includeArchived),
    queryFn: ({ signal }) => referenceApi.listCategories(includeArchived, signal),
    staleTime: 5 * 60_000,
  });
}

export function useTags() {
  return useQuery({
    queryKey: financeKeys.tags(),
    queryFn: ({ signal }) => referenceApi.listTags(signal),
    staleTime: 5 * 60_000,
  });
}

/** One merchant (e.g. to name a merchant filter that came from a link). */
export function useMerchant(id: string) {
  return useQuery({
    queryKey: financeKeys.merchant(id),
    queryFn: ({ signal }) =>
      apiData(api.GET('/merchants/{id}', { params: { path: { id } }, ...signalOption(signal) })),
    enabled: Boolean(id),
    staleTime: 5 * 60_000,
  });
}

/** Merchant suggestions for a search text (kept in memory only, never in the URL). */
export function useMerchantSearch(search: string, enabled = true) {
  const q = search.trim().slice(0, 100);
  return useQuery({
    queryKey: financeKeys.merchants(q),
    queryFn: ({ signal }) => referenceApi.searchMerchants(q, signal),
    enabled,
    staleTime: 60_000,
    placeholderData: keepPreviousData,
  });
}

export function usePaymentMethods(includeArchived = false) {
  return useQuery({
    queryKey: financeKeys.paymentMethods(includeArchived),
    queryFn: ({ signal }) => referenceApi.listPaymentMethods(includeArchived, signal),
    staleTime: 5 * 60_000,
  });
}

export function usePreferences() {
  return useQuery({
    queryKey: preferencesQueryKey,
    queryFn: ({ signal }) => referenceApi.getPreferences(signal),
    staleTime: 5 * 60_000,
  });
}

/** Accounts that can receive new transactions: owned and active. */
export function writableAccounts(accounts: readonly Account[] | undefined): Account[] {
  return (accounts ?? []).filter((account) => account.owned && account.status === 'active');
}
