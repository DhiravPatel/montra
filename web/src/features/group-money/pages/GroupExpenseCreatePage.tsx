import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { Card } from '@/shared/components/Card';
import { EmptyState } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { groupExpensePath, groupExpensesPath } from '@/shared/config/paths';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { groupMoneyApi } from '../api';
import { ExpenseForm } from '../components/ExpenseForm';
import { GroupMoneyPage } from '../components/GroupMoneyPage';
import { defaultExpenseValues } from '../expenseForm';
import { groupMoneyKeys, refreshAfterGroupWrite } from '../keys';
import { isReadOnlyGroup, usePeople } from '../people';
import type { GroupDetail, GroupExpenseInput, SavedState } from '../types';

export function GroupExpenseCreatePage() {
  const t = useT();
  const { groupId = '' } = useParams();
  useDocumentTitle(t('groupMoney.create.title'));
  return (
    <GroupMoneyPage
      groupId={groupId}
      title={t('groupMoney.create.title')}
      back={{ to: groupExpensesPath(groupId), label: t('groupMoney.expenses.back') }}
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
          <CreateExpense group={group} />
        )
      }
    </GroupMoneyPage>
  );
}

function CreateExpense({ group }: { group: GroupDetail }) {
  const t = useT();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const people = usePeople(group);
  // One key per draft: a retry after a lost response replays instead of adding it twice.
  const idempotency = useIdempotencyKey();
  const [initialValues] = useState(() =>
    defaultExpenseValues(group, people.active, people.meId, todayInTimeZone(group.timezone)),
  );
  const create = useMutation({
    mutationFn: (body: GroupExpenseInput) =>
      groupMoneyApi.createExpense(group.id, body, idempotency.key),
  });

  return (
    <Card>
      <ExpenseForm
        group={group}
        people={people}
        mode="create"
        initialValues={initialValues}
        submitLabel={t('groupMoney.create.submit')}
        cancelTo={groupExpensesPath(group.id)}
        onSubmit={async (body) => {
          if (create.isPending) return;
          const expense = await create.mutateAsync(body);
          idempotency.renew();
          queryClient.setQueryData(groupMoneyKeys.expense(group.id, expense.id), expense);
          void refreshAfterGroupWrite(queryClient);
          toast.show({ tone: 'success', title: t('groupMoney.create.done') });
          const state: SavedState = { saved: true };
          void navigate(groupExpensePath(group.id, expense.id), { state });
        }}
      />
    </Card>
  );
}
