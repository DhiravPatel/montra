import { useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import { fxKeys } from './keys';
import type { Conversion, ConvertQuery, ManualRateInput, RatesQuery, StoredRate } from './types';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

/**
 * Exchange rates (spec §4.19, §20B.20). Rates only change how amounts are
 * converted for display; recorded transactions are never rewritten.
 */
export const fxApi = {
  /** The latest rate per pair and source: provider rates plus your own overrides. */
  rates: (query: RatesQuery, signal?: AbortSignal): Promise<StoredRate[]> =>
    apiData(api.GET('/fx/rates', { params: { query }, ...signalOption(signal) })),
  /** Adds a manual rate; earlier rates are kept as history. */
  addRate: (body: ManualRateInput): Promise<StoredRate> => apiData(api.POST('/fx/rates', { body })),
  /** Deletes one of your manual rates (provider rates cannot be deleted). */
  deleteRate: (id: string): Promise<{ ok: boolean }> =>
    apiData(api.DELETE('/fx/rates/{id}', { params: { path: { id } } })),
  /** Converts an amount and discloses the rate used, its source and date. */
  convert: (query: ConvertQuery, signal?: AbortSignal): Promise<Conversion> =>
    apiData(api.GET('/fx/convert', { params: { query }, ...signalOption(signal) })),
};

export function useRates(query: RatesQuery) {
  return useQuery({
    queryKey: fxKeys.rates(query),
    queryFn: ({ signal }) => fxApi.rates(query, signal),
  });
}
