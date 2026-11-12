import { StatusBadge } from '@/shared/components/StatusBadge';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { reasonLabel, reportStatusLook, targetLabel } from '../labels';
import type { ModerationReport } from '../types';

/**
 * Reports you filed and where they stand. Nobody is told who reported
 * something; the reported content itself is not shown again here.
 */
export function MyReportsList({
  reports,
  timeZone,
}: {
  reports: readonly ModerationReport[];
  timeZone: string;
}) {
  const { t, formatLocale } = useI18n();
  const format = (iso: string | undefined) => {
    const date = parseTimestamp(iso);
    return date ? formatDateTime(date, formatLocale, timeZone) : null;
  };
  return (
    <ul className="divide-y divide-line">
      {reports.map((report) => {
        const look = reportStatusLook[report.status];
        const created = format(report.created_at);
        const resolved = format(report.resolved_at);
        return (
          <li key={report.id} className="space-y-2 py-4 first:pt-0 last:pb-0">
            <div className="flex flex-wrap items-start justify-between gap-2">
              <h3 className="font-medium text-fg">
                {t('moderation.reports.item', {
                  target: t(targetLabel(report.target_type)),
                  reason: t(reasonLabel(report.reason)),
                })}
              </h3>
              <StatusBadge tone={look.tone} icon={look.icon}>
                {t(look.key)}
              </StatusBadge>
            </div>
            {report.details ? (
              <p className="text-sm text-fg">
                <span className="font-medium">{t('moderation.reports.yourNote')}</span>{' '}
                <span className="whitespace-pre-line">{report.details}</span>
              </p>
            ) : null}
            <p className="text-sm text-fg-muted">
              {[
                created ? t('moderation.reports.filedOn', { date: created }) : null,
                resolved ? t('moderation.reports.resolvedOn', { date: resolved }) : null,
              ]
                .filter(Boolean)
                .join(' · ')}
            </p>
          </li>
        );
      })}
    </ul>
  );
}
