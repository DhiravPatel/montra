import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useId, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { Select } from '@/shared/components/Select';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { currencyOptions, useCurrencies } from '@/shared/currency/api';
import { invalidateFinance } from '@/shared/finance/keys';
import { formatDate, parseTimestamp } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { RefreshFailed } from '@/features/analytics/components/Blocks';
import { fxApi, useRates } from '../api';
import { sourceDisplay } from '../labels';
import { formatRate } from '../rate';
import type { RatesQuery, StoredRate } from '../types';

/** The list filter with one side set or cleared (no empty values in the request). */
function withCurrency(current: RatesQuery, side: 'base' | 'quote', code: string): RatesQuery {
  const base = side === 'base' ? code : current.base;
  const quote = side === 'quote' ? code : current.quote;
  const next: RatesQuery = {};
  if (base) next.base = base;
  if (quote) next.quote = quote;
  return next;
}

function RateRow({
  rate,
  onDelete,
}: {
  rate: StoredRate;
  /** Only your own manual rates can be deleted. */
  onDelete?: (rate: StoredRate) => void;
}) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const asOf = parseTimestamp(rate.as_of);
  const source = sourceDisplay[rate.source];
  const equation = t('fx.rate.equation', {
    base: rate.base,
    rate: formatRate(rate.rate, formatLocale),
    quote: rate.quote,
  });
  return (
    <li className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-center">
      <div className="min-w-0 flex-1 space-y-1.5">
        <p className="font-medium text-fg">{equation}</p>
        <p className="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-fg-muted">
          <StatusBadge tone={source.tone} icon={source.icon}>
            {rate.mine ? t('fx.source.mine') : t(source.label)}
          </StatusBadge>
          {asOf ? (
            <span>
              {t('fx.rate.asOf', { date: formatDate(asOf, formatLocale, user.timezone) })}
            </span>
          ) : null}
        </p>
      </div>
      {rate.mine && onDelete ? (
        <Button
          variant="secondary"
          size="sm"
          aria-label={t('fx.delete.action', { pair: `${rate.base} → ${rate.quote}` })}
          onClick={() => {
            onDelete(rate);
          }}
        >
          <Icon name="trash" className="size-4" />
          {t('common.delete')}
        </Button>
      ) : null}
    </li>
  );
}

/**
 * The latest rate for each pair and source: your own rates (which you can
 * delete) and rates from a provider, when one is set up.
 */
export function RatesCard() {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const currencies = useCurrencies();
  const [filter, setFilter] = useState<RatesQuery>({});
  const rates = useRates(filter);
  const [removing, setRemoving] = useState<StoredRate | null>(null);
  const [removeError, setRemoveError] = useState<string | null>(null);
  const mineHeading = useId();
  const providerHeading = useId();
  const remove = useMutation({
    mutationFn: (rate: StoredRate) => fxApi.deleteRate(rate.id),
    onSettled: () => invalidateFinance(queryClient),
  });

  const confirmRemove = () => {
    if (!removing || remove.isPending) return;
    setRemoveError(null);
    remove.mutate(removing, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('fx.delete.done') });
        setRemoving(null);
      },
      onError: (error) => {
        if (hasErrorCode(error, 'NOT_FOUND')) {
          toast.show({ tone: 'info', title: t('fx.delete.gone') });
          setRemoving(null);
        } else {
          setRemoveError(describeError(error, t));
        }
      },
    });
  };

  const options = currencyOptions(currencies.data, formatLocale);
  let content;
  if (rates.isPending) {
    content = <LoadingState label={t('fx.list.loading')} />;
  } else if (!rates.data) {
    content = hasErrorCode(rates.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="h3" />
    ) : (
      <ErrorState
        title={t('fx.list.error')}
        error={rates.error}
        retrying={rates.isFetching}
        onRetry={() => {
          void rates.refetch();
        }}
      />
    );
  } else if (rates.data.length === 0) {
    content = (
      <EmptyState
        icon="arrow-left-right"
        title={filter.base || filter.quote ? t('fx.list.noMatches') : t('fx.list.empty')}
        description={t('fx.list.emptyBody')}
      />
    );
  } else {
    const mine = rates.data.filter((rate) => rate.mine);
    const others = rates.data.filter((rate) => !rate.mine);
    content = (
      <div className="space-y-6">
        {mine.length > 0 ? (
          <section aria-labelledby={mineHeading}>
            <h3 id={mineHeading} className="mb-3 text-sm font-semibold text-fg">
              {t('fx.list.mine')}
            </h3>
            <ul className="divide-y divide-line">
              {mine.map((rate) => (
                <RateRow
                  key={rate.id}
                  rate={rate}
                  onDelete={(target) => {
                    setRemoveError(null);
                    setRemoving(target);
                  }}
                />
              ))}
            </ul>
          </section>
        ) : null}
        {others.length > 0 ? (
          <section aria-labelledby={providerHeading}>
            <h3 id={providerHeading} className="mb-3 text-sm font-semibold text-fg">
              {t('fx.list.provider')}
            </h3>
            <ul className="divide-y divide-line">
              {others.map((rate) => (
                <RateRow key={rate.id} rate={rate} />
              ))}
            </ul>
          </section>
        ) : null}
      </div>
    );
  }

  const removingAsOf = removing ? parseTimestamp(removing.as_of) : null;
  return (
    <Card title={t('fx.list.title')} description={t('fx.list.description')}>
      <div
        role="group"
        aria-label={t('fx.list.filters')}
        className="mb-5 flex flex-wrap items-end gap-3"
      >
        <Select
          label={t('fx.list.base')}
          optional
          placeholder={t('fx.list.anyCurrency')}
          options={options}
          value={filter.base ?? ''}
          className="min-w-48"
          onChange={(event) => {
            setFilter((current) => withCurrency(current, 'base', event.target.value));
          }}
        />
        <Select
          label={t('fx.list.quote')}
          optional
          placeholder={t('fx.list.anyCurrency')}
          options={options}
          value={filter.quote ?? ''}
          className="min-w-48"
          onChange={(event) => {
            setFilter((current) => withCurrency(current, 'quote', event.target.value));
          }}
        />
      </div>
      {rates.isError && rates.data ? (
        <RefreshFailed
          message={t('fx.stale.list')}
          retrying={rates.isFetching}
          onRetry={() => {
            void rates.refetch();
          }}
        />
      ) : null}
      <div aria-busy={rates.isFetching || undefined}>{content}</div>
      <ConfirmDialog
        open={removing !== null}
        onOpenChange={(open) => {
          if (!open) setRemoving(null);
        }}
        title={t('fx.delete.title')}
        description={
          removing ? (
            <>
              <p>
                {t('fx.rate.equation', {
                  base: removing.base,
                  rate: formatRate(removing.rate, formatLocale),
                  quote: removing.quote,
                })}
                {removingAsOf
                  ? ` · ${t('fx.rate.asOf', { date: formatDate(removingAsOf, formatLocale, user.timezone) })}`
                  : null}
              </p>
              <p className="mt-2">{t('fx.delete.body')}</p>
            </>
          ) : null
        }
        confirmLabel={t('fx.delete.confirm')}
        onConfirm={confirmRemove}
        pending={remove.isPending}
        error={removeError}
      />
    </Card>
  );
}
