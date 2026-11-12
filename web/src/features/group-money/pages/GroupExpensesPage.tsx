import { type SyntheticEvent, useEffect, useRef, useState } from 'react';
import { Link, useParams } from 'react-router';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';
import { hasErrorCode } from '@/shared/api/errors';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { Select } from '@/shared/components/Select';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { groupExpenseNewPath, groupExpensePath } from '@/shared/config/paths';
import { formatLocalDate, isLocalDate } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useGroupExpenses } from '../api';
import { GroupMoneyPage } from '../components/GroupMoneyPage';
import { ExpenseStatusBadge } from '../components/StatusBadges';
import { categoryKeyName, categoryKeyOptions, splitMethodName } from '../labels';
import { type People, isReadOnlyGroup, usePeople } from '../people';
import type { ExpenseFilters, ExpenseStatus, GroupDetail, GroupExpense } from '../types';

export function GroupExpensesPage() {
  const { t } = useI18n();
  const { groupId = '' } = useParams();
  useDocumentTitle(t('groupMoney.expenses.title'));
  return (
    <GroupMoneyPage
      groupId={groupId}
      title={t('groupMoney.expenses.title')}
      actions={(group) =>
        isReadOnlyGroup(group) ? null : (
          <ButtonLink to={groupExpenseNewPath(group.id)}>
            <Icon name="plus" className="size-4" />
            {t('groupMoney.expenses.add')}
          </ButtonLink>
        )
      }
    >
      {(group) => <ExpensesList group={group} />}
    </GroupMoneyPage>
  );
}

const NO_FILTERS: ExpenseFilters = {
  status: '',
  from: '',
  to: '',
  payerUserId: '',
  categoryKey: '',
  includeDeleted: false,
};

function isStatus(value: string): value is ExpenseStatus {
  return value === 'active' || value === 'disputed' || value === 'deleted';
}

/** True when any server-side filter is set (the empty state then says so). */
function hasFilters(filters: ExpenseFilters): boolean {
  return (
    filters.status !== '' ||
    filters.from !== '' ||
    filters.to !== '' ||
    filters.payerUserId !== '' ||
    filters.categoryKey !== ''
  );
}

/**
 * Shared expenses, newest first, filtered and paged by the server: a
 * status, who paid, a category and a date range go with every page, and
 * "Load more" follows the server's cursor.
 */
function ExpensesList({ group }: { group: GroupDetail }) {
  const { t } = useI18n();
  const announce = useAnnounce();
  const people = usePeople(group);
  const [filters, setFilters] = useState<ExpenseFilters>(NO_FILTERS);
  // Dates apply together (a half-typed range is never sent).
  const [dates, setDates] = useState({ from: '', to: '' });
  const [dateError, setDateError] = useState<string | null>(null);
  const expenses = useGroupExpenses(group.id, filters);
  const items = expenses.data?.pages.flatMap((page) => page.items) ?? [];

  // Later pages and filter changes are announced; the first load is not.
  const lastAnnounced = useRef<string | null>(null);
  useEffect(() => {
    if (!expenses.isSuccess || expenses.isFetching) return;
    const message = expenses.hasNextPage
      ? t('groupMoney.expenses.countMore', { count: items.length })
      : t('groupMoney.expenses.count', { count: items.length });
    if (lastAnnounced.current === null) {
      lastAnnounced.current = message;
      return;
    }
    if (lastAnnounced.current !== message) {
      lastAnnounced.current = message;
      announce(message);
    }
  }, [expenses.isSuccess, expenses.isFetching, expenses.hasNextPage, items.length, announce, t]);

  const update = (change: Partial<ExpenseFilters>) => {
    setFilters((current) => ({ ...current, ...change }));
  };
  const applyDates = (event: SyntheticEvent) => {
    event.preventDefault();
    if ((dates.from && !isLocalDate(dates.from)) || (dates.to && !isLocalDate(dates.to))) {
      setDateError(t('validation.dateInvalid'));
      return;
    }
    if (dates.from && dates.to && dates.to < dates.from) {
      setDateError(t('validation.dateOrder'));
      return;
    }
    setDateError(null);
    update(dates);
  };
  const clear = () => {
    setDates({ from: '', to: '' });
    setDateError(null);
    setFilters(NO_FILTERS);
  };

  const statusOptions = [
    { value: '', label: t('groupMoney.expenses.filter.all') },
    { value: 'active', label: t('groupMoney.expenseStatus.active') },
    { value: 'disputed', label: t('groupMoney.expenseStatus.disputed') },
    { value: 'deleted', label: t('groupMoney.expenseStatus.deleted') },
  ];
  const payerOptions = [
    { value: '', label: t('groupMoney.expenses.filter.anyone') },
    ...people.everyone.map((member) => ({
      value: member.user_id,
      label: people.optionLabel(member),
    })),
  ];
  const categoryOptions = [
    { value: '', label: t('groupMoney.expenses.filter.anyCategory') },
    { value: 'uncategorized', label: t('categories.uncategorized') },
    ...categoryKeyOptions(t),
  ];

  let content;
  if (expenses.isPending) {
    content = <LoadingState label={t('groupMoney.expenses.loading')} />;
  } else if (expenses.isLoadingError) {
    content = hasErrorCode(expenses.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('groupMoney.expenses.error')}
        error={expenses.error}
        retrying={expenses.isFetching}
        onRetry={() => {
          void expenses.refetch();
        }}
      />
    );
  } else if (items.length === 0) {
    content = hasFilters(filters) ? (
      <EmptyState
        icon="filter"
        title={t('groupMoney.expenses.noMatches.title')}
        description={t('groupMoney.expenses.noMatches.body')}
        action={
          <Button variant="secondary" onClick={clear}>
            {t('groupMoney.expenses.filter.clear')}
          </Button>
        }
      />
    ) : (
      <EmptyState
        icon="receipt"
        title={t('groupMoney.expenses.empty.title')}
        description={t('groupMoney.expenses.empty.body')}
        action={
          isReadOnlyGroup(group) ? undefined : (
            <ButtonLink to={groupExpenseNewPath(group.id)}>
              <Icon name="plus" className="size-4" />
              {t('groupMoney.expenses.add')}
            </ButtonLink>
          )
        }
      />
    );
  } else {
    content = (
      <>
        <p className="mb-3 text-sm text-fg-muted" role="status">
          {expenses.hasNextPage
            ? t('groupMoney.expenses.countMore', { count: items.length })
            : t('groupMoney.expenses.count', { count: items.length })}
        </p>
        <ul className="divide-y divide-line">
          {items.map((expense) => (
            <ExpenseRow key={expense.id} expense={expense} people={people} groupId={group.id} />
          ))}
        </ul>
        {expenses.isFetchNextPageError ? (
          <p role="alert" className="mt-4 flex items-start gap-1.5 text-sm text-danger">
            <Icon name="alert-circle" className="mt-0.5 size-4 shrink-0" />
            {t('groupMoney.expenses.moreFailed')}
          </p>
        ) : null}
        {expenses.hasNextPage ? (
          <div className="mt-4 flex justify-center">
            <Button
              variant="secondary"
              loading={expenses.isFetchingNextPage}
              onClick={() => {
                void expenses.fetchNextPage();
              }}
            >
              {t('common.loadMore')}
            </Button>
          </div>
        ) : null}
      </>
    );
  }

  return (
    <Card
      title={t('groupMoney.expenses.listTitle')}
      description={t('groupMoney.expenses.listBody')}
    >
      <form
        noValidate
        aria-label={t('groupMoney.expenses.filters')}
        onSubmit={applyDates}
        className="mb-6 flex flex-wrap items-end gap-4 border-b border-line pb-6"
      >
        <Select
          label={t('groupMoney.expenses.filter.status')}
          options={statusOptions}
          value={filters.status}
          className="min-w-40"
          onChange={(event) => {
            const next = event.target.value;
            update({ status: isStatus(next) ? next : '' });
          }}
        />
        <Select
          label={t('groupMoney.expenses.filter.paidBy')}
          options={payerOptions}
          value={filters.payerUserId}
          className="min-w-44"
          onChange={(event) => {
            update({ payerUserId: event.target.value });
          }}
        />
        <Select
          label={t('groupMoney.expenses.filter.category')}
          options={categoryOptions}
          value={filters.categoryKey}
          className="min-w-44"
          onChange={(event) => {
            update({ categoryKey: event.target.value });
          }}
        />
        <TextField
          label={t('finance.range.from')}
          type="date"
          value={dates.from}
          className="min-w-40"
          onChange={(event) => {
            setDates((current) => ({ ...current, from: event.target.value }));
          }}
        />
        <TextField
          label={t('finance.range.to')}
          type="date"
          value={dates.to}
          className="min-w-40"
          error={dateError ?? undefined}
          onChange={(event) => {
            setDates((current) => ({ ...current, to: event.target.value }));
          }}
        />
        <Button type="submit" variant="secondary">
          {t('common.apply')}
        </Button>
        <label className="inline-flex min-h-11 cursor-pointer items-center gap-2 text-sm text-fg">
          <input
            type="checkbox"
            checked={filters.includeDeleted}
            disabled={filters.status !== ''}
            onChange={(event) => {
              update({ includeDeleted: event.target.checked });
            }}
            className="size-4 accent-accent"
          />
          {t('groupMoney.expenses.showDeleted')}
        </label>
        {hasFilters(filters) || filters.includeDeleted ? (
          <Button variant="ghost" onClick={clear}>
            {t('groupMoney.expenses.filter.clear')}
          </Button>
        ) : null}
      </form>
      {content}
    </Card>
  );
}

function ExpenseRow({
  expense,
  people,
  groupId,
}: {
  expense: GroupExpense;
  people: People;
  groupId: string;
}) {
  const { t, formatLocale } = useI18n();
  const firstPayer = expense.payers[0];
  const paidBy =
    expense.payers.length === 1 && firstPayer
      ? t('groupMoney.expenses.paidBy', { name: people.inSentence(firstPayer.user_id) })
      : t('groupMoney.expenses.paidByMany', { count: expense.payers.length });
  const details = [
    formatLocalDate(expense.expense_date, formatLocale),
    categoryKeyName(expense.category_key, t),
    splitMethodName(expense.split_method, t),
  ];
  return (
    <li className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-start sm:justify-between">
      <div className="min-w-0 space-y-1">
        <Link
          to={groupExpensePath(groupId, expense.id)}
          className="font-medium text-fg underline-offset-4 hover:underline"
        >
          {expense.description}
        </Link>
        <p className="text-sm text-fg-muted">{details.join(' · ')}</p>
        <p className="text-sm text-fg-muted">{paidBy}</p>
        {expense.status !== 'active' ? (
          <div>
            <ExpenseStatusBadge status={expense.status} />
          </div>
        ) : null}
      </div>
      <div className="shrink-0 space-y-1 text-start sm:text-end">
        <MoneyText money={expense.amount} className="block font-semibold text-fg" />
        {expense.original_amount ? (
          <p className="text-sm text-fg-muted">
            {t('groupMoney.expenses.original')} <MoneyText money={expense.original_amount} />
          </p>
        ) : null}
        <p className="text-sm text-fg-muted">
          {t('groupMoney.expenses.yourShare')} <MoneyText money={expense.my_share} />
        </p>
      </div>
    </li>
  );
}
