import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, LoadingState } from '@/shared/components/states';
import { paths } from '@/shared/config/paths';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useAccountTotals } from '../api';
import {
  CurrencySection,
  QueryError,
  RefreshFailed,
  Refreshing,
  StatTile,
} from '../components/Blocks';
import { ViewOptions } from '../components/ViewOptions';
import type { ViewProps } from './CashFlowView';

/** What you have, what you owe and net worth per currency, as of now (not the period). */
export function AccountsView({ filters, onChange }: ViewProps) {
  const { t } = useI18n();
  const report = useAccountTotals(filters.overviewOnly);

  let content;
  if (report.isPending) {
    content = (
      <LoadingState label={t('analytics.loading')}>
        <Skeleton className="h-40 w-full" />
      </LoadingState>
    );
  } else if (!report.data) {
    content = (
      <QueryError
        error={report.error}
        title={t('analytics.error')}
        retrying={report.isFetching}
        onRetry={() => {
          void report.refetch();
        }}
      />
    );
  } else if (report.data.totals.length === 0) {
    content = (
      <EmptyState
        icon="wallet"
        title={t('analytics.accounts.empty')}
        description={t('analytics.accounts.emptyBody')}
        action={
          <ButtonLink to={paths.accountNew} variant="secondary">
            <Icon name="plus" className="size-4" />
            {t('accounts.add')}
          </ButtonLink>
        }
      />
    );
  } else {
    const totals = report.data.totals;
    content = (
      <Refreshing fetching={report.isFetching} stale={report.isPlaceholderData}>
        <div className="space-y-8">
          {totals.map((total) => (
            <CurrencySection
              key={total.currency}
              currency={total.currency}
              showHeading={totals.length > 1}
            >
              <dl className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                <StatTile label={t('analytics.accounts.assets')}>
                  <MoneyText money={total.assets} />
                </StatTile>
                <StatTile label={t('analytics.accounts.liabilities')}>
                  <MoneyText money={total.liabilities} />
                </StatTile>
                <StatTile label={t('analytics.accounts.netWorth')}>
                  <MoneyText money={total.net_worth} signDisplay="exceptZero" />
                </StatTile>
                <StatTile label={t('analytics.accounts.count')}>
                  <span>{total.account_count}</span>
                </StatTile>
              </dl>
            </CurrencySection>
          ))}
          <p className="text-sm text-fg-muted">{t('finance.tracked')}</p>
        </div>
      </Refreshing>
    );
  }

  return (
    <>
      <ViewOptions label={t('analytics.options.label')}>
        <label className="inline-flex min-h-11 cursor-pointer items-center gap-2 text-sm text-fg">
          <input
            type="checkbox"
            checked={filters.overviewOnly}
            onChange={(event) => {
              onChange({ ...filters, overviewOnly: event.target.checked });
            }}
            className="size-5 accent-accent"
          />
          {t('analytics.accounts.overviewOnly')}
        </label>
      </ViewOptions>
      <Card
        title={t('analytics.accounts.title')}
        description={t('analytics.accounts.description')}
        actions={
          <ButtonLink to={paths.accounts} variant="ghost" size="sm">
            {t('analytics.accounts.viewAccounts')}
            <Icon name="arrow-right" className="size-4" />
          </ButtonLink>
        }
      >
        {report.isError && report.data ? (
          <RefreshFailed
            message={t('analytics.stale.figures')}
            retrying={report.isFetching}
            onRetry={() => {
              void report.refetch();
            }}
          />
        ) : null}
        {content}
      </Card>
    </>
  );
}
