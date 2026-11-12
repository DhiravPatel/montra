import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { isDateRangePreset, rangeLabel } from '@/shared/finance/labels';
import {
  formatDateTime,
  formatLocalDate,
  formatLocalDateRange,
  formatRelativeTime,
  parseTimestamp,
  todayInTimeZone,
} from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import {
  failureMessage,
  formatLabel,
  isReportType,
  PERIOD_TYPES,
  reportTypeLabel,
  statusDisplay,
} from '../labels';
import { displayStatus, isStalled } from '../polling';
import type { Report } from '../types';

/**
 * The period a report covers: the dates the API resolved when it was
 * requested (`window`), named after the period that was asked for. Reports
 * from before windows were stored fall back to the filter snapshot, dated
 * by the day they were requested in the report's time zone.
 */
function periodText(report: Report, t: Translate, locale: string): string {
  if (isReportType(report.report_type) && !PERIOD_TYPES.has(report.report_type)) {
    return t('reports.period.current');
  }
  const { range, from, to } = report.filters;
  const named = range && isDateRangePreset(range) ? t(rangeLabel[range]) : null;
  if (report.window) {
    const dates = formatLocalDateRange(report.window.from, report.window.to, locale);
    return named ? t('reports.period.named', { period: named, dates }) : dates;
  }
  if (from && to) return formatLocalDateRange(from, to, locale);
  const label = named ?? t('reports.period.default');
  const requested = parseTimestamp(report.requested_at);
  if (!requested) return label;
  return t('reports.period.asOf', {
    period: label,
    date: formatLocalDate(todayInTimeZone(report.timezone, requested), locale),
  });
}

/** The filters a report was made with, in words (IDs are only counted). */
function filterText(report: Report, t: Translate): string[] {
  const filters = report.filters;
  const parts: string[] = [];
  if (filters.currency) parts.push(t('reports.filter.currency', { currency: filters.currency }));
  if (filters.account_ids?.length) {
    parts.push(t('reports.filter.accounts', { count: filters.account_ids.length }));
  }
  if (filters.category_ids?.length) {
    parts.push(t('reports.filter.categories', { count: filters.category_ids.length }));
  }
  if (filters.include_pending) parts.push(t('reports.filter.pending'));
  if (filters.display_currency) {
    parts.push(t('reports.filter.converted', { currency: filters.display_currency }));
  }
  return parts;
}

interface ReportItemProps {
  report: Report;
  /** The API's clock when the list was loaded. */
  serverTime: string;
  /** The device clock, for "requested 5 minutes ago" (refreshed by the list). */
  now: number;
  downloading: boolean;
  repeating: boolean;
  onDownload: (report: Report) => void;
  onRepeat: (report: Report) => void;
  onDelete: (report: Report) => void;
}

/** One requested report: what it covers, its state, and what can be done with it. */
export function ReportItem({
  report,
  serverTime,
  now,
  downloading,
  repeating,
  onDownload,
  onRepeat,
  onDelete,
}: ReportItemProps) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  // A completed report past its download window is shown as expired.
  const state = displayStatus(report, serverTime);
  const status = statusDisplay[state];
  const stalled = isStalled(report, serverTime);
  const requested = parseTimestamp(report.requested_at);
  const expires = parseTimestamp(report.expires_at);
  const typeLabel = isReportType(report.report_type)
    ? t(reportTypeLabel[report.report_type])
    : report.report_type;
  const filters = filterText(report, t);
  const canRepeat =
    isReportType(report.report_type) && (state === 'failed' || state === 'expired' || stalled);

  return (
    <li className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-start">
      <div className="min-w-0 flex-1 space-y-1">
        <div className="flex flex-wrap items-center gap-2">
          <p className="font-medium break-words text-fg">{report.title}</p>
          <StatusBadge tone={status.tone} icon={status.icon}>
            {t(status.label)}
          </StatusBadge>
        </div>
        <p className="text-sm text-fg-muted">
          {[typeLabel, t(formatLabel[report.format]), periodText(report, t, formatLocale)].join(
            ' · ',
          )}
        </p>
        {filters.length > 0 ? <p className="text-sm text-fg-muted">{filters.join(' · ')}</p> : null}
        <p className="text-sm text-fg-muted">
          {requested ? (
            <time dateTime={report.requested_at}>
              {t('reports.item.requested', {
                when: formatRelativeTime(requested, formatLocale, now),
              })}
            </time>
          ) : null}
          {state === 'completed' && report.row_count !== undefined
            ? ` · ${t('reports.item.rows', { count: report.row_count })}`
            : null}
          {state === 'completed' && expires
            ? ` · ${t('reports.item.availableUntil', {
                date: formatDateTime(expires, formatLocale, user.timezone),
              })}`
            : null}
          {state === 'expired' && expires
            ? ` · ${t('reports.item.expiredOn', {
                date: formatDateTime(expires, formatLocale, user.timezone),
              })}`
            : null}
        </p>
        {state === 'failed' ? (
          <p className="text-sm text-fg">{t(failureMessage(report.error_code))}</p>
        ) : null}
        {stalled ? <p className="text-sm text-fg">{t('reports.item.stalled')}</p> : null}
      </div>
      <div className="flex shrink-0 flex-wrap gap-2">
        {state === 'completed' ? (
          <Button
            size="sm"
            loading={downloading}
            aria-label={t('reports.item.downloadLabel', { title: report.title })}
            onClick={() => {
              onDownload(report);
            }}
          >
            <Icon name="download" className="size-4" />
            {t('reports.item.download')}
          </Button>
        ) : null}
        {canRepeat ? (
          <Button
            variant="secondary"
            size="sm"
            loading={repeating}
            aria-label={t('reports.item.repeatLabel', { title: report.title })}
            onClick={() => {
              onRepeat(report);
            }}
          >
            <Icon name="rotate-ccw" className="size-4" />
            {t('reports.item.repeat')}
          </Button>
        ) : null}
        <Button
          variant="ghost"
          size="sm"
          aria-label={t('reports.item.deleteLabel', { title: report.title })}
          onClick={() => {
            onDelete(report);
          }}
        >
          <Icon name="trash" className="size-4" />
          {t('common.delete')}
        </Button>
      </div>
    </li>
  );
}
