import { Link } from 'react-router';
import { ButtonLink } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { EmptyState } from '@/shared/components/states';
import { goalPath, paths } from '@/shared/config/paths';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { GoalProgressSummary } from '@/features/goals/components/GoalProgressSummary';
import { PlanningWidgetCard, type PlanningWidgetProps } from '../components/PlanningWidgetCard';

/** Active goals, nearest target date first: saved of target exactly as the API reports it. */
export function GoalsWidget({ title, planning }: PlanningWidgetProps) {
  const { t, formatLocale } = useI18n();
  return (
    <PlanningWidgetCard
      title={title}
      planning={planning}
      scopeLabel={() => t('dashboard.goals.scope')}
      loadingLabel={t('dashboard.goals.loading')}
      errorTitle={t('dashboard.goals.error')}
      total={(data) => data.goal_count}
      countText={(data) =>
        t('dashboard.goals.count', { count: data.goal_count, shown: data.goals.length })
      }
      viewAll={{
        to: paths.goals,
        label: (count) => t('dashboard.goals.viewAll', { count }),
      }}
      empty={
        <EmptyState
          titleAs="p"
          icon="target"
          title={t('dashboard.goals.empty')}
          description={t('dashboard.goals.emptyBody')}
          action={
            <ButtonLink to={paths.goalNew} variant="secondary">
              <Icon name="plus" className="size-4" />
              {t('dashboard.goals.create')}
            </ButtonLink>
          }
        />
      }
    >
      {(data) => (
        <ul className="divide-y divide-line">
          {data.goals.map((goal) => (
            <li key={goal.id} className="space-y-2 py-3 first:pt-0">
              <div className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
                <Link
                  to={goalPath(goal.id)}
                  className="font-medium break-words text-fg underline-offset-4 hover:underline"
                >
                  {goal.name}
                </Link>
                <span className="text-sm text-fg-muted">
                  {goal.target_date ? (
                    <time dateTime={goal.target_date}>
                      {t('dashboard.goals.targetDate', {
                        date: formatLocalDate(goal.target_date, formatLocale),
                      })}
                    </time>
                  ) : (
                    t('dashboard.goals.noTargetDate')
                  )}
                </span>
              </div>
              <GoalProgressSummary goal={goal} size="sm" />
            </li>
          ))}
        </ul>
      )}
    </PlanningWidgetCard>
  );
}
