import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useRef, useState } from 'react';
import { Link, useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { newIdempotencyKey } from '@/shared/api/idempotency';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { groupExpensePath } from '@/shared/config/paths';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import {
  OccurrenceStatusBadge,
  RuleStatusBadge,
} from '@/features/planning/components/StatusBadges';
import { isOpenOccurrence, occurrenceRowDate } from '@/features/planning/labels';
import { describeEnd, describeSchedule } from '@/features/planning/schedule';
import { groupMoneyApi, useGroupRecurring } from '../api';
import { GroupMoneyPage } from '../components/GroupMoneyPage';
import { RecurringDialog } from '../components/RecurringDialog';
import { groupMoneyErrorMessage, isStateConflict } from '../errors';
import { groupMoneyKeys, refreshAfterGroupWrite, reloadGroupAfterConflict } from '../keys';
import { categoryKeyName, splitMethodName } from '../labels';
import { type People, isGroupAdmin, isReadOnlyGroup, usePeople } from '../people';
import type { GroupDetail, GroupRecurring, Occurrence, RecurringStatusAction } from '../types';

export function GroupRecurringPage() {
  const { t } = useI18n();
  const { groupId = '' } = useParams();
  useDocumentTitle(t('groupMoney.recurring.title'));
  return (
    <GroupMoneyPage groupId={groupId} title={t('groupMoney.recurring.title')}>
      {(group) => <RecurringList group={group} />}
    </GroupMoneyPage>
  );
}

type DialogState = { kind: 'create' } | { kind: 'edit'; ruleId: string } | null;

function RecurringList({ group }: { group: GroupDetail }) {
  const { t } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const people = usePeople(group);
  const readOnly = isReadOnlyGroup(group);
  const list = useGroupRecurring(group.id);
  const [dialog, setDialog] = useState<DialogState>(null);
  const editing =
    dialog?.kind === 'edit' ? list.data?.find((item) => item.rule.id === dialog.ruleId) : undefined;

  let content;
  if (list.isPending) {
    content = <LoadingState label={t('groupMoney.recurring.loading')} />;
  } else if (list.isError) {
    content = hasErrorCode(list.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('groupMoney.recurring.error')}
        error={list.error}
        retrying={list.isFetching}
        onRetry={() => {
          void list.refetch();
        }}
      />
    );
  } else if (list.data.length === 0) {
    content = (
      <Card>
        <EmptyState
          icon="repeat"
          title={t('groupMoney.recurring.empty.title')}
          description={t('groupMoney.recurring.empty.body')}
          action={
            readOnly ? undefined : (
              <Button
                onClick={() => {
                  setDialog({ kind: 'create' });
                }}
              >
                <Icon name="plus" className="size-4" />
                {t('groupMoney.recurring.add')}
              </Button>
            )
          }
        />
      </Card>
    );
  } else {
    content = (
      <div className="space-y-6">
        {list.data.map((recurring) => (
          <RecurringCard
            key={recurring.rule.id}
            group={group}
            people={people}
            recurring={recurring}
            onEdit={() => {
              setDialog({ kind: 'edit', ruleId: recurring.rule.id });
            }}
          />
        ))}
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="max-w-2xl text-fg-muted">{t('groupMoney.recurring.intro')}</p>
        {readOnly ? null : (
          <Button
            onClick={() => {
              setDialog({ kind: 'create' });
            }}
          >
            <Icon name="plus" className="size-4" />
            {t('groupMoney.recurring.add')}
          </Button>
        )}
      </div>
      {content}
      <RecurringDialog
        open={dialog !== null && (dialog.kind === 'create' || Boolean(editing))}
        onOpenChange={(open) => {
          if (!open) setDialog(null);
        }}
        group={group}
        people={people}
        recurring={editing ?? null}
        onConflict={() => {
          void list.refetch();
        }}
        onSaved={(saved) => {
          const created = dialog?.kind === 'create';
          setDialog(null);
          queryClient.setQueryData<GroupRecurring[]>(groupMoneyKeys.recurring(group.id), (old) =>
            old
              ? created
                ? [saved, ...old]
                : old.map((item) => (item.rule.id === saved.rule.id ? saved : item))
              : old,
          );
          void refreshAfterGroupWrite(queryClient);
          toast.show({
            tone: 'success',
            title: created ? t('groupMoney.recurring.created') : t('groupMoney.recurring.saved'),
          });
        }}
      />
    </div>
  );
}

const statusDone: Readonly<Record<RecurringStatusAction, MessageKey>> = {
  pause: 'groupMoney.recurring.paused',
  resume: 'groupMoney.recurring.resumed',
  stop: 'groupMoney.recurring.stopped',
};

type Pending = { kind: 'stop' } | { kind: 'skip'; occurrence: Occurrence } | null;

function RecurringCard({
  group,
  people,
  recurring,
  onEdit,
}: {
  group: GroupDetail;
  people: People;
  recurring: GroupRecurring;
  onEdit: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const rule = recurring.rule;
  const template = recurring.template;
  // Creator or admins change it (pause, stop, skip, edit). Adding an occurrence is also
  // limited to them here: the API fails (500) when another member adds one (reported).
  const manager = people.isMe(recurring.created_by) || isGroupAdmin(group);
  const editable = manager && !isReadOnlyGroup(group);
  const [confirming, setConfirming] = useState<Pending>(null);
  const [confirmError, setConfirmError] = useState<string | null>(null);
  // One Idempotency-Key per occurrence, kept while that add is retried.
  const addKeys = useRef(new Map<string, string>());

  const apply = (saved: GroupRecurring) => {
    queryClient.setQueryData<GroupRecurring[]>(groupMoneyKeys.recurring(group.id), (old) =>
      old?.map((item) => (item.rule.id === saved.rule.id ? saved : item)),
    );
    return refreshAfterGroupWrite(queryClient);
  };
  const messageFor = (error: unknown) => {
    // Already added or skipped, stopped, or the group archived: show the current state.
    if (isStateConflict(error)) void reloadGroupAfterConflict(queryClient, group.id);
    return groupMoneyErrorMessage(error, t, formatLocale, {
      conflict: t('groupMoney.recurring.occurrenceHandled'),
      notFound: t('groupMoney.recurring.gone'),
      forbidden: t('groupMoney.recurring.forbidden'),
      memberName: (userId) => people.name(userId),
    });
  };

  const setStatus = useMutation({
    mutationFn: (action: RecurringStatusAction) =>
      groupMoneyApi.recurringStatus(group.id, rule.id, action),
  });
  const add = useMutation({
    mutationFn: ({ occurrence, key }: { occurrence: Occurrence; key: string }) =>
      groupMoneyApi.addOccurrence(group.id, rule.id, occurrence.id, key),
  });
  const skip = useMutation({
    mutationFn: (occurrence: Occurrence) =>
      groupMoneyApi.skipOccurrence(group.id, rule.id, occurrence.id),
  });
  const busy = setStatus.isPending || add.isPending || skip.isPending;

  const changeStatus = (action: RecurringStatusAction) => {
    if (busy) return;
    setStatus.mutate(action, {
      onSuccess: (saved) => {
        void apply(saved);
        setConfirming(null);
        toast.show({ tone: 'success', title: t(statusDone[action]) });
      },
      onError: (error) => {
        if (action === 'stop') setConfirmError(messageFor(error));
        else {
          toast.show({
            tone: 'danger',
            title: t('groupMoney.recurring.failed'),
            description: messageFor(error),
          });
        }
      },
    });
  };

  const addNow = (occurrence: Occurrence) => {
    if (busy) return;
    let key = addKeys.current.get(occurrence.id);
    if (!key) {
      key = newIdempotencyKey();
      addKeys.current.set(occurrence.id, key);
    }
    add.mutate(
      { occurrence, key },
      {
        onSuccess: (expense) => {
          addKeys.current.delete(occurrence.id);
          queryClient.setQueryData(groupMoneyKeys.expense(group.id, expense.id), expense);
          void refreshAfterGroupWrite(queryClient);
          toast.show({ tone: 'success', title: t('groupMoney.recurring.added') });
        },
        onError: (error) => {
          toast.show({
            tone: 'danger',
            title: t('groupMoney.recurring.addFailed'),
            description: messageFor(error),
          });
        },
      },
    );
  };

  const payersText =
    !template.payers || template.payers.length === 0
      ? t('groupMoney.recurring.whoeverAdds')
      : template.payers.map((payer) => people.name(payer.user_id)).join(', ');

  return (
    <Card
      title={rule.name}
      actions={
        editable && rule.status !== 'ended' ? (
          <>
            <Button variant="secondary" size="sm" onClick={onEdit}>
              <Icon name="pencil" className="size-4" />
              {t('common.edit')}
            </Button>
            {rule.status === 'active' ? (
              <Button
                variant="secondary"
                size="sm"
                loading={setStatus.isPending && setStatus.variables === 'pause'}
                onClick={() => {
                  changeStatus('pause');
                }}
              >
                <Icon name="pause" className="size-4" />
                {t('groupMoney.recurring.pause')}
              </Button>
            ) : (
              <Button
                variant="secondary"
                size="sm"
                loading={setStatus.isPending && setStatus.variables === 'resume'}
                onClick={() => {
                  changeStatus('resume');
                }}
              >
                <Icon name="play" className="size-4" />
                {t('groupMoney.recurring.resume')}
              </Button>
            )}
            <Button
              variant="secondary"
              size="sm"
              onClick={() => {
                setConfirmError(null);
                setConfirming({ kind: 'stop' });
              }}
            >
              <Icon name="ban" className="size-4" />
              {t('groupMoney.recurring.stop')}
            </Button>
          </>
        ) : null
      }
    >
      <div className="space-y-5">
        <div className="flex flex-wrap gap-2">
          <RuleStatusBadge status={rule.status} />
          {recurring.auto_add ? (
            <StatusBadge tone="info" icon="repeat">
              {t('groupMoney.recurring.autoAdd')}
            </StatusBadge>
          ) : (
            <StatusBadge tone="neutral" icon="user">
              {t('groupMoney.recurring.manualAdd')}
            </StatusBadge>
          )}
        </div>
        <Facts>
          <Fact label={t('groupMoney.recurring.amount')}>
            {rule.amount ? <MoneyText money={rule.amount} className="font-semibold" /> : '—'}
          </Fact>
          <Fact label={t('groupMoney.recurring.repeats')}>
            {describeSchedule(rule, t, formatLocale)}
            <span className="block text-sm text-fg-muted">
              {describeEnd(rule, t, formatLocale)}
            </span>
          </Fact>
          {rule.next_occurrence && rule.status === 'active' ? (
            <Fact label={t('groupMoney.recurring.next')}>
              {formatLocalDate(rule.next_occurrence, formatLocale, 'long')}
            </Fact>
          ) : null}
          <Fact label={t('groupMoney.recurring.split')}>
            {splitMethodName(template.split_method ?? group.default_split_method, t)} ·{' '}
            {template.participants
              .map((participant) => people.name(participant.user_id))
              .join(', ')}
          </Fact>
          <Fact label={t('groupMoney.recurring.paidBy')}>{payersText}</Fact>
          {template.category_key ? (
            <Fact label={t('groupMoney.form.category')}>
              {categoryKeyName(template.category_key, t)}
            </Fact>
          ) : null}
          <Fact label={t('groupMoney.recurring.setUpBy')}>{people.name(recurring.created_by)}</Fact>
        </Facts>

        <section aria-labelledby={`occurrences-${rule.id}`} className="space-y-3">
          <h3 id={`occurrences-${rule.id}`} className="text-base font-semibold text-fg">
            {t('groupMoney.recurring.occurrences')}
          </h3>
          {recurring.occurrences.length === 0 ? (
            <p className="text-sm text-fg-muted">{t('groupMoney.recurring.noOccurrences')}</p>
          ) : (
            <ul className="divide-y divide-line">
              {recurring.occurrences.map((occurrence) => {
                const open = isOpenOccurrence(occurrence.status) && !occurrence.group_expense_id;
                const date = formatLocalDate(occurrenceRowDate(occurrence), formatLocale, 'long');
                return (
                  <li
                    key={occurrence.id}
                    className="flex flex-wrap items-center gap-x-4 gap-y-2 py-3 first:pt-0 last:pb-0"
                  >
                    <div className="min-w-0 flex-1 space-y-1">
                      <p className="font-medium text-fg">{date}</p>
                      <div className="flex flex-wrap items-center gap-2">
                        <OccurrenceStatusBadge status={occurrence.status} />
                        {occurrence.group_expense_id ? (
                          <Link
                            to={groupExpensePath(group.id, occurrence.group_expense_id)}
                            className="text-sm font-medium text-accent underline underline-offset-4"
                          >
                            {t('groupMoney.recurring.viewExpense')}
                          </Link>
                        ) : null}
                      </div>
                    </div>
                    {occurrence.amount ? (
                      <MoneyText money={occurrence.amount} className="font-medium" />
                    ) : null}
                    {open && editable && rule.status === 'active' ? (
                      <div className="flex flex-wrap gap-2">
                        <Button
                          size="sm"
                          loading={add.isPending && add.variables.occurrence.id === occurrence.id}
                          aria-label={t('groupMoney.recurring.addFor', { date })}
                          onClick={() => {
                            addNow(occurrence);
                          }}
                        >
                          <Icon name="plus" className="size-4" />
                          {t('groupMoney.recurring.addNow')}
                        </Button>
                        <Button
                          variant="secondary"
                          size="sm"
                          aria-label={t('groupMoney.recurring.skipFor', { date })}
                          onClick={() => {
                            setConfirmError(null);
                            setConfirming({ kind: 'skip', occurrence });
                          }}
                        >
                          <Icon name="skip-forward" className="size-4" />
                          {t('groupMoney.recurring.skip')}
                        </Button>
                      </div>
                    ) : null}
                  </li>
                );
              })}
            </ul>
          )}
          {!manager && recurring.occurrences.some((item) => isOpenOccurrence(item.status)) ? (
            <p className="text-sm text-fg-muted">
              {t('groupMoney.recurring.managersOnly', { name: people.name(recurring.created_by) })}
            </p>
          ) : null}
        </section>
      </div>

      <ConfirmDialog
        open={confirming?.kind === 'stop'}
        onOpenChange={(open) => {
          if (!open) setConfirming(null);
        }}
        title={t('groupMoney.recurring.stopTitle')}
        description={t('groupMoney.recurring.stopBody', { name: rule.name })}
        confirmLabel={t('groupMoney.recurring.stopConfirm')}
        pending={setStatus.isPending}
        error={confirmError}
        onConfirm={() => {
          changeStatus('stop');
        }}
      />
      <ConfirmDialog
        open={confirming?.kind === 'skip'}
        onOpenChange={(open) => {
          if (!open) setConfirming(null);
        }}
        title={t('groupMoney.recurring.skipTitle')}
        description={
          confirming?.kind === 'skip'
            ? t('groupMoney.recurring.skipBody', {
                date: formatLocalDate(
                  occurrenceRowDate(confirming.occurrence),
                  formatLocale,
                  'long',
                ),
              })
            : ''
        }
        confirmLabel={t('groupMoney.recurring.skipConfirm')}
        tone="primary"
        pending={skip.isPending}
        error={confirmError}
        onConfirm={() => {
          if (confirming?.kind !== 'skip' || busy) return;
          skip.mutate(confirming.occurrence, {
            onSuccess: (saved) => {
              void apply(saved);
              setConfirming(null);
              toast.show({ tone: 'success', title: t('groupMoney.recurring.skipped') });
            },
            onError: (error) => {
              setConfirmError(messageFor(error));
            },
          });
        }}
      />
    </Card>
  );
}
