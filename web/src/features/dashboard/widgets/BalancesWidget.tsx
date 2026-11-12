import { MoneyText } from '@/shared/components/MoneyText';
import { EmptyState } from '@/shared/components/states';
import { paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { WidgetCard } from '../components/WidgetCard';
import type { WidgetProps } from './types';

/** Tracked net worth per currency: what you have and what you owe (overview accounts). */
export function BalancesWidget({ summary, title }: WidgetProps) {
  const t = useT();
  return (
    <WidgetCard
      title={title}
      generatedAt={summary.generated_at}
      drillDown={{ to: paths.accounts, label: t('dashboard.viewAccounts') }}
    >
      {summary.balances.length === 0 ? (
        <EmptyState
          icon="wallet"
          title={t('dashboard.balances.empty')}
          description={t('dashboard.balances.emptyBody')}
        />
      ) : (
        <>
          <ul className="grid gap-4 sm:grid-cols-2">
            {summary.balances.map((total) => (
              <li key={total.currency} className="rounded-lg border border-line p-4">
                <p className="text-sm text-fg-muted">
                  {t('dashboard.balances.netWorth', { currency: total.currency })}
                </p>
                <MoneyText money={total.net_worth} className="mt-1 block text-3xl font-semibold" />
                <dl className="mt-3 space-y-1 text-sm">
                  <div className="flex justify-between gap-3">
                    <dt className="text-fg-muted">{t('accounts.totals.assets')}</dt>
                    <dd>
                      <MoneyText money={total.assets} />
                    </dd>
                  </div>
                  <div className="flex justify-between gap-3">
                    <dt className="text-fg-muted">{t('accounts.totals.liabilities')}</dt>
                    <dd>
                      <MoneyText money={total.liabilities} />
                    </dd>
                  </div>
                  <div className="flex justify-between gap-3">
                    <dt className="text-fg-muted">{t('accounts.totals.count')}</dt>
                    <dd className="tabular-nums">{total.account_count}</dd>
                  </div>
                </dl>
              </li>
            ))}
          </ul>
          <p className="mt-4 text-sm text-fg-muted">
            {summary.coverage.provider_synced
              ? t('dashboard.balances.synced')
              : t('finance.tracked')}
          </p>
        </>
      )}
    </WidgetCard>
  );
}
