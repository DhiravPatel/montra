import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useLocation, useNavigate, useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { groupExpenseEditPath, groupExpensesPath } from '@/shared/config/paths';
import { formatDateTime, formatLocalDate, parseTimestamp } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { formatRate } from '@/features/fx/rate';
import { groupMoneyApi, useGroupExpense } from '../api';
import { groupMoneyErrorMessage } from '../errors';
import { CommentsCard, DisputesCard, MyRecordCard } from '../components/ExpenseCards';
import { ExpenseBreakdown } from '../components/ExpenseBreakdown';
import { GroupMoneyPage } from '../components/GroupMoneyPage';
import { ExpenseStatusBadge } from '../components/StatusBadges';
import { groupMoneyKeys, refreshAfterGroupWrite } from '../keys';
import { categoryKeyName, fxRateSourceLabel, splitMethodName } from '../labels';
import { isGroupAdmin, isReadOnlyGroup, usePeople } from '../people';
import type { GroupDetail, GroupExpenseDetail } from '../types';

function isSavedState(state: unknown): boolean {
  return typeof state === 'object' && state !== null && 'saved' in state && state.saved === true;
}

export function GroupExpenseDetailPage() {
  const { t } = useI18n();
  const { groupId = '', expenseId = '' } = useParams();
  useDocumentTitle(t('groupMoney.expense.title'));
  // Loaded beside the group so the heading can name the expense.
  const query = useGroupExpense(groupId, expenseId);
  return (
    <GroupMoneyPage
      groupId={groupId}
      title={query.data?.description ?? t('groupMoney.expense.title')}
      back={{ to: groupExpensesPath(groupId), label: t('groupMoney.expenses.back') }}
    >
      {(group) => {
        if (query.isPending) return <LoadingState label={t('groupMoney.expense.loading')} />;
        if (query.isError) {
          if (hasErrorCode(query.error, 'NOT_FOUND')) {
            return (
              <EmptyState
                titleAs="h2"
                icon="receipt"
                title={t('groupMoney.expense.notFound')}
                description={t('groupMoney.expense.notFoundBody')}
                action={
                  <ButtonLink to={groupExpensesPath(groupId)}>
                    {t('groupMoney.expenses.back')}
                  </ButtonLink>
                }
              />
            );
          }
          if (hasErrorCode(query.error, 'FORBIDDEN')) return <PermissionDenied titleAs="h2" />;
          return (
            <ErrorState
              titleAs="h2"
              title={t('groupMoney.expense.error')}
              error={query.error}
              retrying={query.isFetching}
              onRetry={() => {
                void query.refetch();
              }}
            />
          );
        }
        return <ExpenseDetail group={group} expense={query.data} />;
      }}
    </GroupMoneyPage>
  );
}

function ExpenseDetail({ group, expense }: { group: GroupDetail; expense: GroupExpenseDetail }) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const location = useLocation();
  const queryClient = useQueryClient();
  const people = usePeople(group);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [opening, setOpening] = useState(false);
  const remove = useMutation({
    mutationFn: () => groupMoneyApi.deleteExpense(group.id, expense.id),
    onSettled: () => refreshAfterGroupWrite(queryClient),
  });
  const readOnly = isReadOnlyGroup(group);
  const deleted = expense.status === 'deleted';
  const canEdit = !readOnly && !deleted;
  const canDelete = canEdit && (isGroupAdmin(group) || people.isMe(expense.created_by));
  const justSaved = isSavedState(location.state);
  const edits = Math.max(0, expense.revisions - 1);
  // Where the saved rate came from and when it was fixed (the server's values).
  const rateSource = expense.fx_rate_source ? t(fxRateSourceLabel[expense.fx_rate_source]) : null;
  const rateAt = parseTimestamp(expense.fx_rate_at);

  const openAttachment = async (fileId: string) => {
    if (opening) return;
    // Open the tab inside the click so pop-up blockers allow it, then point it at the file.
    const tab = window.open('', '_blank');
    if (tab) tab.opener = null;
    setOpening(true);
    try {
      const access = await groupMoneyApi.fileAccess(fileId);
      if (tab) tab.location.href = access.url;
      else window.location.assign(access.url);
    } catch (error) {
      tab?.close();
      toast.show({
        tone: 'danger',
        title: t('groupMoney.attachment.openFailed'),
        description: describeError(error, t),
      });
    } finally {
      setOpening(false);
    }
  };

  return (
    <div className="space-y-6">
      {justSaved ? (
        <Alert tone="success" live="polite" title={t('groupMoney.expense.savedTitle')}>
          {t('groupMoney.expense.savedBody')}
        </Alert>
      ) : null}
      {deleted ? (
        <Alert tone="neutral" title={t('groupMoney.expense.deletedTitle')}>
          {t('groupMoney.expense.deletedBody')}
        </Alert>
      ) : null}
      {expense.status === 'disputed' ? (
        <Alert tone="warning" title={t('groupMoney.expense.disputedTitle')}>
          {t('groupMoney.expense.disputedBody')}
        </Alert>
      ) : null}

      <Card
        title={t('groupMoney.expense.summary')}
        actions={
          canEdit ? (
            <>
              <ButtonLink
                to={groupExpenseEditPath(group.id, expense.id)}
                variant="secondary"
                size="sm"
              >
                <Icon name="pencil" className="size-4" />
                {t('groupMoney.expense.edit')}
              </ButtonLink>
              {canDelete ? (
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={() => {
                    setDeleteError(null);
                    setDeleting(true);
                  }}
                >
                  <Icon name="trash" className="size-4" />
                  {t('groupMoney.expense.delete')}
                </Button>
              ) : null}
            </>
          ) : null
        }
      >
        <Facts>
          <Fact label={t('groupMoney.expense.amount')}>
            <MoneyText money={expense.amount} className="font-semibold" />
          </Fact>
          {expense.original_amount ? (
            <Fact label={t('groupMoney.expense.original')}>
              <span className="space-y-1">
                <MoneyText money={expense.original_amount} />
                {expense.fx_rate ? (
                  <span className="block text-sm text-fg-muted">
                    {t('groupMoney.expense.rateUsed', {
                      from: expense.original_amount.currency,
                      to: expense.amount.currency,
                      rate: formatRate(expense.fx_rate, formatLocale),
                    })}
                  </span>
                ) : null}
                {rateSource ? (
                  <span className="block text-sm text-fg-muted">
                    {rateAt
                      ? t('groupMoney.expense.rateDetails', {
                          source: rateSource,
                          when: formatDateTime(rateAt, formatLocale),
                        })
                      : rateSource}
                  </span>
                ) : null}
              </span>
            </Fact>
          ) : null}
          <Fact label={t('groupMoney.expense.yourShare')}>
            <MoneyText money={expense.my_share} />
          </Fact>
          <Fact label={t('groupMoney.expense.youPaid')}>
            <MoneyText money={expense.my_paid} />
          </Fact>
          <Fact label={t('groupMoney.expense.date')}>
            {formatLocalDate(expense.expense_date, formatLocale, 'long')}
          </Fact>
          <Fact label={t('groupMoney.expense.category')}>
            {categoryKeyName(expense.category_key, t)}
          </Fact>
          <Fact label={t('groupMoney.expense.splitMethod')}>
            {splitMethodName(expense.split_method, t)}
          </Fact>
          <Fact label={t('groupMoney.expense.status')}>
            <ExpenseStatusBadge status={expense.status} />
          </Fact>
          <Fact label={t('groupMoney.expense.addedBy')}>{people.name(expense.created_by)}</Fact>
          {expense.notes ? (
            <Fact label={t('groupMoney.expense.notes')}>
              <span className="whitespace-pre-wrap">{expense.notes}</span>
            </Fact>
          ) : null}
          {expense.receipt_file_id ? (
            <Fact label={t('groupMoney.expense.attachment')}>
              <Button
                variant="secondary"
                size="sm"
                loading={opening}
                onClick={() => {
                  if (expense.receipt_file_id) void openAttachment(expense.receipt_file_id);
                }}
              >
                <Icon name="paperclip" className="size-4" />
                {t('groupMoney.attachment.open')}
              </Button>
            </Fact>
          ) : null}
          <Fact label={t('groupMoney.expense.history')}>
            {edits === 0
              ? t('groupMoney.expense.neverEdited')
              : t('groupMoney.expense.edited', { count: edits })}
          </Fact>
        </Facts>
      </Card>

      <Card title={t('groupMoney.expense.split')} description={t('groupMoney.expense.splitBody')}>
        <ExpenseBreakdown expense={expense} people={people} />
      </Card>

      <MyRecordCard group={group} expense={expense} />
      <DisputesCard group={group} expense={expense} people={people} />
      <CommentsCard group={group} expense={expense} people={people} />

      <ConfirmDialog
        open={deleting}
        onOpenChange={setDeleting}
        title={t('groupMoney.expense.deleteTitle')}
        description={t('groupMoney.expense.deleteBody')}
        confirmLabel={t('groupMoney.expense.deleteConfirm')}
        pending={remove.isPending}
        error={deleteError}
        onConfirm={() => {
          if (remove.isPending) return;
          setDeleteError(null);
          remove.mutate(undefined, {
            onSuccess: () => {
              queryClient.removeQueries({ queryKey: groupMoneyKeys.expense(group.id, expense.id) });
              setDeleting(false);
              toast.show({ tone: 'success', title: t('groupMoney.expense.deleted') });
              void navigate(groupExpensesPath(group.id));
            },
            onError: (error) => {
              setDeleteError(
                groupMoneyErrorMessage(error, t, formatLocale, {
                  forbidden: t('groupMoney.expense.deleteForbidden'),
                  notFound: t('groupMoney.expense.notFoundBody'),
                }),
              );
            },
          });
        }}
      />
    </div>
  );
}
