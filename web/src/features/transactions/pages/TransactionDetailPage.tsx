import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useLocation, useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { PageHeader } from '@/shared/components/PageHeader';
import { Skeleton } from '@/shared/components/Skeleton';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { accountPath, paths, transactionEditPath, transactionPath } from '@/shared/config/paths';
import { categoriesById, categoryRefName } from '@/shared/finance/categories';
import { TransactionAmount } from '@/shared/finance/components/TransactionAmount';
import { invalidateFinance } from '@/shared/finance/keys';
import {
  reconciliationLabel,
  sourceLabel,
  transactionStatusLabel,
  transactionTypeLabel,
} from '@/shared/finance/labels';
import { paymentMethodLabel } from '@/shared/finance/options';
import { useCategories, usePaymentMethods } from '@/shared/finance/reference';
import { transactionTitle } from '@/shared/finance/transactionDisplay';
import type { Transaction } from '@/shared/finance/types';
import { formatDateTime, formatLocalDate, parseTimestamp } from '@/shared/formatting/dates';
import { isZeroDecimal } from '@/shared/formatting/decimal';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { transactionsApi, useTransaction } from '../api';
import { AttachmentsCard } from '../components/AttachmentsCard';
import { AuditHistory } from '../components/AuditHistory';
import { DuplicateDialog } from '../components/DuplicateDialog';
import { DuplicateHints } from '../components/DuplicateHints';
import { RefundDialog } from '../components/RefundDialog';
import { TransferSection } from '../components/TransferSection';
import { readCreatedState } from '../duplicates';
import { domainRuleMessage } from '@/shared/finance/domainErrors';

const GROUP_TYPES = new Set(['group_expense', 'settlement']);

function DetailsCard({ transaction }: { transaction: Transaction }) {
  const { t, formatLocale } = useI18n();
  const categories = useCategories(true);
  const methods = usePaymentMethods(true);
  const byId = categoriesById(categories.data);
  const method = methods.data?.find((item) => item.id === transaction.payment_method_id);
  const created = parseTimestamp(transaction.created_at);
  const updated = parseTimestamp(transaction.updated_at);
  const posted = parseTimestamp(transaction.posted_at);
  const reconciliation = reconciliationLabel[transaction.reconciliation_state];
  return (
    <Card title={t('transactions.detail.details')}>
      <Facts>
        <Fact label={t('transactions.detail.type')}>
          {t(transactionTypeLabel[transaction.type])}
        </Fact>
        <Fact label={t('transactions.detail.status')}>
          {t(transactionStatusLabel[transaction.status])}
        </Fact>
        <Fact label={t('transactions.form.date')}>
          {formatLocalDate(transaction.local_date, formatLocale, 'long')}
          <span className="block text-sm text-fg-muted">
            {t('transactions.detail.timezone', { zone: transaction.timezone })}
          </span>
        </Fact>
        <Fact label={t('transactions.form.account')}>
          <TextLink to={accountPath(transaction.account_id)}>{transaction.account_name}</TextLink>
        </Fact>
        <Fact label={t('transactions.form.category')}>
          {transaction.category
            ? categoryRefName(transaction.category, byId, t)
            : t('categories.uncategorized')}
        </Fact>
        {transaction.merchant ? (
          <Fact label={t('finance.merchant.label')}>{transaction.merchant.name}</Fact>
        ) : null}
        {method ? (
          <Fact label={t('transactions.form.paymentMethod')}>{paymentMethodLabel(method, t)}</Fact>
        ) : null}
        {transaction.tags.length > 0 ? (
          <Fact label={t('finance.tags.label')}>
            <span className="flex flex-wrap gap-1.5">
              {transaction.tags.map((tag) => (
                <StatusBadge key={tag.id} tone="neutral" icon="tag">
                  {tag.name}
                </StatusBadge>
              ))}
            </span>
          </Fact>
        ) : null}
        {transaction.description ? (
          <Fact label={t('transactions.form.description')}>{transaction.description}</Fact>
        ) : null}
        {transaction.notes ? (
          <Fact label={t('transactions.form.notes')}>
            <span className="whitespace-pre-line">{transaction.notes}</span>
          </Fact>
        ) : null}
        {transaction.location_text ? (
          <Fact label={t('transactions.detail.location')}>{transaction.location_text}</Fact>
        ) : null}
        {transaction.original_transaction_id ? (
          <Fact label={t('transactions.detail.original')}>
            <TextLink to={transactionPath(transaction.original_transaction_id)}>
              {t('transactions.detail.viewOriginal')}
            </TextLink>
          </Fact>
        ) : null}
        <Fact label={t('transactions.detail.source')}>{t(sourceLabel(transaction.source))}</Fact>
        <Fact label={t('transactions.detail.reconciliation')}>{t(reconciliation)}</Fact>
        {posted ? (
          <Fact label={t('transactions.detail.posted')}>
            <time dateTime={transaction.posted_at}>{formatDateTime(posted, formatLocale)}</time>
          </Fact>
        ) : null}
        {created ? (
          <Fact label={t('transactions.detail.created')}>
            <time dateTime={transaction.created_at}>{formatDateTime(created, formatLocale)}</time>
          </Fact>
        ) : null}
        {updated ? (
          <Fact label={t('transactions.detail.updated')}>
            <time dateTime={transaction.updated_at}>{formatDateTime(updated, formatLocale)}</time>
            {' · '}
            {t('transactions.audit.version', { version: transaction.version })}
          </Fact>
        ) : null}
      </Facts>
    </Card>
  );
}

function AmountCard({ transaction }: { transaction: Transaction }) {
  const t = useI18n().t;
  const format = useFormatMoney();
  const refunded = !isZeroDecimal(transaction.refunded_total.amount);
  return (
    <Card title={t('transactions.detail.amount')}>
      <TransactionAmount transaction={transaction} className="text-3xl" />
      <Facts className="mt-4">
        {transaction.original_amount ? (
          <Fact label={t('transactions.detail.originalAmount')}>
            <MoneyText money={transaction.original_amount} />
            {transaction.fx_rate ? (
              <span className="block text-sm text-fg-muted">
                {t('transactions.detail.fxRate', {
                  from: transaction.original_amount.currency,
                  rate: transaction.fx_rate,
                  to: transaction.amount.currency,
                })}
              </span>
            ) : null}
          </Fact>
        ) : null}
        {refunded ? (
          <Fact label={t('transactions.detail.refunded')}>
            {t('transactions.detail.refundedValue', {
              refunded: format(transaction.refunded_total),
              original: format(transaction.amount),
            })}
          </Fact>
        ) : null}
        {transaction.personal_share ? (
          <Fact label={t('transactions.detail.personalShare')}>
            <MoneyText money={transaction.personal_share} />
          </Fact>
        ) : null}
      </Facts>
    </Card>
  );
}

/** One transaction: amount, details, transfer legs, attachments and audit history. */
export function TransactionDetailPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('transactions.detail.documentTitle'));
  const { transactionId = '' } = useParams();
  const location = useLocation();
  const toast = useToast();
  const queryClient = useQueryClient();
  const query = useTransaction(transactionId);
  const [confirm, setConfirm] = useState<'void' | 'restore' | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [refundOpen, setRefundOpen] = useState(false);
  const [duplicateOpen, setDuplicateOpen] = useState(false);
  const duplicates = readCreatedState(location.state);

  const lifecycle = useMutation({
    mutationFn: async (action: 'void' | 'restore') => {
      const transferId = query.data?.transfer_id;
      // Transfers change as one unit (both legs and the fee) through their own endpoints.
      if (transferId) {
        await (action === 'void'
          ? transactionsApi.voidTransfer(transferId)
          : transactionsApi.restoreTransfer(transferId));
        return;
      }
      await (action === 'void'
        ? transactionsApi.void(transactionId)
        : transactionsApi.restore(transactionId));
    },
    onSuccess: () => invalidateFinance(queryClient),
  });

  if (query.isPending) {
    return (
      <LoadingState label={t('transactions.detail.loading')}>
        <div className="space-y-6" aria-hidden="true">
          <Skeleton className="h-9 w-1/2" />
          <Skeleton className="h-32 w-full" />
          <Skeleton className="h-64 w-full" />
        </div>
      </LoadingState>
    );
  }
  if (query.isError) {
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      return (
        <EmptyState
          titleAs="h2"
          icon="list"
          title={t('transactions.detail.notFound')}
          description={t('transactions.detail.notFoundBody')}
          action={<ButtonLink to={paths.transactions}>{t('transactions.backToList')}</ButtonLink>}
        />
      );
    }
    if (hasErrorCode(query.error, 'FORBIDDEN')) return <PermissionDenied titleAs="h2" />;
    return (
      <ErrorState
        titleAs="h2"
        title={t('transactions.detail.error')}
        error={query.error}
        retrying={query.isFetching}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }

  const transaction = query.data;
  const voided = transaction.status === 'voided';
  const isTransfer = Boolean(transaction.transfer_id);
  const groupLinked = GROUP_TYPES.has(transaction.type);
  const owned = transaction.owned;
  const canEdit = owned && !voided;
  const canVoid = owned && !voided && !groupLinked;
  const canRefund = owned && !voided && transaction.type === 'expense' && !isTransfer;
  const canDuplicate =
    owned && (transaction.type === 'expense' || transaction.type === 'income') && !isTransfer;

  const runLifecycle = () => {
    if (!confirm || lifecycle.isPending) return;
    setActionError(null);
    const action = confirm;
    lifecycle.mutate(action, {
      onSuccess: () => {
        toast.show({
          tone: 'success',
          title:
            action === 'void'
              ? isTransfer
                ? t('transactions.void.doneTransfer')
                : t('transactions.void.done')
              : t('transactions.restore.done'),
        });
        setConfirm(null);
      },
      onError: (error) => {
        if (hasErrorCode(error, 'DOMAIN_RULE_VIOLATION')) {
          setActionError(
            domainRuleMessage(error, t, formatLocale) ??
              (action === 'void'
                ? t('transactions.void.notAllowed')
                : t('transactions.restore.notAllowed')),
          );
        } else if (hasErrorCode(error, 'CONFLICT')) {
          setActionError(t('transactions.restore.conflict'));
          void query.refetch();
        } else {
          setActionError(describeError(error, t));
        }
      },
    });
  };

  return (
    <>
      <p className="mb-2">
        <TextLink to={paths.transactions}>
          <Icon name="arrow-left" className="me-1 inline size-4" />
          {t('transactions.backToList')}
        </TextLink>
      </p>
      <PageHeader
        title={transactionTitle(transaction, t)}
        description={`${t(transactionTypeLabel[transaction.type])} · ${transaction.account_name}`}
        actions={
          <>
            {canEdit ? (
              <ButtonLink to={transactionEditPath(transaction.id)} variant="secondary">
                <Icon name="pencil" className="size-4" />
                {t('common.edit')}
              </ButtonLink>
            ) : null}
            {canRefund ? (
              <Button
                variant="secondary"
                onClick={() => {
                  setRefundOpen(true);
                }}
              >
                <Icon name="undo" className="size-4" />
                {t('transactions.refund.action')}
              </Button>
            ) : null}
            {canDuplicate ? (
              <Button
                variant="secondary"
                onClick={() => {
                  setDuplicateOpen(true);
                }}
              >
                <Icon name="copy" className="size-4" />
                {t('transactions.duplicate.action')}
              </Button>
            ) : null}
            {canVoid ? (
              <Button
                variant="secondary"
                onClick={() => {
                  setActionError(null);
                  setConfirm('void');
                }}
              >
                <Icon name="trash" className="size-4" />
                {isTransfer ? t('transactions.void.actionTransfer') : t('common.delete')}
              </Button>
            ) : null}
          </>
        }
      />
      <div className="mb-6 space-y-4">
        <DuplicateHints hints={duplicates} />
        {voided ? (
          <Alert tone="info" title={t('transactions.detail.voidedTitle')}>
            <p>{t('transactions.detail.voidedBody')}</p>
            {owned ? (
              <Button
                variant="secondary"
                size="sm"
                onClick={() => {
                  setActionError(null);
                  setConfirm('restore');
                }}
              >
                <Icon name="rotate-ccw" className="size-4" />
                {t('transactions.restore.action')}
              </Button>
            ) : null}
          </Alert>
        ) : null}
        {groupLinked ? (
          <Alert tone="info" title={t('transactions.detail.groupTitle')}>
            {t('transactions.detail.groupBody')}
          </Alert>
        ) : null}
        {!owned ? (
          <Alert tone="info" title={t('accounts.detail.readOnlyTitle')}>
            {t('transactions.detail.sharedBody')}
          </Alert>
        ) : null}
        {transaction.status === 'pending' || transaction.status === 'draft' ? (
          <Alert tone="info">
            {transaction.status === 'pending'
              ? t('transactions.detail.pendingBody')
              : t('transactions.detail.draftBody')}
          </Alert>
        ) : null}
      </div>
      <div className="grid gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          <AmountCard transaction={transaction} />
          {isTransfer ? <TransferSection transaction={transaction} /> : null}
          <DetailsCard transaction={transaction} />
        </div>
        <div className="space-y-6">
          <AttachmentsCard transactionId={transaction.id} editable={canEdit} />
          <AuditHistory transactionId={transaction.id} />
        </div>
      </div>
      {canRefund ? (
        <RefundDialog original={transaction} open={refundOpen} onOpenChange={setRefundOpen} />
      ) : null}
      {canDuplicate ? (
        <DuplicateDialog
          transaction={transaction}
          open={duplicateOpen}
          onOpenChange={setDuplicateOpen}
        />
      ) : null}
      <ConfirmDialog
        open={confirm !== null}
        onOpenChange={(open) => {
          if (!open) setConfirm(null);
        }}
        tone={confirm === 'restore' ? 'primary' : 'danger'}
        title={
          confirm === 'restore'
            ? t('transactions.restore.title')
            : isTransfer
              ? t('transactions.void.titleTransfer')
              : t('transactions.void.title')
        }
        description={
          confirm === 'restore'
            ? t('transactions.restore.body')
            : isTransfer
              ? t('transactions.void.bodyTransfer')
              : t('transactions.void.body')
        }
        confirmLabel={confirm === 'restore' ? t('transactions.restore.action') : t('common.delete')}
        onConfirm={runLifecycle}
        pending={lifecycle.isPending}
        error={actionError}
      />
    </>
  );
}
