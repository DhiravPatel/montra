import { useState } from 'react';
import { Button } from '@/shared/components/Button';
import { Icon, type IconName } from '@/shared/components/Icon';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextLink } from '@/shared/components/TextLink';
import { communityPath, postPath } from '@/shared/config/paths';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { affectedTitle } from '../labels';
import { appealWindow, isInForce } from '../standing';
import type { AppealState as Appeal, ModerationAction } from '../types';
import { AppealDialog } from './AppealDialog';

const actionIcons: Readonly<Record<string, IconName>> = {
  hide: 'eye-off',
  remove: 'trash',
  warn: 'alert-triangle',
  restrict: 'clock',
  ban: 'ban',
  unban: 'check-circle',
};

function ActionStatus({
  action,
  now,
  format,
}: {
  action: ModerationAction;
  now: number;
  format: (iso: string | undefined) => string | null;
}) {
  const { t } = useI18n();
  const reversed = format(action.reversed_at);
  if (reversed) {
    return (
      <StatusBadge tone="success" icon="undo">
        {t('moderation.mine.status.reversed', { date: reversed })}
      </StatusBadge>
    );
  }
  if (action.action === 'unban') {
    return (
      <StatusBadge tone="success" icon="check-circle">
        {t('moderation.mine.status.lifted')}
      </StatusBadge>
    );
  }
  const expires = format(action.expires_at);
  if (expires) {
    return isInForce(action, now) ? (
      <StatusBadge tone="warning" icon="clock">
        {t('moderation.mine.status.until', { date: expires })}
      </StatusBadge>
    ) : (
      <StatusBadge tone="neutral" icon="check">
        {t('moderation.mine.status.ended', { date: expires })}
      </StatusBadge>
    );
  }
  if (action.action === 'ban' || action.action === 'restrict') {
    return (
      <StatusBadge tone="warning" icon="clock">
        {t('moderation.mine.status.noEnd')}
      </StatusBadge>
    );
  }
  return (
    <StatusBadge tone="info" icon="info">
      {t('moderation.mine.status.inEffect')}
    </StatusBadge>
  );
}

const appealLook = {
  open: { tone: 'info', icon: 'clock', key: 'moderation.appeal.status.open' },
  upheld: { tone: 'neutral', icon: 'check', key: 'moderation.appeal.status.upheld' },
  overturned: { tone: 'success', icon: 'undo', key: 'moderation.appeal.status.overturned' },
} as const;

/** Where your appeal stands and, once decided, the outcome and the reviewer's note. */
export function AppealStatus({
  appeal,
  format,
}: {
  appeal: Pick<Appeal, 'status' | 'created_at' | 'decided_at' | 'decision_note'>;
  format: (iso: string | undefined) => string | null;
}) {
  const { t } = useI18n();
  const look = appealLook[appeal.status];
  const sent = format(appeal.created_at);
  const decided = format(appeal.decided_at);
  return (
    <div className="space-y-1">
      <StatusBadge tone={look.tone} icon={look.icon}>
        {t(look.key)}
      </StatusBadge>
      <p className="text-sm text-fg-muted">
        {sent ? t('moderation.appeal.sentOn', { date: sent }) : t('moderation.appeal.pending')}
      </p>
      {decided ? (
        <p className="text-sm text-fg-muted">
          {appeal.status === 'overturned'
            ? t('moderation.appeal.overturnedOn', { date: decided })
            : t('moderation.appeal.upheldOn', { date: decided })}
        </p>
      ) : null}
      {appeal.decision_note ? (
        <p className="text-sm text-fg">
          {t('moderation.appeal.note')}{' '}
          <span className="break-words whitespace-pre-line">{appeal.decision_note}</span>
        </p>
      ) : null}
    </div>
  );
}

function ActionItem({
  action,
  now,
  timeZone,
}: {
  action: ModerationAction;
  now: number;
  timeZone: string;
}) {
  const { t, formatLocale } = useI18n();
  const [appealOpen, setAppealOpen] = useState(false);
  const format = (iso: string | undefined) => {
    const date = parseTimestamp(iso);
    return date ? formatDateTime(date, formatLocale, timeZone) : null;
  };
  const created = format(action.created_at);
  const review = appealWindow(action, now);
  const where = action.community_id
    ? t('moderation.mine.inCommunity')
    : t('moderation.mine.byMontra');
  const deadline =
    review.state === 'none' ? null : formatDateTime(review.deadline, formatLocale, timeZone);

  return (
    <li className="flex items-start gap-3 py-4 first:pt-0 last:pb-0">
      <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
        <Icon name={actionIcons[action.action] ?? 'shield'} />
      </span>
      <div className="min-w-0 flex-1 space-y-2">
        <div className="space-y-1">
          <h3 className="font-medium text-fg">{t(affectedTitle(action))}</h3>
          <p className="text-sm text-fg-muted">{created ? `${where} · ${created}` : where}</p>
        </div>
        {action.reason ? (
          <p className="text-sm text-fg">
            <span className="font-medium">{t('moderation.mine.reason')}</span>{' '}
            <span className="whitespace-pre-line">{action.reason}</span>
          </p>
        ) : null}
        <div className="flex flex-wrap gap-2">
          <ActionStatus action={action} now={now} format={format} />
        </div>
        <div className="flex flex-wrap gap-x-4 gap-y-1 text-sm">
          {action.target_type === 'post' &&
          (action.action === 'hide' || action.action === 'remove') ? (
            <TextLink to={postPath(action.target_id)}>{t('moderation.mine.viewPost')}</TextLink>
          ) : null}
          {action.community_id ? (
            <TextLink to={communityPath(action.community_id)}>
              {t('moderation.mine.openCommunity')}
            </TextLink>
          ) : null}
        </div>
        {action.appeal ? (
          <AppealStatus appeal={action.appeal} format={format} />
        ) : review.state === 'open' ? (
          <div className="space-y-2">
            <p className="text-sm text-fg-muted">
              {t('moderation.appeal.until', { date: deadline ?? '' })}
            </p>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => {
                setAppealOpen(true);
              }}
            >
              <Icon name="message-square" className="size-4" />
              {t('moderation.appeal.action')}
            </Button>
            <AppealDialog
              action={action}
              deadline={review.deadline}
              timeZone={timeZone}
              open={appealOpen}
              onOpenChange={setAppealOpen}
            />
          </div>
        ) : review.state === 'closed' ? (
          <p className="text-sm text-fg-muted">
            {t('moderation.appeal.closed', { date: deadline ?? '' })}
          </p>
        ) : null}
      </div>
    </li>
  );
}

/** Decisions that affected your posts, comments or account, newest first. */
export function MyActionsList({
  actions,
  now,
  timeZone,
}: {
  actions: readonly ModerationAction[];
  now: number;
  timeZone: string;
}) {
  return (
    <ul className="divide-y divide-line">
      {actions.map((action) => (
        <ActionItem key={action.id} action={action} now={now} timeZone={timeZone} />
      ))}
    </ul>
  );
}
