import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { groupExpensePath, groupExpensesPath } from '@/shared/config/paths';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { groupMoneyApi, useGroupExpense } from '../api';
import { ExpenseForm } from '../components/ExpenseForm';
import { GroupMoneyPage } from '../components/GroupMoneyPage';
import { isStateConflict } from '../errors';
import { expenseToValues, involvesFormerMembers } from '../expenseForm';
import { groupMoneyKeys, refreshAfterGroupWrite, reloadGroupAfterConflict } from '../keys';
import { isReadOnlyGroup, usePeople } from '../people';
import type { GroupDetail, GroupExpenseInput, SavedState } from '../types';

export function GroupExpenseEditPage() {
  const { t } = useI18n();
  const { groupId = '', expenseId = '' } = useParams();
  useDocumentTitle(t('groupMoney.edit.title'));
  return (
    <GroupMoneyPage
      groupId={groupId}
      title={t('groupMoney.edit.title')}
      back={{ to: groupExpensePath(groupId, expenseId), label: t('groupMoney.expense.back') }}
    >
      {(group) =>
        isReadOnlyGroup(group) ? (
          <EmptyState
            titleAs="h2"
            icon="lock"
            title={t('groupMoney.page.readOnlyTitle')}
            description={t('groupMoney.page.archivedBody')}
          />
        ) : (
          <EditExpense group={group} expenseId={expenseId} />
        )
      }
    </GroupMoneyPage>
  );
}

function EditExpense({ group, expenseId }: { group: GroupDetail; expenseId: string }) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const people = usePeople(group);
  const query = useGroupExpense(group.id, expenseId);
  const [conflict, setConflict] = useState(false);
  const update = useMutation({
    mutationFn: (body: GroupExpenseInput) => groupMoneyApi.updateExpense(group.id, expenseId, body),
  });

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
            <ButtonLink to={groupExpensesPath(group.id)}>
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
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }

  const expense = query.data;
  if (expense.status === 'deleted') {
    return (
      <EmptyState
        titleAs="h2"
        icon="trash"
        title={t('groupMoney.edit.deletedTitle')}
        description={t('groupMoney.form.deleted')}
        action={
          <ButtonLink to={groupExpensesPath(group.id)}>{t('groupMoney.expenses.back')}</ButtonLink>
        }
      />
    );
  }

  return (
    <>
      {conflict ? (
        <Alert tone="warning" live="assertive" className="mb-6" title={t('finance.conflict.title')}>
          {t('groupMoney.edit.conflict')}
        </Alert>
      ) : null}
      <Card>
        <ExpenseForm
          // Remount with the latest values after a version conflict reload.
          key={expense.version}
          group={group}
          people={people}
          mode="edit"
          expense={expense}
          initialValues={expenseToValues(expense, group, people.active, people.meId, formatLocale)}
          submitLabel={t('groupMoney.edit.submit')}
          cancelTo={groupExpensePath(group.id, expense.id)}
          notice={
            involvesFormerMembers(expense, people.active) ? (
              <Alert tone="warning" title={t('groupMoney.edit.formerTitle')}>
                {t('groupMoney.edit.formerBody')}
              </Alert>
            ) : null
          }
          onError={(error) => {
            if (hasErrorCode(error, 'VERSION_CONFLICT')) {
              setConflict(true);
              void query.refetch();
              return true;
            }
            // Deleted meanwhile, or the group was archived: show the current state too.
            if (isStateConflict(error)) {
              void query.refetch();
              void reloadGroupAfterConflict(queryClient, group.id);
            }
            return false;
          }}
          onSubmit={async (body) => {
            if (update.isPending) return;
            setConflict(false);
            const saved = await update.mutateAsync(body);
            queryClient.setQueryData(groupMoneyKeys.expense(group.id, saved.id), saved);
            void refreshAfterGroupWrite(queryClient);
            toast.show({ tone: 'success', title: t('groupMoney.edit.done') });
            const state: SavedState = { saved: true };
            void navigate(groupExpensePath(group.id, saved.id), { state });
          }}
        />
      </Card>
    </>
  );
}
