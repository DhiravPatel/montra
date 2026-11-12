import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode, isApiError } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { MoneyField } from '@/shared/components/MoneyField';
import { MoneyText } from '@/shared/components/MoneyText';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { TextField } from '@/shared/components/TextField';
import { currencyOptions, exponentFor, useCurrencies } from '@/shared/currency/api';
import { formatLocalDate, isLocalDate, todayInTimeZone } from '@/shared/formatting/dates';
import { isZeroDecimal, normalizeDecimalInput } from '@/shared/formatting/decimal';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { fxApi } from '../api';
import type { Conversion, ConversionPolicy, ConvertQuery } from '../types';
import { CurrenciesGate } from './CurrenciesGate';
import { DisclosedRateText } from './DisclosedRate';

interface Values {
  amount: string;
  from: string;
  to: string;
  policy: ConversionPolicy;
  date: string;
}

interface Converted {
  result: Conversion;
  /** The calendar date asked for (historical policy only). */
  date: string | null;
}

/**
 * Converts an amount with the API's rate and shows that rate, where it
 * comes from and its date. Nothing is saved; transactions never change.
 */
export function ConverterCard() {
  const { t } = useI18n();
  return (
    <Card title={t('fx.convert.title')} description={t('fx.convert.description')}>
      <CurrenciesGate>
        <ConverterForm />
      </CurrenciesGate>
    </Card>
  );
}

function ConverterForm() {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const currencies = useCurrencies();
  const today = todayInTimeZone(user.timezone);
  const [formError, setFormError] = useState<string | null>(null);
  const [converted, setConverted] = useState<Converted | null>(null);
  const schema = useMemo(
    () =>
      z
        .object({
          amount: z.string(),
          from: z.string().min(1, { error: t('fx.form.currencyRequired') }),
          to: z.string().min(1, { error: t('fx.form.currencyRequired') }),
          policy: z.enum(['current', 'historical']),
          date: z.string(),
        })
        .superRefine((values, ctx) => {
          if (values.from && values.to && values.from === values.to) {
            ctx.addIssue({ code: 'custom', path: ['to'], message: t('fx.form.sameCurrency') });
          }
          if (values.from) {
            checkAmount(ctx, {
              value: values.amount,
              path: 'amount',
              locale: formatLocale,
              currency: values.from,
              exponent: exponentFor(currencies.data, values.from),
              t,
            });
          } else if (values.amount.trim() === '') {
            ctx.addIssue({
              code: 'custom',
              path: ['amount'],
              message: t('validation.amountRequired'),
            });
          }
          if (values.policy === 'historical') {
            if (!isLocalDate(values.date)) {
              ctx.addIssue({
                code: 'custom',
                path: ['date'],
                message: t('validation.dateRequired'),
              });
            } else if (values.date > today) {
              ctx.addIssue({ code: 'custom', path: ['date'], message: t('fx.form.dateFuture') });
            }
          }
        }),
    [t, formatLocale, currencies.data, today],
  );
  const form = useForm<Values>({
    resolver: zodResolver(schema),
    defaultValues: { amount: '', from: '', to: user.base_currency, policy: 'current', date: today },
  });
  const from = useWatch({ control: form.control, name: 'from' });
  const policy = useWatch({ control: form.control, name: 'policy' });
  const convert = useMutation({ mutationFn: (query: ConvertQuery) => fxApi.convert(query) });

  const onSubmit = form.handleSubmit((values) => {
    if (convert.isPending) return;
    // The same exact reader as the validation, so the API gets what was checked.
    const amount = normalizeDecimalInput(values.amount, formatLocale, {
      exponent: exponentFor(currencies.data, values.from),
    });
    if (!amount.ok) return;
    setFormError(null);
    const query: ConvertQuery = {
      amount: amount.value,
      from: values.from,
      to: values.to,
      policy: values.policy,
      ...(values.policy === 'historical' ? { date: values.date } : {}),
    };
    convert.mutate(query, {
      onSuccess: (result) => {
        setConverted({ result, date: values.policy === 'historical' ? values.date : null });
      },
      onError: (error) => {
        setConverted(null);
        if (hasErrorCode(error, 'NOT_FOUND')) {
          setFormError(t('fx.convert.noRate', { from: values.from, to: values.to }));
        } else if (
          isApiError(error) &&
          error.details.some((detail) => detail.field === 'query.amount')
        ) {
          form.setError(
            'amount',
            { type: 'server', message: t('fx.convert.amountInvalid', { currency: values.from }) },
            { shouldFocus: true },
          );
        } else {
          setFormError(describeError(error, t));
        }
      },
    });
  });

  const { errors } = form.formState;
  const options = currencyOptions(currencies.data, formatLocale);
  return (
    <>
      <form onSubmit={onSubmit} noValidate className="space-y-5">
        <FormAlert message={formError} />
        <div className="grid gap-5 sm:grid-cols-2">
          <Select
            label={t('fx.convert.from')}
            placeholder={t('fx.form.chooseCurrency')}
            options={options}
            error={errors.from?.message}
            {...form.register('from')}
          />
          <Select
            label={t('fx.convert.to')}
            placeholder={t('fx.form.chooseCurrency')}
            options={options}
            error={errors.to?.message}
            {...form.register('to')}
          />
        </div>
        <MoneyField
          label={t('fx.convert.amount')}
          currency={from || null}
          error={errors.amount?.message}
          {...form.register('amount')}
        />
        <RadioGroup
          legend={t('fx.convert.policy')}
          value={policy}
          options={[
            { value: 'current', label: t('fx.convert.policyCurrent') },
            { value: 'historical', label: t('fx.convert.policyHistorical') },
          ]}
          onChange={(value) => {
            form.setValue('policy', value);
          }}
        />
        {policy === 'historical' ? (
          <TextField
            label={t('fx.convert.date')}
            type="date"
            max={today}
            error={errors.date?.message}
            className="max-w-xs"
            {...form.register('date')}
          />
        ) : null}
        <Button type="submit" loading={convert.isPending}>
          {t('fx.convert.submit')}
        </Button>
      </form>
      <div role="status" className="mt-6">
        {converted ? <ConversionResult converted={converted} /> : null}
      </div>
    </>
  );
}

function ConversionResult({ converted }: { converted: Converted }) {
  const { t, formatLocale } = useI18n();
  const { result, date } = converted;
  return (
    <Alert tone="success" title={t('fx.convert.resultTitle')}>
      <p className="text-xl font-semibold text-fg">
        <MoneyText money={result.from} /> = <MoneyText money={result.to} />
      </p>
      <DisclosedRateText rate={result.rate} />
      <p className="text-sm text-fg-muted">
        {result.policy === 'historical' && date
          ? t('fx.convert.usedHistorical', { date: formatLocalDate(date, formatLocale) })
          : t('fx.convert.usedCurrent')}{' '}
        {isZeroDecimal(result.rounding_delta) ? null : t('fx.convert.rounded')}
      </p>
    </Alert>
  );
}
