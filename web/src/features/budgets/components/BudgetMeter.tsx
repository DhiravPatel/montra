import { ProgressMeter } from '@/shared/components/ProgressMeter';
import type { BudgetProgress } from '@/shared/finance/types';
import { formatBasisPoints } from '@/shared/formatting/dates';
import { isZeroDecimal } from '@/shared/formatting/decimal';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import { expectedMarker } from '../explanation';
import { paceDisplay } from '../labels';

interface BudgetMeterProps {
  name: string;
  progress: BudgetProgress;
  /** Mark where spending would be if it were spread evenly over the period. */
  showExpected?: boolean;
}

/** Spent-of-limit meter with the server's amounts in words beside it. */
export function BudgetMeter({ name, progress, showExpected = false }: BudgetMeterProps) {
  const { t, formatLocale } = useI18n();
  const formatMoney = useFormatMoney();
  const spent = formatMoney(progress.spent);
  const limit = formatMoney(progress.limit);
  const over = !isZeroDecimal(progress.overspent.amount);
  const markerAt = showExpected ? expectedMarker(progress) : null;
  return (
    <div className="space-y-2">
      <ProgressMeter
        percentBp={progress.percent_bp}
        label={t('budgets.progress.meterLabel', { name })}
        valueText={t('budgets.progress.valueText', {
          spent,
          limit,
          percent: formatBasisPoints(progress.percent_bp, formatLocale),
        })}
        tone={paceDisplay[progress.pace].meter}
        marker={
          markerAt === null
            ? null
            : {
                percentBp: markerAt,
                label: t('budgets.progress.expected', {
                  amount: formatMoney(progress.expected_by_now),
                }),
              }
        }
      />
      <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 text-sm">
        <p className="text-fg">{t('budgets.progress.spentOf', { spent, limit })}</p>
        <p className={over ? 'font-medium text-fg' : 'text-fg-muted'}>
          {over
            ? t('budgets.progress.over', { amount: formatMoney(progress.overspent) })
            : t('budgets.progress.left', { amount: formatMoney(progress.remaining) })}
        </p>
      </div>
    </div>
  );
}
