import { useId } from 'react';
import { type UseFormReturn, useFieldArray, useWatch } from 'react-hook-form';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { FieldError } from '@/shared/components/FieldParts';
import { Icon } from '@/shared/components/Icon';
import { MoneyField } from '@/shared/components/MoneyField';
import { Select, type SelectGroup, type SelectOption } from '@/shared/components/Select';
import { TextField } from '@/shared/components/TextField';
import { useT } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import {
  type AllocationTarget,
  type BudgetFormValues,
  allowedAllocationTargets,
  defaultAllocationTarget,
  emptyAllocation,
} from '../formValues';
import { MerchantPicker } from './MerchantPicker';

const targetLabel: Readonly<Record<AllocationTarget, MessageKey>> = {
  category: 'budgets.form.alloc.target.category',
  merchant: 'budgets.form.alloc.target.merchant',
  account: 'budgets.form.alloc.target.account',
  member: 'budgets.form.alloc.target.member',
  label: 'budgets.form.alloc.target.label',
};

interface AllocationsEditorProps {
  form: UseFormReturn<BudgetFormValues, unknown, BudgetFormValues>;
  budgetType: string;
  /** Group budgets can split the limit between members. */
  grouped: boolean;
  currency: string;
  categoryChoices: readonly SelectOption[];
  accountChoices: readonly SelectGroup[];
  memberChoices: readonly SelectOption[];
  /** Problems with the list as a whole (from the form or the API). */
  error?: string | undefined;
}

/** Sub-limits of a budget: by category, merchant, account, group member or a label. */
export function AllocationsEditor({
  form,
  budgetType,
  grouped,
  currency,
  categoryChoices,
  accountChoices,
  memberChoices,
  error,
}: AllocationsEditorProps) {
  const t = useT();
  const errorId = useId();
  const { fields, append, remove } = useFieldArray({ control: form.control, name: 'allocations' });
  const rows = useWatch({ control: form.control, name: 'allocations' });
  const { errors, isSubmitted } = form.formState;
  const listError = errors.allocations?.root?.message ?? errors.allocations?.message;
  const required =
    budgetType === 'category' || budgetType === 'envelope' || budgetType === 'zero_based';

  const allowed = allowedAllocationTargets(budgetType, grouped);
  let help: string;
  if (grouped) help = t('budgets.form.alloc.help.group');
  else if (budgetType === 'category') help = t('budgets.form.alloc.help.category');
  else if (budgetType === 'envelope') help = t('budgets.form.alloc.help.envelope');
  else if (budgetType === 'zero_based') help = t('budgets.form.alloc.help.zero_based');
  else help = t('budgets.form.alloc.help.optional');

  return (
    <fieldset className="space-y-4">
      <legend className="text-base font-semibold text-fg">
        {t('budgets.form.allocations')}
        {required ? null : (
          <span className="font-normal text-fg-muted"> ({t('common.optional')})</span>
        )}
      </legend>
      <p className="text-sm text-fg-muted">{help}</p>
      {fields.length > 0 ? (
        <ol className="space-y-4">
          {fields.map((field, index) => {
            const row = rows[index] ?? field;
            const rowErrors = errors.allocations?.[index];
            // A saved target that no longer fits stays listed (flagged by validation) so it can be changed.
            const targets: AllocationTarget[] = allowed.includes(row.target)
              ? allowed
              : [...allowed, row.target];
            const number = index + 1;
            let picker = null;
            if (row.target === 'category') {
              picker = (
                <Select
                  label={t('budgets.form.alloc.category')}
                  placeholder={t('budgets.form.alloc.categoryPlaceholder')}
                  options={categoryChoices}
                  error={rowErrors?.categoryId?.message}
                  {...form.register(`allocations.${index}.categoryId`)}
                />
              );
            } else if (row.target === 'account') {
              picker = (
                <Select
                  label={t('budgets.form.alloc.account')}
                  placeholder={t('budgets.form.alloc.accountPlaceholder')}
                  groups={accountChoices}
                  error={rowErrors?.accountId?.message}
                  {...form.register(`allocations.${index}.accountId`)}
                />
              );
            } else if (row.target === 'member') {
              picker = (
                <Select
                  label={t('budgets.form.alloc.member')}
                  placeholder={t('budgets.form.alloc.memberPlaceholder')}
                  options={memberChoices}
                  error={rowErrors?.memberUserId?.message}
                  {...form.register(`allocations.${index}.memberUserId`)}
                />
              );
            } else if (row.target === 'merchant') {
              picker = (
                <MerchantPicker
                  single
                  legend={t('budgets.form.alloc.merchant')}
                  error={rowErrors?.merchantId?.message}
                  value={row.merchantId ? [{ id: row.merchantId, name: row.merchantName }] : []}
                  onChange={(choices) => {
                    const [choice] = choices;
                    form.setValue(`allocations.${index}.merchantName`, choice?.name ?? '');
                    form.setValue(`allocations.${index}.merchantId`, choice?.id ?? '', {
                      shouldValidate: isSubmitted,
                    });
                  }}
                />
              );
            }
            return (
              <li key={field.id}>
                <fieldset className="space-y-4 rounded-lg border border-line p-4">
                  <legend className="px-1 text-sm font-medium text-fg">
                    {t('budgets.form.alloc.legend', { number })}
                  </legend>
                  <div className="grid gap-4 sm:grid-cols-2">
                    <Select
                      label={t('budgets.form.alloc.target')}
                      options={targets.map((target) => ({
                        value: target,
                        label: t(targetLabel[target]),
                      }))}
                      error={rowErrors?.target?.message}
                      {...form.register(`allocations.${index}.target`)}
                    />
                    {picker}
                    <TextField
                      label={t('budgets.form.alloc.label')}
                      optional={row.target !== 'label'}
                      maxLength={80}
                      autoComplete="off"
                      error={rowErrors?.label?.message}
                      {...form.register(`allocations.${index}.label`)}
                    />
                    <MoneyField
                      label={t('budgets.form.alloc.limit')}
                      currency={currency || null}
                      error={rowErrors?.limit?.message}
                      {...form.register(`allocations.${index}.limit`)}
                    />
                  </div>
                  <div className="flex justify-end">
                    <Button
                      variant="ghost"
                      size="sm"
                      aria-label={t('budgets.form.alloc.removeNumber', { number })}
                      onClick={() => {
                        remove(index);
                      }}
                    >
                      <Icon name="trash" className="size-4" />
                      {t('budgets.form.alloc.remove')}
                    </Button>
                  </div>
                </fieldset>
              </li>
            );
          })}
        </ol>
      ) : (
        <p className="rounded-md border border-dashed border-line px-4 py-4 text-sm text-fg-muted">
          {t('budgets.form.alloc.none')}
        </p>
      )}
      {error ? (
        <Alert tone="danger" live="assertive">
          {error}
        </Alert>
      ) : null}
      {listError ? <FieldError id={errorId}>{listError}</FieldError> : null}
      <Button
        variant="secondary"
        onClick={() => {
          append(emptyAllocation(defaultAllocationTarget(budgetType, grouped)));
        }}
      >
        <Icon name="plus" className="size-4" />
        {t('budgets.form.alloc.add')}
      </Button>
    </fieldset>
  );
}
