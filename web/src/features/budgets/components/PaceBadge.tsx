import { StatusBadge } from '@/shared/components/StatusBadge';
import type { BudgetPace } from '@/shared/finance/types';
import { useT } from '@/shared/i18n/I18nContext';
import { paceDisplay } from '../labels';

/** The budget's pace in words with an icon (never color alone). */
export function PaceBadge({ pace }: { pace: BudgetPace }) {
  const t = useT();
  const display = paceDisplay[pace];
  return (
    <StatusBadge tone={display.tone} icon={display.icon}>
      {t(display.label)}
    </StatusBadge>
  );
}
