import { useI18n } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';

export interface CountItem {
  key: string;
  label: string;
  value: number;
  /** A short note under the number (e.g. "left out unless fixed"). */
  note?: string;
}

/** Row counts reported by the server, as a grid of labelled numbers. */
export function CountGrid({
  items,
  className,
}: {
  items: readonly CountItem[];
  className?: string;
}) {
  const { formatLocale } = useI18n();
  const format = new Intl.NumberFormat(formatLocale);
  return (
    <dl className={cx('grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4', className)}>
      {items.map((item) => (
        <div key={item.key} className="rounded-lg border border-line bg-surface p-3">
          <dt className="text-sm text-fg-muted">{item.label}</dt>
          <dd className="mt-1 text-xl font-semibold text-fg tabular-nums">
            {format.format(item.value)}
          </dd>
          {item.note ? <dd className="mt-0.5 text-xs text-fg-muted">{item.note}</dd> : null}
        </div>
      ))}
    </dl>
  );
}
