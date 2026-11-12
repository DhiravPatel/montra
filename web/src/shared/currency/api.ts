import { useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import type { components } from '@/shared/api/schema';
import type { SelectOption } from '@/shared/components/Select';
import { currencyName } from './currencies';

/** A currency from `GET /currencies` (public reference data). */
export type Currency = components['schemas']['CurrencyDTO'];

export const currenciesQueryKey = ['reference', 'currencies'] as const;

export async function fetchCurrencies(signal?: AbortSignal): Promise<Currency[]> {
  // List data is never null (empty lists are `[]`).
  return apiData(api.GET('/currencies', signal ? { signal } : {}));
}

/**
 * Supported currencies, cached for the session. Pickers must offer only
 * `selectable` ones; retired currencies (e.g. BGN) stay valid for history.
 */
export function useCurrencies() {
  return useQuery({
    queryKey: currenciesQueryKey,
    queryFn: ({ signal }) => fetchCurrencies(signal),
    staleTime: 24 * 60 * 60 * 1000,
  });
}

/** Selectable currencies only, for pickers. */
export function selectableCurrencies(currencies: readonly Currency[] | undefined): Currency[] {
  return (currencies ?? []).filter((currency) => currency.selectable);
}

/** Minor-unit digits for a currency from GET /currencies (Intl's data as a fallback). */
export function exponentFor(currencies: readonly Currency[] | undefined, code: string): number {
  const found = currencies?.find((currency) => currency.code === code);
  if (found) return found.exponent;
  try {
    return (
      new Intl.NumberFormat('en', { style: 'currency', currency: code }).resolvedOptions()
        .maximumFractionDigits ?? 2
    );
  } catch {
    return 2;
  }
}

/**
 * Picker options: selectable currencies (plus `keep`, e.g. an existing
 * account's retired currency), labelled "Indian Rupee (INR)".
 */
export function currencyOptions(
  currencies: readonly Currency[] | undefined,
  locale: string,
  keep?: string,
): SelectOption[] {
  return (currencies ?? [])
    .filter((currency) => currency.selectable || currency.code === keep)
    .map((currency) => ({
      value: currency.code,
      label: `${currencyName(currency.code, locale, currency.name)} (${currency.code})`,
    }))
    .sort((a, b) => a.label.localeCompare(b.label, locale));
}
