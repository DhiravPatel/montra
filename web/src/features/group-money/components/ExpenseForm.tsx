import { zodResolver } from '@hookform/resolvers/zod';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { type ReactNode, useCallback, useMemo, useRef, useState } from 'react';
import { type FieldPath, FormProvider, useForm, useFormContext, useWatch } from 'react-hook-form';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { MoneyField } from '@/shared/components/MoneyField';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { type Currency, exponentFor, useCurrencies } from '@/shared/currency/api';
import { accountGroups } from '@/shared/finance/options';
import { useAccounts, writableAccounts } from '@/shared/finance/reference';
import { uploadFile } from '@/shared/files/upload';
import { FormAlert } from '@/shared/forms/FormAlert';
import { isLocalDate } from '@/shared/formatting/dates';
import { useDebouncedValue } from '@/shared/hooks/useDebouncedValue';
import { useI18n } from '@/shared/i18n/I18nContext';
import { uploadErrorMessage } from '@/features/receipts/uploads';
import { groupMoneyApi } from '../api';
import { groupMoneyErrorMessage, groupRuleCode } from '../errors';
import {
  type ConversionLookup,
  type ExpenseFormDeps,
  type ExpenseFormValues,
  type RequestRows,
  buildExpenseSchema,
  emptyItem,
  expenseFieldMap,
  expenseTotal,
  originalAmountValue,
  savedRateOf,
  toExpenseInput,
} from '../expenseForm';
import { groupMoneyKeys } from '../keys';
import { SPLIT_METHODS, categoryKeyOptions } from '../labels';
import type { People } from '../people';
import { type SplitContext, paysAnything, serverFieldPath } from '../splitForm';
import type { Conversion, GroupDetail, GroupExpenseDetail, GroupExpenseInput } from '../types';
import { AttachmentField } from './AttachmentField';
import { type ConversionState, ForeignCurrencyFields } from './ForeignCurrencyFields';
import { PayerFields } from './PayerFields';
import { SplitFields } from './SplitFields';

interface ExpenseFormProps {
  group: GroupDetail;
  people: People;
  mode: 'create' | 'edit';
  /** The saved expense (edit mode). */
  expense?: GroupExpenseDetail;
  initialValues: ExpenseFormValues;
  submitLabel: string;
  cancelTo: string;
  /** Saves; rejects with the API error so the form can show it. */
  onSubmit: (body: GroupExpenseInput) => Promise<void>;
  /** Return true when the page handled an error itself (e.g. a version conflict). */
  onError?: (error: unknown) => boolean;
  /** Shown above the fields (e.g. a note about people who left the group). */
  notice?: ReactNode;
}

/** Renders once the currency list has loaded (exponents and the currency picker need it). */
export function ExpenseForm(props: ExpenseFormProps) {
  const { t } = useI18n();
  const currencies = useCurrencies();
  if (currencies.isPending) return <LoadingState label={t('groupMoney.form.loading')} />;
  if (currencies.isError) {
    return (
      <ErrorState
        title={t('groupMoney.form.loadError')}
        error={currencies.error}
        onRetry={() => {
          void currencies.refetch();
        }}
      />
    );
  }
  return <ExpenseFormFields {...props} currencies={currencies.data} />;
}

/**
 * The shared expense form (create and edit): details, an optional foreign
 * currency, who paid, how to split, and an attachment. Live guidance uses
 * exact decimal math on what was typed; the server validates and computes
 * every share, and the amount of a foreign-currency expense.
 */
function ExpenseFormFields({
  group,
  people,
  mode,
  expense,
  initialValues,
  submitLabel,
  cancelTo,
  onSubmit,
  onError,
  notice,
  currencies,
}: ExpenseFormProps & { currencies: readonly Currency[] }) {
  const { t, formatLocale } = useI18n();
  const queryClient = useQueryClient();
  const groupCurrency = group.base_currency;
  const exponent = useCallback((code: string) => exponentFor(currencies, code), [currencies]);
  const [formError, setFormError] = useState<string | null>(null);
  const [file, setFile] = useState<File | null>(null);
  const [fileError, setFileError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  // A file already uploaded for this draft is reused when the save is retried.
  const uploaded = useRef<{ file: File; id: string } | null>(null);

  // Montra's rate answers live in the query cache, keyed by the lookup.
  const saved = useMemo(() => (expense ? savedRateOf(expense) : null), [expense]);
  const deps: ExpenseFormDeps = useMemo(
    () => ({
      t,
      locale: formatLocale,
      groupCurrency,
      exponent,
      conversion: (lookup: ConversionLookup) =>
        queryClient.getQueryData<Conversion>(groupMoneyKeys.conversion(lookup)) ?? null,
      rateMissing: (lookup: ConversionLookup) =>
        hasErrorCode(
          queryClient.getQueryState(groupMoneyKeys.conversion(lookup))?.error,
          'NOT_FOUND',
        ),
      saved,
      meId: people.meId,
    }),
    [t, formatLocale, groupCurrency, exponent, queryClient, saved, people.meId],
  );
  const schema = useMemo(() => buildExpenseSchema(deps), [deps]);
  const form = useForm<ExpenseFormValues, unknown, ExpenseFormValues>({
    resolver: zodResolver(schema),
    defaultValues: initialValues,
  });
  const { control, register, formState } = form;
  const errors = formState.errors;
  const [
    foreign,
    amount,
    originalCurrency,
    originalAmount,
    rateChoice,
    ownRate,
    expenseDate,
    payerMode,
    singlePayer,
    payers,
  ] = useWatch({
    control,
    name: [
      'foreign',
      'amount',
      'originalCurrency',
      'originalAmount',
      'rateChoice',
      'ownRate',
      'expenseDate',
      'payerMode',
      'singlePayer',
      'payers',
    ],
  });
  const amountValues = {
    foreign,
    amount,
    originalCurrency,
    originalAmount,
    rateChoice,
    ownRate,
    expenseDate,
  };

  // Montra's rate for the original amount, looked up once typing pauses.
  const original = foreign ? originalAmountValue(amountValues, deps) : null;
  const debouncedOriginal = useDebouncedValue(original ?? '', 400);
  const lookup: ConversionLookup = {
    amount: debouncedOriginal,
    from: originalCurrency,
    to: groupCurrency,
    date: expenseDate,
  };
  const lookupEnabled =
    foreign &&
    rateChoice === 'montra' &&
    debouncedOriginal !== '' &&
    debouncedOriginal === original &&
    isLocalDate(expenseDate);
  const conversionQuery = useQuery({
    queryKey: groupMoneyKeys.conversion(lookup),
    queryFn: ({ signal }) => groupMoneyApi.convert(lookup, signal),
    enabled: lookupEnabled,
    retry: false,
    staleTime: 5 * 60_000,
  });
  const total = expenseTotal(amountValues, deps);
  let conversion: ConversionState = { status: 'idle' };
  if (foreign && rateChoice === 'montra' && original !== null && isLocalDate(expenseDate)) {
    if (!lookupEnabled || conversionQuery.isPending) {
      conversion = { status: 'loading' };
    } else if (conversionQuery.isError) {
      conversion = hasErrorCode(conversionQuery.error, 'NOT_FOUND')
        ? { status: 'missing' }
        : {
            status: 'error',
            retry: () => {
              void conversionQuery.refetch();
            },
          };
    } else {
      conversion = { status: 'ready', conversion: conversionQuery.data };
    }
  }

  const context: SplitContext = {
    t,
    locale: formatLocale,
    currency: groupCurrency,
    exponent: exponent(groupCurrency),
  };
  const iPay = paysAnything({ payerMode, singlePayer, payers }, people.meId, context);

  const showServerError = (error: unknown, values: ExpenseFormValues, rows: RequestRows) => {
    if (hasErrorCode(error, 'VALIDATION_ERROR')) {
      const plain = expenseFieldMap(values);
      const unmatched: string[] = [];
      let focused = false;
      for (const detail of error.details) {
        if (detail.field === 'body.receipt_file_id') {
          setFileError(detail.message);
          continue;
        }
        const path = detail.field
          ? serverFieldPath(
              detail.field,
              { participants: rows.participants, payers: rows.payers, payerMode: values.payerMode },
              plain,
            )
          : null;
        // The server converts foreign amounts; a rate that rounds to zero
        // comes back coded so it can be shown in the interface language.
        const message =
          detail.code === 'converted_too_small'
            ? t('groupMoney.form.fx.roundsToZero', {
                currency: typeof detail.params?.currency === 'string' ? detail.params.currency : '',
              })
            : detail.message;
        if (path) {
          form.setError(
            path as FieldPath<ExpenseFormValues>,
            { type: 'server', message },
            { shouldFocus: !focused },
          );
          focused = true;
        } else {
          unmatched.push(message);
        }
      }
      setFormError(unmatched.length > 0 ? unmatched.join(' ') : t('groupMoney.form.fixErrors'));
      return;
    }
    const message = groupMoneyErrorMessage(error, t, formatLocale, {
      conflict: t('groupMoney.form.deleted'),
      notFound: t('groupMoney.form.notFound'),
    });
    const code = groupRuleCode(error);
    if (code === 'fx_rate_unavailable') {
      // Montra has no rate for the date: the own-rate choice stays available.
      form.setError('checks.rate', { type: 'server', message });
    } else if (code === 'split_mismatch') {
      form.setError(values.splitMethod === 'itemized' ? 'checks.items' : 'checks.split', {
        type: 'server',
        message,
      });
    } else if (code === 'payers_total_mismatch') {
      form.setError('checks.payers', { type: 'server', message });
    } else if (code === 'items_exceed_total' || code === 'items_need_amount') {
      form.setError('checks.items', { type: 'server', message });
    }
    setFormError(message);
  };

  const submit = form.handleSubmit(
    async (values) => {
      if (busy) return;
      setFormError(null);
      setBusy(true);
      try {
        let receiptFileId: string | undefined;
        if (file) {
          if (uploaded.current?.file === file) {
            receiptFileId = uploaded.current.id;
          } else {
            try {
              const record = await uploadFile(file, {
                purpose: 'group_attachment',
                groupId: group.id,
              });
              uploaded.current = { file, id: record.id };
              receiptFileId = record.id;
            } catch (error) {
              setFileError(uploadErrorMessage(error, t, formatLocale));
              setFormError(t('groupMoney.attachment.failed'));
              return;
            }
          }
        } else if (mode === 'edit' && values.keepAttachment && expense?.receipt_file_id) {
          receiptFileId = expense.receipt_file_id;
        }
        const { body, rows } = toExpenseInput(values, deps, {
          ...(receiptFileId ? { receiptFileId } : {}),
          ...(expense ? { version: expense.version } : {}),
          create: mode === 'create',
        });
        try {
          await onSubmit(body);
        } catch (error) {
          if (onError?.(error)) return;
          showServerError(error, values, rows);
        }
      } finally {
        setBusy(false);
      }
    },
    () => {
      setFormError(t('groupMoney.form.fixErrors'));
    },
  );

  return (
    <FormProvider {...form}>
      <form onSubmit={submit} noValidate className="space-y-8">
        <FormAlert message={formError} />
        {notice}
        <fieldset className="space-y-5">
          <legend className="mb-1 text-base font-semibold text-fg">
            {t('groupMoney.form.details')}
          </legend>
          <TextField
            label={t('groupMoney.form.description')}
            maxLength={200}
            autoComplete="off"
            error={errors.description?.message}
            {...register('description')}
          />
          <div className="grid gap-5 sm:grid-cols-2">
            {foreign ? null : (
              <MoneyField
                label={t('groupMoney.form.amount')}
                currency={groupCurrency}
                error={errors.amount?.message}
                {...register('amount')}
              />
            )}
            <TextField
              label={t('groupMoney.form.date')}
              type="date"
              error={errors.expenseDate?.message}
              {...register('expenseDate')}
            />
          </div>
          <Checkbox
            label={t('groupMoney.form.fx.toggle')}
            description={t('groupMoney.form.fx.toggleHelp', { currency: groupCurrency })}
            {...register('foreign')}
          />
          {foreign ? (
            <ForeignCurrencyFields
              groupCurrency={groupCurrency}
              currencies={currencies}
              conversion={conversion}
              total={total}
              original={original}
              saved={saved}
              onUseOwnRate={() => {
                form.setValue('rateChoice', 'own');
              }}
            />
          ) : null}
          <div className="grid gap-5 sm:grid-cols-2">
            <Select
              label={t('groupMoney.form.category')}
              optional
              placeholder={t('categories.uncategorized')}
              options={categoryKeyOptions(t, initialValues.categoryKey || undefined)}
              error={errors.categoryKey?.message}
              {...register('categoryKey')}
            />
          </div>
          <TextArea
            label={t('groupMoney.form.notes')}
            optional
            maxLength={2000}
            error={errors.notes?.message}
            {...register('notes')}
          />
        </fieldset>

        <PayerFields people={people} total={total} context={context} />
        {mode === 'create' && iPay ? (
          <PayerAccountField currency={groupCurrency} error={errors.payerAccountId?.message} />
        ) : null}

        <SplitFields
          people={people}
          total={total}
          context={context}
          methods={SPLIT_METHODS}
          onMethodChange={(method) => {
            if (method === 'itemized' && form.getValues('items').length === 0) {
              form.setValue('items', [emptyItem()]);
            }
          }}
        />

        <AttachmentField
          label={t('groupMoney.attachment.label')}
          file={file}
          error={fileError}
          onChange={(picked, problem) => {
            setFile(picked);
            setFileError(problem);
          }}
        >
          {mode === 'edit' && expense?.receipt_file_id ? (
            <Checkbox
              label={t('groupMoney.attachment.keep')}
              description={t('groupMoney.attachment.keepHelp')}
              {...register('keepAttachment')}
            />
          ) : null}
        </AttachmentField>

        <p className="text-sm text-fg-muted">{t('groupMoney.form.serverSplits')}</p>
        <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <ButtonLink to={cancelTo} variant="ghost">
            {t('common.cancel')}
          </ButtonLink>
          <Button type="submit" loading={busy}>
            {submitLabel}
          </Button>
        </div>
      </form>
    </FormProvider>
  );
}

/** Create only: record my payment in one of my accounts in the group currency. */
function PayerAccountField({ currency, error }: { currency: string; error: string | undefined }) {
  const { t } = useI18n();
  const accounts = useAccounts();
  const { register } = useFormContext<ExpenseFormValues>();
  if (accounts.isPending) return <LoadingState label={t('groupMoney.form.account.loading')} />;
  const choices = writableAccounts(accounts.data).filter(
    (account) => account.currency === currency,
  );
  if (choices.length === 0) {
    return (
      <Alert tone="info" title={t('groupMoney.form.account.title')}>
        {t('groupMoney.form.account.none', { currency })}
      </Alert>
    );
  }
  return (
    <Select
      label={t('groupMoney.form.account.label')}
      optional
      placeholder={t('groupMoney.form.account.dontRecord')}
      groups={accountGroups(choices, t)}
      help={t('groupMoney.form.account.help')}
      error={error}
      {...register('payerAccountId')}
    />
  );
}
