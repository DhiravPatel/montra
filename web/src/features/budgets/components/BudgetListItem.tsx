import { Link } from 'react-router';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { budgetPath } from '@/shared/config/paths';
import type { Budget } from '@/shared/finance/types';
import { formatLocalDateRange } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { accessLabel, budgetStatusLabel, budgetTypeLabel, periodLabel } from '../labels';
import { BudgetMeter } from './BudgetMeter';
import { PaceBadge } from './PaceBadge';

/** One budget in the list: current period progress in words and a meter. */
export function BudgetListItem({ budget }: { budget: Budget }) {
  const { t, formatLocale } = useI18n();
  const progress = budget.progress;
  const details = [t(budgetTypeLabel[budget.budget_type]), t(periodLabel[budget.period])];
  if (progress) {
    details.push(formatLocalDateRange(progress.period_start, progress.period_end, formatLocale));
  }
  return (
    <li className="space-y-4 rounded-lg border border-line p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0 space-y-1">
          <h3 className="text-base font-semibold text-fg">
            <Link to={budgetPath(budget.id)} className="underline-offset-4 hover:underline">
              {budget.name}
            </Link>
          </h3>
          <p className="text-sm text-fg-muted">{details.join(' · ')}</p>
        </div>
        <div className="flex flex-wrap gap-2">
          {budget.status !== 'active' ? (
            <StatusBadge tone="neutral" icon={budget.status === 'paused' ? 'pause' : 'archive'}>
              {t(budgetStatusLabel[budget.status])}
            </StatusBadge>
          ) : null}
          {budget.access !== 'owner' ? (
            <StatusBadge tone="info" icon="users">
              {t('budgets.sharedBy', {
                name: budget.owner_display_name,
                access: t(accessLabel[budget.access]),
              })}
            </StatusBadge>
          ) : budget.members.length > 0 ? (
            <StatusBadge tone="neutral" icon="users">
              {t('budgets.sharedWith', { count: budget.members.length })}
            </StatusBadge>
          ) : null}
          {budget.group_id ? (
            <StatusBadge tone="neutral" icon="home">
              {t('budgets.groupBudget')}
            </StatusBadge>
          ) : null}
        </div>
      </div>
      {progress ? (
        <div className="space-y-3">
          <BudgetMeter name={budget.name} progress={progress} />
          <PaceBadge pace={progress.pace} />
        </div>
      ) : (
        <p className="text-sm text-fg-muted">{t('budgets.noProgress')}</p>
      )}
    </li>
  );
}
