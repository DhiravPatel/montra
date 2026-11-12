import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Card } from '@/shared/components/Card';
import { Icon, type IconName } from '@/shared/components/Icon';
import { formatDate, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { HALFWAY_PERCENT, TARGET_PERCENT } from '../progress';
import type { Challenge, ChallengeParticipation } from '../types';
import { ChallengeProgressSummary } from './ChallengeProgressSummary';

interface Milestone {
  id: string;
  label: string;
  detail: string;
  reached: boolean;
}

function MilestoneItem({ milestone }: { milestone: Milestone }) {
  const icon: IconName = milestone.reached ? 'check-circle' : 'circle';
  return (
    <li className="flex items-start gap-3 py-3 first:pt-0 last:pb-0">
      <Icon
        name={icon}
        className={milestone.reached ? 'mt-0.5 text-success' : 'mt-0.5 text-fg-muted'}
      />
      <div className="min-w-0">
        <p className="font-medium text-fg">{milestone.label}</p>
        <p className="text-sm text-fg-muted">{milestone.detail}</p>
      </div>
    </li>
  );
}

/**
 * Your progress in words and as a meter, your streaks, and the milestones
 * the API marks (joining, halfway, reaching the target), all from the
 * API's values.
 */
export function ProgressCard({
  challenge,
  me,
}: {
  challenge: Challenge;
  me: ChallengeParticipation;
}) {
  const { t, formatLocale } = useI18n();
  const { timezone } = useCurrentUser();
  const joined = parseTimestamp(me.joined_at);
  const completed = parseTimestamp(me.completed_at);
  const halfway = me.percent_complete >= HALFWAY_PERCENT;
  const reached = me.status === 'completed' || me.percent_complete >= TARGET_PERCENT;
  const milestones: Milestone[] = [
    {
      id: 'joined',
      label: t('challenges.milestones.joined'),
      detail: joined
        ? t('challenges.milestones.joinedOn', { date: formatDate(joined, formatLocale, timezone) })
        : t('challenges.milestones.reached'),
      reached: true,
    },
    {
      id: 'halfway',
      label: t('challenges.milestones.halfway'),
      detail: halfway ? t('challenges.milestones.reached') : t('challenges.milestones.notYet'),
      reached: halfway,
    },
    {
      id: 'target',
      label: t('challenges.milestones.target'),
      detail: completed
        ? t('challenges.milestones.reachedOn', {
            date: formatDate(completed, formatLocale, timezone),
          })
        : reached
          ? t('challenges.milestones.reached')
          : t('challenges.milestones.notYet'),
      reached,
    },
  ];

  return (
    <Card
      title={t('challenges.progress.title')}
      description={
        me.share_progress ? t('challenges.progress.shared') : t('challenges.progress.private')
      }
    >
      <div className="space-y-6">
        <ChallengeProgressSummary challenge={challenge} me={me} />
        <dl className="grid gap-4 sm:grid-cols-2">
          <div className="rounded-lg border border-line p-3">
            <dt className="text-sm text-fg-muted">{t('challenges.streak.current')}</dt>
            <dd className="text-lg font-semibold text-fg">
              {t('challenges.streak.days', { count: me.current_streak })}
            </dd>
          </div>
          <div className="rounded-lg border border-line p-3">
            <dt className="text-sm text-fg-muted">{t('challenges.streak.best')}</dt>
            <dd className="text-lg font-semibold text-fg">
              {t('challenges.streak.days', { count: me.best_streak })}
            </dd>
          </div>
        </dl>
        <section aria-labelledby={`milestones-${challenge.id}`}>
          <h3 id={`milestones-${challenge.id}`} className="mb-3 text-base font-semibold text-fg">
            {t('challenges.milestones.title')}
          </h3>
          <ul className="divide-y divide-line">
            {milestones.map((milestone) => (
              <MilestoneItem key={milestone.id} milestone={milestone} />
            ))}
          </ul>
        </section>
      </div>
    </Card>
  );
}
