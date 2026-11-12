import { zodResolver } from '@hookform/resolvers/zod';
import { type ReactNode, useMemo, useState } from 'react';
import { Controller, useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { MoneyField } from '@/shared/components/MoneyField';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { currencyOptions, exponentFor, useCurrencies } from '@/shared/currency/api';
import { categoryFitsType } from '@/shared/finance/categories';
import { MerchantField } from '@/shared/finance/components/MerchantField';
import { TagPicker } from '@/shared/finance/components/TagPicker';
import { TRANSACTION_TYPES } from '@/shared/finance/labels';
import { accountGroups, categoryOptions, paymentMethodOptions } from '@/shared/finance/options';
import {
  useAccounts,
  useCategories,
  usePaymentMethods,
  useTags,
  writableAccounts,
} from '@/shared/finance/reference';
import type { Account, TransactionType } from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { normalizeDecimalInput } from '@/shared/formatting/decimal';
import { isLocalDate } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import {
  type EntryStatus,
  METADATA_ONLY_TYPES,
  type TransactionFormResult,
  type TransactionFormValues,
} from '../formValues';
import { domainRuleMessage } from '@/shared/finance/domainErrors';

const serverFields = {
  account_id: 'accountId',
  amount: 'amount',
  local_date: 'localDate',
  occurred_at: 'localDate',
  category_id: 'categoryId',
  merchant_name: 'merchant',
  merchant_id: 'merchant',
  description: 'description',
  payment_method_id: 'paymentMethodId',
  status: 'status',
  notes: 'notes',
  original_amount: 'originalAmount',
  original_currency: 'originalCurrency',
  tag_names: 'tags',
  tag_ids: 'tags',
} as const;

interface TransactionFormProps {
  mode: 'create' | 'edit';
  initialValues: TransactionFormValues;
  /** The status the transaction has now (edit): limits which statuses are offered. */
  currentStatus?: string;
  onSubmit: (result: TransactionFormResult, intent: 'save' | 'another') => Promise<void>;
  /** Return true when the page handled an error itself (e.g. a version conflict). */
  onError?: (error: unknown) => boolean;
  submitLabel: string;
  secondaryAction?: ReactNode;
  /** Accounts that exist but cannot receive new entries are still shown when already chosen. */
  lockedAccount?: Account | null;
}

function statusOptions(current: string | undefined): EntryStatus[] {
  // Allowed moves: draft → pending/posted, pending → posted (the API enforces this too).
  if (current === 'pending') return ['pending', 'posted'];
  if (current === 'posted') return ['posted'];
  return ['posted', 'pending', 'draft'];
}

/**
 * Expense and income entry and editing (spec §18 "Add expense"). The form
 * renders once its reference data has loaded, so every select shows the
 * value it starts with.
 */
export function TransactionForm(props: TransactionFormProps) {
  const { t } = useI18n();
  const queries = [useAccounts(), useCategories(), useTags(), usePaymentMethods(), useCurrencies()];
  const failed = queries.find((query) => query.isError);
  if (failed) {
    return (
      <ErrorState
        title={t('transactions.form.loadFailed')}
        error={failed.error}
        onRetry={() => {
          for (const query of queries) if (query.isError) void query.refetch();
        }}
      />
    );
  }
  if (queries.some((query) => query.isPending)) {
    return <LoadingState label={t('transactions.form.loading')} />;
  }
  return <TransactionFormInner {...props} />;
}

function TransactionFormInner({
  mode,
  initialValues,
  currentStatus,
  onSubmit,
  onError,
  submitLabel,
  secondaryAction,
  lockedAccount,
}: TransactionFormProps) {
  const { t, formatLocale } = useI18n();
  const accounts = useAccounts();
  const categories = useCategories();
  const tags = useTags();
  const methods = usePaymentMethods();
  const currencies = useCurrencies();
  const [formError, setFormError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState<'save' | 'another' | null>(null);
  const metadataOnly = METADATA_ONLY_TYPES.has(initialValues.type);

  const accountChoices = useMemo(() => {
    const writable = writableAccounts(accounts.data);
    if (lockedAccount && !writable.some((account) => account.id === lockedAccount.id)) {
      return [lockedAccount, ...writable];
    }
    return writable;
  }, [accounts.data, lockedAccount]);
  const accountById = useMemo(
    () =>
      new Map(
        [...(accounts.data ?? []), ...(lockedAccount ? [lockedAccount] : [])].map((a) => [a.id, a]),
      ),
    [accounts.data, lockedAccount],
  );

  const schema = useMemo(
    () =>
      z
        .object({
          type: z.custom<TransactionType>(
            (value) => typeof value === 'string' && (TRANSACTION_TYPES as string[]).includes(value),
          ),
          accountId: z.string().min(1, { error: t('validation.chooseAccount') }),
          amount: z.string(),
          localDate: z.string(),
          categoryId: z.string(),
          merchant: z.string().max(120, { error: t('validation.maxLength', { max: 120 }) }),
          description: z.string().max(500, { error: t('validation.maxLength', { max: 500 }) }),
          paymentMethodId: z.string(),
          tags: z.object({ tagIds: z.array(z.string()), newNames: z.array(z.string()) }),
          status: z.enum(['posted', 'pending', 'draft']),
          notes: z.string().max(4000, { error: t('validation.maxLength', { max: 4000 }) }),
          foreign: z.boolean(),
          originalAmount: z.string(),
          originalCurrency: z.string(),
        })
        .superRefine((values, ctx) => {
          if (metadataOnly) return;
          const account = accountById.get(values.accountId);
          const currency = account?.currency ?? '';
          if (account) {
            checkAmount(ctx, {
              value: values.amount,
              path: 'amount',
              locale: formatLocale,
              currency,
              exponent: exponentFor(currencies.data, currency),
              t,
            });
          }
          if (!values.localDate) {
            ctx.addIssue({
              code: 'custom',
              path: ['localDate'],
              message: t('validation.dateRequired'),
            });
          } else if (!isLocalDate(values.localDate)) {
            ctx.addIssue({
              code: 'custom',
              path: ['localDate'],
              message: t('validation.dateInvalid'),
            });
          }
          if (values.foreign) {
            if (
              !/^[A-Z]{3}$/.test(values.originalCurrency) ||
              values.originalCurrency === currency
            ) {
              ctx.addIssue({
                code: 'custom',
                path: ['originalCurrency'],
                message: t('transactions.form.foreignCurrencyInvalid'),
              });
            } else {
              checkAmount(ctx, {
                value: values.originalAmount,
                path: 'originalAmount',
                locale: formatLocale,
                currency: values.originalCurrency,
                exponent: exponentFor(currencies.data, values.originalCurrency),
                t,
              });
            }
          }
        }),
    [t, formatLocale, metadataOnly, accountById, currencies.data],
  );

  const form = useForm<TransactionFormValues, unknown, TransactionFormValues>({
    resolver: zodResolver(schema),
    defaultValues: initialValues,
  });
  const [type, accountId, foreign, merchant, originalCurrency] = useWatch({
    control: form.control,
    name: ['type', 'accountId', 'foreign', 'merchant', 'originalCurrency'],
  });
  const account = accountById.get(accountId);
  const currency = account?.currency ?? null;

  const categoryChoices = categoryOptions(categories.data ?? [], t, formatLocale, (category) =>
    categoryFitsType(category, type),
  );

  const submit = (intent: 'save' | 'another') =>
    form.handleSubmit(async (values) => {
      if (submitting) return;
      setFormError(null);
      const accountCurrency = accountById.get(values.accountId)?.currency ?? '';
      const amount = normalizeDecimalInput(values.amount, formatLocale, {
        exponent: exponentFor(currencies.data, accountCurrency),
      });
      const original =
        values.foreign && values.originalCurrency
          ? normalizeDecimalInput(values.originalAmount, formatLocale, {
              exponent: exponentFor(currencies.data, values.originalCurrency),
            })
          : null;
      setSubmitting(intent);
      try {
        await onSubmit(
          {
            values,
            amount: amount.ok ? amount.value : values.amount,
            originalAmount: original?.ok ? original.value : null,
          },
          intent,
        );
        if (intent === 'another') {
          form.reset({
            ...values,
            amount: '',
            categoryId: '',
            merchant: '',
            description: '',
            tags: { tagIds: [], newNames: [] },
            notes: '',
            foreign: false,
            originalAmount: '',
            originalCurrency: '',
          });
          form.setFocus('amount');
        }
      } catch (error) {
        if (onError?.(error)) return;
        if (hasErrorCode(error, 'VALIDATION_ERROR')) {
          const rest = applyServerErrors(error, form.setError, serverFields);
          if (rest.length > 0) setFormError(rest.join(' '));
          else if (error.details.length === 0) setFormError(t('errors.VALIDATION_ERROR'));
        } else if (hasErrorCode(error, 'DOMAIN_RULE_VIOLATION')) {
          setFormError(
            domainRuleMessage(error, t, formatLocale) ??
              (mode === 'edit'
                ? t('transactions.form.editNotAllowed')
                : t('transactions.form.createNotAllowed')),
          );
        } else if (hasErrorCode(error, 'CONSENT_REQUIRED')) {
          setFormError(t('transactions.form.locationConsent'));
        } else if (hasErrorCode(error, 'IDEMPOTENCY_CONFLICT')) {
          setFormError(t('finance.errors.maybeSaved'));
        } else {
          setFormError(describeError(error, t));
        }
      } finally {
        setSubmitting(null);
      }
    });

  const { errors } = form.formState;
  const statuses = statusOptions(mode === 'edit' ? currentStatus : undefined);

  if (accounts.isSuccess && accountChoices.length === 0) {
    return (
      <Alert tone="info" title={t('transactions.form.noAccountsTitle')}>
        {t('transactions.form.noAccountsBody')}
      </Alert>
    );
  }

  return (
    <form onSubmit={submit('save')} noValidate className="space-y-5">
      <FormAlert message={formError} />
      {metadataOnly ? <Alert tone="info">{t('transactions.form.metadataOnly')}</Alert> : null}
      {mode === 'create' ? (
        <Controller
          control={form.control}
          name="type"
          render={({ field }) => (
            <RadioGroup<TransactionType>
              legend={t('transactions.form.type')}
              value={field.value}
              onChange={(next) => {
                field.onChange(next);
                form.setValue('categoryId', '');
              }}
              options={[
                { value: 'expense', label: t('finance.txType.expense') },
                { value: 'income', label: t('finance.txType.income') },
              ]}
            />
          )}
        />
      ) : null}
      <div className="grid gap-5 sm:grid-cols-2">
        <Select
          label={t('transactions.form.account')}
          placeholder={
            accounts.isPending
              ? t('accounts.list.loading')
              : t('transactions.form.accountPlaceholder')
          }
          groups={accountGroups(accountChoices, t)}
          disabled={metadataOnly || !accounts.isSuccess}
          error={errors.accountId?.message}
          help={
            mode === 'edit' && !metadataOnly ? t('transactions.form.accountEditHelp') : undefined
          }
          {...form.register('accountId')}
        />
        <MoneyField
          label={t('transactions.form.amount')}
          currency={currency}
          disabled={metadataOnly}
          help={t('transactions.form.amountHelp')}
          error={errors.amount?.message}
          {...form.register('amount')}
        />
      </div>
      <div className="grid gap-5 sm:grid-cols-2">
        <TextField
          label={t('transactions.form.date')}
          type="date"
          disabled={metadataOnly}
          error={errors.localDate?.message}
          {...form.register('localDate')}
        />
        <Select
          label={t('transactions.form.category')}
          optional
          placeholder={t('transactions.form.categoryNone')}
          options={categoryChoices}
          disabled={metadataOnly}
          help={mode === 'create' ? t('transactions.form.categoryHelp') : undefined}
          error={errors.categoryId?.message}
          {...form.register('categoryId')}
        />
      </div>
      <MerchantField
        search={merchant}
        error={errors.merchant?.message}
        {...form.register('merchant')}
      />
      <TextField
        label={t('transactions.form.description')}
        optional
        maxLength={500}
        autoComplete="off"
        error={errors.description?.message}
        {...form.register('description')}
      />
      <div className="grid gap-5 sm:grid-cols-2">
        <Select
          label={t('transactions.form.paymentMethod')}
          optional
          placeholder={t('common.none')}
          options={paymentMethodOptions(methods.data ?? [], t)}
          disabled={metadataOnly}
          error={errors.paymentMethodId?.message}
          {...form.register('paymentMethodId')}
        />
        {statuses.length > 1 && !metadataOnly ? (
          <Select
            label={t('transactions.form.status')}
            options={statuses.map((status) => ({
              value: status,
              label: t(`finance.txStatus.${status}`),
            }))}
            help={t('transactions.form.statusHelp')}
            error={errors.status?.message}
            {...form.register('status')}
          />
        ) : null}
      </div>
      <Controller
        control={form.control}
        name="tags"
        render={({ field }) => (
          <TagPicker
            tags={tags.data ?? []}
            value={field.value}
            onChange={field.onChange}
            error={errors.tags?.message}
          />
        )}
      />
      <TextArea
        label={t('transactions.form.notes')}
        optional
        maxLength={4000}
        help={t('finance.sensitiveHint')}
        error={errors.notes?.message}
        {...form.register('notes')}
      />
      {metadataOnly ? null : (
        <div className="space-y-4 rounded-lg border border-line p-4">
          <Checkbox
            label={t('transactions.form.foreign')}
            description={t('transactions.form.foreignHelp')}
            {...form.register('foreign')}
          />
          {foreign ? (
            <div className="grid gap-5 sm:grid-cols-2">
              <Select
                label={t('transactions.form.foreignCurrency')}
                placeholder={t('auth.fields.currencyPlaceholder')}
                options={currencyOptions(currencies.data, formatLocale, originalCurrency).filter(
                  (option) => option.value !== currency,
                )}
                error={errors.originalCurrency?.message}
                {...form.register('originalCurrency')}
              />
              <MoneyField
                label={t('transactions.form.foreignAmount')}
                currency={originalCurrency || null}
                error={errors.originalAmount?.message}
                {...form.register('originalAmount')}
              />
            </div>
          ) : null}
        </div>
      )}
      <div className="flex flex-wrap items-center gap-3">
        <Button type="submit" loading={submitting === 'save'} disabled={submitting === 'another'}>
          {submitLabel}
        </Button>
        {mode === 'create' ? (
          <Button
            variant="secondary"
            loading={submitting === 'another'}
            disabled={submitting === 'save'}
            onClick={(event) => {
              void submit('another')(event);
            }}
          >
            {t('transactions.form.saveAndAdd')}
          </Button>
        ) : null}
        {secondaryAction}
      </div>
    </form>
  );
}
