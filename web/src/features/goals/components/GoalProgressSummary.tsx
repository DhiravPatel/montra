import { ProgressMeter } from '@/shared/components/ProgressMeter';
import type { Goal } from '@/shared/finance/types';
import { formatBasisPoints } from '@/shared/formatting/dates';
import { isZeroDecimal } from '@/shared/formatting/decimal';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';

/**
 * Saved / target / remaining exactly as the API reports them, with a meter
 * driven by the server's percent_bp (never computed here).
 */
export function GoalProgressSummary({ goal, size = 'md' }: { goal: Goal; size?: 'sm' | 'md' }) {
  const { t, formatLocale } = useI18n();
  const formatMoney = useFormatMoney();
  const { progress } = goal;
  const percent = formatBasisPoints(progress.percent_bp, formatLocale);
  const done = isZeroDecimal(progress.remaining.amount);
  return (
    <div className="space-y-2">
      <ProgressMeter
        percentBp={progress.percent_bp}
        label={goal.name}
        valueText={t('goals.card.meterValue', {
          saved: formatMoney(progress.saved),
          target: formatMoney(goal.target),
          percent,
        })}
        tone={goal.status === 'achieved' || done ? 'success' : 'accent'}
        size={size}
      />
      <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 text-sm">
        <p className="text-fg">
          <span className="font-semibold">
            {t('goals.card.saved', {
              saved: formatMoney(progress.saved),
              target: formatMoney(goal.target),
            })}
          </span>{' '}
          <span className="text-fg-muted">({percent})</span>
        </p>
        <p className="text-fg-muted">
          {done
            ? t('goals.card.complete')
            : t('goals.card.remaining', { amount: formatMoney(progress.remaining) })}
        </p>
      </div>
    </div>
  );
}
