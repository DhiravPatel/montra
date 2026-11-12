import { Controller, useFormContext, useWatch } from 'react-hook-form';
import { Button } from '@/shared/components/Button';
import { FieldError } from '@/shared/components/FieldParts';
import { Icon } from '@/shared/components/Icon';
import { MoneyField } from '@/shared/components/MoneyField';
import { type RadioOption, RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { TextField } from '@/shared/components/TextField';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { type Currency, currencyOptions } from '@/shared/currency/api';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { formatRate } from '@/features/fx/rate';
import type { ExpenseFormValues, RateChoice, SavedRate } from '../expenseForm';
import { fxRateSourceLabel } from '../labels';
import type { Conversion } from '../types';

export type ConversionState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'ready'; conversion: Conversion }
  | { status: 'missing' }
  | { status: 'error'; retry: () => void };

/** Where a looked-up rate comes from (GET /fx/convert). */
const lookupSourceLabel: Readonly<Record<Conversion['rate']['source'], MessageKey>> = {
  manual: 'groupMoney.form.fx.source.manual',
  ecb: 'groupMoney.form.fx.source.ecb',
  provider: 'groupMoney.form.fx.source.provider',
};

interface ForeignCurrencyFieldsProps {
  groupCurrency: string;
  currencies: readonly Currency[] | undefined;
  conversion: ConversionState;
  /**
   * The amount in the group currency as the server knows it: Montra's
   * conversion, or the saved amount of an unchanged expense (null otherwise).
   */
  total: string | null;
  /** The original amount as an exact decimal (null while incomplete). */
  original: string | null;
  /** Edit mode: the rate saved with the expense. */
  saved: SavedRate | null;
  /** Switches to entering your own rate (offered when Montra has none). */
  onUseOwnRate: () => void;
}

/**
 * Paid in another currency: the original amount and where the rate comes
 * from. The server works out the amount in the group currency when the
 * expense is saved (original × rate, rounded as the API does); Montra's own
 * rate is previewed from GET /fx/convert, your own rate is never multiplied
 * here.
 */
export function ForeignCurrencyFields({
  groupCurrency,
  currencies,
  conversion,
  total,
  original,
  saved,
  onUseOwnRate,
}: ForeignCurrencyFieldsProps) {
  const { t, formatLocale } = useI18n();
  const format = useFormatMoney();
  const { register, control, formState } = useFormContext<ExpenseFormValues>();
  const errors = formState.errors;
  const [originalCurrency, rateChoice, expenseDate] = useWatch({
    control,
    name: ['originalCurrency', 'rateChoice', 'expenseDate'],
  });
  const options = currencyOptions(currencies, formatLocale, originalCurrency || undefined).filter(
    (option) => option.value !== groupCurrency,
  );
  const hasCurrency = /^[A-Z]{3}$/.test(originalCurrency);
  const pair = { from: originalCurrency || '—', to: groupCurrency };

  const rateOptions: RadioOption<RateChoice>[] = [
    ...(saved
      ? [
          {
            value: 'saved' as const,
            label: t('groupMoney.form.fx.useSaved'),
            description: t('groupMoney.form.fx.savedRate', {
              from: saved.originalCurrency,
              to: groupCurrency,
              rate: formatRate(saved.rate, formatLocale),
              source: t(fxRateSourceLabel[saved.source]),
            }),
          },
        ]
      : []),
    {
      value: 'montra' as const,
      label: t('groupMoney.form.fx.useMontra'),
      description: t('groupMoney.form.fx.useMontraHelp'),
    },
    {
      value: 'own' as const,
      label: t('groupMoney.form.fx.useOwn'),
      description: t('groupMoney.form.fx.useOwnHelp'),
    },
  ];

  let montraStatus = null;
  if (rateChoice === 'montra' && hasCurrency) {
    switch (conversion.status) {
      case 'loading':
        montraStatus = <p className="text-sm text-fg-muted">{t('groupMoney.form.fx.looking')}</p>;
        break;
      case 'ready':
        montraStatus = (
          <p className="text-sm text-fg">
            {t('groupMoney.form.fx.montraRate', {
              ...pair,
              rate: formatRate(conversion.conversion.rate.rate, formatLocale),
              date: formatLocalDate(expenseDate, formatLocale),
              source: t(lookupSourceLabel[conversion.conversion.rate.source]),
            })}
          </p>
        );
        break;
      case 'missing':
        montraStatus = (
          <div className="space-y-2 text-sm text-fg">
            <p>{t('groupMoney.form.fx.noRate', pair)}</p>
            <div className="flex flex-wrap items-center gap-3">
              <Button variant="secondary" size="sm" onClick={onUseOwnRate}>
                {t('groupMoney.form.fx.enterOwn')}
              </Button>
              <TextLink to={paths.exchangeRates}>{t('groupMoney.form.fx.addRate')}</TextLink>
            </div>
          </div>
        );
        break;
      case 'error':
        montraStatus = (
          <div className="flex flex-wrap items-center gap-3 text-sm">
            <span>{t('groupMoney.form.fx.lookupFailed')}</span>
            <Button variant="secondary" size="sm" onClick={conversion.retry}>
              <Icon name="refresh" className="size-4" />
              {t('common.retry')}
            </Button>
          </div>
        );
        break;
      case 'idle':
        montraStatus = (
          <p className="text-sm text-fg-muted">{t('groupMoney.form.fx.enterOriginal')}</p>
        );
        break;
    }
  }

  // What the expense will be saved as: only amounts the server worked out are shown.
  let outcome;
  if (total && original && hasCurrency) {
    outcome = (
      <p>
        {rateChoice === 'saved'
          ? t('groupMoney.form.fx.savedAs', {
              total: format({ amount: total, currency: groupCurrency }),
            })
          : t('groupMoney.form.fx.willSaveAs', {
              original: format({ amount: original, currency: originalCurrency }),
              total: format({ amount: total, currency: groupCurrency }),
            })}
      </p>
    );
  } else {
    outcome = (
      <p className="text-fg-muted">
        {rateChoice === 'own'
          ? t('groupMoney.form.fx.serverFromOwn', { currency: groupCurrency })
          : rateChoice === 'saved'
            ? t('groupMoney.form.fx.serverFromSaved', { currency: groupCurrency })
            : t('groupMoney.form.fx.serverFromMontra', { currency: groupCurrency })}
      </p>
    );
  }

  return (
    <div className="space-y-5 rounded-lg border border-line p-4">
      <div className="grid gap-5 sm:grid-cols-2">
        <Select
          label={t('groupMoney.form.fx.currency')}
          placeholder={t('groupMoney.form.fx.currencyPlaceholder')}
          options={options}
          error={errors.originalCurrency?.message}
          {...register('originalCurrency')}
        />
        <MoneyField
          label={t('groupMoney.form.fx.originalAmount')}
          currency={hasCurrency ? originalCurrency : null}
          error={errors.originalAmount?.message}
          {...register('originalAmount')}
        />
      </div>
      <Controller
        control={control}
        name="rateChoice"
        render={({ field }) => (
          <RadioGroup<RateChoice>
            legend={t('groupMoney.form.fx.rateLegend')}
            value={field.value}
            onChange={field.onChange}
            variant="cards"
            options={rateOptions}
          />
        )}
      />
      {montraStatus}
      {rateChoice === 'own' ? (
        <TextField
          label={t('groupMoney.form.fx.ownRate', pair)}
          help={t('groupMoney.form.fx.ownRateHelp', pair)}
          inputMode="decimal"
          autoComplete="off"
          maxLength={40}
          error={errors.ownRate?.message}
          {...register('ownRate')}
        />
      ) : null}
      {errors.checks?.rate?.message ? (
        <FieldError id="group-expense-rate-error">{errors.checks.rate.message}</FieldError>
      ) : null}
      <div role="status" className="rounded-md bg-surface-muted p-3 text-sm">
        {outcome}
      </div>
    </div>
  );
}
