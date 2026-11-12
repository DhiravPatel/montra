import { Select } from '@/shared/components/Select';
import { DateRangeFields } from '@/shared/finance/components/DateRangeFields';
import { accountGroups, categoryOptions } from '@/shared/finance/options';
import { useAccounts, useCategories } from '@/shared/finance/reference';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { DashboardFilters as Filters } from '../filters';

interface DashboardFiltersProps {
  value: Filters;
  onChange: (next: Filters) => void;
  rangeError?: string | undefined;
}

/** One filter row above every widget; all widgets use the same slice (spec §4.2 filters). */
export function DashboardFilters({ value, onChange, rangeError }: DashboardFiltersProps) {
  const { t, formatLocale } = useI18n();
  const accounts = useAccounts();
  const categories = useCategories();
  const currencies = [...new Set((accounts.data ?? []).map((account) => account.currency))].sort();
  return (
    <section
      aria-label={t('dashboard.filters.label')}
      className="mb-6 rounded-xl border border-line bg-surface p-4 shadow-card sm:p-5"
    >
      <div className="flex flex-wrap items-end gap-3">
        <DateRangeFields
          value={{ range: value.range, from: value.from, to: value.to }}
          error={rangeError}
          onChange={(next) => {
            if (next.range === 'all') return;
            onChange({ ...value, range: next.range, from: next.from, to: next.to });
          }}
        />
        <Select
          label={t('transactions.filters.account')}
          optional
          placeholder={t('dashboard.filters.allAccounts')}
          value={value.accountId}
          groups={accountGroups(accounts.data ?? [], t)}
          className="min-w-48"
          onChange={(event) => {
            onChange({ ...value, accountId: event.target.value });
          }}
        />
        <Select
          label={t('transactions.filters.category')}
          optional
          placeholder={t('transactions.filters.anyCategory')}
          value={value.categoryId}
          options={categoryOptions(categories.data ?? [], t, formatLocale)}
          className="min-w-48"
          onChange={(event) => {
            onChange({ ...value, categoryId: event.target.value });
          }}
        />
        {currencies.length > 1 ? (
          <Select
            label={t('common.currency')}
            optional
            placeholder={t('dashboard.filters.allCurrencies')}
            value={value.currency}
            options={currencies.map((code) => ({ value: code, label: code }))}
            className="min-w-36"
            onChange={(event) => {
              onChange({ ...value, currency: event.target.value });
            }}
          />
        ) : null}
        <label className="inline-flex min-h-11 cursor-pointer items-center gap-2 text-sm text-fg">
          <input
            type="checkbox"
            checked={value.includePending}
            onChange={(event) => {
              onChange({ ...value, includePending: event.target.checked });
            }}
            className="size-5 accent-accent"
          />
          {t('dashboard.filters.includePending')}
        </label>
      </div>
    </section>
  );
}
