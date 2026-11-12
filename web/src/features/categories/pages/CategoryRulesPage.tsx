import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Checkbox } from '@/shared/components/Checkbox';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Dialog } from '@/shared/components/Dialog';
import { Icon } from '@/shared/components/Icon';
import { Menu, MenuContent, MenuItem, MenuTrigger } from '@/shared/components/Menu';
import { PageHeader } from '@/shared/components/PageHeader';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { categoriesById, categoryName } from '@/shared/finance/categories';
import { invalidateFinance } from '@/shared/finance/keys';
import { useAccounts, useCategories } from '@/shared/finance/reference';
import type { Account, Category, CategoryRule } from '@/shared/finance/types';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { rulesApi, useCategoryRules } from '../api';
import { OrganizeSubNav } from '../components/OrganizeSubNav';
import { RuleDialog, type RuleDialogMode } from '../components/RuleDialog';
import { organizeErrorMessage } from '../errors';
import {
  ruleApplyToLabel,
  ruleFieldLabel,
  ruleSummaryKey,
  ruleTypeLabel,
  sortRules,
} from '../labels';

const triggerClasses =
  'inline-flex size-9 shrink-0 cursor-pointer items-center justify-center rounded-md border border-line-strong ' +
  'text-fg hover:bg-surface-muted';

function ruleCategoryName(
  rule: CategoryRule,
  categories: ReadonlyMap<string, Category>,
  t: Translate,
): string {
  const category = categories.get(rule.set_category_id);
  return category ? categoryName(category, t) : t('categoryRules.missingCategory');
}

/** "Description contains “swiggy”" plus the extra conditions, in words. */
function RuleDescription({
  rule,
  categories,
  accounts,
}: {
  rule: CategoryRule;
  categories: ReadonlyMap<string, Category>;
  accounts: ReadonlyMap<string, Account>;
}) {
  const { t } = useI18n();
  const formatMoney = useFormatMoney();
  const condition = t(ruleSummaryKey[rule.match_type], {
    field: t(ruleFieldLabel[rule.match_field]),
    pattern: rule.pattern,
  });
  const sets = t('categoryRules.summary.sets', {
    category: ruleCategoryName(rule, categories, t),
  });
  // Bounds are in the rule's currency and match only transactions in that currency.
  const bound = (value: string) =>
    rule.currency ? formatMoney({ amount: value, currency: rule.currency }) : value;
  let amount: string | null = null;
  if (rule.amount_min && rule.amount_max) {
    amount = t('categoryRules.amount.between', {
      min: bound(rule.amount_min),
      max: bound(rule.amount_max),
    });
  } else if (rule.amount_min) {
    amount = t('categoryRules.amount.min', { min: bound(rule.amount_min) });
  } else if (rule.amount_max) {
    amount = t('categoryRules.amount.max', { max: bound(rule.amount_max) });
  }
  const account = rule.account_id ? accounts.get(rule.account_id) : undefined;
  const extras = [
    rule.transaction_type ? t(ruleTypeLabel[rule.transaction_type]) : null,
    account ? t('categoryRules.onlyAccount', { account: account.name }) : null,
    amount,
    t(ruleApplyToLabel[rule.apply_to]),
  ].filter(Boolean);
  return (
    <>
      <p className="text-sm text-fg">
        {condition}
        <Icon name="arrow-right" className="mx-1.5 inline size-4 text-fg-muted" />
        {sets}
      </p>
      <p className="text-sm text-fg-muted">{extras.join(' · ')}</p>
    </>
  );
}

/** Apply a saved rule to existing transactions (audited by the API). */
function ApplyRuleDialog({
  rule,
  categories,
  onClose,
}: {
  rule: CategoryRule | null;
  categories: ReadonlyMap<string, Category>;
  onClose: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [onlyUncategorized, setOnlyUncategorized] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const apply = useMutation({
    mutationFn: (target: CategoryRule) =>
      rulesApi.applySaved(target.id, { only_uncategorized: onlyUncategorized }),
    onSuccess: () => invalidateFinance(queryClient),
  });
  const close = () => {
    setError(null);
    setOnlyUncategorized(true);
    onClose();
  };
  return (
    <Dialog
      open={rule !== null}
      onOpenChange={(open) => {
        if (!open) close();
      }}
      title={t('categoryRules.apply.title')}
      description={
        rule
          ? t('categoryRules.apply.body', {
              name: rule.name,
              category: ruleCategoryName(rule, categories, t),
            })
          : null
      }
      busy={apply.isPending}
    >
      {error ? (
        <Alert tone="danger" live="assertive" className="mb-4">
          {error}
        </Alert>
      ) : null}
      <Checkbox
        label={t('categoryRules.apply.onlyUncategorized')}
        description={t('categoryRules.apply.onlyUncategorizedHelp')}
        checked={onlyUncategorized}
        onChange={(event) => {
          setOnlyUncategorized(event.target.checked);
        }}
      />
      <div className="mt-6 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={apply.isPending} onClick={close}>
          {t('common.cancel')}
        </Button>
        <Button
          loading={apply.isPending}
          onClick={() => {
            if (!rule || apply.isPending) return;
            setError(null);
            apply.mutate(rule, {
              onSuccess: (result) => {
                const message =
                  result.match_count === 0
                    ? t('categoryRules.apply.none')
                    : t('categoryRules.apply.done', { count: result.match_count });
                // The toast is a live region, so the result is announced.
                toast.show({ tone: result.match_count === 0 ? 'info' : 'success', title: message });
                close();
              },
              onError: (failure) => {
                // e.g. rule_category_unavailable: the rule's category was archived.
                setError(
                  hasErrorCode(failure, 'NOT_FOUND')
                    ? t('categoryRules.notFound')
                    : organizeErrorMessage(failure, t, formatLocale),
                );
              },
            });
          }}
        >
          {t('categoryRules.apply.confirm')}
        </Button>
      </div>
    </Dialog>
  );
}

/** Categorization rules in run order, with create/edit (+ preview), apply and delete. */
export function CategoryRulesPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('categoryRules.title'));
  const toast = useToast();
  const queryClient = useQueryClient();
  const rules = useCategoryRules();
  const categories = useCategories(true);
  const accounts = useAccounts(true);
  const [dialog, setDialog] = useState<RuleDialogMode | null>(null);
  const [applying, setApplying] = useState<CategoryRule | null>(null);
  const [removing, setRemoving] = useState<CategoryRule | null>(null);
  const [removeError, setRemoveError] = useState<string | null>(null);
  const byId = categoriesById(categories.data);
  const accountsById = new Map((accounts.data ?? []).map((account) => [account.id, account]));

  const remove = useMutation({
    mutationFn: (rule: CategoryRule) => rulesApi.remove(rule.id),
    onSettled: () => invalidateFinance(queryClient),
  });

  const addButton = (
    <Button
      onClick={() => {
        setDialog({ kind: 'create' });
      }}
    >
      <Icon name="plus" className="size-4" />
      {t('categoryRules.add')}
    </Button>
  );

  let content;
  if (rules.isPending) {
    content = <LoadingState label={t('categoryRules.loading')} />;
  } else if (rules.isError) {
    content = hasErrorCode(rules.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('categoryRules.error')}
        error={rules.error}
        retrying={rules.isFetching}
        onRetry={() => {
          void rules.refetch();
        }}
      />
    );
  } else if (rules.data.length === 0) {
    content = (
      <EmptyState
        icon="sliders"
        title={t('categoryRules.empty.title')}
        description={t('categoryRules.empty.body')}
        action={addButton}
      />
    );
  } else {
    content = (
      <ol className="divide-y divide-line">
        {sortRules(rules.data).map((rule) => (
          <li
            key={rule.id}
            className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-start"
          >
            <div className="min-w-0 flex-1 space-y-1">
              <p className="font-medium text-fg">{rule.name}</p>
              <RuleDescription rule={rule} categories={byId} accounts={accountsById} />
              <div className="flex flex-wrap gap-2 pt-1">
                <StatusBadge icon="list">
                  {t('categoryRules.priority', { priority: rule.priority })}
                </StatusBadge>
                {rule.enabled ? null : (
                  <StatusBadge tone="warning" icon="pause">
                    {t('categoryRules.off')}
                  </StatusBadge>
                )}
              </div>
            </div>
            <div className="flex shrink-0 gap-2">
              <Button
                variant="secondary"
                size="sm"
                aria-label={`${t('common.edit')}: ${rule.name}`}
                onClick={() => {
                  setDialog({ kind: 'edit', rule });
                }}
              >
                <Icon name="pencil" className="size-4" />
                {t('common.edit')}
              </Button>
              <Menu>
                <MenuTrigger
                  className={triggerClasses}
                  aria-label={t('organize.actionsFor', { name: rule.name })}
                >
                  <Icon name="more-horizontal" />
                </MenuTrigger>
                <MenuContent>
                  <MenuItem
                    icon="refresh"
                    onSelect={() => {
                      setApplying(rule);
                    }}
                  >
                    {t('categoryRules.apply.action')}
                  </MenuItem>
                  <MenuItem
                    icon="trash"
                    tone="danger"
                    onSelect={() => {
                      setRemoveError(null);
                      setRemoving(rule);
                    }}
                  >
                    {t('categoryRules.delete.action')}
                  </MenuItem>
                </MenuContent>
              </Menu>
            </div>
          </li>
        ))}
      </ol>
    );
  }

  return (
    <>
      <PageHeader
        title={t('categoryRules.title')}
        description={t('categoryRules.description')}
        actions={addButton}
      />
      <OrganizeSubNav />
      <Card title={t('categoryRules.list.title')} description={t('categoryRules.list.order')}>
        {content}
      </Card>
      <RuleDialog
        mode={dialog}
        onClose={() => {
          setDialog(null);
        }}
      />
      <ApplyRuleDialog
        rule={applying}
        categories={byId}
        onClose={() => {
          setApplying(null);
        }}
      />
      <ConfirmDialog
        open={removing !== null}
        onOpenChange={(open) => {
          if (!open) setRemoving(null);
        }}
        title={t('categoryRules.delete.title')}
        description={t('categoryRules.delete.body', { name: removing?.name ?? '' })}
        confirmLabel={t('categoryRules.delete.confirm')}
        pending={remove.isPending}
        error={removeError}
        onConfirm={() => {
          if (!removing || remove.isPending) return;
          setRemoveError(null);
          remove.mutate(removing, {
            onSuccess: () => {
              toast.show({ tone: 'success', title: t('categoryRules.delete.done') });
              setRemoving(null);
            },
            onError: (error) => {
              if (hasErrorCode(error, 'NOT_FOUND')) {
                toast.show({ tone: 'info', title: t('categoryRules.notFound') });
                setRemoving(null);
              } else {
                setRemoveError(organizeErrorMessage(error, t, formatLocale));
              }
            },
          });
        }}
      />
    </>
  );
}
