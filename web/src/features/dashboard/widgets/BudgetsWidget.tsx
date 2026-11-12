import { Link } from 'react-router';
import { ButtonLink } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { EmptyState } from '@/shared/components/states';
import { budgetPath, paths } from '@/shared/config/paths';
import { formatLocalDateRange } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { BudgetMeter } from '@/features/budgets/components/BudgetMeter';
import { PaceBadge } from '@/features/budgets/components/PaceBadge';
import { PlanningWidgetCard, type PlanningWidgetProps } from '../components/PlanningWidgetCard';

/**
 * Active budgets, fullest first, as the API ranked them: spent of limit
 * with the pace in words (the meter's color only repeats it).
 */
export function BudgetsWidget({ title, planning }: PlanningWidgetProps) {
  const { t, formatLocale } = useI18n();
  return (
    <PlanningWidgetCard
      title={title}
      planning={planning}
      scopeLabel={() => t('dashboard.budgets.scope')}
      loadingLabel={t('dashboard.budgets.loading')}
      errorTitle={t('dashboard.budgets.error')}
      total={(data) => data.budget_count}
      countText={(data) =>
        data.over_budget_count > 0
          ? t('dashboard.budgets.countOver', {
              count: data.budget_count,
              shown: data.budgets.length,
              over: data.over_budget_count,
            })
          : t('dashboard.budgets.count', {
              count: data.budget_count,
              shown: data.budgets.length,
            })
      }
      viewAll={{
        to: paths.budgets,
        label: (count) => t('dashboard.budgets.viewAll', { count }),
      }}
      empty={
        <EmptyState
          titleAs="p"
          icon="pie-chart"
          title={t('dashboard.budgets.empty')}
          description={t('dashboard.budgets.emptyBody')}
          action={
            <ButtonLink to={paths.budgetNew} variant="secondary">
              <Icon name="plus" className="size-4" />
              {t('dashboard.budgets.create')}
            </ButtonLink>
          }
        />
      }
    >
      {(data) => (
        <ul className="divide-y divide-line">
          {data.budgets.map((budget) => {
            const progress = budget.progress;
            return (
              <li key={budget.id} className="space-y-2 py-3 first:pt-0">
                <div className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
                  <Link
                    to={budgetPath(budget.id)}
                    className="font-medium break-words text-fg underline-offset-4 hover:underline"
                  >
                    {budget.name}
                  </Link>
                  {progress ? (
                    <span className="text-sm text-fg-muted">
                      {formatLocalDateRange(
                        progress.period_start,
                        progress.period_end,
                        formatLocale,
                      )}
                    </span>
                  ) : null}
                </div>
                {progress ? (
                  <>
                    <BudgetMeter name={budget.name} progress={progress} />
                    <PaceBadge pace={progress.pace} />
                  </>
                ) : (
                  <p className="text-sm text-fg-muted">{t('budgets.noProgress')}</p>
                )}
              </li>
            );
          })}
        </ul>
      )}
    </PlanningWidgetCard>
  );
}
