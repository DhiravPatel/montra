import type { ReactNode } from 'react';
import { Select } from '@/shared/components/Select';
import { currencyOptions, useCurrencies } from '@/shared/currency/api';
import { useI18n } from '@/shared/i18n/I18nContext';
import { allowedGranularities, type AnalyticsFilters, effectiveGranularity } from '../filters';
import { granularityLabel } from '../labels';

/** Options for one section (how a chart is grouped, what else to show). */
export function ViewOptions({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div role="group" aria-label={label} className="mb-6 flex flex-wrap items-end gap-3">
      {children}
    </div>
  );
}

interface FilterControlProps {
  filters: AnalyticsFilters;
  onChange: (next: AnalyticsFilters) => void;
}

/** Day / week / month / year buckets; only sizes that keep the chart readable for the period. */
export function GroupBySelect({ filters, onChange }: FilterControlProps) {
  const { t } = useI18n();
  const allowed = allowedGranularities(filters);
  return (
    <Select
      label={t('analytics.group.label')}
      value={effectiveGranularity(filters) ?? ''}
      options={[
        { value: '', label: t('analytics.group.auto') },
        ...allowed.map((granularity) => ({
          value: granularity,
          label: t(granularityLabel[granularity]),
        })),
      ]}
      className="min-w-44"
      onChange={(event) => {
        const value = event.target.value;
        const next = allowed.find((granularity) => granularity === value);
        onChange({ ...filters, group: next ?? '' });
      }}
    />
  );
}

/** Adds totals converted by the API into one currency, with the rates disclosed. */
export function DisplayCurrencySelect({ filters, onChange }: FilterControlProps) {
  const { t, formatLocale } = useI18n();
  const currencies = useCurrencies();
  return (
    <Select
      label={t('analytics.converted.label')}
      optional
      value={filters.display}
      placeholder={t('analytics.converted.none')}
      options={currencyOptions(currencies.data, formatLocale, filters.display || undefined)}
      help={t('analytics.converted.help')}
      className="min-w-56"
      onChange={(event) => {
        onChange({ ...filters, display: event.target.value });
      }}
    />
  );
}
