import type { ReactNode } from 'react';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { useCurrencies } from '@/shared/currency/api';
import { useT } from '@/shared/i18n/I18nContext';

/**
 * Currency pickers need GET /currencies before the form starts, so a
 * preselected currency (your main one) is really selected and the amount
 * precision is known.
 */
export function CurrenciesGate({ children }: { children: ReactNode }) {
  const t = useT();
  const currencies = useCurrencies();
  if (currencies.isPending) return <LoadingState label={t('fx.currencies.loading')} />;
  if (currencies.isError) {
    return (
      <ErrorState
        title={t('fx.currencies.error')}
        error={currencies.error}
        retrying={currencies.isFetching}
        onRetry={() => {
          void currencies.refetch();
        }}
        titleAs="h3"
      />
    );
  }
  return <>{children}</>;
}
