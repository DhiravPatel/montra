import { formatBasisPoints } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';

export type MeterTone = 'accent' | 'success' | 'warning' | 'danger' | 'neutral';

interface ProgressMeterProps {
  /**
   * Share from the API in basis points (10000 = 100 %), e.g. a budget's or
   * goal's `percent_bp`. Never computed on the client; it may exceed 10000.
   */
  percentBp: number;
  /** Accessible name, e.g. "Groceries budget". */
  label: string;
  /**
   * What a screen reader announces, e.g. "₹3,000 of ₹5,000 spent (60 %)".
   * Defaults to the percentage. Show the same facts as visible text nearby:
   * the bar's color is never the only signal.
   */
  valueText?: string;
  tone?: MeterTone;
  /** A reference point on the track, e.g. "expected by today", in basis points. */
  marker?: { percentBp: number; label: string } | null;
  size?: 'sm' | 'md';
  className?: string;
}

const fill: Readonly<Record<MeterTone, string>> = {
  accent: 'bg-accent',
  success: 'bg-success',
  warning: 'bg-warning',
  danger: 'bg-danger',
  neutral: 'bg-fg-muted',
};

function clampPercent(basisPoints: number): number {
  if (!Number.isFinite(basisPoints)) return 0;
  return Math.min(Math.max(basisPoints, 0), 10_000) / 100;
}

/**
 * A horizontal meter (role="meter") for budget use or goal progress. The
 * fill stops at the end of the track when the value is over 100 %; callers
 * say so in words (e.g. "Over by ₹500") next to the bar.
 */
export function ProgressMeter({
  percentBp,
  label,
  valueText,
  tone = 'accent',
  marker,
  size = 'md',
  className,
}: ProgressMeterProps) {
  const { formatLocale } = useI18n();
  const percent = Math.round(percentBp) / 100;
  return (
    <div
      role="meter"
      aria-label={label}
      aria-valuemin={0}
      aria-valuemax={Math.max(100, percent)}
      aria-valuenow={percent}
      aria-valuetext={valueText ?? formatBasisPoints(percentBp, formatLocale)}
      className={cx(
        'relative w-full rounded-full bg-surface-muted ring-1 ring-line ring-inset',
        size === 'sm' ? 'h-1.5' : 'h-2.5',
        className,
      )}
    >
      <div
        className={cx('h-full rounded-full', fill[tone])}
        style={{ width: `${clampPercent(percentBp)}%` }}
      />
      {marker ? (
        <div
          aria-hidden="true"
          title={marker.label}
          className="absolute -top-1 -bottom-1 w-0.5 rounded-full bg-fg"
          style={{ insetInlineStart: `calc(${clampPercent(marker.percentBp)}% - 1px)` }}
        />
      ) : null}
    </div>
  );
}
