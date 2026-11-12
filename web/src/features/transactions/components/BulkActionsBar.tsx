import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { Select } from '@/shared/components/Select';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';
import { useToast } from '@/shared/components/toast/ToastContext';
import { invalidateFinance } from '@/shared/finance/keys';
import { accountGroups, categoryOptions } from '@/shared/finance/options';
import { useAccounts, useCategories, useTags, writableAccounts } from '@/shared/finance/reference';
import type { BulkUpdateInput } from '@/shared/finance/types';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { transactionsApi } from '../api';
import { domainRuleMessage } from '@/shared/finance/domainErrors';

type BulkAction = 'category' | 'clearCategory' | 'addTag' | 'removeTag' | 'account';

const ACTIONS: readonly BulkAction[] = [
  'category',
  'clearCategory',
  'addTag',
  'removeTag',
  'account',
];

function isBulkAction(value: string): value is BulkAction {
  return (ACTIONS as readonly string[]).includes(value);
}

interface BulkActionsBarProps {
  selectedIds: readonly string[];
  onClear: () => void;
}

/** Bulk category/tag/account changes and bulk delete for the selected rows. */
export function BulkActionsBar({ selectedIds, onClear }: BulkActionsBarProps) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const announce = useAnnounce();
  const queryClient = useQueryClient();
  const accounts = useAccounts();
  const categories = useCategories();
  const tags = useTags();
  const [action, setAction] = useState<BulkAction | ''>('');
  const [target, setTarget] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const count = selectedIds.length;

  const update = useMutation({
    mutationFn: (body: BulkUpdateInput) => transactionsApi.bulkUpdate(body),
    onSettled: () => invalidateFinance(queryClient),
  });
  const remove = useMutation({
    mutationFn: (ids: string[]) => transactionsApi.bulkDelete(ids),
    onSettled: () => invalidateFinance(queryClient),
  });

  const needsTarget = action !== '' && action !== 'clearCategory';
  let targetSelect = null;
  if (action === 'category') {
    targetSelect = (
      <Select
        label={t('transactions.bulk.category')}
        placeholder={t('transactions.bulk.choose')}
        value={target}
        options={categoryOptions(categories.data ?? [], t, formatLocale)}
        onChange={(event) => {
          setTarget(event.target.value);
        }}
      />
    );
  } else if (action === 'addTag' || action === 'removeTag') {
    targetSelect = (
      <Select
        label={t('transactions.bulk.tag')}
        placeholder={t('transactions.bulk.choose')}
        value={target}
        options={(tags.data ?? [])
          .filter((tag) => !tag.archived_at)
          .map((tag) => ({ value: tag.id, label: tag.name }))}
        onChange={(event) => {
          setTarget(event.target.value);
        }}
      />
    );
  } else if (action === 'account') {
    targetSelect = (
      <Select
        label={t('transactions.bulk.account')}
        placeholder={t('transactions.bulk.choose')}
        value={target}
        groups={accountGroups(writableAccounts(accounts.data), t)}
        help={t('transactions.bulk.accountHelp')}
        onChange={(event) => {
          setTarget(event.target.value);
        }}
      />
    );
  }

  const apply = () => {
    if (update.isPending || action === '') return;
    if (needsTarget && !target) {
      setError(t('transactions.bulk.chooseFirst'));
      return;
    }
    setError(null);
    const ids = [...selectedIds];
    const body: BulkUpdateInput = { transaction_ids: ids };
    if (action === 'category') body.category_id = target;
    if (action === 'clearCategory') body.clear_category = true;
    if (action === 'addTag') body.add_tag_ids = [target];
    if (action === 'removeTag') body.remove_tag_ids = [target];
    if (action === 'account') body.account_id = target;
    update.mutate(body, {
      onSuccess: (result) => {
        const message = t('transactions.bulk.updated', { count: result.updated });
        toast.show({ tone: 'success', title: message });
        announce(message);
        setAction('');
        setTarget('');
        onClear();
      },
      onError: (failure) => {
        setError(
          hasErrorCode(failure, 'DOMAIN_RULE_VIOLATION')
            ? (domainRuleMessage(failure, t, formatLocale) ?? t('transactions.bulk.notAllowed'))
            : describeError(failure, t),
        );
      },
    });
  };

  const runDelete = () => {
    if (remove.isPending) return;
    setDeleteError(null);
    remove.mutate([...selectedIds], {
      onSuccess: (result) => {
        toast.show({
          tone: 'success',
          title: t('transactions.bulk.deleted', { count: result.updated }),
        });
        setConfirmDelete(false);
        onClear();
      },
      onError: (failure) => {
        setDeleteError(describeError(failure, t));
      },
    });
  };

  return (
    <section
      aria-label={t('transactions.bulk.label')}
      className="mb-4 rounded-xl border border-accent bg-accent-soft p-4"
    >
      <div className="flex flex-wrap items-end gap-3">
        <p className="me-auto self-center font-semibold text-fg" aria-live="polite">
          {t('transactions.bulk.selected', { count })}
        </p>
        <Select
          label={t('transactions.bulk.action')}
          placeholder={t('transactions.bulk.choose')}
          value={action}
          options={ACTIONS.map((value) => ({
            value,
            label: t(`transactions.bulk.action.${value}`),
          }))}
          onChange={(event) => {
            const value = event.target.value;
            setAction(isBulkAction(value) ? value : '');
            setTarget('');
            setError(null);
          }}
        />
        {targetSelect}
        <Button onClick={apply} loading={update.isPending} disabled={action === ''}>
          {t('common.apply')}
        </Button>
        <Button
          variant="secondary"
          onClick={() => {
            setDeleteError(null);
            setConfirmDelete(true);
          }}
        >
          <Icon name="trash" className="size-4" />
          {t('transactions.bulk.delete')}
        </Button>
        <Button variant="ghost" onClick={onClear}>
          {t('transactions.bulk.clear')}
        </Button>
      </div>
      {error ? (
        <Alert tone="danger" live="assertive" className="mt-3">
          {error}
        </Alert>
      ) : null}
      <ConfirmDialog
        open={confirmDelete}
        onOpenChange={setConfirmDelete}
        title={t('transactions.bulk.deleteTitle', { count })}
        description={t('transactions.bulk.deleteBody')}
        confirmLabel={t('transactions.bulk.deleteConfirm', { count })}
        onConfirm={runDelete}
        pending={remove.isPending}
        error={deleteError}
      />
    </section>
  );
}
