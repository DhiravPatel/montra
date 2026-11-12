import { Link } from 'react-router';
import { Icon } from '@/shared/components/Icon';
import { goalPath } from '@/shared/config/paths';
import type { Goal } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { goalTypeIcon, goalTypeName } from '../labels';
import { GoalBadges } from './GoalBadges';
import { GoalProgressSummary } from './GoalProgressSummary';

export function GoalCard({ goal }: { goal: Goal }) {
  const { t, formatLocale } = useI18n();
  const details = [
    goalTypeName(goal.goal_type, t),
    goal.target_date
      ? t('goals.card.byDate', { date: formatLocalDate(goal.target_date, formatLocale) })
      : t('goals.card.noDate'),
  ];
  return (
    <article className="flex h-full flex-col gap-4 rounded-xl border border-line bg-surface p-5 shadow-card">
      <div className="flex items-start gap-3">
        <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
          <Icon name={goalTypeIcon(goal.goal_type)} />
        </span>
        <div className="min-w-0 flex-1 space-y-1">
          <h3 className="text-base font-semibold text-fg">
            <Link
              to={goalPath(goal.id)}
              className="underline-offset-4 hover:underline focus-visible:underline"
            >
              {goal.name}
            </Link>
          </h3>
          <p className="text-sm text-fg-muted">{details.join(' · ')}</p>
        </div>
      </div>
      <GoalBadges goal={goal} />
      <div className="mt-auto">
        <GoalProgressSummary goal={goal} size="sm" />
      </div>
    </article>
  );
}
