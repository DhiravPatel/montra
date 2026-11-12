import { zodResolver } from '@hookform/resolvers/zod';
import { type ReactNode, useMemo, useState } from 'react';
import { FormProvider, useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { MoneyField } from '@/shared/components/MoneyField';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { currencyOptions, exponentFor, useCurrencies } from '@/shared/currency/api';
import { categoryFitsType } from '@/shared/finance/categories';
import { accountGroups, categoryOptions } from '@/shared/finance/options';
import { useAccounts, useCategories } from '@/shared/finance/reference';
import type { Bill, BillInput, BillPatch } from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { normalizeDecimalInput } from '@/shared/formatting/decimal';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { planningErrorMessage } from '../errors';
import { type BillFormValues, accountChoices } from '../formValues';
import { billPatchFrom } from '../patches';
import { scheduleSchema, toScheduleInput } from '../schedule';
import { RecurrenceFields } from './RecurrenceFields';

interface BillFormBaseProps {
  initialValues: BillFormValues;
  /** Return true when the page handled an error itself (e.g. a version conflict). */
  onError?: (error: unknown) => boolean;
  submitLabel: string;
  secondaryAction?: ReactNode;
}

/**
 * Create sends the whole bill; edit sends only what changed (a partial
 * PATCH built against the bill on screen; fields the form does not show,
 * like the attached document, are left as they are). `onSubmit` rejects
 * with the API error so the form can show it.
 */
type BillFormProps = BillFormBaseProps &
  (
    | { mode: 'create'; bill?: undefined; onSubmit: (input: BillInput) => Promise<void> }
    | { mode: 'edit'; bill: Bill; onSubmit: (patch: BillPatch) => Promise<void> }
  );

/**
 * API field (without `body.`) -> form field. Bills are validated like their
 * schedule, so some errors name the schedule's fields (amount, account_id,
 * merchant_name) instead of the bill's.
 */
const serverFields = {
  name: 'name',
  provider_name: 'providerName',
  merchant_name: 'providerName',
  expected_amount: 'amount',
  amount: 'amount',
  payment_account_id: 'accountId',
  account_id: 'accountId',
  currency: 'currency',
  category_id: 'categoryId',
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
export function BillForm(props: BillFormProps) {
  const { t } = useI18n();
  const currencies = useCurrencies();
  const accounts = useAccounts(true);
  const categories = useCategories();
  const failed = [currencies, accounts, categories].find((query) => query.isError);
  if (failed) {
    return (
      <ErrorState
        title={t('bills.form.loadFailed')}
        error={failed.error}
        retrying={failed.isFetching}
        onRetry={() => {
          void failed.refetch();
        }}
      />
    );
  }
  if (currencies.isPending || accounts.isPending || categories.isPending) {
    return <LoadingState label={t('bills.form.loading')} />;
  }
  return <BillFormInner {...props} />;
}

function buildSchema(
  t: Translate,
  locale: string,
  currencyOf: (values: { accountId: string; currency: string }) => string,
  exponent: (currency: string) => number,
) {
  return z
    .object({
      name: z
        .string()
        .trim()
        .min(1, { error: t('bills.form.nameRequired') })
        .max(120, { error: t('validation.maxLength', { max: 120 }) }),
      providerName: z
        .string()
        .trim()
        .max(120, { error: t('validation.maxLength', { max: 120 }) }),
      amount: z.string(),
      variable: z.boolean(),
      accountId: z.string(),
      currency: z.string(),
      categoryId: z.string(),
      notes: z.string().max(2000, { error: t('validation.maxLength', { max: 2000 }) }),
      schedule: scheduleSchema(t),
    })
    .superRefine((values, ctx) => {
      const currency = currencyOf(values);
      if (!/^[A-Z]{3}$/.test(currency)) {
        ctx.addIssue({
          code: 'custom',
          path: ['currency'],
          message: t('validation.currencyRequired'),
        });
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

function BillFormInner(props: BillFormProps) {
  const { mode, initialValues, bill, onError, submitLabel, secondaryAction } = props;
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

  const form = useForm<BillFormValues, unknown, BillFormValues>({
    resolver: zodResolver(schema),
    defaultValues: initialValues,
  });
  const [accountId, currencyValue, variable] = useWatch({
    control: form.control,
    name: ['accountId', 'currency', 'variable'],
  });
  const account = accountList?.find((item) => item.id === accountId);
  const currency = account?.currency ?? currencyValue;

  const onValid = form.handleSubmit(async (values) => {
    if (submitting) return;
    setFormError(null);
    const chosen = accountList?.find((item) => item.id === values.accountId);
    const code = chosen?.currency ?? values.currency;
    const amount = values.amount.trim()
      ? normalizeDecimalInput(values.amount, formatLocale, {
          exponent: exponentFor(currencies.data, code),
        })
      : null;
    const expected = amount?.ok ? amount.value : null;
    const input: BillInput = {
      name: values.name.trim(),
      ...toScheduleInput(values.schedule, bill?.schedule.timezone),
      amount_is_variable: values.variable,
      currency: code,
      ...(expected && !values.variable ? { expected_amount: expected } : {}),
      ...(values.providerName.trim() ? { provider_name: values.providerName.trim() } : {}),
      ...(values.accountId ? { payment_account_id: values.accountId } : {}),
      ...(values.categoryId ? { category_id: values.categoryId } : {}),
      ...(values.notes.trim() ? { notes: values.notes.trim() } : {}),
    };
    setSubmitting(true);
    try {
      if (props.mode === 'edit') await props.onSubmit(billPatchFrom(props.bill, input));
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
  const choices = accountChoices(accountList, [initialValues.accountId]);
  const expenseCategories = categoryOptions(categories.data ?? [], t, formatLocale, (category) =>
    categoryFitsType(category, 'expense'),
  );

  return (
    <FormProvider {...form}>
      <form onSubmit={onValid} noValidate className="space-y-6">
        <FormAlert message={formError} />
        <div className="grid gap-5 sm:grid-cols-2">
          <TextField
            label={t('bills.form.name')}
            help={t('bills.form.nameHelp')}
            maxLength={120}
            autoComplete="off"
            error={errors.name?.message}
            {...form.register('name')}
          />
          <TextField
            label={t('bills.form.provider')}
            help={t('bills.form.providerHelp')}
            optional
            maxLength={120}
            autoComplete="off"
            error={errors.providerName?.message}
            {...form.register('providerName')}
          />
        </div>
        <div className="grid gap-5 sm:grid-cols-2">
          <Select
            label={t('bills.form.account')}
            optional
            placeholder={t('common.none')}
            groups={accountGroups(choices, t)}
            help={t('bills.form.accountHelp')}
            error={errors.accountId?.message}
            {...form.register('accountId')}
          />
          {account ? (
            <div className="space-y-1.5">
              <p className="text-sm font-medium text-fg">{t('bills.form.currency')}</p>
              <p className="text-sm text-fg-muted">
                {t('bills.form.currencyFromAccount', { currency: account.currency })}
              </p>
            </div>
          ) : (
            <Select
              label={t('bills.form.currency')}
              placeholder={t('auth.fields.currencyPlaceholder')}
              options={currencyOptions(currencies.data, formatLocale, initialValues.currency)}
              error={errors.currency?.message}
              {...form.register('currency')}
            />
          )}
        </div>
        <div className="space-y-4">
          <Checkbox
            label={t('bills.form.variable')}
            description={t('bills.form.variableHelp')}
            {...form.register('variable')}
          />
          {variable ? null : (
            <MoneyField
              label={t('bills.form.amount')}
              currency={currency || null}
              help={t('bills.form.amountHelp')}
              error={errors.amount?.message}
              {...form.register('amount')}
            />
          )}
        </div>
        <Select
          label={t('bills.form.category')}
          optional
          placeholder={t('common.none')}
          options={expenseCategories}
          error={errors.categoryId?.message}
          {...form.register('categoryId')}
        />
        <RecurrenceFields />
        <TextArea
          label={t('bills.form.notes')}
          optional
          maxLength={2000}
          help={t('finance.sensitiveHint')}
          error={errors.notes?.message}
          {...form.register('notes')}
        />
        {mode === 'edit' ? (
          <p className="text-sm text-fg-muted">{t('bills.edit.futureNote')}</p>
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
