import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { CopyButton } from '@/shared/components/CopyButton';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useStaffAppeals } from '../../hooks';
import { staffActionLabel, targetLabel } from '../../labels';
import type { ModerationAppeal } from '../../types';

/** Every open appeal (GET /moderation/appeals), oldest first as the API sends them. */
export function AppealsQueue({
  timeZone,
  onDecide,
}: {
  timeZone: string;
  onDecide: (appeal: ModerationAppeal) => void;
}) {
  const { t, formatLocale } = useI18n();
  const appeals = useStaffAppeals();

  let content;
  if (appeals.isPending) {
    content = <LoadingState label={t('moderation.staff.appeals.loading')} />;
  } else if (appeals.isError) {
    content = (
      <ErrorState
        title={t('moderation.staff.appeals.error')}
        error={appeals.error}
        retrying={appeals.isFetching}
        onRetry={() => {
          void appeals.refetch();
        }}
      />
    );
  } else if (appeals.data.length === 0) {
    content = (
      <EmptyState
        icon="check-circle"
        title={t('moderation.staff.appeals.empty.title')}
        description={t('moderation.staff.appeals.empty.body')}
      />
    );
  } else {
    content = (
      <ul className="divide-y divide-line">
        {appeals.data.map((appeal) => {
          const created = parseTimestamp(appeal.created_at);
          return (
            <li key={appeal.id} className="space-y-3 py-4 first:pt-0 last:pb-0">
              <div className="space-y-1">
                <h3 className="font-medium text-fg">
                  {appeal.community_id
                    ? t('moderation.staff.appeals.community')
                    : t('moderation.staff.appeals.platform')}
                </h3>
                {created ? (
                  <p className="text-sm text-fg-muted">
                    {t('moderation.staff.appeals.sentOn', {
                      date: formatDateTime(created, formatLocale, timeZone),
                    })}
                  </p>
                ) : null}
              </div>
              <div className="space-y-1 text-sm">
                <p className="text-fg">
                  {t('moderation.staff.appeals.against', {
                    action: t(staffActionLabel(appeal.action.action, appeal.action.target_type)),
                    target: t(targetLabel(appeal.action.target_type)),
                  })}
                </p>
                {appeal.action.reason ? (
                  <p className="text-fg">
                    <span className="font-medium">{t('moderation.staff.act.reason')}:</span>{' '}
                    <span className="break-words whitespace-pre-line">{appeal.action.reason}</span>
                  </p>
                ) : null}
                {appeal.action.reversed_at ? (
                  <p className="text-fg-muted">{t('moderation.staff.appeals.alreadyReversed')}</p>
                ) : null}
              </div>
              <blockquote className="border-s-4 border-line ps-3 text-sm break-words whitespace-pre-line text-fg">
                {appeal.statement}
              </blockquote>
              <div className="flex flex-wrap items-center gap-2 text-sm text-fg-muted">
                <span>{t('moderation.staff.appeals.actionId')}</span>
                <code className="font-mono break-all text-fg">{appeal.action_id}</code>
                <CopyButton value={appeal.action_id} label={t('moderation.staff.copyId')} />
              </div>
              <Button
                size="sm"
                onClick={() => {
                  onDecide(appeal);
                }}
              >
                {t('moderation.staff.appeals.decide')}
              </Button>
            </li>
          );
        })}
      </ul>
    );
  }

  return (
    <Card
      title={t('moderation.staff.appeals.title')}
      description={t('moderation.staff.appeals.description')}
    >
      {content}
    </Card>
  );
}
