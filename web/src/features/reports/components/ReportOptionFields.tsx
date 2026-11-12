import { Checkbox } from '@/shared/components/Checkbox';
import { Select } from '@/shared/components/Select';
import { currencyOptions, useCurrencies } from '@/shared/currency/api';
import { accountGroups, categoryOptions } from '@/shared/finance/options';
import { useAccounts, useCategories } from '@/shared/finance/reference';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { ReportOptionValues } from '../formValues';
import { CONVERTIBLE_TYPES, PERIOD_TYPES } from '../labels';
import type { ReportType } from '../types';

interface ReportOptionFieldsProps {
  type: ReportType | null;
  value: ReportOptionValues;
  onChange: (next: ReportOptionValues) => void;
}

/**
 * Optional filters for reports built from transactions: an account, a
 * category, one currency, pending transactions and converted totals. Reports
 * of current figures (balances, budgets…) take no filters.
 */
export function ReportOptionFields({ type, value, onChange }: ReportOptionFieldsProps) {
  const { t, formatLocale } = useI18n();
  const accounts = useAccounts(true);
  const categories = useCategories();
  const currencies = useCurrencies();
  if (!type) return null;
  if (!PERIOD_TYPES.has(type)) {
    return <p className="text-sm text-fg-muted">{t('reports.form.currentFigures')}</p>;
  }
  const accountCurrencies = [
    ...new Set((accounts.data ?? []).map((account) => account.currency)),
  ].sort();
  return (
    <fieldset className="space-y-4">
      <legend className="mb-1 text-sm font-semibold text-fg">{t('reports.form.filters')}</legend>
      <div className="grid gap-4 sm:grid-cols-2">
        <Select
          label={t('transactions.filters.account')}
          optional
          placeholder={t('reports.form.allAccounts')}
          groups={accountGroups(accounts.data ?? [], t)}
          value={value.accountId}
          onChange={(event) => {
            onChange({ ...value, accountId: event.target.value });
          }}
        />
        <Select
          label={t('transactions.filters.category')}
          optional
          placeholder={t('transactions.filters.anyCategory')}
          options={categoryOptions(categories.data ?? [], t, formatLocale)}
          value={value.categoryId}
          onChange={(event) => {
            onChange({ ...value, categoryId: event.target.value });
          }}
        />
        {accountCurrencies.length > 1 ? (
          <Select
            label={t('reports.form.currency')}
            optional
            placeholder={t('reports.form.allCurrencies')}
            options={accountCurrencies.map((code) => ({ value: code, label: code }))}
            value={value.currency}
            onChange={(event) => {
              onChange({ ...value, currency: event.target.value });
            }}
          />
        ) : null}
        {CONVERTIBLE_TYPES.has(type) ? (
          <Select
            label={t('reports.form.display')}
            optional
            placeholder={t('reports.form.noConversion')}
            options={currencyOptions(currencies.data, formatLocale, value.display || undefined)}
            help={t('reports.form.displayHelp')}
            value={value.display}
            onChange={(event) => {
              onChange({ ...value, display: event.target.value });
            }}
          />
        ) : null}
      </div>
      <Checkbox
        label={t('reports.form.includePending')}
        checked={value.includePending}
        onChange={(event) => {
          onChange({ ...value, includePending: event.target.checked });
        }}
      />
    </fieldset>
  );
}
