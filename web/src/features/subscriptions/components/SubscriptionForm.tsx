import { zodResolver } from '@hookform/resolvers/zod';
import { type ReactNode, useMemo, useState } from 'react';
import { useFieldArray, useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { Disclosure } from '@/shared/components/Disclosure';
import { Icon } from '@/shared/components/Icon';
import { IconButton } from '@/shared/components/IconButton';
import { MoneyField } from '@/shared/components/MoneyField';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { currencyOptions, exponentFor, useCurrencies } from '@/shared/currency/api';
import { categoryFitsType } from '@/shared/finance/categories';
import { MerchantField } from '@/shared/finance/components/MerchantField';
import { accountGroups, categoryOptions } from '@/shared/finance/options';
import { useAccounts, useCategories, writableAccounts } from '@/shared/finance/reference';
import { groupOptions, useGroups } from '@/shared/finance/sharing';
import type { SubscriptionDetail } from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { isLocalDate } from '@/shared/formatting/dates';
import { normalizeDecimalInput } from '@/shared/formatting/decimal';
import { useI18n, useT } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { subscriptionErrorMessage } from '../errors';
import type { SubscriptionFormValues } from '../formValues';
import {
  FREQUENCIES,
  INTERVAL_UNITS,
  REMINDER_CHOICES,
  frequencyLabel,
  intervalUnitLabel,
  isFrequency,
  isIntervalUnit,
  reminderLabel,
} from '../labels';

const HTTPS_URL = /^https:\/\/[^\s<>"]+$/i;

function buildSchema(
  t: Translate,
  locale: string,
  exponent: (currency: string) => number,
  /** Editing a cancelled subscription: its cancellation date can be corrected. */
  withCancelledOn: boolean,
) {
  const max = (limit: number) => ({ error: t('validation.maxLength', { max: limit }) });
  const optionalDate = z
    .string()
    .refine((value) => value === '' || isLocalDate(value), { error: t('validation.dateInvalid') });
  return z
    .object({
      name: z
        .string()
        .trim()
        .min(1, { error: t('subscriptions.form.nameRequired') })
        .max(120, max(120)),
      planName: z.string().trim().max(120, max(120)),
      merchantName: z.string().trim().max(120, max(120)),
      amount: z.string(),
      currency: z.string().regex(/^[A-Z]{3}$/, { error: t('subscriptions.form.currencyRequired') }),
      billingFrequency: z
        .string()
        .refine(isFrequency, { error: t('subscriptions.form.frequencyRequired') }),
      intervalCount: z.string(),
      intervalUnit: z.string(),
      startDate: z.string().refine(isLocalDate, { error: t('validation.dateRequired') }),
      nextRenewalDate: optionalDate,
      trialEndsOn: optionalDate,
      paymentAccountId: z.string(),
      categoryId: z.string(),
      reminders: z.array(z.string()),
      cancellationUrl: z
        .string()
        .trim()
        .max(500, max(500))
        .refine((value) => value === '' || HTTPS_URL.test(value), {
          error: t('subscriptions.form.urlHttps'),
        }),
      cancellationInstructions: z.string().trim().max(4000, max(4000)),
      checklist: z.array(
        z.object({ item: z.string().trim().max(200, max(200)), done: z.boolean() }),
      ),
      groupId: z.string(),
      notes: z.string().trim().max(2000, max(2000)),
      cancelledOn: z.string(),
    })
    .superRefine((values, ctx) => {
      if (withCancelledOn && !isLocalDate(values.cancelledOn)) {
        ctx.addIssue({
          code: 'custom',
          path: ['cancelledOn'],
          message: values.cancelledOn ? t('validation.dateInvalid') : t('validation.dateRequired'),
        });
      }
      if (/^[A-Z]{3}$/.test(values.currency)) {
        checkAmount(ctx, {
          value: values.amount,
          path: 'amount',
          locale,
          currency: values.currency,
          t,
          exponent: exponent(values.currency),
        });
      }
      if (values.billingFrequency === 'custom') {
        const count = Number(values.intervalCount);
        if (!Number.isInteger(count) || count < 1 || count > 366) {
          ctx.addIssue({
            code: 'custom',
            path: ['intervalCount'],
            message: t('subscriptions.form.intervalRange'),
          });
        }
        if (!isIntervalUnit(values.intervalUnit)) {
          ctx.addIssue({
            code: 'custom',
            path: ['intervalUnit'],
            message: t('subscriptions.form.unitRequired'),
          });
        }
      }
      if (
        values.trialEndsOn &&
        isLocalDate(values.trialEndsOn) &&
        isLocalDate(values.startDate) &&
        values.trialEndsOn < values.startDate
      ) {
        ctx.addIssue({
          code: 'custom',
          path: ['trialEndsOn'],
          message: t('subscriptions.form.trialBeforeStart'),
        });
      }
    });
}

/** API field (without `body.`) → form field, for server validation details. */
const serverFields = {
  name: 'name',
  plan_name: 'planName',
  merchant_name: 'merchantName',
  amount: 'amount',
  currency: 'currency',
  billing_frequency: 'billingFrequency',
  interval_count: 'intervalCount',
  interval_unit: 'intervalUnit',
  start_date: 'startDate',
  next_renewal_date: 'nextRenewalDate',
  trial_ends_on: 'trialEndsOn',
  payment_account_id: 'paymentAccountId',
  category_id: 'categoryId',
  reminder_days_before: 'reminders',
  cancellation_url: 'cancellationUrl',
  cancellation_instructions: 'cancellationInstructions',
  cancellation_checklist: 'checklist',
  group_id: 'groupId',
  notes: 'notes',
  cancelled_on: 'cancelledOn',
} as const;

interface SubscriptionFormProps {
  initialValues: SubscriptionFormValues;
  /** The saved record when editing (a cancelled one shows its cancellation date). */
  existing?: SubscriptionDetail;
  submitLabel: string;
  secondaryAction?: ReactNode;
  /** Saves the validated values; `amount` is the exact decimal price. */
  onSubmit: (values: SubscriptionFormValues, amount: string) => Promise<void>;
  /** Return true when the error was handled (e.g. a version conflict). */
  onError?: (error: unknown) => boolean;
}

/**
 * Reference data first (accounts, categories, currencies, groups), so the
 * selects can show the saved choices.
 */
export function SubscriptionForm(props: SubscriptionFormProps) {
  const t = useT();
  const accounts = useAccounts(true);
  const categories = useCategories(true);
  const currencies = useCurrencies();
  const groups = useGroups();
  const failed = [accounts, categories, currencies].find((query) => query.isError);
  if (failed) {
    return (
      <ErrorState
        title={t('subscriptions.form.loadError')}
        error={failed.error}
        onRetry={() => {
          void accounts.refetch();
          void categories.refetch();
          void currencies.refetch();
        }}
      />
    );
  }
  if (accounts.isPending || categories.isPending || currencies.isPending || groups.isPending) {
    return <LoadingState label={t('subscriptions.form.loading')} />;
  }
  return <SubscriptionFormFields {...props} />;
}

function SubscriptionFormFields({
  initialValues,
  existing,
  submitLabel,
  secondaryAction,
  onSubmit,
  onError,
}: SubscriptionFormProps) {
  const { t, formatLocale } = useI18n();
  const accounts = useAccounts(true);
  const categories = useCategories(true);
  const currencies = useCurrencies();
  const groups = useGroups();
  const [formError, setFormError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const withCancelledOn = existing?.status === 'cancelled';
  const schema = useMemo(
    () =>
      buildSchema(t, formatLocale, (code) => exponentFor(currencies.data, code), withCancelledOn),
    [t, formatLocale, currencies.data, withCancelledOn],
  );
  const form = useForm<SubscriptionFormValues, unknown, SubscriptionFormValues>({
    resolver: zodResolver(schema),
    defaultValues: initialValues,
  });
  const checklist = useFieldArray({ control: form.control, name: 'checklist' });
  const [frequency, currency, merchantName] = useWatch({
    control: form.control,
    name: ['billingFrequency', 'currency', 'merchantName'],
  });

  const keepAccount = initialValues.paymentAccountId;
  const accountChoices = writableAccounts(accounts.data).concat(
    (accounts.data ?? []).filter(
      (account) => account.id === keepAccount && !(account.owned && account.status === 'active'),
    ),
  );
  const keepCategory = initialValues.categoryId;
  const categoryChoices = categoryOptions(
    (categories.data ?? []).filter(
      (category) => category.status === 'active' || category.id === keepCategory,
    ),
    t,
    formatLocale,
    (category) => categoryFitsType(category, 'expense'),
  );
  const reminderChoices = [
    ...new Set([...REMINDER_CHOICES, ...initialValues.reminders.map(Number)]),
  ].sort((a, b) => a - b);
  const groupChoices = groupOptions(groups.data);
  const keepGroup = initialValues.groupId;
  if (keepGroup && !groupChoices.some((option) => option.value === keepGroup)) {
    groupChoices.push({ value: keepGroup, label: t('subscriptions.form.groupUnavailable') });
  }

  const onValid = form.handleSubmit(async (values) => {
    if (submitting) return;
    setFormError(null);
    const exact = normalizeDecimalInput(values.amount, formatLocale, {
      exponent: exponentFor(currencies.data, values.currency),
    });
    if (!exact.ok) return; // the schema already reported it
    setSubmitting(true);
    try {
      await onSubmit(values, exact.value);
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
        setFormError(subscriptionErrorMessage(error, t, formatLocale));
      }
    } finally {
      setSubmitting(false);
    }
  });

  const { errors } = form.formState;

  return (
    <form onSubmit={onValid} noValidate className="space-y-8">
      <FormAlert message={formError} />

      <fieldset className="space-y-5">
        <legend className="mb-1 text-base font-semibold text-fg">
          {t('subscriptions.form.section.what')}
        </legend>
        <TextField
          label={t('subscriptions.form.name')}
          help={t('subscriptions.form.nameHelp')}
          maxLength={120}
          autoComplete="off"
          error={errors.name?.message}
          {...form.register('name')}
        />
        <div className="grid gap-5 sm:grid-cols-2">
          <TextField
            label={t('subscriptions.form.plan')}
            optional
            maxLength={120}
            autoComplete="off"
            error={errors.planName?.message}
            {...form.register('planName')}
          />
          <MerchantField
            search={merchantName}
            error={errors.merchantName?.message}
            {...form.register('merchantName')}
          />
        </div>
      </fieldset>

      <fieldset className="space-y-5">
        <legend className="mb-1 text-base font-semibold text-fg">
          {t('subscriptions.form.section.price')}
        </legend>
        <div className="grid gap-5 sm:grid-cols-2">
          <MoneyField
            label={t('subscriptions.form.amount')}
            help={t('subscriptions.form.amountHelp')}
            currency={currency || null}
            error={errors.amount?.message}
            {...form.register('amount')}
          />
          <Select
            label={t('common.currency')}
            options={currencyOptions(currencies.data, formatLocale, initialValues.currency)}
            error={errors.currency?.message}
            {...form.register('currency')}
          />
        </div>
        <Select
          label={t('subscriptions.form.frequency')}
          options={FREQUENCIES.map((value) => ({ value, label: t(frequencyLabel[value]) }))}
          error={errors.billingFrequency?.message}
          {...form.register('billingFrequency')}
        />
        {frequency === 'custom' ? (
          <div className="grid gap-5 sm:grid-cols-2">
            <TextField
              label={t('subscriptions.form.intervalCount')}
              inputMode="numeric"
              autoComplete="off"
              error={errors.intervalCount?.message}
              {...form.register('intervalCount')}
            />
            <Select
              label={t('subscriptions.form.intervalUnit')}
              options={INTERVAL_UNITS.map((value) => ({
                value,
                label: t(intervalUnitLabel[value]),
              }))}
              error={errors.intervalUnit?.message}
              {...form.register('intervalUnit')}
            />
          </div>
        ) : null}
      </fieldset>

      <fieldset className="space-y-5">
        <legend className="mb-1 text-base font-semibold text-fg">
          {t('subscriptions.form.section.dates')}
        </legend>
        <div className="grid gap-5 sm:grid-cols-3">
          <TextField
            type="date"
            label={t('subscriptions.form.startDate')}
            error={errors.startDate?.message}
            {...form.register('startDate')}
          />
          <TextField
            type="date"
            label={t('subscriptions.form.nextRenewal')}
            help={t('subscriptions.form.nextRenewalHelp')}
            optional
            error={errors.nextRenewalDate?.message}
            {...form.register('nextRenewalDate')}
          />
          <TextField
            type="date"
            label={t('subscriptions.form.trialEnds')}
            help={t('subscriptions.form.trialEndsHelp')}
            optional
            error={errors.trialEndsOn?.message}
            {...form.register('trialEndsOn')}
          />
        </div>
        {withCancelledOn ? (
          <TextField
            type="date"
            label={t('subscriptions.form.cancelledOn')}
            help={t('subscriptions.form.cancelledOnHelp')}
            error={errors.cancelledOn?.message}
            {...form.register('cancelledOn')}
          />
        ) : null}
        <fieldset className="space-y-2">
          <legend className="text-sm font-medium text-fg">
            {t('subscriptions.form.reminders')}
          </legend>
          <p className="text-sm text-fg-muted">{t('subscriptions.form.remindersHelp')}</p>
          <div className="flex flex-wrap gap-x-6 gap-y-2">
            {reminderChoices.map((days) => (
              <Checkbox
                key={days}
                label={reminderLabel(days, t)}
                value={String(days)}
                {...form.register('reminders')}
              />
            ))}
          </div>
        </fieldset>
      </fieldset>

      <fieldset className="space-y-5">
        <legend className="mb-1 text-base font-semibold text-fg">
          {t('subscriptions.form.section.payment')}
        </legend>
        <div className="grid gap-5 sm:grid-cols-2">
          <Select
            label={t('subscriptions.form.account')}
            help={t('subscriptions.form.accountHelp')}
            optional
            placeholder={t('common.none')}
            groups={accountGroups(accountChoices, t)}
            error={errors.paymentAccountId?.message}
            {...form.register('paymentAccountId')}
          />
          <Select
            label={t('subscriptions.form.category')}
            optional
            placeholder={t('categories.uncategorized')}
            options={categoryChoices}
            error={errors.categoryId?.message}
            {...form.register('categoryId')}
          />
        </div>
        {groupChoices.length > 0 ? (
          <Select
            label={t('subscriptions.form.group')}
            help={t('subscriptions.form.groupHelp')}
            optional
            placeholder={t('subscriptions.form.groupNone')}
            options={groupChoices}
            error={errors.groupId?.message}
            {...form.register('groupId')}
          />
        ) : null}
      </fieldset>

      <Disclosure
        summary={t('subscriptions.form.section.cancellation')}
        defaultOpen={
          Boolean(initialValues.cancellationUrl) ||
          Boolean(initialValues.cancellationInstructions) ||
          initialValues.checklist.length > 0
        }
      >
        <div className="space-y-5">
          <p className="text-sm text-fg-muted">{t('subscriptions.form.cancellationIntro')}</p>
          <TextField
            type="url"
            label={t('subscriptions.form.cancellationUrl')}
            help={t('subscriptions.form.cancellationUrlHelp')}
            optional
            maxLength={500}
            autoComplete="off"
            inputMode="url"
            error={errors.cancellationUrl?.message}
            {...form.register('cancellationUrl')}
          />
          <TextArea
            label={t('subscriptions.form.cancellationInstructions')}
            optional
            maxLength={4000}
            error={errors.cancellationInstructions?.message}
            {...form.register('cancellationInstructions')}
          />
          <fieldset className="space-y-3">
            <legend className="text-sm font-medium text-fg">
              {t('subscriptions.form.checklist')}
            </legend>
            <p className="text-sm text-fg-muted">{t('subscriptions.form.checklistHelp')}</p>
            {checklist.fields.length > 0 ? (
              <ul className="space-y-3">
                {checklist.fields.map((field, index) => (
                  <li key={field.id} className="flex items-start gap-2">
                    <TextField
                      className="flex-1"
                      label={t('subscriptions.form.checklistItem', { number: index + 1 })}
                      maxLength={200}
                      autoComplete="off"
                      error={errors.checklist?.[index]?.item?.message}
                      {...form.register(`checklist.${index}.item`)}
                    />
                    <IconButton
                      icon="trash"
                      label={t('subscriptions.form.checklistRemove', { number: index + 1 })}
                      className="mt-7"
                      onClick={() => {
                        checklist.remove(index);
                      }}
                    />
                  </li>
                ))}
              </ul>
            ) : null}
            <Button
              variant="secondary"
              size="sm"
              disabled={checklist.fields.length >= 20}
              onClick={() => {
                checklist.append({ item: '', done: false }, { shouldFocus: true });
              }}
            >
              <Icon name="plus" className="size-4" />
              {t('subscriptions.form.checklistAdd')}
            </Button>
          </fieldset>
        </div>
      </Disclosure>

      <TextArea
        label={t('subscriptions.form.notes')}
        optional
        maxLength={2000}
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
