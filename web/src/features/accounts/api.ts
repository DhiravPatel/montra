import { useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData, apiEnvelope } from '@/shared/api/request';
import { financeKeys } from '@/shared/finance/keys';
import type {
  Account,
  AccountInput,
  AccountPatch,
  AccountsReport,
  AdjustmentInput,
  BalanceReport,
  Transaction,
} from '@/shared/finance/types';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

/** Account endpoints (spec §4.3, §20B.4). Balances are always the API's ledger values. */
export const accountsApi = {
  get: (id: string, signal?: AbortSignal): Promise<Account> =>
    apiData(api.GET('/accounts/{id}', { params: { path: { id } }, ...signalOption(signal) })),
  create: (body: AccountInput, idempotencyKey: string): Promise<Account> =>
    apiData(
      api.POST('/accounts', { params: { header: { 'Idempotency-Key': idempotencyKey } }, body }),
    ),
  update: (id: string, body: AccountPatch): Promise<Account> =>
    apiData(api.PATCH('/accounts/{id}', { params: { path: { id } }, body })),
  archive: (id: string, version: number): Promise<Account> =>
    apiData(api.POST('/accounts/{id}/archive', { params: { path: { id }, query: { version } } })),
  restore: (id: string, version: number): Promise<Account> =>
    apiData(api.POST('/accounts/{id}/restore', { params: { path: { id }, query: { version } } })),
  close: (id: string, version: number): Promise<Account> =>
    apiData(api.POST('/accounts/{id}/close', { params: { path: { id }, query: { version } } })),
  adjust: (id: string, body: AdjustmentInput, idempotencyKey: string): Promise<Account> =>
    apiData(
      api.POST('/accounts/{id}/adjustments', {
        params: { path: { id }, header: { 'Idempotency-Key': idempotencyKey } },
        body,
      }),
    ),
  balanceHistory: (id: string, from: string, signal?: AbortSignal): Promise<BalanceReport> =>
    apiData(
      api.GET('/accounts/{id}/balance', {
        params: { path: { id }, query: { from } },
        ...signalOption(signal),
      }),
    ),
  recentTransactions: async (
    id: string,
    limit: number,
    signal?: AbortSignal,
  ): Promise<{ items: Transaction[]; hasMore: boolean }> => {
    const envelope = await apiEnvelope(
      api.GET('/accounts/{id}/transactions', {
        params: { path: { id }, query: { limit } },
        ...signalOption(signal),
      }),
    );
    return { items: envelope.data, hasMore: Boolean(envelope.meta.next_cursor) };
  },
  totals: (signal?: AbortSignal): Promise<AccountsReport> =>
    apiData(api.GET('/analytics/accounts', { params: { query: {} }, ...signalOption(signal) })),
};

export function useAccount(id: string) {
  return useQuery({
    queryKey: financeKeys.account(id),
    queryFn: ({ signal }) => accountsApi.get(id, signal),
  });
}

export function useAccountTotals() {
  return useQuery({
    queryKey: financeKeys.accountTotals(),
    queryFn: ({ signal }) => accountsApi.totals(signal),
  });
}

export function useBalanceHistory(id: string, from: string, today: string) {
  return useQuery({
    queryKey: financeKeys.accountBalance(id, from, today),
    queryFn: ({ signal }) => accountsApi.balanceHistory(id, from, signal),
  });
}

export function useRecentAccountTransactions(id: string, limit = 10) {
  return useQuery({
    queryKey: financeKeys.accountTransactions(id),
    queryFn: ({ signal }) => accountsApi.recentTransactions(id, limit, signal),
  });
}
