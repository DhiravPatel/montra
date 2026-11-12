import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Card } from '@/shared/components/Card';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import type { Goal } from '@/shared/finance/types';
import { formatBasisPoints, formatDate, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { GoalProgressSummary } from './GoalProgressSummary';

/** Server progress with its parts, and the milestones reached so far. */
export function GoalProgressCard({ goal }: { goal: Goal }) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const { progress } = goal;
  const milestones = [...goal.milestones].sort((a, b) => a.percent - b.percent);
  return (
    <Card title={t('goals.progress.title')} description={t('goals.progress.savedNote')}>
      <div className="space-y-6">
        <GoalProgressSummary goal={goal} />
        <Facts>
          <Fact label={t('goals.progress.saved')}>
            <MoneyText money={progress.saved} />
          </Fact>
          <Fact label={t('goals.detail.starting')}>
            <MoneyText money={goal.starting} />
          </Fact>
          <Fact label={t('goals.progress.verified')}>
            <MoneyText money={progress.verified} />
          </Fact>
          <Fact label={t('goals.progress.planned')}>
            <MoneyText money={progress.planned} />
          </Fact>
          <Fact label={t('goals.progress.count')}>
            {new Intl.NumberFormat(formatLocale).format(progress.contribution_count)}
          </Fact>
        </Facts>
        <section aria-labelledby="goal-milestones" className="space-y-3">
          <h3 id="goal-milestones" className="text-base font-semibold text-fg">
            {t('goals.milestones.title')}
          </h3>
          {milestones.length === 0 ? (
            <p className="text-sm text-fg-muted">{t('goals.milestones.none')}</p>
          ) : (
            <ol className="space-y-2">
              {milestones.map((milestone) => {
                const reached = parseTimestamp(milestone.reached_at);
                const percent = t('goals.card.percent', {
                  percent: formatBasisPoints(milestone.percent * 100, formatLocale),
                });
                return (
                  <li key={milestone.percent} className="flex items-start gap-3 text-sm">
                    <Icon
                      name={reached ? 'check-circle' : 'circle'}
                      className={cx('mt-0.5 size-4', reached ? 'text-success' : 'text-fg-muted')}
                    />
                    <div className="min-w-0">
                      <p className="font-medium text-fg">
                        {milestone.label ? `${milestone.label} · ${percent}` : percent}
                      </p>
                      <p className="text-fg-muted">
                        {reached
                          ? t('goals.milestones.reached', {
                              date: formatDate(reached, formatLocale, user.timezone),
                            })
                          : t('goals.milestones.notYet')}
                      </p>
                    </div>
                  </li>
                );
              })}
            </ol>
          )}
        </section>
      </div>
    </Card>
  );
}
