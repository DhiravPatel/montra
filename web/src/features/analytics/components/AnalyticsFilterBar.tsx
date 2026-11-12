import { Select } from '@/shared/components/Select';
import { DateRangeFields } from '@/shared/finance/components/DateRangeFields';
import { accountGroups, categoryOptions } from '@/shared/finance/options';
import { useAccounts, useCategories } from '@/shared/finance/reference';
import { useI18n } from '@/shared/i18n/I18nContext';
import { type AnalyticsFilters, periodOutOfOrder } from '../filters';

interface AnalyticsFilterBarProps {
  value: AnalyticsFilters;
  onChange: (next: AnalyticsFilters) => void;
}

/**
 * One filter row above every period-based section: the period (named
 * periods are resolved by the API in your time zone, or custom dates), an
 * account, a category and whether pending transactions count.
 */
export function AnalyticsFilterBar({ value, onChange }: AnalyticsFilterBarProps) {
  const { t, formatLocale } = useI18n();
  const accounts = useAccounts(true);
  const categories = useCategories();
  return (
    <section
      aria-label={t('analytics.filters.label')}
      className="mb-6 rounded-xl border border-line bg-surface p-4 shadow-card sm:p-5"
    >
      <div className="flex flex-wrap items-end gap-3">
        <DateRangeFields
          value={{ range: value.range, from: value.from, to: value.to }}
          error={periodOutOfOrder(value) ? t('validation.dateOrder') : undefined}
          onChange={(next) => {
            if (next.range === 'all') return;
            onChange({ ...value, range: next.range, from: next.from, to: next.to });
          }}
        />
        <Select
          label={t('transactions.filters.account')}
          optional
          placeholder={t('analytics.filters.allAccounts')}
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
        <label className="inline-flex min-h-11 cursor-pointer items-center gap-2 text-sm text-fg">
          <input
            type="checkbox"
            checked={value.includePending}
            onChange={(event) => {
              onChange({ ...value, includePending: event.target.checked });
            }}
            className="size-5 accent-accent"
          />
          {t('analytics.filters.includePending')}
        </label>
      </div>
    </section>
  );
}
