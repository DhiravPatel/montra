import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type ReactNode, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon, type IconName } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { groupBalancesPath, settlementPath, transactionPath } from '@/shared/config/paths';
import { formatDateTime, formatLocalDate, parseTimestamp } from '@/shared/formatting/dates';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { cx } from '@/shared/utils/cx';
import { groupMoneyApi, useSettlement } from '../api';
import { AccountActionDialog } from '../components/AccountActionDialog';
import { GroupMoneyPage } from '../components/GroupMoneyPage';
import { SettlementDialog } from '../components/SettlementDialog';
import { CountedBadge, SettlementStatusBadge } from '../components/StatusBadges';
import { TextPromptDialog } from '../components/TextPromptDialog';
import { groupMoneyErrorMessage, isStateConflict } from '../errors';
import { groupMoneyKeys, refreshAfterGroupWrite, reloadGroupAfterConflict } from '../keys';
import { settlementMethodLabel } from '../labels';
import { isGroupAdmin, isReadOnlyGroup, settlementTitle, usePeople } from '../people';
import type { GroupDetail, Settlement, SettlementAction } from '../types';

export function SettlementDetailPage() {
  const { t } = useI18n();
  const { groupId = '', settlementId = '' } = useParams();
  useDocumentTitle(t('groupMoney.settlement.title'));
  const query = useSettlement(groupId, settlementId);
  return (
    <GroupMoneyPage
      groupId={groupId}
      title={t('groupMoney.settlement.title')}
      back={{ to: groupBalancesPath(groupId), label: t('groupMoney.settlement.back') }}
    >
      {(group) => {
        if (query.isPending) return <LoadingState label={t('groupMoney.settlement.loading')} />;
        if (query.isError) {
          if (hasErrorCode(query.error, 'NOT_FOUND')) {
            return (
              <EmptyState
                titleAs="h2"
                icon="handshake"
                title={t('groupMoney.settlement.notFound')}
                description={t('groupMoney.settlement.notFoundBody')}
                action={
                  <ButtonLink to={groupBalancesPath(groupId)}>
                    {t('groupMoney.settlement.back')}
                  </ButtonLink>
                }
              />
            );
          }
          if (hasErrorCode(query.error, 'FORBIDDEN')) return <PermissionDenied titleAs="h2" />;
          return (
            <ErrorState
              titleAs="h2"
              title={t('groupMoney.settlement.error')}
              error={query.error}
              retrying={query.isFetching}
              onRetry={() => {
                void query.refetch();
              }}
            />
          );
        }
        return (
          <SettlementDetail
            group={group}
            settlement={query.data}
            reload={() => {
              void query.refetch();
            }}
          />
        );
      }}
    </GroupMoneyPage>
  );
}

type Step = { kind: SettlementAction } | { kind: 'correct' } | null;

const doneMessage: Readonly<Record<SettlementAction, MessageKey>> = {
  'mark-paid': 'groupMoney.settlement.markedPaid',
  confirm: 'groupMoney.settlement.confirmed',
  dispute: 'groupMoney.settlement.disputed',
  void: 'groupMoney.settlement.voided',
  record: 'groupMoney.settlement.recorded',
  unlink: 'groupMoney.settlement.unlinked',
};

function SideLine({
  icon,
  tone,
  who,
  children,
}: {
  icon: IconName;
  tone: string;
  who: string;
  children: ReactNode;
}) {
  return (
    <li className="flex items-start gap-3">
      <Icon name={icon} className={cx('mt-0.5 size-5 shrink-0', tone)} />
      <div className="min-w-0">
        <p className="font-medium text-fg">{who}</p>
        <p className="text-sm text-fg-muted">{children}</p>
      </div>
    </li>
  );
}

function SettlementDetail({
  group,
  settlement,
  reload,
}: {
  group: GroupDetail;
  settlement: Settlement;
  reload: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const format = useFormatMoney();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const people = usePeople(group);
  const [step, setStep] = useState<Step>(null);
  const [stepError, setStepError] = useState<string | null>(null);
  const [conflict, setConflict] = useState(false);
  const act = useMutation({
    mutationFn: ({
      action,
      reason,
      accountId,
    }: {
      action: SettlementAction;
      reason?: string;
      accountId?: string | null;
    }) =>
      groupMoneyApi.settlementAction(group.id, settlement.id, action, {
        version: settlement.version,
        ...(reason ? { reason } : {}),
        ...(accountId ? { account_id: accountId } : {}),
      }),
  });

  const payer = people.name(settlement.payer_user_id, settlement.payer_name);
  const payee = people.name(settlement.payee_user_id, settlement.payee_name);
  const isPayer = people.isMe(settlement.payer_user_id);
  const isPayee = people.isMe(settlement.payee_user_id);
  const party = isPayer || isPayee;
  const admin = isGroupAdmin(group);
  const readOnly = isReadOnlyGroup(group);
  const status = settlement.status;
  const voided = status === 'voided';
  const amount = format(settlement.amount);
  // A payment to someone who left (or was removed) is confirmed by an admin on their behalf.
  const payeeFormer = !people.isActiveMember(settlement.payee_user_id);
  const confirmForFormer = !isPayee && admin && payeeFormer;

  const can = {
    markPaid: !readOnly && isPayer && status === 'proposed',
    confirm:
      !readOnly &&
      (isPayee || confirmForFormer) &&
      (status === 'proposed' || status === 'user_reported_paid' || status === 'disputed'),
    dispute: !readOnly && party && (status === 'user_reported_paid' || status === 'confirmed'),
    void: !readOnly && !voided && (party || admin || people.isMe(settlement.proposed_by)),
    correct: !readOnly && !voided && (party || admin),
    record:
      !settlement.my_transaction_id &&
      ((isPayer &&
        (status === 'user_reported_paid' || status === 'confirmed' || status === 'disputed')) ||
        (isPayee && status === 'confirmed')),
    unlink: Boolean(settlement.my_transaction_id),
  };

  const open = (next: Step) => {
    setStepError(null);
    setStep(next);
  };

  const run = (
    action: SettlementAction,
    extra: { reason?: string; accountId?: string | null } = {},
  ) => {
    if (act.isPending) return;
    setStepError(null);
    act.mutate(
      { action, ...extra },
      {
        onSuccess: (saved) => {
          queryClient.setQueryData(groupMoneyKeys.settlement(group.id, saved.id), saved);
          void refreshAfterGroupWrite(queryClient);
          setConflict(false);
          setStep(null);
          toast.show({ tone: 'success', title: t(doneMessage[action]) });
        },
        onError: (error) => {
          if (hasErrorCode(error, 'VERSION_CONFLICT')) {
            setStep(null);
            setConflict(true);
            reload();
            return;
          }
          // Voided, already confirmed or otherwise moved on: show the current state.
          if (isStateConflict(error)) {
            reload();
            void reloadGroupAfterConflict(queryClient, group.id);
          }
          setStepError(
            groupMoneyErrorMessage(error, t, formatLocale, {
              conflict: t('groupMoney.settlement.stateChanged'),
              notFound:
                action === 'unlink'
                  ? t('groupMoney.record.notFound')
                  : t('groupMoney.settlement.notFoundBody'),
              forbidden: t('groupMoney.settlement.forbidden'),
            }),
          );
        },
      },
    );
  };

  // The two sides of the settlement: the payer's report and the payee's confirmation.
  let payerSide: { icon: IconName; tone: string; text: string };
  let payeeSide: { icon: IconName; tone: string; text: string };
  if (voided) {
    payerSide = { icon: 'ban', tone: 'text-fg-muted', text: t('groupMoney.settlement.sideVoided') };
    payeeSide = payerSide;
  } else {
    payerSide =
      status === 'proposed'
        ? { icon: 'calendar', tone: 'text-fg-muted', text: t('groupMoney.settlement.payerPlanned') }
        : {
            icon: 'check-circle',
            tone: 'text-success',
            text: t('groupMoney.settlement.payerReported', {
              date: formatLocalDate(settlement.settled_on, formatLocale),
            }),
          };
    const confirmedAt = parseTimestamp(settlement.confirmed_at);
    payeeSide =
      status === 'confirmed'
        ? {
            icon: 'check-circle',
            tone: 'text-success',
            text: confirmedAt
              ? t('groupMoney.settlement.payeeConfirmedAt', {
                  when: formatDateTime(confirmedAt, formatLocale),
                })
              : t('groupMoney.settlement.payeeConfirmed'),
          }
        : status === 'disputed'
          ? {
              icon: 'alert-triangle',
              tone: 'text-warning',
              text: settlement.dispute_reason
                ? t('groupMoney.settlement.payeeDisputedReason', {
                    reason: settlement.dispute_reason,
                  })
                : t('groupMoney.settlement.payeeDisputed'),
            }
          : { icon: 'clock', tone: 'text-fg-muted', text: t('groupMoney.settlement.payeeWaiting') };
  }

  const actions = [
    can.markPaid
      ? {
          kind: 'mark-paid' as const,
          label: t('groupMoney.settlement.markPaid'),
          icon: 'check' as const,
          primary: true,
        }
      : null,
    can.confirm
      ? {
          kind: 'confirm' as const,
          label: confirmForFormer
            ? t('groupMoney.settlement.confirmForFormer', { name: payee })
            : t('groupMoney.settlement.confirm'),
          icon: 'check-circle' as const,
          primary: true,
        }
      : null,
    can.dispute
      ? {
          kind: 'dispute' as const,
          label: t('groupMoney.settlement.dispute'),
          icon: 'flag' as const,
          primary: false,
        }
      : null,
    can.correct
      ? {
          kind: 'correct' as const,
          label: t('groupMoney.settlement.correct'),
          icon: 'pencil' as const,
          primary: false,
        }
      : null,
    can.void
      ? {
          kind: 'void' as const,
          label: t('groupMoney.settlement.void'),
          icon: 'ban' as const,
          primary: false,
        }
      : null,
  ].filter((item) => item !== null);

  return (
    <div className="space-y-6">
      {conflict ? (
        <Alert tone="warning" live="assertive" title={t('finance.conflict.title')}>
          {t('groupMoney.settlement.conflict')}
        </Alert>
      ) : null}
      <Alert tone="info">{t('groupMoney.settlement.noMoney')}</Alert>
      {voided ? (
        <Alert tone="neutral" title={t('groupMoney.settlement.voidedTitle')}>
          {settlement.void_reason
            ? t('groupMoney.settlement.voidedReason', { reason: settlement.void_reason })
            : t('groupMoney.settlement.voidedBody')}
        </Alert>
      ) : null}

      <Card title={t('groupMoney.settlement.summary')}>
        <div className="space-y-5">
          <div className="space-y-2">
            <p className="text-lg font-semibold text-fg">
              {settlementTitle(settlement, people, t)}
            </p>
            <MoneyText money={settlement.amount} className="block text-2xl font-semibold" />
            <div className="flex flex-wrap gap-2">
              <SettlementStatusBadge status={status} />
              <CountedBadge counted={settlement.counted} />
            </div>
          </div>
          <section aria-label={t('groupMoney.settlement.sides')}>
            <h3 className="mb-3 text-base font-semibold text-fg">
              {t('groupMoney.settlement.sides')}
            </h3>
            <ol className="space-y-3">
              <SideLine
                icon={payerSide.icon}
                tone={payerSide.tone}
                who={t('groupMoney.settlement.payerSide', { name: payer })}
              >
                {payerSide.text}
              </SideLine>
              <SideLine
                icon={payeeSide.icon}
                tone={payeeSide.tone}
                who={t('groupMoney.settlement.payeeSide', { name: payee })}
              >
                {payeeSide.text}
                {payeeFormer && !voided && status !== 'confirmed' ? (
                  <span className="block">{t('groupMoney.settlement.payeeFormer')}</span>
                ) : null}
              </SideLine>
            </ol>
          </section>
          {actions.length > 0 ? (
            <div className="flex flex-wrap gap-2">
              {actions.map((item) => (
                <Button
                  key={item.kind}
                  variant={item.primary ? 'primary' : 'secondary'}
                  size="sm"
                  onClick={() => {
                    open({ kind: item.kind });
                  }}
                >
                  <Icon name={item.icon} className="size-4" />
                  {item.label}
                </Button>
              ))}
            </div>
          ) : null}
        </div>
      </Card>

      <Card title={t('groupMoney.settlement.details')}>
        <Facts>
          <Fact label={t('groupMoney.settle.method')}>
            {t(settlementMethodLabel[settlement.method])}
          </Fact>
          <Fact label={t('groupMoney.settle.date')}>
            {formatLocalDate(settlement.settled_on, formatLocale, 'long')}
          </Fact>
          <Fact label={t('groupMoney.settlement.verification')}>
            {settlement.verification === 'provider_verified'
              ? t('groupMoney.settlement.providerVerified')
              : t('groupMoney.settlement.userReported')}
          </Fact>
          {settlement.proposed_by ? (
            <Fact label={t('groupMoney.settlement.recordedBy')}>
              {people.name(settlement.proposed_by)}
            </Fact>
          ) : null}
          {settlement.note ? (
            <Fact label={t('groupMoney.settle.note')}>
              <span className="whitespace-pre-wrap">{settlement.note}</span>
            </Fact>
          ) : null}
          {settlement.corrects_settlement_id ? (
            <Fact label={t('groupMoney.settlement.corrects')}>
              <TextLink to={settlementPath(group.id, settlement.corrects_settlement_id)}>
                {t('groupMoney.settlement.viewOriginal')}
              </TextLink>
            </Fact>
          ) : null}
          {settlement.corrected_by_settlement_id ? (
            <Fact label={t('groupMoney.settlement.correctedBy')}>
              <TextLink to={settlementPath(group.id, settlement.corrected_by_settlement_id)}>
                {t('groupMoney.settlement.viewCorrection')}
              </TextLink>
            </Fact>
          ) : null}
        </Facts>
      </Card>

      {party ? (
        <Card
          title={t('groupMoney.record.title')}
          description={t('groupMoney.settlement.recordBody')}
        >
          {settlement.my_transaction_id ? (
            <div className="flex flex-wrap items-center gap-3">
              <span className="inline-flex items-center gap-2 text-sm text-fg">
                <Icon name="check-circle" className="size-4 text-success" />
                {t('groupMoney.settlement.recordLinked')}
              </span>
              <TextLink to={transactionPath(settlement.my_transaction_id)}>
                {t('groupMoney.record.view')}
              </TextLink>
              <Button
                variant="secondary"
                size="sm"
                onClick={() => {
                  open({ kind: 'unlink' });
                }}
              >
                {t('groupMoney.record.unlink')}
              </Button>
            </div>
          ) : can.record ? (
            <Button
              variant="secondary"
              size="sm"
              onClick={() => {
                open({ kind: 'record' });
              }}
            >
              <Icon name="wallet" className="size-4" />
              {t('groupMoney.settlement.record')}
            </Button>
          ) : (
            <p className="text-sm text-fg-muted">
              {isPayee
                ? t('groupMoney.settlement.recordAfterConfirm')
                : t('groupMoney.settlement.recordAfterPaid')}
            </p>
          )}
        </Card>
      ) : null}

      <AccountActionDialog
        open={step?.kind === 'mark-paid'}
        onOpenChange={(next) => {
          if (!next) setStep(null);
        }}
        title={t('groupMoney.settlement.markPaidTitle')}
        description={t('groupMoney.settlement.markPaidBody', { amount, name: payee })}
        currency={settlement.amount.currency}
        account="optional"
        accountLabel={t('groupMoney.settle.account')}
        accountHelp={t('groupMoney.settle.accountHelp')}
        confirmLabel={t('groupMoney.settlement.markPaidConfirm')}
        pending={act.isPending}
        error={stepError}
        onConfirm={(accountId) => {
          run('mark-paid', { accountId });
        }}
      />
      <AccountActionDialog
        open={step?.kind === 'confirm'}
        onOpenChange={(next) => {
          if (!next) setStep(null);
        }}
        title={
          confirmForFormer
            ? t('groupMoney.settlement.confirmForFormerTitle', { name: payee })
            : t('groupMoney.settlement.confirmTitle')
        }
        description={
          confirmForFormer
            ? t('groupMoney.settlement.confirmForFormerBody', { name: payee, payer, amount })
            : t('groupMoney.settlement.confirmBody', { amount, name: payer })
        }
        currency={settlement.amount.currency}
        // Confirming for someone else never records anything in your own accounts.
        account={confirmForFormer ? 'none' : 'optional'}
        accountLabel={t('groupMoney.settle.account')}
        accountHelp={t('groupMoney.settle.accountHelp')}
        confirmLabel={t('groupMoney.settlement.confirmConfirm')}
        pending={act.isPending}
        error={stepError}
        onConfirm={(accountId) => {
          run('confirm', { accountId });
        }}
      />
      <AccountActionDialog
        open={step?.kind === 'record'}
        onOpenChange={(next) => {
          if (!next) setStep(null);
        }}
        title={t('groupMoney.settlement.recordTitle')}
        description={t('groupMoney.settlement.recordDialogBody')}
        currency={settlement.amount.currency}
        account="required"
        accountLabel={t('groupMoney.record.account')}
        confirmLabel={t('groupMoney.settlement.record')}
        pending={act.isPending}
        error={stepError}
        onConfirm={(accountId) => {
          run('record', { accountId });
        }}
      />
      <TextPromptDialog
        open={step?.kind === 'dispute'}
        onOpenChange={(next) => {
          if (!next) setStep(null);
        }}
        title={t('groupMoney.settlement.disputeTitle')}
        description={t('groupMoney.settlement.disputeBody')}
        label={t('groupMoney.disputes.reason')}
        required
        requiredMessage={t('groupMoney.disputes.reasonRequired')}
        maxLength={500}
        confirmLabel={t('groupMoney.settlement.disputeConfirm')}
        pending={act.isPending}
        error={stepError}
        onConfirm={(reason) => {
          run('dispute', { reason });
        }}
      />
      <TextPromptDialog
        open={step?.kind === 'void'}
        onOpenChange={(next) => {
          if (!next) setStep(null);
        }}
        title={t('groupMoney.settlement.voidTitle')}
        description={t('groupMoney.settlement.voidBody')}
        label={t('groupMoney.settlement.voidReason')}
        required
        requiredMessage={t('groupMoney.settlement.voidReasonRequired')}
        maxLength={500}
        confirmLabel={t('groupMoney.settlement.voidConfirm')}
        tone="danger"
        pending={act.isPending}
        error={stepError}
        onConfirm={(reason) => {
          run('void', { reason });
        }}
      />
      <ConfirmDialog
        open={step?.kind === 'unlink'}
        onOpenChange={(next) => {
          if (!next) setStep(null);
        }}
        title={t('groupMoney.record.unlinkTitle')}
        description={t('groupMoney.settlement.unlinkBody')}
        confirmLabel={t('groupMoney.record.unlinkConfirm')}
        pending={act.isPending}
        error={stepError}
        onConfirm={() => {
          run('unlink');
        }}
      />
      <SettlementDialog
        open={step?.kind === 'correct'}
        onOpenChange={(next) => {
          if (!next) setStep(null);
        }}
        group={group}
        people={people}
        mode="correct"
        correcting={settlement}
        prefill={{
          payerUserId: settlement.payer_user_id,
          payeeUserId: settlement.payee_user_id,
          amount: settlement.amount.amount,
          method: settlement.method,
          ...(settlement.note ? { note: settlement.note } : {}),
          settledOn: settlement.settled_on,
          state: status === 'proposed' ? 'proposed' : 'paid',
        }}
        onSaved={(saved) => {
          setStep(null);
          queryClient.setQueryData(groupMoneyKeys.settlement(group.id, saved.id), saved);
          void refreshAfterGroupWrite(queryClient);
          toast.show({ tone: 'success', title: t('groupMoney.settlement.corrected') });
          void navigate(settlementPath(group.id, saved.id));
        }}
      />
    </div>
  );
}
