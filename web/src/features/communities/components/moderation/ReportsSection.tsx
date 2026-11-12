import { useState } from 'react';
import { Link } from 'react-router';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { postPath } from '@/shared/config/paths';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useModerationReports } from '../../api';
import {
  REPORT_FILTERS,
  reportFilterLabel,
  reportReasonName,
  reportStatusIcon,
  reportStatusLabel,
  reportStatusTone,
  targetName,
} from '../../labels';
import { excerpt } from '../../text/userText';
import type { Community, Report, ReportFilter } from '../../types';
import { UserTextExcerpt } from '../UserText';
import { type ActionTarget, ActionDialog } from './ActionDialog';
import { useMemberNames } from './useMemberNames';

/** Reports in these states can still be resolved by an action. */
const ACTIONABLE: ReadonlySet<string> = new Set(['open', 'under_review', 'escalated']);

/** The post a report is about: the post itself, or the post a reported comment is on. */
function reportedPostId(report: Report): string | null {
  if (report.target_type === 'post') return report.target_id;
  if (report.target_type === 'comment') return report.post_id ?? null;
  return null;
}

/**
 * The community's report queue. Each report shows what was reported (an
 * excerpt, as plain text), by whom it was written, why, and how many open
 * reports point at the same content; moderators resolve it with an
 * audited action.
 */
export function ReportsSection({ community }: { community: Community }) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const nameOf = useMemberNames(community.id);
  const [status, setStatus] = useState<ReportFilter>('open');
  const reports = useModerationReports(community.id, status);
  const [acting, setActing] = useState<ActionTarget | null>(null);

  const actOn = (report: Report) => {
    if (report.target_type !== 'post' && report.target_type !== 'comment') return;
    const preview = report.preview ? excerpt(report.preview.replace(/\s+/gu, ' '), 140) : '';
    const postId = reportedPostId(report);
    setActing({
      type: report.target_type,
      id: report.target_id,
      reportId: report.id,
      ...(postId ? { postId } : {}),
      summary: preview
        ? t('communities.mod.reports.summary', {
            target: targetName(report.target_type, t),
            text: preview,
          })
        : targetName(report.target_type, t),
    });
  };

  let content;
  if (reports.isPending) {
    content = <LoadingState label={t('communities.mod.reports.loading')} />;
  } else if (reports.isError) {
    content = (
      <ErrorState
        titleAs="p"
        title={t('communities.mod.reports.error')}
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
        titleAs="p"
        icon="check-circle"
        title={
          status === 'open'
            ? t('communities.mod.reports.emptyOpen')
            : t('communities.mod.reports.empty')
        }
      />
    );
  } else {
    content = (
      <ul className="divide-y divide-line" aria-busy={reports.isFetching || undefined}>
        {reports.data.map((report) => {
          const created = parseTimestamp(report.created_at);
          const kind = targetName(report.target_type, t);
          const reason = reportReasonName(report.reason, t);
          const isContent = report.target_type === 'post' || report.target_type === 'comment';
          const postId = reportedPostId(report);
          return (
            <li key={report.id} className="space-y-3 py-4 first:pt-0 last:pb-0">
              <div className="flex flex-wrap items-center gap-2">
                <StatusBadge
                  tone={reportStatusTone[report.status]}
                  icon={reportStatusIcon[report.status]}
                >
                  {t(reportStatusLabel[report.status])}
                </StatusBadge>
                <span className="font-medium text-fg">
                  {t('communities.mod.reports.heading', { target: kind, reason })}
                </span>
              </div>
              {report.preview ? (
                <blockquote className="border-s-4 border-line ps-3">
                  <UserTextExcerpt text={report.preview} className="text-sm" />
                </blockquote>
              ) : (
                <p className="text-sm text-fg-muted">{t('communities.mod.reports.noPreview')}</p>
              )}
              {report.details ? (
                <div className="text-sm">
                  <p className="font-medium text-fg-muted">{t('communities.mod.reports.note')}</p>
                  <UserTextExcerpt text={report.details} maxChars={1000} />
                </div>
              ) : null}
              {report.target_user_id ? (
                <p className="text-sm text-fg">
                  {t('communities.mod.reports.author', { name: nameOf(report.target_user_id) })}
                </p>
              ) : null}
              <p className="text-sm text-fg-muted">
                {[
                  created
                    ? t('communities.mod.reports.created', {
                        date: formatDateTime(created, formatLocale, user.timezone),
                      })
                    : null,
                  report.open_reports > 1
                    ? t('communities.mod.reports.openCount', { count: report.open_reports })
                    : null,
                ]
                  .filter(Boolean)
                  .join(' · ')}
              </p>
              <div className="flex flex-wrap gap-2">
                {postId ? (
                  <Link
                    to={postPath(postId)}
                    className="inline-flex min-h-9 items-center gap-1.5 rounded-md border border-line-strong bg-surface px-3 text-sm font-medium text-fg hover:bg-surface-muted"
                  >
                    <Icon name="eye" className="size-4" />
                    {t('communities.mod.reports.openPost')}
                  </Link>
                ) : null}
                {isContent && ACTIONABLE.has(report.status) ? (
                  <Button
                    size="sm"
                    aria-label={t('communities.mod.reports.actNamed', { target: kind, reason })}
                    onClick={() => {
                      actOn(report);
                    }}
                  >
                    <Icon name="shield" className="size-4" />
                    {t('communities.mod.reports.act')}
                  </Button>
                ) : null}
              </div>
            </li>
          );
        })}
      </ul>
    );
  }

  return (
    <Card
      title={t('communities.mod.reports.title')}
      description={t('communities.mod.reports.description')}
    >
      <div className="space-y-5">
        <RadioGroup<ReportFilter>
          legend={t('communities.mod.reports.show')}
          value={status}
          onChange={setStatus}
          options={REPORT_FILTERS.map((value) => ({ value, label: t(reportFilterLabel[value]) }))}
        />
        {content}
      </div>
      <ActionDialog
        communityId={community.id}
        target={acting}
        open={acting !== null}
        onOpenChange={(open) => {
          if (!open) setActing(null);
        }}
      />
    </Card>
  );
}
