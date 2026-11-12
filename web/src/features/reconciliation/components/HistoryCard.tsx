import { Card } from '@/shared/components/Card';
import { MoneyText } from '@/shared/components/MoneyText';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextLink } from '@/shared/components/TextLink';
import { importPath } from '@/shared/config/paths';
import { LoadMoreButton } from '@/shared/finance/components/LoadMoreButton';
import { formatDateTime, formatLocalDate, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { loadedItems, useReconciliationHistory } from '../api';
import type { Reconciliation } from '../types';

/** "3 reconciled · 2 statement lines unmatched · 6 not reconciled" (the stored counts). */
function countsText(entry: Reconciliation, t: ReturnType<typeof useI18n>['t']): string {
  return [
    t('reconciliation.history.reconciledCount', { count: entry.reconciled_count }),
    entry.import_batch_id
      ? t('reconciliation.history.unmatchedCount', { count: entry.unmatched_statement_rows })
      : null,
    t('reconciliation.history.unreconciledCount', { count: entry.unreconciled_transactions }),
  ]
    .filter(Boolean)
    .join(' · ');
}

/** Past balance checks, latest statement first, with the server's balances, difference and counts. */
export function HistoryCard({ accountId }: { accountId: string }) {
  const { t, formatLocale } = useI18n();
  const history = useReconciliationHistory(accountId, true);
  const entries = loadedItems(history.data);

  let content;
  if (history.isPending) {
    content = <LoadingState label={t('reconciliation.history.loading')} />;
  } else if (history.isError && !history.isFetchNextPageError) {
    content = (
      <ErrorState
        title={t('reconciliation.history.error')}
        error={history.error}
        retrying={history.isFetching}
        onRetry={() => {
          void history.refetch();
        }}
      />
    );
  } else if (entries.length === 0) {
    content = (
      <EmptyState
        icon="history"
        title={t('reconciliation.history.empty')}
        description={t('reconciliation.history.emptyBody')}
      />
    );
  } else {
    content = (
      <>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <caption className="sr-only">{t('reconciliation.history.caption')}</caption>
            <thead>
              <tr className="border-b border-line text-fg-muted">
                <th scope="col" className="py-2 pe-4 text-start font-medium">
                  {t('reconciliation.history.date')}
                </th>
                <th scope="col" className="py-2 pe-4 text-end font-medium">
                  {t('reconciliation.result.statement')}
                </th>
                <th scope="col" className="py-2 pe-4 text-end font-medium">
                  {t('reconciliation.result.ledger')}
                </th>
                <th scope="col" className="py-2 pe-4 text-end font-medium">
                  {t('reconciliation.result.difference')}
                </th>
                <th scope="col" className="py-2 text-start font-medium">
                  {t('reconciliation.history.result')}
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {entries.map((entry) => {
                const balanced = entry.status === 'balanced';
                const checked = parseTimestamp(entry.created_at);
                return (
                  <tr key={entry.id} className="align-top">
                    <th scope="row" className="py-3 pe-4 text-start font-medium text-fg">
                      {formatLocalDate(entry.statement_date, formatLocale)}
                      {checked ? (
                        <span className="block text-xs font-normal text-fg-muted">
                          {t('reconciliation.history.checked', {
                            date: formatDateTime(checked, formatLocale),
                          })}
                        </span>
                      ) : null}
                    </th>
                    <td className="py-3 pe-4 text-end">
                      <MoneyText money={entry.statement_balance} />
                    </td>
                    <td className="py-3 pe-4 text-end">
                      <MoneyText money={entry.ledger_balance} />
                    </td>
                    <td className="py-3 pe-4 text-end">
                      <MoneyText money={entry.difference} signDisplay="exceptZero" />
                    </td>
                    <td className="space-y-1 py-3">
                      <StatusBadge
                        tone={balanced ? 'success' : 'warning'}
                        icon={balanced ? 'check-circle' : 'alert-triangle'}
                      >
                        {balanced
                          ? t('reconciliation.status.balanced')
                          : t('reconciliation.status.unbalanced')}
                      </StatusBadge>
                      <span className="block text-fg-muted">{countsText(entry, t)}</span>
                      {entry.import_batch_id ? (
                        <span className="block">
                          <TextLink to={importPath(entry.import_batch_id)}>
                            {t('reconciliation.history.import')}
                          </TextLink>
                        </span>
                      ) : null}
                      {entry.notes ? (
                        <span className="block break-words text-fg-muted">{entry.notes}</span>
                      ) : null}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <LoadMoreButton
          hasMore={history.hasNextPage}
          loading={history.isFetchingNextPage}
          failed={history.isFetchNextPageError}
          onLoadMore={() => {
            void history.fetchNextPage();
          }}
        />
      </>
    );
  }

  return (
    <Card
      title={t('reconciliation.history.title')}
      description={t('reconciliation.history.description')}
    >
      {content}
    </Card>
  );
}
