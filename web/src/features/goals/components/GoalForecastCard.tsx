import { Card } from '@/shared/components/Card';
import { Disclosure } from '@/shared/components/Disclosure';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon } from '@/shared/components/Icon';
import { ErrorState, LoadingState } from '@/shared/components/states';
import type { Goal, GoalForecast } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useGoalForecast } from '../api';
import { forecastAssumptions } from '../forecast';
import { scheduleLabel } from '../labels';

function OnTrack({ forecast }: { forecast: GoalForecast }) {
  const { t } = useI18n();
  if (forecast.achieved) {
    return (
      <p className="flex items-start gap-2 text-fg">
        <Icon name="flag" className="mt-0.5 size-4 text-success" />
        {t('goals.forecast.achieved')}
      </p>
    );
  }
  if (forecast.on_track === undefined) return null;
  return forecast.on_track ? (
    <p className="flex items-start gap-2 text-fg">
      <Icon name="check-circle" className="mt-0.5 size-4 text-success" />
      {t('goals.forecast.onTrack')}
    </p>
  ) : (
    <p className="flex items-start gap-2 text-fg">
      <Icon name="info" className="mt-0.5 size-4 text-info" />
      {t('goals.forecast.offTrack')}
    </p>
  );
}

/** Required pace, recent pace and estimated completion, in calm words. */
export function GoalForecastCard({ goal }: { goal: Goal }) {
  const { t, formatLocale } = useI18n();
  const formatMoney = useFormatMoney();
  const query = useGoalForecast(goal.id);

  let content;
  if (query.isPending) {
    content = <LoadingState label={t('goals.forecast.loading')} />;
  } else if (query.isError) {
    content = (
      <ErrorState
        titleAs="p"
        title={t('goals.forecast.error')}
        error={query.error}
        retrying={query.isFetching}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  } else {
    const forecast = query.data;
    const date = (value: string) => formatLocalDate(value, formatLocale, 'long');
    const targetDate = forecast.target_date;
    const assumptions = forecastAssumptions(forecast, t);
    content = (
      <div className="space-y-5">
        <div className="space-y-2">
          <OnTrack forecast={forecast} />
          {targetDate && !forecast.achieved ? (
            <p className="text-sm text-fg-muted">
              {forecast.days_left !== undefined && forecast.days_left > 0
                ? t('goals.forecast.daysLeft', {
                    count: forecast.days_left,
                    date: date(targetDate),
                  })
                : t('goals.forecast.datePassed', { date: date(targetDate) })}
            </p>
          ) : null}
        </div>
        {!forecast.achieved ? (
          <Facts>
            {forecast.required_per_month ? (
              <Fact label={t('goals.forecast.requiredPerMonth')}>
                <span className="block">{formatMoney(forecast.required_per_month)}</span>
                {targetDate ? (
                  <span className="block text-sm text-fg-muted">
                    {t('goals.forecast.requiredHelp', { date: date(targetDate) })}
                  </span>
                ) : null}
              </Fact>
            ) : null}
            {forecast.required_per_week ? (
              <Fact label={t('goals.forecast.requiredPerWeek')}>
                {formatMoney(forecast.required_per_week)}
              </Fact>
            ) : null}
            <Fact label={t('goals.forecast.pace')}>
              {t('goals.forecast.paceValue', { amount: formatMoney(forecast.recent_monthly_pace) })}
            </Fact>
            <Fact label={t('goals.forecast.projected')}>
              {forecast.projected_completion
                ? t('goals.forecast.aroundDate', { date: date(forecast.projected_completion) })
                : t('goals.forecast.noPace')}
            </Fact>
            {forecast.planned_completion && goal.contribution_schedule !== 'none' ? (
              <Fact label={t('goals.forecast.planned')}>
                <span className="block">
                  {t('goals.forecast.aroundDate', { date: date(forecast.planned_completion) })}
                </span>
                {goal.planned_contribution ? (
                  <span className="block text-sm text-fg-muted">
                    {t('goals.detail.planValue', {
                      schedule: t(scheduleLabel[goal.contribution_schedule]),
                      amount: formatMoney(goal.planned_contribution),
                    })}
                  </span>
                ) : null}
              </Fact>
            ) : null}
          </Facts>
        ) : null}
        {assumptions.length > 0 ? (
          <Disclosure summary={t('goals.forecast.assumptions')}>
            <ul className="list-disc space-y-1 ps-5 text-sm text-fg-muted">
              {assumptions.map((assumption) => (
                <li key={assumption.text} lang={assumption.lang}>
                  {assumption.text}
                </li>
              ))}
            </ul>
          </Disclosure>
        ) : null}
      </div>
    );
  }

  return (
    <Card title={t('goals.forecast.title')} description={t('goals.forecast.description')}>
      {content}
    </Card>
  );
}
