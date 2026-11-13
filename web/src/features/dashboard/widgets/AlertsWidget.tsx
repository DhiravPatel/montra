import { Link } from 'react-router';
import { Icon } from '@/shared/components/Icon';
import { EmptyState } from '@/shared/components/states';
import { budgetPath, paths } from '@/shared/config/paths';
import { formatRelativeTime, parseTimestamp } from '@/shared/formatting/dates';
import { useNow } from '@/shared/hooks/useNow';
import { useI18n } from '@/shared/i18n/I18nContext';
import { alertMessage, useBudgetAlertActions } from '@/features/budgets/alertActions';
import { BudgetAlertButtons } from '@/features/budgets/components/BudgetAlertButtons';
import { PlanningWidgetCard, type PlanningWidgetProps } from '../components/PlanningWidgetCard';

/**
 * Active budget alerts, newest first: the budget, what happened and the
 * threshold in words, with snooze and dismiss. A change refreshes the
 * planning cards (and every alert list) from the API.
 */
export function AlertsWidget({ title, planning }: PlanningWidgetProps) {
  const { t, formatLocale } = useI18n();
  const now = useNow();
  const actions = useBudgetAlertActions();
  return (
    <PlanningWidgetCard
      title={title}
      planning={planning}
      scopeLabel={() => t('dashboard.alerts.scope')}
      loadingLabel={t('dashboard.alerts.loading')}
      errorTitle={t('dashboard.alerts.error')}
      total={(data) => data.alert_count}
      countText={(data) =>
        t('dashboard.alerts.count', { count: data.alert_count, shown: data.alerts.length })
      }
      viewAll={{
        to: paths.budgets,
        label: (count) => t('dashboard.alerts.viewAll', { count }),
      }}
      empty={
        <EmptyState
          titleAs="p"
          icon="bell"
          title={t('dashboard.alerts.empty')}
          description={t('dashboard.alerts.emptyBody')}
        />
      }
    >
      {(data) => (
        <ul className="divide-y divide-line">
          {data.alerts.map((alert) => {
            const message = alertMessage(alert, t, formatLocale);
            const raised = parseTimestamp(alert.triggered_at);
            return (
              <li
                key={alert.id}
                className="flex flex-col gap-3 py-3 first:pt-0 sm:flex-row sm:items-center"
              >
                <div className="flex min-w-0 flex-1 gap-3">
                  <Icon
                    name={alert.kind === 'threshold' ? 'bell' : 'trending-up'}
                    className="mt-0.5 shrink-0 text-warning"
                  />
                  <div className="min-w-0 space-y-1">
                    <p className="text-sm font-medium break-words text-fg">
                      <Link
                        to={budgetPath(alert.budget_id)}
                        className="underline-offset-4 hover:underline"
                      >
                        {message}
                      </Link>
                    </p>
                    {raised ? (
                      <p className="text-xs text-fg-muted">
                        <time dateTime={alert.triggered_at}>
                          {t('budgets.alerts.raised', {
                            when: formatRelativeTime(raised, formatLocale, now),
                          })}
                        </time>
                      </p>
                    ) : null}
                  </div>
                </div>
                <BudgetAlertButtons alert={alert} message={message} actions={actions} />
              </li>
            );
          })}
        </ul>
      )}
    </PlanningWidgetCard>
  );
}
