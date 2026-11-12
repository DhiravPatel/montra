import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { CopyButton } from '@/shared/components/CopyButton';
import { Icon } from '@/shared/components/Icon';
import { Select } from '@/shared/components/Select';
import { TextLink } from '@/shared/components/TextLink';
import { postPath } from '@/shared/config/paths';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useStaffReports } from '../../hooks';
import {
  QUEUE_STATUSES,
  isOpenReport,
  queueStatusLabel,
  reasonLabel,
  reportStatusLook,
  targetLabel,
} from '../../labels';
import type { ModerationReport, QueueStatus } from '../../types';
import type { ActionTarget } from './ActionDialog';

function isQueueStatus(value: string): value is QueueStatus {
  return QUEUE_STATUSES.some((status) => status === value);
}

function ReportItem({
  report,
  timeZone,
  onAct,
}: {
  report: ModerationReport;
  timeZone: string;
  onAct: (target: ActionTarget) => void;
}) {
  const { t, formatLocale } = useI18n();
  const look = reportStatusLook[report.status];
  const created = parseTimestamp(report.created_at);
  const resolved = parseTimestamp(report.resolved_at);
  const source = report.community_id
    ? t('moderation.staff.reports.fromCommunity')
    : t('moderation.staff.reports.toMontra');
  const actionable = isOpenReport(report.status);
  const targetType = report.target_type;
  // A comment report points at its post; a post report at the post itself.
  const postId =
    report.target_type === 'post'
      ? report.target_id
      : report.target_type === 'comment'
        ? (report.post_id ?? null)
        : null;
  return (
    <li className="space-y-3 py-4 first:pt-0 last:pb-0">
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
      {report.open_reports > 1 ? (
        <p className="text-sm text-fg">
          {t('moderation.staff.reports.openCount', { count: report.open_reports })}
        </p>
      ) : null}
      {report.preview ? (
        <figure className="space-y-1">
          <figcaption className="text-sm font-medium text-fg-muted">
            {t('moderation.staff.reports.preview')}
          </figcaption>
          <blockquote className="border-s-4 border-line ps-3 text-sm break-words whitespace-pre-line text-fg">
            {report.preview}
          </blockquote>
        </figure>
      ) : null}
      {report.details ? (
        <p className="text-sm text-fg">
          <span className="font-medium">{t('moderation.staff.reports.reporterNote')}</span>{' '}
          <span className="whitespace-pre-line">{report.details}</span>
        </p>
      ) : null}
      <p className="text-sm text-fg-muted">
        {[
          source,
          created
            ? t('moderation.reports.filedOn', {
                date: formatDateTime(created, formatLocale, timeZone),
              })
            : null,
          resolved
            ? t('moderation.reports.resolvedOn', {
                date: formatDateTime(resolved, formatLocale, timeZone),
              })
            : null,
        ]
          .filter(Boolean)
          .join(' · ')}
      </p>
      <div className="flex flex-wrap items-center gap-2 text-sm text-fg-muted">
        <span>{t('moderation.staff.reports.targetId')}</span>
        <code className="font-mono break-all text-fg">{report.target_id}</code>
        <CopyButton value={report.target_id} label={t('moderation.staff.copyId')} />
      </div>
      {report.target_user_id ? (
        <div className="flex flex-wrap items-center gap-2 text-sm text-fg-muted">
          <span>{t('moderation.staff.reports.personId')}</span>
          <code className="font-mono break-all text-fg">{report.target_user_id}</code>
          <CopyButton value={report.target_user_id} label={t('moderation.staff.copyId')} />
        </div>
      ) : null}
      {postId ? (
        <p className="text-sm">
          <TextLink to={postPath(postId)}>{t('moderation.staff.reports.openPost')}</TextLink>
        </p>
      ) : null}
      {actionable ? (
        <>
          {targetType === 'group' ? (
            <p className="text-sm text-fg-muted">
              {t('moderation.staff.reports.groupDismissOnly')}
            </p>
          ) : null}
          <Button
            size="sm"
            onClick={() => {
              onAct({ type: targetType, id: report.target_id, reportId: report.id });
            }}
          >
            <Icon name="shield" className="size-4" />
            {t('moderation.staff.reports.act')}
          </Button>
        </>
      ) : null}
    </li>
  );
}

/** The platform queue: profiles, groups, communities and escalations (GET /moderation/reports). */
export function ReportsQueue({
  status,
  onStatusChange,
  timeZone,
  onAct,
}: {
  status: QueueStatus;
  onStatusChange: (status: QueueStatus) => void;
  timeZone: string;
  onAct: (target: ActionTarget) => void;
}) {
  const { t } = useI18n();
  const reports = useStaffReports(status);

  let content;
  if (reports.isPending) {
    content = <LoadingState label={t('moderation.staff.reports.loading')} />;
  } else if (reports.isError) {
    content = (
      <ErrorState
        title={t('moderation.staff.reports.error')}
        error={reports.error}
        retrying={reports.isFetching}
        onRetry={() => {
          void reports.refetch();
        }}
      />
    );
  } else if (reports.data.length === 0) {
    content = (
      <EmptyState
        icon="inbox"
        title={t('moderation.staff.reports.empty.title')}
        description={t('moderation.staff.reports.empty.body')}
      />
    );
  } else {
    content = (
      <ul className="divide-y divide-line">
        {reports.data.map((report) => (
          <ReportItem key={report.id} report={report} timeZone={timeZone} onAct={onAct} />
        ))}
      </ul>
    );
  }

  return (
    <Card
      title={t('moderation.staff.reports.title')}
      description={t('moderation.staff.reports.description')}
    >
      <div className="mb-5 sm:max-w-xs">
        <Select
          label={t('moderation.staff.reports.filter')}
          value={status}
          options={QUEUE_STATUSES.map((value) => ({ value, label: t(queueStatusLabel[value]) }))}
          onChange={(event) => {
            if (isQueueStatus(event.target.value)) onStatusChange(event.target.value);
          }}
        />
      </div>
      {content}
    </Card>
  );
}
