import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { commaSeparatedArrays } from '@/shared/api/query';
import { apiData } from '@/shared/api/request';
import { analyticsKeys } from './keys';
import type {
  AccountsReport,
  AnalyticsQuery,
  BudgetPerformance,
  CashFlowReport,
  CategoryReport,
  CompareQuery,
  Comparison,
  GoalReport,
  MerchantReport,
  PaymentMethodReport,
  RecurringReport,
  SubscriptionSummary,
} from './types';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

/** Most merchants the API returns in one answer (its documented maximum). */
export const MERCHANT_LIMIT = 100;

/**
 * Analytics endpoints (spec §4.11, §20B.12). Every figure is computed by the
 * API per currency; this client only displays them and never adds amounts.
 */
export const analyticsApi = {
  cashFlow: (query: AnalyticsQuery, signal?: AbortSignal): Promise<CashFlowReport> =>
    apiData(
      api.GET('/analytics/cash-flow', {
        params: { query },
        querySerializer: commaSeparatedArrays,
        ...signalOption(signal),
      }),
    ),
  /** Spending only (expenses, group shares, refunds and reimbursements): same model as cash flow. */
  expenses: (query: AnalyticsQuery, signal?: AbortSignal): Promise<CashFlowReport> =>
    apiData(
      api.GET('/analytics/expenses', {
        params: { query },
        querySerializer: commaSeparatedArrays,
        ...signalOption(signal),
      }),
    ),
  /** Income only: same model as cash flow. */
  income: (query: AnalyticsQuery, signal?: AbortSignal): Promise<CashFlowReport> =>
    apiData(
      api.GET('/analytics/income', {
        params: { query },
        querySerializer: commaSeparatedArrays,
        ...signalOption(signal),
      }),
    ),
  categories: (
    query: AnalyticsQuery & { subcategories?: boolean },
    signal?: AbortSignal,
  ): Promise<CategoryReport> =>
    apiData(
      api.GET('/analytics/categories', {
        params: { query },
        querySerializer: commaSeparatedArrays,
        ...signalOption(signal),
      }),
    ),
  merchants: (
    query: AnalyticsQuery & { limit?: number },
    signal?: AbortSignal,
  ): Promise<MerchantReport> =>
    apiData(
      api.GET('/analytics/merchants', {
        params: { query },
        querySerializer: commaSeparatedArrays,
        ...signalOption(signal),
      }),
    ),
  /** Net spending per payment method, per currency (ANL-002). */
  paymentMethods: (query: AnalyticsQuery, signal?: AbortSignal): Promise<PaymentMethodReport> =>
    apiData(
      api.GET('/analytics/payment-methods', {
        params: { query },
        querySerializer: commaSeparatedArrays,
        ...signalOption(signal),
      }),
    ),
  accounts: (overviewOnly: boolean, signal?: AbortSignal): Promise<AccountsReport> =>
    apiData(
      api.GET('/analytics/accounts', {
        params: { query: overviewOnly ? { overview_only: true } : {} },
        ...signalOption(signal),
      }),
    ),
  compare: (query: CompareQuery, signal?: AbortSignal): Promise<Comparison> =>
    apiData(
      api.GET('/analytics/compare', {
        params: { query },
        querySerializer: commaSeparatedArrays,
        ...signalOption(signal),
      }),
    ),
  budgets: (signal?: AbortSignal): Promise<BudgetPerformance> =>
    apiData(api.GET('/analytics/budgets', signalOption(signal))),
  goals: (signal?: AbortSignal): Promise<GoalReport> =>
    apiData(api.GET('/analytics/goals', signalOption(signal))),
  subscriptions: (signal?: AbortSignal): Promise<SubscriptionSummary> =>
    apiData(api.GET('/analytics/subscriptions', signalOption(signal))),
  recurring: (signal?: AbortSignal): Promise<RecurringReport> =>
    apiData(api.GET('/analytics/recurring', signalOption(signal))),
};

/*
 * While filters change, the previous figures stay on screen (dimmed) instead
 * of flashing a skeleton; `isPlaceholderData` tells the view to dim them.
 */

export function useCashFlow(query: AnalyticsQuery, enabled = true) {
  return useQuery({
    queryKey: analyticsKeys.cashFlow(query),
    queryFn: ({ signal }) => analyticsApi.cashFlow(query, signal),
    enabled,
    placeholderData: keepPreviousData,
  });
}

export type SeriesKind = 'expenses' | 'income';

/** GET /analytics/expenses or /analytics/income: spending-only or income-only cash flow. */
export function useSeriesReport(kind: SeriesKind, query: AnalyticsQuery, enabled = true) {
  return useQuery({
    queryKey: kind === 'expenses' ? analyticsKeys.expenses(query) : analyticsKeys.income(query),
    queryFn: ({ signal }) =>
      kind === 'expenses'
        ? analyticsApi.expenses(query, signal)
        : analyticsApi.income(query, signal),
    enabled,
    placeholderData: keepPreviousData,
  });
}

export function useCategoryBreakdown(
  query: AnalyticsQuery & { subcategories?: boolean },
  enabled = true,
) {
  return useQuery({
    queryKey: analyticsKeys.categories(query),
    queryFn: ({ signal }) => analyticsApi.categories(query, signal),
    enabled,
    placeholderData: keepPreviousData,
  });
}

export function useMerchants(query: AnalyticsQuery & { limit?: number }, enabled = true) {
  return useQuery({
    queryKey: analyticsKeys.merchants(query),
    queryFn: ({ signal }) => analyticsApi.merchants(query, signal),
    enabled,
    placeholderData: keepPreviousData,
  });
}

export function usePaymentMethodBreakdown(query: AnalyticsQuery, enabled = true) {
  return useQuery({
    queryKey: analyticsKeys.paymentMethods(query),
    queryFn: ({ signal }) => analyticsApi.paymentMethods(query, signal),
    enabled,
    placeholderData: keepPreviousData,
  });
}

export function useAccountTotals(overviewOnly: boolean) {
  return useQuery({
    queryKey: analyticsKeys.accounts(overviewOnly),
    queryFn: ({ signal }) => analyticsApi.accounts(overviewOnly, signal),
    placeholderData: keepPreviousData,
  });
}

export function useComparison(query: CompareQuery, enabled: boolean) {
  return useQuery({
    queryKey: analyticsKeys.compare(query),
    queryFn: ({ signal }) => analyticsApi.compare(query, signal),
    enabled,
    placeholderData: keepPreviousData,
  });
}

export function useBudgetPerformance() {
  return useQuery({
    queryKey: analyticsKeys.budgets(),
    queryFn: ({ signal }) => analyticsApi.budgets(signal),
  });
}

export function useGoalReport() {
  return useQuery({
    queryKey: analyticsKeys.goals(),
    queryFn: ({ signal }) => analyticsApi.goals(signal),
  });
}

export function useSubscriptionSummary() {
  return useQuery({
    queryKey: analyticsKeys.subscriptions(),
    queryFn: ({ signal }) => analyticsApi.subscriptions(signal),
  });
}

export function useRecurringReport() {
  return useQuery({
    queryKey: analyticsKeys.recurring(),
    queryFn: ({ signal }) => analyticsApi.recurring(signal),
  });
}
