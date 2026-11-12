import { zodResolver } from '@hookform/resolvers/zod';
import { type ReactNode, useMemo, useState } from 'react';
import { type Path, useController, useForm, useWatch } from 'react-hook-form';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { Disclosure } from '@/shared/components/Disclosure';
import { FieldError } from '@/shared/components/FieldParts';
import { MoneyField } from '@/shared/components/MoneyField';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { currencyOptions, exponentFor, useCurrencies } from '@/shared/currency/api';
import { detailCount, domainRuleCode, domainRuleMessage } from '@/shared/finance/domainErrors';
import { accountGroups, accountOptionLabel, categoryOptions } from '@/shared/finance/options';
import { useAccounts, useCategories } from '@/shared/finance/reference';
import { groupOptions, useGroupDetail, useGroups } from '@/shared/finance/sharing';
import type { BudgetAccess, BudgetType } from '@/shared/finance/types';
import { FormAlert } from '@/shared/forms/FormAlert';
import { formatBasisPoints } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { buildBudgetSchema, readAmounts } from '../budgetSchema';
import type { AlertsMode, AllocationValues, BudgetAmounts, BudgetFormValues } from '../formValues';
import {
  ALERT_THRESHOLDS,
  BUDGET_PERIODS,
  BUDGET_TYPES,
  DEFAULT_ALERT_THRESHOLDS,
  GROUP_BUDGET_TYPES,
  ROLLOVER_POLICIES,
  budgetTypeHelp,
  budgetTypeLabel,
  isBudgetType,
  isGroupBudgetType,
  isRolloverPolicy,
  periodLabel,
  rolloverLabel,
} from '../labels';
import { AllocationsEditor } from './AllocationsEditor';
import { CheckboxGroup } from './CheckboxGroup';
import { MerchantPicker } from './MerchantPicker';

/** API field (without `body.`) -> form field. Allocation errors are handled separately. */
const serverFields: Readonly<Record<string, Path<BudgetFormValues>>> = {
  name: 'name',
  budget_type: 'budgetType',
  period: 'period',
  starts_on: 'startsOn',
  ends_on: 'endsOn',
  currency: 'currency',
  limit: 'limit',
  rollover_policy: 'rolloverPolicy',
  rollover_cap: 'rolloverCap',
  included_account_ids: 'includedAccountIds',
  excluded_category_ids: 'excludedCategoryIds',
  merchant_ids: 'merchants',
  alert_thresholds: 'alertThresholds',
  group_id: 'groupId',
  visibility: 'visibility',
  notes: 'notes',
};

/** API allocation field -> form field (`body.allocations[i].<field>`). */
const allocationFields: Readonly<Record<string, keyof AllocationValues>> = {
  limit: 'limit',
  label: 'label',
  category_id: 'categoryId',
  merchant_id: 'merchantId',
  account_id: 'accountId',
  member_user_id: 'memberUserId',
};

const sectionLegend = 'mb-4 text-lg font-semibold text-fg';

interface BudgetFormProps {
  mode: 'create' | 'edit';
  initialValues: BudgetFormValues;
  submitLabel: string;
  secondaryAction?: ReactNode;
  /** Saves; rejects with the API error so the form can show it. */
  onSubmit: (values: BudgetFormValues, amounts: BudgetAmounts) => Promise<void>;
  /** Return true when the page handled an error itself (e.g. a version conflict). */
  onError?: (error: unknown) => boolean;
  /** The signed-in user's access (editors edit someone else's budget). */
  access?: BudgetAccess;
}

/** Renders once currencies, accounts and categories have loaded, so selects show saved values. */
export function BudgetForm(props: BudgetFormProps) {
  const { t } = useI18n();
  const currencies = useCurrencies();
  const accounts = useAccounts(true);
  const categories = useCategories();
  const failed = currencies.isError
    ? currencies.error
    : accounts.isError
      ? accounts.error
      : categories.isError
        ? categories.error
        : null;
  if (failed) {
    return (
      <ErrorState
        title={t('budgets.form.loadError')}
        error={failed}
        onRetry={() => {
          void currencies.refetch();
          void accounts.refetch();
          void categories.refetch();
        }}
      />
    );
  }
  if (currencies.isPending || accounts.isPending || categories.isPending) {
    return <LoadingState label={t('budgets.form.loading')} />;
  }
  return <BudgetFormInner {...props} />;
}

function BudgetFormInner({
  mode,
  initialValues,
  submitLabel,
  secondaryAction,
  onSubmit,
  onError,
  access = 'owner',
}: BudgetFormProps) {
  const { t, formatLocale } = useI18n();
  const currencies = useCurrencies();
  const accounts = useAccounts(true);
  const categories = useCategories();
  const groups = useGroups();
  const [formError, setFormError] = useState<string | null>(null);
  const [allocationError, setAllocationError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const schema = useMemo(
    () => buildBudgetSchema(t, formatLocale, (code) => exponentFor(currencies.data, code)),
    [t, formatLocale, currencies.data],
  );
  const form = useForm<BudgetFormValues, unknown, BudgetFormValues>({
    resolver: zodResolver(schema),
    defaultValues: initialValues,
  });
  const [budgetType, period, currency, groupId, rolloverPolicy, merchantValues] = useWatch({
    control: form.control,
    name: ['budgetType', 'period', 'currency', 'groupId', 'rolloverPolicy', 'merchants'],
  });
  const grouped = Boolean(groupId);
  const group = useGroupDetail(groupId || null);
  const typeField = useController({ control: form.control, name: 'budgetType' });
  const includedAccounts = useController({ control: form.control, name: 'includedAccountIds' });
  const excludedCategories = useController({ control: form.control, name: 'excludedCategoryIds' });
  const merchants = useController({ control: form.control, name: 'merchants' });
  const thresholds = useController({ control: form.control, name: 'alertThresholds' });
  const alertsMode = useController({ control: form.control, name: 'alertsMode' });
  const visibility = useController({ control: form.control, name: 'visibility' });
  const { errors } = form.formState;

  // Owned accounts; archived ones only when the budget already uses them.
  const keepAccounts = new Set([
    ...initialValues.includedAccountIds,
    ...initialValues.allocations.map((allocation) => allocation.accountId),
  ]);
  const ownedAccounts = (accounts.data ?? []).filter(
    (account) => account.owned && (account.status === 'active' || keepAccounts.has(account.id)),
  );
  const spendingCategories = categoryOptions(
    categories.data ?? [],
    t,
    formatLocale,
    (category) => category.kind !== 'income',
  );
  const memberChoices = (group.data?.members ?? [])
    .filter((member) => member.status === 'active')
    .map((member) => ({ value: member.user_id, label: member.display_name }));
  const thresholdChoices = ALERT_THRESHOLDS.map((value) => ({
    value: String(value),
    label: formatBasisPoints(value * 100, formatLocale),
  }));
  const typeChoices = grouped ? GROUP_BUDGET_TYPES : BUDGET_TYPES;
  const groupName = groups.data?.find((item) => item.id === groupId)?.name;

  const onValid = form.handleSubmit(async (values) => {
    if (submitting) return;
    setFormError(null);
    setAllocationError(null);
    const amounts = readAmounts(
      values,
      formatLocale,
      exponentFor(currencies.data, values.currency),
    );
    setSubmitting(true);
    try {
      await onSubmit(values, amounts);
    } catch (error) {
      if (onError?.(error)) return;
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest: string[] = [];
        const allocationMessages: string[] = [];
        let focused = false;
        for (const detail of error.details) {
          const field = detail.field?.replace(/^body\./, '') ?? '';
          const indexed = /^allocations\[(\d+)\]\.(\w+)$/.exec(field);
          const allocationField = indexed ? allocationFields[indexed[2] ?? ''] : undefined;
          const mapped = serverFields[field];
          if (indexed && allocationField) {
            form.setError(
              `allocations.${Number(indexed[1])}.${allocationField}`,
              { type: 'server', message: detail.message },
              { shouldFocus: !focused },
            );
            focused = true;
          } else if (field.startsWith('allocations')) {
            allocationMessages.push(detail.message);
          } else if (mapped) {
            form.setError(
              mapped,
              { type: 'server', message: detail.message },
              { shouldFocus: !focused },
            );
            focused = true;
          } else {
            rest.push(detail.message);
          }
        }
        if (allocationMessages.length > 0) setAllocationError(allocationMessages.join(' '));
        setFormError(
          rest.length > 0
            ? rest.join(' ')
            : error.details.length === 0
              ? t('errors.VALIDATION_ERROR')
              : t('budgets.form.checkFields'),
        );
      } else if (hasErrorCode(error, 'DOMAIN_RULE_VIOLATION')) {
        const rule = domainRuleCode(error);
        if (rule?.code === 'zero_based_unallocated') {
          const message = t('budgets.rule.zero_based_unallocated');
          setAllocationError(message);
          setFormError(message);
        } else if (rule?.code === 'group_budget_type_unsupported') {
          const message = t('budgets.rule.group_budget_type_unsupported');
          form.setError('budgetType', { type: 'server', message }, { shouldFocus: true });
          setFormError(message);
        } else if (rule?.code === 'group_budget_allocation_unsupported') {
          const message = t('budgets.rule.group_budget_allocation_unsupported');
          const index = detailCount(rule.params, 'index');
          if (index !== null && index < values.allocations.length) {
            form.setError(
              `allocations.${index}.target`,
              { type: 'server', message },
              { shouldFocus: true },
            );
          } else {
            setAllocationError(message);
          }
          setFormError(message);
        } else if (rule?.code === 'group_budget_filter_unsupported') {
          setFormError(t('budgets.rule.group_budget_filter_unsupported'));
        } else if (rule?.code === 'group_budget') {
          setFormError(t('budgets.rule.group_budget'));
        } else {
          setFormError(domainRuleMessage(error, t, formatLocale) ?? describeError(error, t));
        }
      } else if (hasErrorCode(error, 'NOT_FOUND')) {
        if (values.groupId) {
          form.setError('groupId', { type: 'server', message: t('budgets.form.groupNotFound') });
          setFormError(t('budgets.form.groupNotFound'));
        } else {
          setFormError(t('budgets.notFound'));
        }
      } else if (hasErrorCode(error, 'FORBIDDEN')) {
        setFormError(t('budgets.form.forbidden'));
      } else {
        setFormError(describeError(error, t));
      }
    } finally {
      setSubmitting(false);
    }
  });

  const typeValue: BudgetType = isBudgetType(typeField.field.value)
    ? typeField.field.value
    : 'total';
  const rolloverHelp = isRolloverPolicy(rolloverPolicy)
    ? t(`budgets.rollover.${rolloverPolicy}.help`)
    : undefined;

  return (
    <form onSubmit={onValid} noValidate className="space-y-10">
      <FormAlert message={formError} />
      {access === 'editor' ? (
        <Alert tone="info" title={t('budgets.form.editorTitle')}>
          {t('budgets.form.editorBody')}
        </Alert>
      ) : null}

      <fieldset className="space-y-5">
        <legend className={sectionLegend}>{t('budgets.form.basics')}</legend>
        <TextField
          label={t('budgets.form.name')}
          help={t('budgets.form.nameHelp')}
          maxLength={80}
          autoComplete="off"
          error={errors.name?.message}
          {...form.register('name')}
        />
        <RadioGroup<BudgetType>
          legend={t('budgets.form.type')}
          variant="cards"
          value={typeValue}
          onChange={(value) => {
            typeField.field.onChange(value);
          }}
          options={[
            ...typeChoices,
            // Keep a saved type visible so the form shows what the budget is today.
            ...(typeChoices.some((type) => type === typeValue) ? [] : [typeValue]),
          ].map((type) => ({
            value: type,
            label: t(budgetTypeLabel[type]),
            description: t(budgetTypeHelp[type]),
          }))}
          help={grouped ? t('budgets.form.groupTypesHelp') : undefined}
          error={errors.budgetType?.message}
        />
        <div className="grid gap-5 sm:grid-cols-2">
          <Select
            label={t('budgets.form.period')}
            options={BUDGET_PERIODS.map((value) => ({ value, label: t(periodLabel[value]) }))}
            error={errors.period?.message}
            {...form.register('period')}
          />
          <TextField
            label={t('budgets.form.startsOn')}
            help={t('budgets.form.startsOnHelp')}
            type="date"
            error={errors.startsOn?.message}
            {...form.register('startsOn')}
          />
          <TextField
            label={t('budgets.form.endsOn')}
            help={
              period === 'custom' ? t('budgets.form.endsOnCustom') : t('budgets.form.endsOnHelp')
            }
            type="date"
            optional={period !== 'custom'}
            error={errors.endsOn?.message}
            {...form.register('endsOn')}
          />
          {grouped ? (
            <div className="space-y-1.5">
              <p className="text-sm font-medium text-fg">{t('budgets.form.currency')}</p>
              <p className="text-fg">{currency}</p>
              <p className="text-sm text-fg-muted">{t('budgets.form.groupCurrency')}</p>
              {errors.currency?.message ? (
                <FieldError id="budget-currency-error">{errors.currency.message}</FieldError>
              ) : null}
            </div>
          ) : (
            <Select
              label={t('budgets.form.currency')}
              options={currencyOptions(currencies.data, formatLocale, initialValues.currency)}
              error={errors.currency?.message}
              {...form.register('currency')}
            />
          )}
          <MoneyField
            label={t('budgets.form.limit')}
            help={
              budgetType === 'zero_based'
                ? t('budgets.form.limitZeroBased')
                : t('budgets.form.limitHelp')
            }
            currency={currency || null}
            error={errors.limit?.message}
            {...form.register('limit')}
          />
        </div>
      </fieldset>

      <fieldset className="space-y-5">
        <legend className={sectionLegend}>{t('budgets.form.whatCounts')}</legend>
        {grouped ? (
          <p className="text-sm text-fg-muted">{t('budgets.form.groupCounts')}</p>
        ) : (
          <>
            <CheckboxGroup
              legend={t('budgets.form.accounts')}
              help={
                budgetType === 'account'
                  ? t('budgets.form.accountsRequiredHelp')
                  : t('budgets.form.accountsHelp')
              }
              columns={2}
              choices={ownedAccounts.map((account) => ({
                value: account.id,
                label: accountOptionLabel(account),
              }))}
              value={includedAccounts.field.value}
              onChange={includedAccounts.field.onChange}
              error={errors.includedAccountIds?.message}
            />
            {budgetType === 'merchant' || merchantValues.length > 0 ? (
              <MerchantPicker
                legend={t('budgets.form.merchants')}
                help={t('budgets.form.merchantsHelp')}
                value={merchants.field.value}
                onChange={merchants.field.onChange}
                error={errors.merchants?.message}
              />
            ) : null}
            <Disclosure
              summary={t('budgets.form.excludeCategories')}
              defaultOpen={initialValues.excludedCategoryIds.length > 0}
            >
              <CheckboxGroup
                legend={t('budgets.form.excluded')}
                help={t('budgets.form.excludedHelp')}
                scroll
                columns={2}
                choices={spendingCategories}
                value={excludedCategories.field.value}
                onChange={excludedCategories.field.onChange}
                error={errors.excludedCategoryIds?.message}
              />
            </Disclosure>
          </>
        )}
        <div className="space-y-4">
          <Checkbox
            label={t('budgets.form.includePending')}
            description={t('budgets.form.includePendingHelp')}
            {...form.register('includePending')}
          />
          <Checkbox
            label={t('budgets.form.refundsRestore')}
            description={t('budgets.form.refundsRestoreHelp')}
            {...form.register('refundsRestore')}
          />
          {grouped ? null : (
            <Checkbox
              label={t('budgets.form.countGroupShares')}
              description={t('budgets.form.countGroupSharesHelp')}
              {...form.register('countGroupShares')}
            />
          )}
        </div>
      </fieldset>

      <AllocationsEditor
        form={form}
        budgetType={budgetType}
        grouped={grouped}
        currency={currency}
        categoryChoices={spendingCategories}
        accountChoices={accountGroups(ownedAccounts, t)}
        memberChoices={memberChoices}
        error={allocationError ?? undefined}
      />

      <fieldset className="space-y-5">
        <legend className={sectionLegend}>{t('budgets.form.rollover')}</legend>
        <div className="grid gap-5 sm:grid-cols-2">
          <Select
            label={t('budgets.form.rolloverPolicy')}
            help={rolloverHelp}
            options={ROLLOVER_POLICIES.map((value) => ({ value, label: t(rolloverLabel[value]) }))}
            error={errors.rolloverPolicy?.message}
            {...form.register('rolloverPolicy')}
          />
          {rolloverPolicy !== 'none' ? (
            <MoneyField
              label={t('budgets.form.rolloverCap')}
              help={t('budgets.form.rolloverCapHelp')}
              optional
              currency={currency || null}
              error={errors.rolloverCap?.message}
              {...form.register('rolloverCap')}
            />
          ) : null}
        </div>
      </fieldset>

      <fieldset className="space-y-5">
        <legend className={sectionLegend}>{t('budgets.form.alerts')}</legend>
        <RadioGroup<AlertsMode>
          legend={t('budgets.form.thresholdAlerts')}
          variant="cards"
          value={alertsMode.field.value}
          onChange={(value) => {
            alertsMode.field.onChange(value);
            if (value === 'levels' && thresholds.field.value.length === 0) {
              thresholds.field.onChange([...DEFAULT_ALERT_THRESHOLDS]);
            }
          }}
          options={[
            { value: 'levels', label: t('budgets.form.thresholdsOn') },
            {
              value: 'off',
              label: t('budgets.form.thresholdsOff'),
              description: t('budgets.form.thresholdsOffHelp'),
            },
          ]}
        />
        {alertsMode.field.value === 'levels' ? (
          <CheckboxGroup
            legend={t('budgets.form.thresholds')}
            help={t('budgets.form.thresholdsHelp')}
            columns={3}
            choices={thresholdChoices}
            value={thresholds.field.value.map(String)}
            onChange={(value) => {
              thresholds.field.onChange(value.map(Number).sort((a, b) => a - b));
            }}
            error={errors.alertThresholds?.message}
          />
        ) : null}
        <Checkbox
          label={t('budgets.form.alertForecast')}
          description={t('budgets.form.alertForecastHelp')}
          {...form.register('alertForecast')}
        />
      </fieldset>

      <fieldset className="space-y-5">
        <legend className={sectionLegend}>{t('budgets.form.sharing')}</legend>
        {mode === 'create' ? (
          <Select
            label={t('budgets.form.group')}
            help={t('budgets.form.groupHelp')}
            optional
            placeholder={t('budgets.form.noGroup')}
            options={groupOptions(groups.data)}
            error={errors.groupId?.message}
            {...form.register('groupId', {
              onChange: (event: { target: { value: string } }) => {
                const chosen = groups.data?.find((item) => item.id === event.target.value);
                if (chosen) {
                  form.setValue('currency', chosen.base_currency);
                  form.setValue('visibility', 'members');
                  // Group budgets are a total, envelopes or zero-based.
                  if (!isGroupBudgetType(form.getValues('budgetType'))) {
                    form.setValue('budgetType', 'total');
                  }
                } else {
                  form.setValue('visibility', 'private');
                }
              },
            })}
          />
        ) : grouped ? (
          <p className="text-sm text-fg">
            {t('budgets.form.groupLocked', { name: groupName ?? t('budgets.form.groupUnknown') })}
          </p>
        ) : null}
        {grouped ? (
          <RadioGroup<'private' | 'members'>
            legend={t('budgets.form.visibility')}
            variant="cards"
            value={visibility.field.value}
            onChange={visibility.field.onChange}
            options={[
              {
                value: 'members',
                label: t('budgets.visibility.members'),
                description: t('budgets.visibility.members.help'),
              },
              {
                value: 'private',
                label: t('budgets.visibility.private'),
                description: t('budgets.visibility.private.help'),
              },
            ]}
            error={errors.visibility?.message}
          />
        ) : (
          <p className="text-sm text-fg-muted">{t('budgets.form.shareLater')}</p>
        )}
      </fieldset>

      <TextArea
        label={t('budgets.form.notes')}
        optional
        maxLength={1000}
        error={errors.notes?.message}
        {...form.register('notes')}
      />

      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        {secondaryAction}
        <Button type="submit" loading={submitting}>
          {submitLabel}
        </Button>
      </div>
    </form>
  );
}
