import { zodResolver } from '@hookform/resolvers/zod';
import { type ReactNode, useMemo, useState } from 'react';
import { Controller, useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { MoneyField } from '@/shared/components/MoneyField';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import { accountGroups } from '@/shared/finance/options';
import type { Account, TransferInput } from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { normalizeDecimalInput } from '@/shared/formatting/decimal';
import { isLocalDate } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { domainRuleMessage } from '@/shared/finance/domainErrors';

type FxMode = 'amount' | 'rate';

interface TransferValues {
  fromAccountId: string;
  toAccountId: string;
  amount: string;
  fxMode: FxMode;
  toAmount: string;
  fxRate: string;
  fee: string;
  localDate: string;
  description: string;
  notes: string;
}

/** An exact positive decimal with up to 12 fraction digits (the API's rate format). */
const RATE = /^\d+(\.\d{1,12})?$/;

interface TransferFormProps {
  accounts: readonly Account[];
  initialFromId: string;
  today: string;
  onSubmit: (body: TransferInput) => Promise<void>;
  submitting: boolean;
  secondaryAction?: ReactNode;
}

/**
 * Move money between two of your accounts (spec §18 "Transfer"). The API
 * records both sides together and keeps transfers out of income and
 * spending; a fee is recorded as a separate expense.
 */
export function TransferForm({
  accounts,
  initialFromId,
  today,
  onSubmit,
  submitting,
  secondaryAction,
}: TransferFormProps) {
  const { t, formatLocale } = useI18n();
  const currencies = useCurrencies();
  const [formError, setFormError] = useState<string | null>(null);
  const byId = useMemo(() => new Map(accounts.map((account) => [account.id, account])), [accounts]);
  const exponent = (code: string) => exponentFor(currencies.data, code);

  const schema = useMemo(
    () =>
      z
        .object({
          fromAccountId: z.string().min(1, { error: t('transfers.form.fromRequired') }),
          toAccountId: z.string().min(1, { error: t('transfers.form.toRequired') }),
          amount: z.string(),
          fxMode: z.enum(['amount', 'rate']),
          toAmount: z.string(),
          fxRate: z.string(),
          fee: z.string(),
          localDate: z.string(),
          description: z.string().max(500, { error: t('validation.maxLength', { max: 500 }) }),
          notes: z.string().max(4000, { error: t('validation.maxLength', { max: 4000 }) }),
        })
        .superRefine((values, ctx) => {
          const from = byId.get(values.fromAccountId);
          const to = byId.get(values.toAccountId);
          if (values.fromAccountId && values.fromAccountId === values.toAccountId) {
            ctx.addIssue({
              code: 'custom',
              path: ['toAccountId'],
              message: t('transfers.form.sameAccount'),
            });
          }
          if (from) {
            checkAmount(ctx, {
              value: values.amount,
              path: 'amount',
              locale: formatLocale,
              currency: from.currency,
              exponent: exponentFor(currencies.data, from.currency),
              t,
            });
            checkAmount(ctx, {
              value: values.fee,
              path: 'fee',
              locale: formatLocale,
              currency: from.currency,
              exponent: exponentFor(currencies.data, from.currency),
              allowZero: true,
              optional: true,
              t,
            });
          }
          if (from && to && from.currency !== to.currency) {
            if (values.fxMode === 'amount') {
              checkAmount(ctx, {
                value: values.toAmount,
                path: 'toAmount',
                locale: formatLocale,
                currency: to.currency,
                exponent: exponentFor(currencies.data, to.currency),
                t,
              });
            } else if (!RATE.test(values.fxRate.trim()) || !/[1-9]/.test(values.fxRate)) {
              ctx.addIssue({
                code: 'custom',
                path: ['fxRate'],
                message: t('validation.rateFormat'),
              });
            }
          }
          if (!values.localDate || !isLocalDate(values.localDate)) {
            ctx.addIssue({
              code: 'custom',
              path: ['localDate'],
              message: t('validation.dateInvalid'),
            });
          }
        }),
    [t, formatLocale, byId, currencies.data],
  );

  const form = useForm<TransferValues, unknown, TransferValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      fromAccountId: initialFromId,
      toAccountId: '',
      amount: '',
      fxMode: 'amount',
      toAmount: '',
      fxRate: '',
      fee: '',
      localDate: today,
      description: '',
      notes: '',
    },
  });
  const [fromId, toId, fxMode] = useWatch({
    control: form.control,
    name: ['fromAccountId', 'toAccountId', 'fxMode'],
  });
  const from = byId.get(fromId);
  const to = byId.get(toId);
  const crossCurrency = Boolean(from && to && from.currency !== to.currency);

  const onValid = form.handleSubmit(async (values) => {
    if (submitting) return;
    setFormError(null);
    const source = byId.get(values.fromAccountId);
    const target = byId.get(values.toAccountId);
    if (!source || !target) return;
    const canonical = (raw: string, currency: string, allowZero = false) => {
      const result = normalizeDecimalInput(raw, formatLocale, {
        exponent: exponent(currency),
        allowZero,
      });
      return result.ok ? result.value : null;
    };
    const amount = canonical(values.amount, source.currency);
    if (!amount) return;
    const body: TransferInput = {
      from_account_id: source.id,
      to_account_id: target.id,
      amount,
      local_date: values.localDate,
    };
    if (source.currency !== target.currency) {
      if (values.fxMode === 'amount') {
        const toAmount = canonical(values.toAmount, target.currency);
        if (toAmount) body.to_amount = toAmount;
      } else {
        body.fx_rate = values.fxRate.trim();
      }
    }
    if (values.fee.trim()) {
      const fee = canonical(values.fee, source.currency, true);
      if (fee && /[1-9]/.test(fee)) body.fee = fee;
    }
    if (values.description.trim()) body.description = values.description.trim();
    if (values.notes.trim()) body.notes = values.notes.trim();
    try {
      await onSubmit(body);
    } catch (error) {
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, {
          from_account_id: 'fromAccountId',
          to_account_id: 'toAccountId',
          amount: 'amount',
          to_amount: 'toAmount',
          fx_rate: 'fxRate',
          fee: 'fee',
          local_date: 'localDate',
          description: 'description',
          notes: 'notes',
        });
        if (rest.length > 0) setFormError(rest.join(' '));
      } else if (hasErrorCode(error, 'DOMAIN_RULE_VIOLATION')) {
        setFormError(domainRuleMessage(error, t, formatLocale) ?? t('transfers.form.notAllowed'));
      } else if (hasErrorCode(error, 'IDEMPOTENCY_CONFLICT')) {
        setFormError(t('finance.errors.maybeSaved'));
      } else {
        setFormError(describeError(error, t));
      }
    }
  });

  const { errors } = form.formState;
  const groups = accountGroups(accounts, t);

  if (accounts.length < 2) {
    return (
      <Alert tone="info" title={t('transfers.form.needTwoTitle')}>
        {t('transfers.form.needTwoBody')}
      </Alert>
    );
  }

  return (
    <form onSubmit={onValid} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <div className="grid gap-5 sm:grid-cols-2">
        <Select
          label={t('transfers.form.from')}
          placeholder={t('transactions.form.accountPlaceholder')}
          groups={groups}
          error={errors.fromAccountId?.message}
          {...form.register('fromAccountId')}
        />
        <Select
          label={t('transfers.form.to')}
          placeholder={t('transactions.form.accountPlaceholder')}
          groups={groups}
          error={errors.toAccountId?.message}
          {...form.register('toAccountId')}
        />
      </div>
      <div className="grid gap-5 sm:grid-cols-2">
        <MoneyField
          label={t('transfers.form.amount')}
          currency={from?.currency ?? null}
          help={t('transfers.form.amountHelp')}
          error={errors.amount?.message}
          {...form.register('amount')}
        />
        <TextField
          label={t('transactions.form.date')}
          type="date"
          error={errors.localDate?.message}
          {...form.register('localDate')}
        />
      </div>
      {crossCurrency && from && to ? (
        <div className="space-y-4 rounded-lg border border-line p-4">
          <p className="text-sm text-fg">
            {t('transfers.form.crossCurrency', { from: from.currency, to: to.currency })}
          </p>
          <Controller
            control={form.control}
            name="fxMode"
            render={({ field }) => (
              <RadioGroup<FxMode>
                legend={t('transfers.form.fxMode')}
                value={field.value}
                onChange={field.onChange}
                options={[
                  { value: 'amount', label: t('transfers.form.fxAmount') },
                  { value: 'rate', label: t('transfers.form.fxRate') },
                ]}
              />
            )}
          />
          {fxMode === 'amount' ? (
            <MoneyField
              label={t('transfers.form.toAmount')}
              currency={to.currency}
              error={errors.toAmount?.message}
              {...form.register('toAmount')}
            />
          ) : (
            <TextField
              label={t('transfers.form.rate')}
              help={t('transfers.form.rateHelp', { from: from.currency, to: to.currency })}
              inputMode="decimal"
              autoComplete="off"
              error={errors.fxRate?.message}
              {...form.register('fxRate')}
            />
          )}
        </div>
      ) : null}
      <MoneyField
        label={t('transfers.form.fee')}
        currency={from?.currency ?? null}
        optional
        help={t('transfers.form.feeHelp')}
        error={errors.fee?.message}
        {...form.register('fee')}
      />
      <TextField
        label={t('transactions.form.description')}
        optional
        maxLength={500}
        autoComplete="off"
        error={errors.description?.message}
        {...form.register('description')}
      />
      <TextArea
        label={t('transactions.form.notes')}
        optional
        rows={2}
        maxLength={4000}
        help={t('finance.sensitiveHint')}
        error={errors.notes?.message}
        {...form.register('notes')}
      />
      <p className="text-sm text-fg-muted">{t('transactions.transfer.excluded')}</p>
      <div className="flex flex-wrap items-center gap-3">
        <Button type="submit" loading={submitting}>
          {t('transfers.form.submit')}
        </Button>
        {secondaryAction}
      </div>
    </form>
  );
}
