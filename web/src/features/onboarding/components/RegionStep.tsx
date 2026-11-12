import { zodResolver } from '@hookform/resolvers/zod';
import { useMemo, useState } from 'react';
import { useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { currencyOptions, useCurrencies } from '@/shared/currency/api';
import { defaultCurrencyForLocale } from '@/shared/currency/currencies';
import type { PreferencesPatch } from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { FormAlert } from '@/shared/forms/FormAlert';
import { localeDisplayName } from '@/shared/formatting/names';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { supportedLanguages } from '@/shared/i18n/languages';
import { countryOptions, regionOf } from '../countries';
import { StepActions } from './StepActions';
import type { StepProps } from './types';
import { usePreferencePatch } from './usePreferencePatch';

interface RegionValues {
  country: string;
  currency: string;
  timezone: string;
  locale: string;
  weekStart: string;
  monthStartDay: string;
}

function supportedTimeZones(): string[] {
  try {
    return Intl.supportedValuesOf('timeZone');
  } catch {
    return [];
  }
}

function timeZones(current: string): string[] {
  return [...new Set([current, ...supportedTimeZones(), 'UTC'].filter(Boolean))].sort();
}

/** Monday..Sunday names in the interface language, keyed 0 = Sunday like the API. */
function weekdayOptions(locale: string) {
  const format = new Intl.DateTimeFormat(locale, { weekday: 'long', timeZone: 'UTC' });
  // 2026-11-01 was a Sunday.
  return Array.from({ length: 7 }, (_, day) => ({
    value: String(day),
    label: format.format(new Date(Date.UTC(2026, 10, 1 + day))),
  }));
}

/** Country, main currency, time zone, formats and week/month starts (spec §20B.2). */
export function RegionStep(props: StepProps) {
  const { t } = useI18n();
  const currencies = useCurrencies();
  if (currencies.isError) {
    return (
      <ErrorState
        title={t('currency.loadFailed')}
        error={currencies.error}
        onRetry={() => {
          void currencies.refetch();
        }}
      />
    );
  }
  if (currencies.isPending) return <LoadingState label={t('currency.loading')} />;
  return <RegionForm {...props} />;
}

function RegionForm({ preferences, onNext, onBack, advancing }: StepProps) {
  const { t, formatLocale } = useI18n();
  const currencies = useCurrencies();
  const patch = usePreferencePatch();
  const [formError, setFormError] = useState<string | null>(null);
  const initialCountry = preferences.country ?? regionOf(preferences.locale);

  const schema = useMemo(
    () =>
      z.object({
        country: z.string(),
        currency: z.string().regex(/^[A-Z]{3}$/, { error: t('validation.currencyRequired') }),
        timezone: z.string().min(1, { error: t('onboarding.region.timezoneRequired') }),
        locale: z
          .string()
          .regex(/^[a-z]{2,3}(-[A-Z]{2})?$/, { error: t('onboarding.region.localeRequired') }),
        weekStart: z.string().regex(/^[0-6]$/),
        monthStartDay: z.string().regex(/^([1-9]|1\d|2[0-8])$/),
      }),
    [t],
  );
  const form = useForm<RegionValues, unknown, RegionValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      country: initialCountry,
      currency: preferences.base_currency,
      timezone: preferences.timezone,
      locale: preferences.locale,
      weekStart: String(preferences.week_start),
      monthStartDay: String(preferences.month_start_day),
    },
  });

  const countries = useMemo(() => countryOptions(formatLocale), [formatLocale]);
  const zones = useMemo(() => timeZones(preferences.timezone), [preferences.timezone]);
  const country = useWatch({ control: form.control, name: 'country' });
  const locales = [
    ...new Set([
      preferences.locale,
      ...supportedLanguages.flatMap((lang) => (country ? [`${lang}-${country}`, lang] : [lang])),
    ]),
  ];

  const onSubmit = form.handleSubmit((values) => {
    if (patch.isPending) return;
    setFormError(null);
    const body: PreferencesPatch = {};
    if (values.country !== (preferences.country ?? '')) body.country = values.country;
    if (values.currency !== preferences.base_currency) body.base_currency = values.currency;
    if (values.timezone !== preferences.timezone) body.timezone = values.timezone;
    if (values.locale !== preferences.locale) body.locale = values.locale;
    if (Number(values.weekStart) !== preferences.week_start)
      body.week_start = Number(values.weekStart);
    if (Number(values.monthStartDay) !== preferences.month_start_day) {
      body.month_start_day = Number(values.monthStartDay);
    }
    if (Object.keys(body).length === 0) {
      onNext('completed');
      return;
    }
    patch.mutate(body, {
      onSuccess: () => {
        onNext('completed');
      },
      onError: (error) => {
        if (hasErrorCode(error, 'VALIDATION_ERROR')) {
          const rest = applyServerErrors(error, form.setError, {
            country: 'country',
            base_currency: 'currency',
            timezone: 'timezone',
            locale: 'locale',
            week_start: 'weekStart',
            month_start_day: 'monthStartDay',
          });
          if (rest.length > 0) setFormError(rest.join(' '));
        } else {
          setFormError(describeError(error, t));
        }
      },
    });
  });

  const { errors } = form.formState;
  const countryField = form.register('country', {
    onChange: (event: { target: { value: string } }) => {
      // Suggest the country's currency unless the person already chose one.
      if (form.getFieldState('currency').isDirty) return;
      const suggestion = defaultCurrencyForLocale(`und-${event.target.value}`);
      if (
        suggestion &&
        currencies.data?.some((item) => item.code === suggestion && item.selectable)
      ) {
        form.setValue('currency', suggestion);
      }
    },
  });

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <div className="grid gap-5 sm:grid-cols-2">
        <Select
          label={t('onboarding.region.country')}
          optional
          placeholder={t('onboarding.region.countryPlaceholder')}
          options={countries}
          help={t('onboarding.region.countryHelp')}
          error={errors.country?.message}
          {...countryField}
        />
        <Select
          label={t('auth.fields.currency')}
          options={currencyOptions(currencies.data, formatLocale, preferences.base_currency)}
          help={t('onboarding.region.currencyHelp')}
          error={errors.currency?.message}
          {...form.register('currency')}
        />
        <Select
          label={t('onboarding.region.timezone')}
          options={zones.map((zone) => ({ value: zone, label: zone.replace(/_/g, ' ') }))}
          help={t('onboarding.region.timezoneHelp')}
          error={errors.timezone?.message}
          {...form.register('timezone')}
        />
        <Select
          label={t('onboarding.region.locale')}
          options={locales.map((locale) => ({
            value: locale,
            label: localeDisplayName(locale, formatLocale),
          }))}
          help={t('onboarding.region.localeHelp')}
          error={errors.locale?.message}
          {...form.register('locale')}
        />
        <Select
          label={t('onboarding.region.weekStart')}
          options={weekdayOptions(formatLocale)}
          error={errors.weekStart?.message}
          {...form.register('weekStart')}
        />
        <Select
          label={t('onboarding.region.monthStart')}
          options={Array.from({ length: 28 }, (_, index) => ({
            value: String(index + 1),
            label: String(index + 1),
          }))}
          help={t('onboarding.region.monthStartHelp')}
          error={errors.monthStartDay?.message}
          {...form.register('monthStartDay')}
        />
      </div>
      <StepActions
        onBack={onBack}
        onSkip={() => {
          onNext('skipped');
        }}
        primaryLabel={t('common.continue')}
        primaryType="submit"
        pending={patch.isPending || advancing}
      />
    </form>
  );
}
