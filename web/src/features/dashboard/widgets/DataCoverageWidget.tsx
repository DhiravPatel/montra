import { Fact, Facts } from '@/shared/components/Facts';
import { TextLink } from '@/shared/components/TextLink';
import { formatDateTime, formatLocalDate, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { WidgetCard } from '../components/WidgetCard';
import type { WidgetProps } from './types';

/** How complete the figures are: counts, dates, pending and uncategorized entries, freshness. */
export function DataCoverageWidget({ summary, title, drill }: WidgetProps) {
  const { t, formatLocale } = useI18n();
  const coverage = summary.coverage;
  const imported = parseTimestamp(coverage.last_import_at);
  return (
    <WidgetCard title={title} window={summary.window} generatedAt={summary.generated_at}>
      <Facts>
        <Fact label={t('dashboard.coverage.count')}>
          <span className="tabular-nums">{coverage.transaction_count}</span>
        </Fact>
        {coverage.earliest_transaction && coverage.latest_transaction ? (
          <Fact label={t('dashboard.coverage.range')}>
            {t('dashboard.coverage.rangeValue', {
              from: formatLocalDate(coverage.earliest_transaction, formatLocale),
              to: formatLocalDate(coverage.latest_transaction, formatLocale),
            })}
          </Fact>
        ) : null}
        <Fact label={t('dashboard.coverage.uncategorized')}>
          {coverage.uncategorized_count > 0 ? (
            <TextLink to={drill({ uncategorized: 'true' })}>
              {t('dashboard.coverage.uncategorizedLink', { count: coverage.uncategorized_count })}
            </TextLink>
          ) : (
            <span className="tabular-nums">0</span>
          )}
        </Fact>
        <Fact label={t('dashboard.coverage.pending')}>
          {coverage.pending_count > 0 ? (
            <TextLink to={drill({ status: 'pending' })}>
              {t('dashboard.coverage.pendingLink', { count: coverage.pending_count })}
            </TextLink>
          ) : (
            <span className="tabular-nums">0</span>
          )}
        </Fact>
        <Fact label={t('dashboard.coverage.lastImport')}>
          {imported ? (
            <time dateTime={coverage.last_import_at}>{formatDateTime(imported, formatLocale)}</time>
          ) : (
            t('dashboard.coverage.noImports')
          )}
        </Fact>
        <Fact label={t('dashboard.coverage.verification')}>
          {coverage.provider_synced ? t('dashboard.balances.synced') : t('finance.tracked')}
        </Fact>
      </Facts>
    </WidgetCard>
  );
}
