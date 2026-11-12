import { type SubmitEvent, useState } from 'react';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { CopyButton } from '@/shared/components/CopyButton';
import { Disclosure } from '@/shared/components/Disclosure';
import { Icon } from '@/shared/components/Icon';
import { Select } from '@/shared/components/Select';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useNow } from '@/shared/hooks/useNow';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { useStaffActions } from '../../hooks';
import { ACTION_KINDS, staffActionLabel, targetLabel } from '../../labels';
import { isInForce } from '../../standing';
import type { ModerationAction, PlatformActionFilters } from '../../types';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const EMPTY_FILTERS: PlatformActionFilters = {
  status: '',
  action: '',
  targetType: '',
  targetId: '',
  targetUserId: '',
};

const STATUSES: readonly { value: PlatformActionFilters['status']; key: MessageKey }[] = [
  { value: '', key: 'moderation.staff.actions.filter.anyStatus' },
  { value: 'active', key: 'moderation.staff.actions.status.active' },
  { value: 'reversed', key: 'moderation.staff.actions.status.reversed' },
  { value: 'expired', key: 'moderation.staff.actions.status.expired' },
];

const TARGET_TYPES: readonly PlatformActionFilters['targetType'][] = [
  'post',
  'comment',
  'profile',
  'group',
  'community',
];

const appealStatusKey: Readonly<Record<string, MessageKey>> = {
  open: 'moderation.appeal.status.open',
  upheld: 'moderation.appeal.status.upheld',
  overturned: 'moderation.appeal.status.overturned',
};

const REVERSIBLE: readonly string[] = ['hide', 'remove', 'lock', 'warn', 'restrict', 'ban'];

function isStatus(value: string): value is PlatformActionFilters['status'] {
  return STATUSES.some((status) => status.value === value);
}

function isAction(value: string): value is PlatformActionFilters['action'] {
  return value === '' || ACTION_KINDS.some((kind) => kind === value);
}

function isTargetType(value: string): value is PlatformActionFilters['targetType'] {
  return value === '' || TARGET_TYPES.some((type) => type === value);
}

function ActionItem({
  action,
  timeZone,
  onReverse,
}: {
  action: ModerationAction;
  timeZone: string;
  onReverse: (actionId: string) => void;
}) {
  const { t, formatLocale } = useI18n();
  const format = (iso: string | undefined) => {
    const date = parseTimestamp(iso);
    return date ? formatDateTime(date, formatLocale, timeZone) : null;
  };
  const created = format(action.created_at);
  const expires = format(action.expires_at);
  const reversed = format(action.reversed_at);
  const now = useNow();
  const active = isInForce(action, now);
  return (
    <li className="space-y-2 py-4 first:pt-0 last:pb-0">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <h3 className="font-medium text-fg">
          {t('moderation.staff.visit.item', {
            action: t(staffActionLabel(action.action, action.target_type)),
            target: t(targetLabel(action.target_type)),
          })}
        </h3>
        {reversed ? (
          <StatusBadge tone="neutral" icon="undo">
            {t('moderation.staff.visit.reversed', { date: reversed })}
          </StatusBadge>
        ) : active ? (
          <StatusBadge tone="info" icon="check">
            {t('moderation.staff.actions.status.active')}
          </StatusBadge>
        ) : (
          <StatusBadge tone="neutral" icon="clock">
            {t('moderation.staff.actions.status.expired')}
          </StatusBadge>
        )}
      </div>
      <p className="text-sm text-fg-muted">
        {[
          created ? t('moderation.staff.visit.on', { date: created }) : null,
          expires && !reversed ? t('moderation.staff.visit.until', { date: expires }) : null,
        ]
          .filter(Boolean)
          .join(' · ')}
      </p>
      {action.reason ? (
        <p className="text-sm text-fg">
          <span className="font-medium">{t('moderation.staff.act.reason')}:</span>{' '}
          <span className="break-words whitespace-pre-line">{action.reason}</span>
        </p>
      ) : null}
      {action.appeal ? (
        <p className="text-sm text-fg">
          {t('moderation.staff.actions.appeal', {
            status: t(appealStatusKey[action.appeal.status] ?? 'moderation.appeal.status.open'),
          })}
        </p>
      ) : null}
      <div className="flex flex-wrap items-center gap-2 text-sm text-fg-muted">
        <span>{t('moderation.staff.reports.targetId')}</span>
        <code className="font-mono break-all text-fg">{action.target_id}</code>
        <CopyButton value={action.target_id} label={t('moderation.staff.copyId')} />
      </div>
      <div className="flex flex-wrap items-center gap-2 text-sm text-fg-muted">
        <span>{t('moderation.staff.appeals.actionId')}</span>
        <code className="font-mono break-all text-fg">{action.id}</code>
      </div>
      {!reversed && REVERSIBLE.includes(action.action) ? (
        <Button
          variant="secondary"
          size="sm"
          aria-label={t('moderation.staff.actions.reverseNamed', {
            action: t(staffActionLabel(action.action, action.target_type)),
            target: t(targetLabel(action.target_type)),
          })}
          onClick={() => {
            onReverse(action.id);
          }}
        >
          <Icon name="undo" className="size-4" />
          {t('moderation.staff.reverse.action')}
        </Button>
      ) : null}
    </li>
  );
}

/**
 * Platform actions (GET /moderation/actions: account sanctions, community
 * suspensions and report dismissals), newest first, with filters, "Load
 * more" and Reverse; plus reversing any action by its ID (appeals and the
 * audit log show action IDs).
 */
export function ActionsListCard({
  timeZone,
  onReverse,
}: {
  timeZone: string;
  onReverse: (actionId: string) => void;
}) {
  const { t } = useI18n();
  const announce = useAnnounce();
  const [draft, setDraft] = useState<PlatformActionFilters>(EMPTY_FILTERS);
  const [filters, setFilters] = useState<PlatformActionFilters>(EMPTY_FILTERS);
  const [filterError, setFilterError] = useState<{ targetId?: string; targetUserId?: string }>({});
  const actions = useStaffActions(filters);
  const [actionId, setActionId] = useState('');
  const [idError, setIdError] = useState<string | null>(null);

  const applyFilters = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    const errors: typeof filterError = {};
    if (draft.targetId.trim() && !UUID.test(draft.targetId.trim())) {
      errors.targetId = t('moderation.staff.act.targetIdInvalid');
    }
    if (draft.targetUserId.trim() && !UUID.test(draft.targetUserId.trim())) {
      errors.targetUserId = t('moderation.staff.act.targetIdInvalid');
    }
    setFilterError(errors);
    if (Object.keys(errors).length > 0) return;
    setFilters({
      ...draft,
      targetId: draft.targetId.trim(),
      targetUserId: draft.targetUserId.trim(),
    });
  };

  const reverseById = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    const id = actionId.trim();
    if (!UUID.test(id)) {
      setIdError(t('moderation.staff.visit.idInvalid'));
      return;
    }
    setIdError(null);
    onReverse(id);
  };

  let content;
  if (actions.isPending) {
    content = <LoadingState label={t('moderation.staff.actions.loading')} />;
  } else if (actions.isLoadingError) {
    content = (
      <ErrorState
        title={t('moderation.staff.actions.error')}
        error={actions.error}
        retrying={actions.isFetching}
        onRetry={() => {
          void actions.refetch();
        }}
      />
    );
  } else {
    const items = actions.data.pages.flatMap((page) => page.items);
    content =
      items.length === 0 ? (
        <EmptyState icon="history" title={t('moderation.staff.actions.empty')} />
      ) : (
        <>
          <ul className="divide-y divide-line" aria-busy={actions.isFetching || undefined}>
            {items.map((action) => (
              <ActionItem
                key={action.id}
                action={action}
                timeZone={timeZone}
                onReverse={onReverse}
              />
            ))}
          </ul>
          {actions.isFetchNextPageError ? (
            <p role="alert" className="mt-4 flex items-start gap-1.5 text-sm text-danger">
              <Icon name="alert-circle" className="mt-0.5 size-4 shrink-0" />
              {t('moderation.staff.actions.moreFailed')}
            </p>
          ) : null}
          {actions.hasNextPage ? (
            <div className="mt-4 flex justify-center">
              <Button
                variant="secondary"
                loading={actions.isFetchingNextPage}
                onClick={() => {
                  if (actions.isFetchingNextPage) return;
                  void actions.fetchNextPage().then((result) => {
                    if (!result.isError) announce(t('moderation.staff.actions.moreLoaded'));
                  });
                }}
              >
                {t('moderation.staff.actions.more')}
              </Button>
            </div>
          ) : null}
        </>
      );
  }

  return (
    <Card
      title={t('moderation.staff.actions.title')}
      description={t('moderation.staff.actions.description')}
    >
      <form onSubmit={applyFilters} noValidate className="mb-5 space-y-3">
        <div className="grid gap-3 sm:grid-cols-3">
          <Select
            label={t('moderation.staff.actions.filter.status')}
            value={draft.status}
            options={STATUSES.map((status) => ({ value: status.value, label: t(status.key) }))}
            onChange={(event) => {
              const value = event.target.value;
              if (isStatus(value)) setDraft({ ...draft, status: value });
            }}
          />
          <Select
            label={t('moderation.staff.act.action')}
            value={draft.action}
            options={[
              { value: '', label: t('moderation.staff.actions.filter.anyAction') },
              ...ACTION_KINDS.map((kind) => ({
                value: kind,
                label: t(staffActionLabel(kind, '')),
              })),
            ]}
            onChange={(event) => {
              const value = event.target.value;
              if (isAction(value)) setDraft({ ...draft, action: value });
            }}
          />
          <Select
            label={t('moderation.staff.act.targetType')}
            value={draft.targetType}
            options={[
              { value: '', label: t('moderation.staff.actions.filter.anyTarget') },
              ...TARGET_TYPES.map((type) => ({ value: type, label: t(targetLabel(type)) })),
            ]}
            onChange={(event) => {
              const value = event.target.value;
              if (isTargetType(value)) setDraft({ ...draft, targetType: value });
            }}
          />
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <TextField
            label={t('moderation.staff.actions.filter.targetId')}
            optional
            autoComplete="off"
            spellCheck={false}
            value={draft.targetId}
            error={filterError.targetId}
            onChange={(event) => {
              setDraft({ ...draft, targetId: event.target.value });
            }}
          />
          <TextField
            label={t('moderation.staff.actions.filter.targetUserId')}
            optional
            autoComplete="off"
            spellCheck={false}
            value={draft.targetUserId}
            error={filterError.targetUserId}
            onChange={(event) => {
              setDraft({ ...draft, targetUserId: event.target.value });
            }}
          />
        </div>
        <div className="flex flex-wrap gap-2">
          <Button type="submit" variant="secondary" size="sm">
            {t('moderation.staff.actions.filter.apply')}
          </Button>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => {
              setDraft(EMPTY_FILTERS);
              setFilters(EMPTY_FILTERS);
              setFilterError({});
            }}
          >
            {t('moderation.staff.actions.filter.clear')}
          </Button>
        </div>
      </form>
      {content}
      <Disclosure summary={t('moderation.staff.visit.byId')} className="mt-5">
        <form onSubmit={reverseById} noValidate className="space-y-3 sm:max-w-md">
          <TextField
            label={t('moderation.staff.visit.idLabel')}
            help={t('moderation.staff.visit.idHelp')}
            autoComplete="off"
            spellCheck={false}
            value={actionId}
            error={idError ?? undefined}
            onChange={(event) => {
              setActionId(event.target.value);
            }}
          />
          <Button type="submit" variant="secondary" size="sm">
            {t('moderation.staff.visit.continue')}
          </Button>
        </form>
      </Disclosure>
    </Card>
  );
}
