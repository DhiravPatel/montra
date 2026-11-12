import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode, isApiError } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Select } from '@/shared/components/Select';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { currencyOptions, useCurrencies } from '@/shared/currency/api';
import { invalidateFinance } from '@/shared/finance/keys';
import { isLocalDate, todayInTimeZone } from '@/shared/formatting/dates';
import { decimalSeparators } from '@/shared/formatting/decimal';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { fxApi } from '../api';
import { CurrenciesGate } from './CurrenciesGate';
import { formatRate, normalizeRateInput, RATE_MAX_DECIMALS, type RateIssue } from '../rate';
import type { ManualRateInput } from '../types';

interface Values {
  base: string;
  quote: string;
  rate: string;
  date: string;
}

function rateIssueMessage(issue: RateIssue, t: Translate, locale: string): string {
  switch (issue) {
    case 'empty':
      return t('fx.form.rateRequired');
    case 'zero':
      return t('fx.form.rateZero');
    case 'ambiguous':
      return t('fx.form.rateDecimalMark', {
        example: `83${decimalSeparators(locale).decimal}1234`,
      });
    case 'format':
    case 'precision':
      return t('validation.rateFormat');
  }
}

/**
 * Adds your own rate for a currency pair (spec §4.19 "manual override").
 * The rate is exact text: it is checked and sent as typed, never as a
 * floating-point number. Earlier rates stay as history.
 */
export function AddRateCard() {
  const { t } = useI18n();
  return (
    <Card title={t('fx.add.title')} description={t('fx.add.description')}>
      <CurrenciesGate>
        <AddRateForm />
      </CurrenciesGate>
    </Card>
  );
}

function AddRateForm() {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const currencies = useCurrencies();
  const today = todayInTimeZone(user.timezone);
  const [formError, setFormError] = useState<string | null>(null);
  const schema = useMemo(
    () =>
      z
        .object({
          base: z.string().min(1, { error: t('fx.form.currencyRequired') }),
          quote: z.string().min(1, { error: t('fx.form.currencyRequired') }),
          rate: z.string(),
          date: z.string(),
        })
        .superRefine((values, ctx) => {
          if (values.base && values.quote && values.base === values.quote) {
            ctx.addIssue({ code: 'custom', path: ['quote'], message: t('fx.form.sameCurrency') });
          }
          const rate = normalizeRateInput(values.rate, formatLocale);
          if (!rate.ok) {
            ctx.addIssue({
              code: 'custom',
              path: ['rate'],
              message: rateIssueMessage(rate.issue, t, formatLocale),
            });
          }
          if (!isLocalDate(values.date)) {
            ctx.addIssue({ code: 'custom', path: ['date'], message: t('validation.dateRequired') });
          } else if (values.date > today) {
            ctx.addIssue({ code: 'custom', path: ['date'], message: t('fx.form.dateFuture') });
          }
        }),
    [t, formatLocale, today],
  );
  const form = useForm<Values>({
    resolver: zodResolver(schema),
    defaultValues: { base: '', quote: user.base_currency, rate: '', date: today },
  });
  const [base, quote, rateText] = useWatch({
    control: form.control,
    name: ['base', 'quote', 'rate'],
  });
  const preview = normalizeRateInput(rateText, formatLocale);
  const add = useMutation({
    mutationFn: (body: ManualRateInput) => fxApi.addRate(body),
    onSuccess: () => invalidateFinance(queryClient),
  });

  const onSubmit = form.handleSubmit((values) => {
    if (add.isPending) return;
    const rate = normalizeRateInput(values.rate, formatLocale);
    if (!rate.ok) return;
    setFormError(null);
    const body: ManualRateInput = {
      base: values.base,
      quote: values.quote,
      rate: rate.value,
      // A bare date means that day in your time zone (today included): the
      // rate applies to conversions dated that day.
      as_of: values.date,
    };
    add.mutate(body, {
      onSuccess: (saved) => {
        toast.show({
          tone: 'success',
          title: t('fx.add.done'),
          description: t('fx.rate.equation', {
            base: saved.base,
            rate: formatRate(saved.rate, formatLocale),
            quote: saved.quote,
          }),
        });
        form.reset({ base: values.base, quote: values.quote, rate: '', date: today });
      },
      onError: (error) => {
        if (hasErrorCode(error, 'VALIDATION_ERROR') && isApiError(error)) {
          const unmatched: string[] = [];
          for (const detail of error.details) {
            if (detail.field === 'body.rate') {
              form.setError('rate', { type: 'server', message: t('validation.rateFormat') });
            } else if (detail.field === 'body.as_of') {
              form.setError('date', { type: 'server', message: t('fx.form.dateFuture') });
            } else if (detail.field === 'body.base' || detail.field === 'body.quote') {
              form.setError('quote', { type: 'server', message: t('fx.form.pairInvalid') });
            } else {
              unmatched.push(detail.message);
            }
          }
          setFormError(
            unmatched.length > 0 || error.details.length === 0 ? describeError(error, t) : null,
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
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <div className="grid gap-5 sm:grid-cols-2">
        <Select
          label={t('fx.add.base')}
          placeholder={t('fx.form.chooseCurrency')}
          options={options}
          error={errors.base?.message}
          {...form.register('base')}
        />
        <Select
          label={t('fx.add.quote')}
          placeholder={t('fx.form.chooseCurrency')}
          options={options}
          error={errors.quote?.message}
          {...form.register('quote')}
        />
      </div>
      <TextField
        label={t('fx.add.rate')}
        inputMode="decimal"
        autoComplete="off"
        spellCheck={false}
        help={
          base && quote && preview.ok
            ? t('fx.rate.equation', {
                base,
                rate: formatRate(preview.value, formatLocale),
                quote,
              })
            : t('fx.add.rateHelp', { count: RATE_MAX_DECIMALS })
        }
        error={errors.rate?.message}
        {...form.register('rate')}
      />
      <TextField
        label={t('fx.add.date')}
        type="date"
        max={today}
        help={t('fx.add.dateHelp')}
        error={errors.date?.message}
        className="max-w-xs"
        {...form.register('date')}
      />
      <Button type="submit" loading={add.isPending}>
        {t('fx.add.submit')}
      </Button>
    </form>
  );
}
