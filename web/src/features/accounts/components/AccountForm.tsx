import { zodResolver } from '@hookform/resolvers/zod';
import { type ReactNode, useMemo, useState } from 'react';
import { useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { MoneyField } from '@/shared/components/MoneyField';
import { Select } from '@/shared/components/Select';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { currencyOptions, exponentFor, useCurrencies } from '@/shared/currency/api';
import {
  ACCOUNT_TYPES,
  LIABILITY_ACCOUNT_TYPES,
  accountTypeLabel,
  isAccountType,
} from '@/shared/finance/labels';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { negateDecimal, normalizeDecimalInput } from '@/shared/formatting/decimal';
import { isLocalDate } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import type { AccountFormResult, AccountFormValues } from '../formValues';
import { domainRuleMessage } from '@/shared/finance/domainErrors';

const DAY_OPTIONS = Array.from({ length: 31 }, (_, index) => ({
  value: String(index + 1),
  label: String(index + 1),
}));

function buildSchema(
  t: Translate,
  locale: string,
  mode: 'create' | 'edit',
  exponent: (currency: string) => number,
) {
  return z
    .object({
      name: z
        .string()
        .trim()
        .min(1, { error: t('accounts.form.nameRequired') })
        .max(80, { error: t('validation.maxLength', { max: 80 }) }),
      accountType: z.string(),
      currency: z.string().regex(/^[A-Z]{3}$/, { error: t('validation.currencyRequired') }),
      openingBalance: z.string(),
      openingDate: z.string(),
      institutionLabel: z
        .string()
        .trim()
        .max(80, { error: t('validation.maxLength', { max: 80 }) }),
      maskedNumber: z
        .string()
        .trim()
        .regex(/^(\d{2,4})?$/, { error: t('accounts.form.maskedInvalid') }),
      creditLimit: z.string(),
      statementDay: z.string(),
      paymentDueDay: z.string(),
      includeInOverview: z.boolean(),
      notes: z.string().max(1000, { error: t('validation.maxLength', { max: 1000 }) }),
    })
    .superRefine((values, ctx) => {
      if (!isAccountType(values.accountType)) {
        ctx.addIssue({
          code: 'custom',
          path: ['accountType'],
          message: t('accounts.form.typeRequired'),
        });
        return;
      }
      const liability = LIABILITY_ACCOUNT_TYPES.has(values.accountType);
      const digits = exponent(values.currency);
      if (mode === 'create') {
        checkAmount(ctx, {
          value: values.openingBalance,
          path: 'openingBalance',
          locale,
          currency: values.currency,
          exponent: digits,
          allowZero: true,
          allowNegative: !liability,
          optional: true,
          t,
        });
        if (values.openingDate && !isLocalDate(values.openingDate)) {
          ctx.addIssue({
            code: 'custom',
            path: ['openingDate'],
            message: t('validation.dateInvalid'),
          });
        }
      }
      checkAmount(ctx, {
        value: values.creditLimit,
        path: 'creditLimit',
        locale,
        currency: values.currency,
        exponent: digits,
        allowZero: true,
        optional: true,
        t,
      });
    });
}

/** API field (without `body.`) -> form field. */
const serverFields = {
  name: 'name',
  account_type: 'accountType',
  currency: 'currency',
  opening_balance: 'openingBalance',
  opening_date: 'openingDate',
  institution_label: 'institutionLabel',
  masked_number: 'maskedNumber',
  credit_limit: 'creditLimit',
  statement_day: 'statementDay',
  payment_due_day: 'paymentDueDay',
  notes: 'notes',
} as const;

interface AccountFormProps {
  mode: 'create' | 'edit';
  initialValues: AccountFormValues;
  /** Saves; rejects with the API error so the form can show it. */
  onSubmit: (result: AccountFormResult) => Promise<void>;
  /** Return true when the page handled an error itself (e.g. a version conflict). */
  onError?: (error: unknown) => boolean;
  submitLabel: string;
  /** Rendered beside the submit button (cancel / skip). */
  secondaryAction?: ReactNode;
  /** Edit mode: the account type cannot change. */
  lockedType?: boolean;
}

/** Renders once the currency list has loaded, so the currency select shows its value. */
export function AccountForm(props: AccountFormProps) {
  const { t } = useI18n();
  const currencies = useCurrencies();
  if (currencies.isError) {
    return (
      <ErrorState
        title={t('currency.loadFailed')}
        error={currencies.error}
        retrying={currencies.isFetching}
        onRetry={() => {
          void currencies.refetch();
        }}
      />
    );
  }
  if (currencies.isPending) return <LoadingState label={t('currency.loading')} />;
  return <AccountFormInner {...props} />;
}

function AccountFormInner({
  mode,
  initialValues,
  onSubmit,
  onError,
  submitLabel,
  secondaryAction,
  lockedType = false,
}: AccountFormProps) {
  const { t, formatLocale } = useI18n();
  const currencies = useCurrencies();
  const [formError, setFormError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const schema = useMemo(
    () => buildSchema(t, formatLocale, mode, (code) => exponentFor(currencies.data, code)),
    [t, formatLocale, mode, currencies.data],
  );
  const form = useForm<AccountFormValues, unknown, AccountFormValues>({
    resolver: zodResolver(schema),
    defaultValues: initialValues,
  });
  const [accountType, currency] = useWatch({
    control: form.control,
    name: ['accountType', 'currency'],
  });
  const liability = isAccountType(accountType) && LIABILITY_ACCOUNT_TYPES.has(accountType);
  const isCard = accountType === 'credit_card';

  const typeOptions = ACCOUNT_TYPES.map((type) => ({
    value: type,
    label: t(accountTypeLabel[type]),
  }));
  const currencyChoices = currencyOptions(currencies.data, formatLocale, initialValues.currency);

  const onValid = form.handleSubmit(async (values) => {
    if (submitting) return;
    setFormError(null);
    const exponent = exponentFor(currencies.data, values.currency);
    // Already validated by the schema; this yields the exact canonical strings.
    const canonical = (raw: string, allowNegative: boolean) => {
      if (!raw.trim()) return null;
      const result = normalizeDecimalInput(raw, formatLocale, {
        exponent,
        allowZero: true,
        allowNegative,
      });
      return result.ok ? result.value : null;
    };
    const owes =
      isAccountType(values.accountType) && LIABILITY_ACCOUNT_TYPES.has(values.accountType);
    const opening = canonical(values.openingBalance, !owes);
    // Credit cards and loans: the amount owed is sent as a negative balance (contract).
    const openingBalance = opening && owes ? negateDecimal(opening) : opening;
    setSubmitting(true);
    try {
      await onSubmit({
        values,
        openingBalance: mode === 'create' ? openingBalance : null,
        creditLimit: canonical(values.creditLimit, false),
      });
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
      } else if (hasErrorCode(error, 'DOMAIN_RULE_VIOLATION')) {
        setFormError(
          domainRuleMessage(error, t, formatLocale) ??
            (mode === 'edit' ? t('accounts.form.currencyLocked') : describeError(error, t)),
        );
      } else if (hasErrorCode(error, 'IDEMPOTENCY_CONFLICT')) {
        setFormError(t('finance.errors.maybeSaved'));
      } else {
        setFormError(describeError(error, t));
      }
    } finally {
      setSubmitting(false);
    }
  });

  const { errors } = form.formState;

  return (
    <form onSubmit={onValid} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <TextField
        label={t('accounts.form.name')}
        help={t('accounts.form.nameHelp')}
        maxLength={80}
        autoComplete="off"
        error={errors.name?.message}
        {...form.register('name')}
      />
      <div className="grid gap-5 sm:grid-cols-2">
        <Select
          label={t('accounts.form.type')}
          placeholder={t('accounts.form.typePlaceholder')}
          options={typeOptions}
          disabled={lockedType}
          help={lockedType ? t('accounts.form.typeLocked') : undefined}
          error={errors.accountType?.message}
          {...form.register('accountType')}
        />
        <Select
          label={t('accounts.form.currency')}
          placeholder={t('auth.fields.currencyPlaceholder')}
          options={currencyChoices}
          help={
            mode === 'edit' ? t('accounts.form.currencyEditHelp') : t('accounts.form.currencyHelp')
          }
          error={errors.currency?.message}
          {...form.register('currency')}
        />
      </div>
      {mode === 'create' ? (
        <div className="grid gap-5 sm:grid-cols-2">
          <MoneyField
            label={liability ? t('accounts.form.amountOwed') : t('accounts.form.openingBalance')}
            currency={currency || null}
            optional
            help={
              liability ? t('accounts.form.amountOwedHelp') : t('accounts.form.openingBalanceHelp')
            }
            error={errors.openingBalance?.message}
            {...form.register('openingBalance')}
          />
          <TextField
            label={t('accounts.form.openingDate')}
            type="date"
            optional
            help={t('accounts.form.openingDateHelp')}
            error={errors.openingDate?.message}
            {...form.register('openingDate')}
          />
        </div>
      ) : null}
      <div className="grid gap-5 sm:grid-cols-2">
        <TextField
          label={t('accounts.form.institution')}
          help={t('accounts.form.institutionHelp')}
          optional
          maxLength={80}
          autoComplete="off"
          error={errors.institutionLabel?.message}
          {...form.register('institutionLabel')}
        />
        <TextField
          label={t('accounts.form.masked')}
          help={t('accounts.form.maskedHelp')}
          optional
          inputMode="numeric"
          maxLength={4}
          autoComplete="off"
          error={errors.maskedNumber?.message}
          {...form.register('maskedNumber')}
        />
      </div>
      {isCard || liability ? (
        <div className="grid gap-5 sm:grid-cols-3">
          {isCard ? (
            <MoneyField
              label={t('accounts.form.creditLimit')}
              currency={currency || null}
              optional
              error={errors.creditLimit?.message}
              {...form.register('creditLimit')}
            />
          ) : null}
          {isCard ? (
            <Select
              label={t('accounts.form.statementDay')}
              optional
              placeholder={t('accounts.form.dayNotSet')}
              options={DAY_OPTIONS}
              help={t('accounts.form.statementDayHelp')}
              error={errors.statementDay?.message}
              {...form.register('statementDay')}
            />
          ) : null}
          <Select
            label={t('accounts.form.dueDay')}
            optional
            placeholder={t('accounts.form.dayNotSet')}
            options={DAY_OPTIONS}
            help={t('accounts.form.dueDayHelp')}
            error={errors.paymentDueDay?.message}
            {...form.register('paymentDueDay')}
          />
        </div>
      ) : null}
      <Checkbox
        label={t('accounts.form.includeInOverview')}
        description={t('accounts.form.includeInOverviewHelp')}
        {...form.register('includeInOverview')}
      />
      <TextArea
        label={t('accounts.form.notes')}
        optional
        maxLength={1000}
        help={t('finance.sensitiveHint')}
        error={errors.notes?.message}
        {...form.register('notes')}
      />
      <div className="flex flex-wrap items-center gap-3">
        <Button type="submit" loading={submitting}>
          {submitLabel}
        </Button>
        {secondaryAction}
      </div>
    </form>
  );
}
