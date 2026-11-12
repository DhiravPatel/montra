import { Select } from '@/shared/components/Select';
import { TextField } from '@/shared/components/TextField';
import { useT } from '@/shared/i18n/I18nContext';
import { type DateRangeValue, parseRangeChoice } from '../dateRange';
import { DATE_RANGE_PRESETS, rangeLabel } from '../labels';

interface DateRangeFieldsProps {
  value: DateRangeValue;
  onChange: (value: DateRangeValue) => void;
  /** Offer "All time" (transaction lists) or not (dashboard periods). */
  allowAll?: boolean;
  label?: string;
  error?: string | undefined;
}

/** Period presets in the user's time zone, plus a custom from/to range. */
export function DateRangeFields({
  value,
  onChange,
  allowAll = false,
  label,
  error,
}: DateRangeFieldsProps) {
  const t = useT();
  const options = [
    ...(allowAll ? [{ value: 'all', label: t('finance.range.all') }] : []),
    ...DATE_RANGE_PRESETS.map((preset) => ({ value: preset, label: t(rangeLabel[preset]) })),
    { value: 'custom', label: t('finance.range.custom') },
  ];
  return (
    <div className="flex flex-wrap items-end gap-3">
      <Select
        label={label ?? t('finance.range.label')}
        options={options}
        value={value.range}
        className="min-w-44 flex-1 sm:flex-none"
        onChange={(event) => {
          const range = parseRangeChoice(event.target.value, allowAll);
          if (range) onChange({ ...value, range });
        }}
      />
      {value.range === 'custom' ? (
        <>
          <TextField
            label={t('finance.range.from')}
            type="date"
            value={value.from}
            max={value.to || undefined}
            className="min-w-40 flex-1 sm:flex-none"
            onChange={(event) => {
              onChange({ ...value, from: event.target.value });
            }}
            error={error}
          />
          <TextField
            label={t('finance.range.to')}
            type="date"
            value={value.to}
            min={value.from || undefined}
            className="min-w-40 flex-1 sm:flex-none"
            onChange={(event) => {
              onChange({ ...value, to: event.target.value });
            }}
          />
        </>
      ) : null}
    </div>
  );
}
