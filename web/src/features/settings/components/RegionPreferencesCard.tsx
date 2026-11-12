import { useMemo, useState } from 'react';
import { useForm, useWatch } from 'react-hook-form';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Select } from '@/shared/components/Select';
import { useToast } from '@/shared/components/toast/ToastContext';
import { currencyOptions, useCurrencies } from '@/shared/currency/api';
import { rangeLabel } from '@/shared/finance/labels';
import { accountGroups } from '@/shared/finance/options';
import { useAccounts } from '@/shared/finance/reference';
import type { Preferences } from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { FormAlert } from '@/shared/forms/FormAlert';
import { localeDisplayName } from '@/shared/formatting/names';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { supportedLanguages } from '@/shared/i18n/languages';
import type { MessageKey } from '@/shared/i18n/types';
import { useTheme } from '@/shared/theme/ThemeContext';
import { countryOptions, regionOf } from '@/features/onboarding/countries';
import { monthStartOptions, timeZones, weekdayOptions } from '@/features/onboarding/regionOptions';
import { useSavePreferences } from '../profileApi';
import {
  DEFAULT_DATE_RANGES,
  type RegionValues,
  regionPatch,
  regionValues,
} from '../profileValues';

const DATE_FORMATS: readonly { value: Preferences['date_format']; label: MessageKey }[] = [
  { value: 'locale', label: 'profileSettings.region.dateFormat.locale' },
  { value: 'dmy', label: 'profileSettings.region.dateFormat.dmy' },
  { value: 'mdy', label: 'profileSettings.region.dateFormat.mdy' },
  { value: 'ymd', label: 'profileSettings.region.dateFormat.ymd' },
];

const NUMBER_FORMATS: readonly { value: Preferences['number_format']; label: MessageKey }[] = [
  { value: 'locale', label: 'profileSettings.region.numberFormat.locale' },
  { value: 'indian', label: 'profileSettings.region.numberFormat.indian' },
  { value: 'international', label: 'profileSettings.region.numberFormat.international' },
];

const THEMES: readonly { value: Preferences['theme']; label: MessageKey }[] = [
  { value: 'system', label: 'preferences.theme.system' },
  { value: 'light', label: 'preferences.theme.light' },
  { value: 'dark', label: 'preferences.theme.dark' },
];

/** API fields (without `body.`) and the form fields they belong to. */
const FIELD_MAP: Readonly<Record<string, keyof RegionValues>> = {
  base_currency: 'baseCurrency',
  display_currency: 'displayCurrency',
  country: 'country',
  timezone: 'timezone',
  locale: 'locale',
  date_format: 'dateFormat',
  number_format: 'numberFormat',
  week_start: 'weekStart',
  month_start_day: 'monthStartDay',
  default_account_id: 'defaultAccountId',
  default_date_range: 'defaultDateRange',
  theme: 'theme',
};

/**
 * Region, currencies, formats, defaults and theme (PATCH
 * /me/preferences). Only the fields that changed are sent.
 */
export function RegionPreferencesCard({ preferences }: { preferences: Preferences }) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const { setPreference } = useTheme();
  const currencies = useCurrencies();
  const accounts = useAccounts();
  const save = useSavePreferences();
  const [formError, setFormError] = useState<string | null>(null);
  const form = useForm<RegionValues>({ defaultValues: regionValues(preferences) });
  const { errors } = form.formState;

  const country = useWatch({ control: form.control, name: 'country' });
  const baseCurrency = useWatch({ control: form.control, name: 'baseCurrency' });
  const countries = useMemo(() => countryOptions(formatLocale), [formatLocale]);
  const zones = useMemo(() => timeZones(preferences.timezone), [preferences.timezone]);
  const region = country || regionOf(preferences.locale);
  const locales = [
    ...new Set([
      preferences.locale,
      ...supportedLanguages.flatMap((lang) => (region ? [`${lang}-${region}`, lang] : [lang])),
    ]),
  ];
  const currencyChoices = currencyOptions(currencies.data, formatLocale, preferences.base_currency);
  const displayChoices = currencyOptions(
    currencies.data,
    formatLocale,
    preferences.display_currency,
  );
  // Active accounts you own, plus the current default if it is no longer one of them.
  const ownAccounts = (accounts.data ?? []).filter((account) => account.owned);
  const defaultMissing =
    preferences.default_account_id &&
    !ownAccounts.some((account) => account.id === preferences.default_account_id);

  const onSubmit = form.handleSubmit((values) => {
    if (save.isPending) return;
    setFormError(null);
    const patch = regionPatch(values, preferences);
    if (Object.keys(patch).length === 0) {
      toast.show({ tone: 'info', title: t('profileSettings.nothingChanged') });
      return;
    }
    save.mutate(patch, {
      onSuccess: (updated) => {
        form.reset(regionValues(updated));
        if (patch.theme) setPreference(updated.theme);
        toast.show({ tone: 'success', title: t('profileSettings.region.saved') });
      },
      onError: (error) => {
        if (hasErrorCode(error, 'VALIDATION_ERROR')) {
          const rest = applyServerErrors(error, form.setError, FIELD_MAP);
          if (rest.length > 0) setFormError(rest.join(' '));
        } else {
          setFormError(describeError(error, t));
        }
      },
    });
  });

  return (
    <Card
      title={t('profileSettings.region.title')}
      description={t('profileSettings.region.description')}
    >
      <form noValidate onSubmit={onSubmit} className="space-y-6">
        <FormAlert message={formError} />
        {currencies.isError ? (
          <Alert tone="warning">{t('profileSettings.region.currenciesFailed')}</Alert>
        ) : null}

        <fieldset className="space-y-4">
          <legend className="text-base font-semibold text-fg">
            {t('profileSettings.region.money')}
          </legend>
          <div className="grid gap-5 sm:grid-cols-2">
            <Select
              label={t('auth.fields.currency')}
              options={
                currencyChoices.length > 0
                  ? currencyChoices
                  : [{ value: preferences.base_currency, label: preferences.base_currency }]
              }
              help={t('profileSettings.region.baseCurrencyHelp')}
              error={errors.baseCurrency?.message}
              {...form.register('baseCurrency')}
            />
            <Select
              label={t('profileSettings.region.displayCurrency')}
              optional
              options={[
                { value: '', label: t('profileSettings.region.displayCurrencyNone') },
                ...displayChoices,
              ]}
              help={t('profileSettings.region.displayCurrencyHelp')}
              error={errors.displayCurrency?.message}
              {...form.register('displayCurrency')}
            />
          </div>
          {baseCurrency !== preferences.base_currency ? (
            <Alert tone="info" title={t('profileSettings.region.baseChangeTitle')}>
              <p>
                {t('profileSettings.region.baseChangeBody', {
                  from: preferences.base_currency,
                  to: baseCurrency,
                })}
              </p>
            </Alert>
          ) : null}
        </fieldset>

        <fieldset className="space-y-4">
          <legend className="text-base font-semibold text-fg">
            {t('profileSettings.region.place')}
          </legend>
          <div className="grid gap-5 sm:grid-cols-2">
            <Select
              label={t('onboarding.region.country')}
              optional
              options={[
                { value: '', label: t('profileSettings.region.countryNone') },
                ...countries,
              ]}
              help={t('onboarding.region.countryHelp')}
              error={errors.country?.message}
              {...form.register('country')}
            />
            <Select
              label={t('onboarding.region.timezone')}
              options={zones.map((zone) => ({ value: zone, label: zone.replace(/_/g, ' ') }))}
              help={t('onboarding.region.timezoneHelp')}
              error={errors.timezone?.message}
              {...form.register('timezone')}
            />
          </div>
        </fieldset>

        <fieldset className="space-y-4">
          <legend className="text-base font-semibold text-fg">
            {t('profileSettings.region.formats')}
          </legend>
          <p className="text-sm text-fg-muted">{t('profileSettings.region.formatsHelp')}</p>
          <div className="grid gap-5 sm:grid-cols-3">
            <Select
              label={t('onboarding.region.locale')}
              options={locales.map((locale) => ({
                value: locale,
                label: localeDisplayName(locale, formatLocale),
              }))}
              error={errors.locale?.message}
              {...form.register('locale')}
            />
            <Select
              label={t('profileSettings.region.dateFormat')}
              options={DATE_FORMATS.map((item) => ({ value: item.value, label: t(item.label) }))}
              error={errors.dateFormat?.message}
              {...form.register('dateFormat')}
            />
            <Select
              label={t('profileSettings.region.numberFormat')}
              options={NUMBER_FORMATS.map((item) => ({ value: item.value, label: t(item.label) }))}
              error={errors.numberFormat?.message}
              {...form.register('numberFormat')}
            />
          </div>
        </fieldset>

        <fieldset className="space-y-4">
          <legend className="text-base font-semibold text-fg">
            {t('profileSettings.region.periods')}
          </legend>
          <div className="grid gap-5 sm:grid-cols-3">
            <Select
              label={t('onboarding.region.weekStart')}
              options={weekdayOptions(formatLocale)}
              error={errors.weekStart?.message}
              {...form.register('weekStart')}
            />
            <Select
              label={t('onboarding.region.monthStart')}
              options={monthStartOptions()}
              help={t('profileSettings.region.monthStartHelp')}
              error={errors.monthStartDay?.message}
              {...form.register('monthStartDay')}
            />
            <Select
              label={t('profileSettings.region.defaultRange')}
              options={DEFAULT_DATE_RANGES.map((range) => ({
                value: range,
                label: t(rangeLabel[range]),
              }))}
              help={t('profileSettings.region.defaultRangeHelp')}
              error={errors.defaultDateRange?.message}
              {...form.register('defaultDateRange')}
            />
          </div>
        </fieldset>

        <fieldset className="space-y-4">
          <legend className="text-base font-semibold text-fg">
            {t('profileSettings.region.defaults')}
          </legend>
          <div className="grid gap-5 sm:grid-cols-2">
            <Select
              label={t('profileSettings.region.defaultAccount')}
              optional
              options={[
                { value: '', label: t('profileSettings.region.defaultAccountNone') },
                ...(defaultMissing && preferences.default_account_id
                  ? [
                      {
                        value: preferences.default_account_id,
                        label: t('profileSettings.region.defaultAccountUnavailable'),
                      },
                    ]
                  : []),
              ]}
              groups={accountGroups(ownAccounts, t)}
              help={
                accounts.isError
                  ? t('profileSettings.region.accountsFailed')
                  : t('profileSettings.region.defaultAccountHelp')
              }
              error={errors.defaultAccountId?.message}
              {...form.register('defaultAccountId')}
            />
            <Select
              label={t('preferences.theme')}
              options={THEMES.map((item) => ({ value: item.value, label: t(item.label) }))}
              help={t('profileSettings.region.themeHelp')}
              error={errors.theme?.message}
              {...form.register('theme')}
            />
          </div>
        </fieldset>

        <Button type="submit" loading={save.isPending}>
          {t('profileSettings.region.save')}
        </Button>
      </form>
    </Card>
  );
}
