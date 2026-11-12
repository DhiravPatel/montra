import { zodResolver } from '@hookform/resolvers/zod';
import { type ReactNode, useMemo, useState } from 'react';
import { Controller, FormProvider, useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { MoneyField } from '@/shared/components/MoneyField';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { currencyOptions, exponentFor, useCurrencies } from '@/shared/currency/api';
import { categoryFitsType } from '@/shared/finance/categories';
import { accountGroups, categoryOptions } from '@/shared/finance/options';
import { useAccounts, useCategories } from '@/shared/finance/reference';
import type { RecurringRule, RecurringRuleInput, RecurringRulePatch } from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { normalizeDecimalInput } from '@/shared/formatting/decimal';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { planningErrorMessage } from '../errors';
import { type RuleFormValues, accountChoices } from '../formValues';
import { EDITABLE_KINDS, type EditableKind, recurringKindLabel } from '../labels';
import { rulePatchFrom } from '../patches';
import { scheduleSchema, toScheduleInput } from '../schedule';
import { RecurrenceFields } from './RecurrenceFields';

interface RecurringRuleFormBaseProps {
  initialValues: RuleFormValues;
  /** Return true when the page handled an error itself (e.g. a version conflict). */
  onError?: (error: unknown) => boolean;
  submitLabel: string;
  secondaryAction?: ReactNode;
}

/**
 * Create sends the whole rule; edit sends only what changed (a partial
 * PATCH built against the rule on screen; its kind and time zone are kept).
 * `onSubmit` rejects with the API error so the form can show it.
 */
type RecurringRuleFormProps = RecurringRuleFormBaseProps &
  (
    | {
        mode: 'create';
        rule?: undefined;
        onSubmit: (input: RecurringRuleInput) => Promise<void>;
      }
    | {
        mode: 'edit';
        rule: RecurringRule;
        onSubmit: (patch: RecurringRulePatch) => Promise<void>;
      }
  );

const serverFields = {
  name: 'name',
  kind: 'kind',
  amount: 'amount',
  account_id: 'accountId',
  to_account_id: 'toAccountId',
  currency: 'currency',
  category_id: 'categoryId',
  merchant_name: 'merchantName',
  description: 'description',
  notes: 'notes',
  frequency: 'schedule.frequency',
  interval_count: 'schedule.intervalCount',
  interval_unit: 'schedule.intervalUnit',
  by_month_day: 'schedule.monthDay',
  by_weekday: 'schedule.weekday',
  by_week_of_month: 'schedule.weekOfMonth',
  start_date: 'schedule.startDate',
  end_date: 'schedule.endDate',
  max_occurrences: 'schedule.maxOccurrences',
  local_time: 'schedule.localTime',
  reminder_days_before: 'schedule.reminders',
} as const;

/** Waits for currencies, accounts and categories so the selects show saved values. */
export function RecurringRuleForm(props: RecurringRuleFormProps) {
  const { t } = useI18n();
  const currencies = useCurrencies();
  const accounts = useAccounts(true);
  const categories = useCategories();
  const failed = [currencies, accounts, categories].find((query) => query.isError);
  if (failed) {
    return (
      <ErrorState
        title={t('recurring.form.loadFailed')}
        error={failed.error}
        retrying={failed.isFetching}
        onRetry={() => {
          void failed.refetch();
        }}
      />
    );
  }
  if (currencies.isPending || accounts.isPending || categories.isPending) {
    return <LoadingState label={t('recurring.form.loading')} />;
  }
  return <RecurringRuleFormInner {...props} />;
}

function buildSchema(
  t: Translate,
  locale: string,
  currencyOf: (values: { accountId: string; currency: string }) => string,
  exponent: (currency: string) => number,
) {
  return z
    .object({
      kind: z.enum(EDITABLE_KINDS),
      name: z
        .string()
        .trim()
        .min(1, { error: t('recurring.form.nameRequired') })
        .max(120, { error: t('validation.maxLength', { max: 120 }) }),
      amount: z.string(),
      variable: z.boolean(),
      accountId: z.string(),
      toAccountId: z.string(),
      currency: z.string(),
      categoryId: z.string(),
      merchantName: z
        .string()
        .trim()
        .max(120, { error: t('validation.maxLength', { max: 120 }) }),
      description: z
        .string()
        .trim()
        .max(500, { error: t('validation.maxLength', { max: 500 }) }),
      notes: z.string().max(2000, { error: t('validation.maxLength', { max: 2000 }) }),
      autoPost: z.boolean(),
      schedule: scheduleSchema(t),
    })
    .superRefine((values, ctx) => {
      const issue = (path: string, message: string) => {
        ctx.addIssue({ code: 'custom', path: [path], message });
      };
      if (values.kind === 'transfer') {
        if (!values.accountId) issue('accountId', t('recurring.form.fromAccountRequired'));
        if (!values.toAccountId) issue('toAccountId', t('recurring.form.toAccountRequired'));
        else if (values.toAccountId === values.accountId) {
          issue('toAccountId', t('recurring.form.sameAccount'));
        }
      }
      if (values.autoPost) {
        if (values.variable) issue('autoPost', t('recurring.form.autoPostNeedsFixed'));
        else if (!values.accountId) issue('accountId', t('recurring.form.autoPostNeedsAccount'));
      }
      const currency = currencyOf(values);
      if (!/^[A-Z]{3}$/.test(currency)) {
        issue('currency', t('validation.currencyRequired'));
        return;
      }
      if (values.variable) return;
      checkAmount(ctx, {
        value: values.amount,
        path: 'amount',
        locale,
        currency,
        exponent: exponent(currency),
        t,
      });
    });
}

function RecurringRuleFormInner(props: RecurringRuleFormProps) {
  const { mode, initialValues, rule, onError, submitLabel, secondaryAction } = props;
  const { t, formatLocale } = useI18n();
  const currencies = useCurrencies();
  const accounts = useAccounts(true);
  const categories = useCategories();
  const [formError, setFormError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const accountList = accounts.data;
  const schema = useMemo(() => {
    const currencyOf = (values: { accountId: string; currency: string }) =>
      accountList?.find((account) => account.id === values.accountId)?.currency ?? values.currency;
    return buildSchema(t, formatLocale, currencyOf, (code) => exponentFor(currencies.data, code));
  }, [t, formatLocale, accountList, currencies.data]);

  const form = useForm<RuleFormValues, unknown, RuleFormValues>({
    resolver: zodResolver(schema),
    defaultValues: initialValues,
  });
  const [kind, accountId, currencyValue, variable] = useWatch({
    control: form.control,
    name: ['kind', 'accountId', 'currency', 'variable'],
  });
  const account = accountList?.find((item) => item.id === accountId);
  const currency = account?.currency ?? currencyValue;
  const transfer = kind === 'transfer';

  const onValid = form.handleSubmit(async (values) => {
    if (submitting) return;
    setFormError(null);
    const chosen = accountList?.find((item) => item.id === values.accountId);
    const code = chosen?.currency ?? values.currency;
    const amount =
      !values.variable && values.amount.trim()
        ? normalizeDecimalInput(values.amount, formatLocale, {
            exponent: exponentFor(currencies.data, code),
          })
        : null;
    const isTransfer = values.kind === 'transfer';
    const input: RecurringRuleInput = {
      kind: values.kind,
      name: values.name.trim(),
      ...toScheduleInput(values.schedule, rule?.timezone),
      amount_is_variable: values.variable,
      auto_post: values.autoPost,
      ...(amount?.ok ? { amount: amount.value } : {}),
      // With an account the API uses the account's currency.
      ...(values.accountId ? { account_id: values.accountId } : { currency: code }),
      ...(isTransfer && values.toAccountId ? { to_account_id: values.toAccountId } : {}),
      ...(!isTransfer && values.categoryId ? { category_id: values.categoryId } : {}),
      ...(!isTransfer && values.merchantName.trim()
        ? { merchant_name: values.merchantName.trim() }
        : {}),
      ...(values.description.trim() ? { description: values.description.trim() } : {}),
      ...(values.notes.trim() ? { notes: values.notes.trim() } : {}),
    };
    setSubmitting(true);
    try {
      if (props.mode === 'edit') await props.onSubmit(rulePatchFrom(props.rule, input, code));
      else await props.onSubmit(input);
    } catch (error) {
      if (onError?.(error)) return;
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, serverFields);
        setFormError(
          rest.length > 0
            ? rest.join(' ')
            : error.details.length === 0
              ? t('errors.VALIDATION_ERROR')
              : null,
        );
      } else {
        setFormError(planningErrorMessage(error, t, formatLocale));
      }
    } finally {
      setSubmitting(false);
    }
  });

  const { errors } = form.formState;
  const choices = accountChoices(accountList, [initialValues.accountId, initialValues.toAccountId]);
  const groups = accountGroups(choices, t);
  const categoryType = kind === 'income' ? 'income' : 'expense';
  const categoryChoices = categoryOptions(categories.data ?? [], t, formatLocale, (category) =>
    categoryFitsType(category, categoryType),
  );

  return (
    <FormProvider {...form}>
      <form onSubmit={onValid} noValidate className="space-y-6">
        <FormAlert message={formError} />
        <Controller
          control={form.control}
          name="kind"
          render={({ field }) => (
            <RadioGroup<EditableKind>
              legend={t('recurring.form.kind')}
              value={field.value}
              onChange={field.onChange}
              disabled={mode === 'edit'}
              help={mode === 'edit' ? t('recurring.form.kindLocked') : undefined}
              options={EDITABLE_KINDS.map((value) => ({
                value,
                label: t(recurringKindLabel[value]),
              }))}
            />
          )}
        />
        <TextField
          label={t('recurring.form.name')}
          help={t('recurring.form.nameHelp')}
          maxLength={120}
          autoComplete="off"
          error={errors.name?.message}
          {...form.register('name')}
        />
        <div className="grid gap-5 sm:grid-cols-2">
          <Select
            label={transfer ? t('recurring.form.fromAccount') : t('recurring.form.account')}
            optional={!transfer}
            placeholder={transfer ? t('recurring.form.accountChoose') : t('common.none')}
            groups={groups}
            help={transfer ? undefined : t('recurring.form.accountHelp')}
            error={errors.accountId?.message}
            {...form.register('accountId')}
          />
          {transfer ? (
            <Select
              label={t('recurring.form.toAccount')}
              placeholder={t('recurring.form.accountChoose')}
              groups={groups}
              error={errors.toAccountId?.message}
              {...form.register('toAccountId')}
            />
          ) : account ? (
            <div className="space-y-1.5">
              <p className="text-sm font-medium text-fg">{t('recurring.form.currency')}</p>
              <p className="text-sm text-fg-muted">
                {t('recurring.form.currencyFromAccount', { currency: account.currency })}
              </p>
            </div>
          ) : (
            <Select
              label={t('recurring.form.currency')}
              placeholder={t('auth.fields.currencyPlaceholder')}
              options={currencyOptions(currencies.data, formatLocale, initialValues.currency)}
              error={errors.currency?.message}
              {...form.register('currency')}
            />
          )}
        </div>
        <div className="space-y-4">
          <Checkbox
            label={t('recurring.form.variable')}
            description={t('recurring.form.variableHelp')}
            {...form.register('variable')}
          />
          {variable ? null : (
            <MoneyField
              label={t('recurring.form.amount')}
              currency={currency || null}
              help={
                transfer ? t('recurring.form.amountTransferHelp') : t('recurring.form.amountHelp')
              }
              error={errors.amount?.message}
              {...form.register('amount')}
            />
          )}
        </div>
        {transfer ? null : (
          <div className="grid gap-5 sm:grid-cols-2">
            <Select
              label={t('recurring.form.category')}
              optional
              placeholder={t('common.none')}
              options={categoryChoices}
              error={errors.categoryId?.message}
              {...form.register('categoryId')}
            />
            <TextField
              label={kind === 'income' ? t('recurring.form.payer') : t('recurring.form.payee')}
              optional
              maxLength={120}
              autoComplete="off"
              error={errors.merchantName?.message}
              {...form.register('merchantName')}
            />
          </div>
        )}
        <TextField
          label={t('recurring.form.description')}
          optional
          maxLength={500}
          autoComplete="off"
          error={errors.description?.message}
          {...form.register('description')}
        />
        <RecurrenceFields />
        <Checkbox
          label={t('recurring.form.autoPost')}
          description={t('recurring.form.autoPostHelp')}
          error={errors.autoPost?.message}
          {...form.register('autoPost')}
        />
        <TextArea
          label={t('recurring.form.notes')}
          optional
          maxLength={2000}
          help={t('finance.sensitiveHint')}
          error={errors.notes?.message}
          {...form.register('notes')}
        />
        {mode === 'edit' ? (
          <p className="text-sm text-fg-muted">{t('recurring.edit.futureNote')}</p>
        ) : null}
        <div className="flex flex-wrap items-center gap-3">
          <Button type="submit" loading={submitting}>
            {submitLabel}
          </Button>
          {secondaryAction}
        </div>
      </form>
    </FormProvider>
  );
}
