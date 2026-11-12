import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Card } from '@/shared/components/Card';
import { Disclosure } from '@/shared/components/Disclosure';
import { Fact, Facts } from '@/shared/components/Facts';
import { TextLink } from '@/shared/components/TextLink';
import { paths, withQuery } from '@/shared/config/paths';
import { formatDateTime, formatLocalDate, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { AnalyticsFilters } from '../filters';
import { transactionsLink, UNCATEGORIZED_TYPES } from '../links';
import type { AnalyticsWindow, Coverage } from '../types';
import { WindowText } from './Blocks';

/**
 * How complete the figures are (spec §4.11 "data coverage"): what was
 * counted, what is missing a category or still pending, and the rules used.
 */
export function CoverageCard({
  coverage,
  window,
  filters,
}: {
  coverage: Coverage;
  window: AnalyticsWindow;
  filters: AnalyticsFilters;
}) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const imported = parseTimestamp(coverage.last_import_at);
  return (
    <Card title={t('analytics.coverage.title')} description={<WindowText window={window} />}>
      <Facts>
        <Fact label={t('analytics.coverage.count')}>
          <span className="tabular-nums">{coverage.transaction_count}</span>
        </Fact>
        {coverage.earliest_transaction && coverage.latest_transaction ? (
          <Fact label={t('analytics.coverage.range')}>
            {t('analytics.coverage.rangeValue', {
              from: formatLocalDate(coverage.earliest_transaction, formatLocale),
              to: formatLocalDate(coverage.latest_transaction, formatLocale),
            })}
          </Fact>
        ) : null}
        <Fact label={t('analytics.coverage.uncategorized')}>
          {coverage.uncategorized_count > 0 ? (
            <TextLink
              to={transactionsLink(window, filters, {
                uncategorized: 'true',
                type: UNCATEGORIZED_TYPES,
              })}
            >
              {t('analytics.coverage.uncategorizedLink', { count: coverage.uncategorized_count })}
            </TextLink>
          ) : (
            <span className="tabular-nums">0</span>
          )}
        </Fact>
        <Fact label={t('analytics.coverage.pending')}>
          <span className="block">
            {coverage.pending_count > 0 ? (
              <TextLink to={withQuery(paths.transactions, { status: 'pending' })}>
                {t('analytics.coverage.pendingLink', { count: coverage.pending_count })}
              </TextLink>
            ) : (
              <span className="tabular-nums">0</span>
            )}
          </span>
          <span className="mt-1 block text-sm text-fg-muted">
            {filters.includePending
              ? t('analytics.coverage.pendingIncluded')
              : t('analytics.coverage.pendingExcluded')}
          </span>
        </Fact>
        <Fact label={t('analytics.coverage.lastImport')}>
          {imported ? (
            <time dateTime={coverage.last_import_at}>
              {formatDateTime(imported, formatLocale, user.timezone)}
            </time>
          ) : (
            t('analytics.coverage.noImports')
          )}
        </Fact>
        <Fact label={t('analytics.coverage.verification')}>
          {coverage.provider_synced ? t('analytics.coverage.synced') : t('finance.tracked')}
        </Fact>
      </Facts>
      <Disclosure summary={t('analytics.rules.show')} className="mt-4">
        <ul className="list-disc space-y-1 ps-5 text-sm text-fg">
          <li>{t('analytics.rules.transfers')}</li>
          <li>{t('analytics.rules.refunds')}</li>
          <li>{t('analytics.rules.currencies')}</li>
          <li>
            {filters.includePending ? t('analytics.rules.pending') : t('analytics.rules.posted')}
          </li>
          <li>{t('analytics.rules.timezone', { zone: window.timezone })}</li>
        </ul>
      </Disclosure>
    </Card>
  );
}
