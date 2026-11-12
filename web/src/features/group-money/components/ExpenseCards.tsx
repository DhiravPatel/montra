import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { TextArea } from '@/shared/components/TextArea';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { transactionPath } from '@/shared/config/paths';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { groupMoneyApi } from '../api';
import { groupMoneyErrorMessage, isStateConflict } from '../errors';
import { groupMoneyKeys, refreshAfterGroupWrite, reloadGroupAfterConflict } from '../keys';
import { type People, isGroupAdmin } from '../people';
import type { GroupDetail, GroupDispute, GroupExpenseDetail } from '../types';
import { AccountSelect } from './AccountSelect';
import { DisputeStatusBadge } from './StatusBadges';
import { TextPromptDialog } from './TextPromptDialog';

function useExpenseUpdater(groupId: string) {
  const queryClient = useQueryClient();
  return (expense: GroupExpenseDetail) => {
    queryClient.setQueryData(groupMoneyKeys.expense(groupId, expense.id), expense);
    return refreshAfterGroupWrite(queryClient);
  };
}

/**
 * The signed-in person's own record of an expense they paid: one of their
 * accounts loses the amount they paid, and only their share counts as their
 * spending. Other members' records are never shown.
 */
export function MyRecordCard({
  group,
  expense,
}: {
  group: GroupDetail;
  expense: GroupExpenseDetail;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const apply = useExpenseUpdater(group.id);
  const [accountId, setAccountId] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [unlinking, setUnlinking] = useState(false);
  const [unlinkError, setUnlinkError] = useState<string | null>(null);
  const record = useMutation({
    mutationFn: (body: Parameters<typeof groupMoneyApi.myRecord>[2]) =>
      groupMoneyApi.myRecord(group.id, expense.id, body),
  });
  const iPaid = expense.my_paid.amount_minor > 0;
  if (!expense.my_transaction_id && (!iPaid || expense.status === 'deleted')) return null;

  const messageFor = (failure: unknown) => {
    // Deleted or already recorded somewhere else: the card follows the current state.
    if (isStateConflict(failure)) void reloadGroupAfterConflict(queryClient, group.id);
    return groupMoneyErrorMessage(failure, t, formatLocale, {
      conflict: t('groupMoney.record.conflict'),
      notFound: t('groupMoney.record.notFound'),
    });
  };

  return (
    <Card title={t('groupMoney.record.title')} description={t('groupMoney.record.body')}>
      {expense.my_transaction_id ? (
        <div className="space-y-4">
          <p className="flex items-center gap-2 text-sm text-fg">
            <Icon name="check-circle" className="size-4 text-success" />
            {t('groupMoney.record.linked')}
          </p>
          <div className="flex flex-wrap gap-3">
            <TextLink to={transactionPath(expense.my_transaction_id)}>
              {t('groupMoney.record.view')}
            </TextLink>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => {
                setUnlinkError(null);
                setUnlinking(true);
              }}
            >
              {t('groupMoney.record.unlink')}
            </Button>
          </div>
        </div>
      ) : (
        <form
          noValidate
          className="space-y-4"
          onSubmit={(event) => {
            event.preventDefault();
            if (record.isPending) return;
            if (!accountId) {
              setError(t('validation.chooseAccount'));
              return;
            }
            setError(null);
            record.mutate(
              { action: 'link', account_id: accountId },
              {
                onSuccess: (saved) => {
                  void apply(saved);
                  toast.show({ tone: 'success', title: t('groupMoney.record.done') });
                },
                onError: (failure) => {
                  setError(messageFor(failure));
                },
              },
            );
          }}
        >
          <p className="text-sm text-fg">
            {t('groupMoney.record.youPaid')} <MoneyText money={expense.my_paid} />
          </p>
          <AccountSelect
            currency={expense.amount.currency}
            label={t('groupMoney.record.account')}
            placeholder={t('groupMoney.record.choose')}
            value={accountId}
            error={error ?? undefined}
            onChange={(value) => {
              setAccountId(value);
              setError(null);
            }}
          />
          <Button type="submit" variant="secondary" loading={record.isPending}>
            {t('groupMoney.record.submit')}
          </Button>
        </form>
      )}
      <ConfirmDialog
        open={unlinking}
        onOpenChange={setUnlinking}
        title={t('groupMoney.record.unlinkTitle')}
        description={t('groupMoney.record.unlinkBody')}
        confirmLabel={t('groupMoney.record.unlinkConfirm')}
        pending={record.isPending}
        error={unlinkError}
        onConfirm={() => {
          if (record.isPending) return;
          record.mutate(
            { action: 'unlink' },
            {
              onSuccess: (saved) => {
                void apply(saved);
                setUnlinking(false);
                toast.show({ tone: 'success', title: t('groupMoney.record.unlinked') });
              },
              onError: (failure) => {
                setUnlinkError(messageFor(failure));
              },
            },
          );
        }}
      />
    </Card>
  );
}

/** Comments on an expense, oldest first, and a box to add one. */
export function CommentsCard({
  group,
  expense,
  people,
}: {
  group: GroupDetail;
  expense: GroupExpenseDetail;
  people: People;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [text, setText] = useState('');
  const [error, setError] = useState<string | null>(null);
  const comment = useMutation({
    mutationFn: (body: string) => groupMoneyApi.comment(group.id, expense.id, body),
    onSuccess: () => refreshAfterGroupWrite(queryClient),
  });

  return (
    <Card title={t('groupMoney.comments.title')}>
      {expense.comments.length === 0 ? (
        <p className="text-sm text-fg-muted">{t('groupMoney.comments.empty')}</p>
      ) : (
        <ul className="divide-y divide-line">
          {expense.comments.map((item) => {
            const when = parseTimestamp(item.created_at);
            return (
              <li key={item.id} className="space-y-1 py-3 first:pt-0">
                <p className="text-sm">
                  <span className="font-medium text-fg">
                    {people.name(item.author_id, t('groupMoney.people.former'))}
                  </span>
                  {when ? (
                    <span className="text-fg-muted">
                      {' · '}
                      <time dateTime={item.created_at}>{formatDateTime(when, formatLocale)}</time>
                    </span>
                  ) : null}
                </p>
                <p className="whitespace-pre-wrap break-words text-fg">{item.body}</p>
              </li>
            );
          })}
        </ul>
      )}
      <form
        noValidate
        className="mt-5 space-y-3"
        onSubmit={(event) => {
          event.preventDefault();
          if (comment.isPending) return;
          const body = text.trim();
          if (!body) {
            setError(t('groupMoney.comments.required'));
            return;
          }
          setError(null);
          comment.mutate(body, {
            onSuccess: () => {
              setText('');
              toast.show({ tone: 'success', title: t('groupMoney.comments.done') });
            },
            onError: (failure) => {
              setError(
                groupMoneyErrorMessage(failure, t, formatLocale, {
                  notFound: t('groupMoney.expense.notFoundBody'),
                }),
              );
            },
          });
        }}
      >
        <TextArea
          label={t('groupMoney.comments.add')}
          maxLength={2000}
          value={text}
          error={error ?? undefined}
          onChange={(event) => {
            setText(event.target.value);
            if (error) setError(null);
          }}
        />
        <Button type="submit" variant="secondary" loading={comment.isPending}>
          <Icon name="message-square" className="size-4" />
          {t('groupMoney.comments.submit')}
        </Button>
      </form>
    </Card>
  );
}

type DisputeDialog =
  | { kind: 'raise' }
  | { kind: 'resolve'; dispute: GroupDispute }
  | { kind: 'withdraw'; dispute: GroupDispute }
  | null;

/**
 * Disputes on an expense. A disputed expense still counts in balances
 * until the dispute is resolved or the expense is edited or deleted. The
 * person who raised it, or an admin, resolves it; the raiser can withdraw.
 */
export function DisputesCard({
  group,
  expense,
  people,
}: {
  group: GroupDetail;
  expense: GroupExpenseDetail;
  people: People;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [dialog, setDialog] = useState<DisputeDialog>(null);
  const [error, setError] = useState<string | null>(null);
  const refresh = () => refreshAfterGroupWrite(queryClient);
  const raise = useMutation({
    mutationFn: (reason: string) => groupMoneyApi.dispute(group.id, expense.id, reason),
    onSettled: refresh,
  });
  const resolve = useMutation({
    mutationFn: ({
      dispute,
      resolution,
      withdraw,
    }: {
      dispute: GroupDispute;
      resolution?: string;
      withdraw?: boolean;
    }) =>
      groupMoneyApi.resolveDispute(group.id, dispute.id, {
        ...(resolution ? { resolution } : {}),
        ...(withdraw ? { withdraw: true } : {}),
      }),
    onSettled: refresh,
  });
  const admin = isGroupAdmin(group);
  const pending = raise.isPending || resolve.isPending;
  const failed = (failure: unknown) => {
    if (isStateConflict(failure)) void reloadGroupAfterConflict(queryClient, group.id);
    setError(
      groupMoneyErrorMessage(failure, t, formatLocale, {
        notFound: t('groupMoney.disputes.gone'),
        forbidden: t('groupMoney.disputes.forbidden'),
      }),
    );
  };
  const open = (next: DisputeDialog) => {
    setError(null);
    setDialog(next);
  };

  return (
    <Card
      title={t('groupMoney.disputes.title')}
      description={t('groupMoney.disputes.body')}
      actions={
        expense.status === 'deleted' ? null : (
          <Button
            variant="secondary"
            size="sm"
            onClick={() => {
              open({ kind: 'raise' });
            }}
          >
            <Icon name="flag" className="size-4" />
            {t('groupMoney.disputes.raise')}
          </Button>
        )
      }
    >
      {expense.disputes.length === 0 ? (
        <p className="text-sm text-fg-muted">{t('groupMoney.disputes.empty')}</p>
      ) : (
        <ul className="divide-y divide-line">
          {expense.disputes.map((dispute) => {
            const mine = people.isMe(dispute.raised_by);
            const when = parseTimestamp(dispute.created_at);
            return (
              <li key={dispute.id} className="space-y-2 py-3 first:pt-0 last:pb-0">
                <div className="flex flex-wrap items-center gap-2">
                  <DisputeStatusBadge status={dispute.status} />
                  <span className="text-sm text-fg-muted">
                    {t('groupMoney.disputes.raisedBy', {
                      name: people.inSentence(dispute.raised_by),
                    })}
                    {when ? ` · ${formatDateTime(when, formatLocale)}` : ''}
                  </span>
                </div>
                <p className="whitespace-pre-wrap break-words text-fg">{dispute.reason}</p>
                {dispute.resolution ? (
                  <p className="text-sm text-fg-muted">
                    {t('groupMoney.disputes.resolution', { text: dispute.resolution })}
                  </p>
                ) : null}
                {dispute.status === 'open' && (mine || admin) ? (
                  <div className="flex flex-wrap gap-2">
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={() => {
                        open({ kind: 'resolve', dispute });
                      }}
                    >
                      <Icon name="check" className="size-4" />
                      {t('groupMoney.disputes.resolve')}
                    </Button>
                    {mine ? (
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => {
                          open({ kind: 'withdraw', dispute });
                        }}
                      >
                        <Icon name="undo" className="size-4" />
                        {t('groupMoney.disputes.withdraw')}
                      </Button>
                    ) : null}
                  </div>
                ) : null}
              </li>
            );
          })}
        </ul>
      )}

      <TextPromptDialog
        open={dialog?.kind === 'raise'}
        onOpenChange={(next) => {
          if (!next) setDialog(null);
        }}
        title={t('groupMoney.disputes.raiseTitle')}
        description={t('groupMoney.disputes.raiseBody')}
        label={t('groupMoney.disputes.reason')}
        required
        requiredMessage={t('groupMoney.disputes.reasonRequired')}
        maxLength={1000}
        confirmLabel={t('groupMoney.disputes.raiseConfirm')}
        pending={pending}
        error={error}
        onConfirm={(reason) => {
          raise.mutate(reason, {
            onSuccess: () => {
              setDialog(null);
              toast.show({ tone: 'success', title: t('groupMoney.disputes.raised') });
            },
            onError: failed,
          });
        }}
      />
      <TextPromptDialog
        open={dialog?.kind === 'resolve'}
        onOpenChange={(next) => {
          if (!next) setDialog(null);
        }}
        title={t('groupMoney.disputes.resolveTitle')}
        description={t('groupMoney.disputes.resolveBody')}
        label={t('groupMoney.disputes.resolutionLabel')}
        maxLength={1000}
        confirmLabel={t('groupMoney.disputes.resolveConfirm')}
        pending={pending}
        error={error}
        onConfirm={(resolution) => {
          if (dialog?.kind !== 'resolve') return;
          resolve.mutate(
            { dispute: dialog.dispute, resolution },
            {
              onSuccess: () => {
                setDialog(null);
                toast.show({ tone: 'success', title: t('groupMoney.disputes.resolved') });
              },
              onError: failed,
            },
          );
        }}
      />
      <ConfirmDialog
        open={dialog?.kind === 'withdraw'}
        onOpenChange={(next) => {
          if (!next) setDialog(null);
        }}
        title={t('groupMoney.disputes.withdrawTitle')}
        description={t('groupMoney.disputes.withdrawBody')}
        confirmLabel={t('groupMoney.disputes.withdrawConfirm')}
        tone="primary"
        pending={pending}
        error={error}
        onConfirm={() => {
          if (dialog?.kind !== 'withdraw' || pending) return;
          resolve.mutate(
            { dispute: dialog.dispute, withdraw: true },
            {
              onSuccess: () => {
                setDialog(null);
                toast.show({ tone: 'success', title: t('groupMoney.disputes.withdrawn') });
              },
              onError: failed,
            },
          );
        }}
      />
    </Card>
  );
}
