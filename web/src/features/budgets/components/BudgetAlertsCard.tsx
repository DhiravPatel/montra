import { useState } from 'react';
import { Link } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { budgetPath } from '@/shared/config/paths';
import { LoadMoreButton } from '@/shared/finance/components/LoadMoreButton';
import { formatDateTime, formatRelativeTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { alertMessage, useBudgetAlertActions } from '../alertActions';
import { type AlertStatus, useBudgetAlerts } from '../api';
import { alertStatusLabel } from '../labels';
import { BudgetAlertButtons } from './BudgetAlertButtons';

/**
 * Budget alerts (thresholds reached, possible overspend) with dismiss,
 * snooze and reactivate, in cursor pages ("Load more"). Pass `budgetId` to
 * show one budget's alerts (the server filters by `budget_id`).
 */
export function BudgetAlertsCard({ budgetId }: { budgetId?: string }) {
  const { t, formatLocale } = useI18n();
  const [status, setStatus] = useState<AlertStatus>('active');
  const alerts = useBudgetAlerts(status, budgetId ?? '');
  const actions = useBudgetAlertActions();

  let content;
  if (alerts.isPending) {
    content = <LoadingState label={t('budgets.alerts.loading')} />;
  } else if (alerts.isError && !alerts.isFetchNextPageError) {
    content = hasErrorCode(alerts.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="p" />
    ) : (
      <ErrorState
        titleAs="p"
        title={t('budgets.alerts.error')}
        error={alerts.error}
        retrying={alerts.isFetching}
        onRetry={() => {
          void alerts.refetch();
        }}
      />
    );
  } else {
    const shown = alerts.data.pages.flatMap((page) => page.items);
    const emptyText =
      status === 'active'
        ? t('budgets.alerts.emptyActive')
        : status === 'snoozed'
          ? t('budgets.alerts.emptySnoozed')
          : t('budgets.alerts.emptyDismissed');
    content =
      shown.length === 0 ? (
        <p className="text-sm text-fg-muted">{emptyText}</p>
      ) : (
        <ul className="divide-y divide-line">
          {shown.map((alert) => {
            const message = alertMessage(alert, t, formatLocale);
            const raised = parseTimestamp(alert.triggered_at);
            const until = parseTimestamp(alert.snoozed_until);
            return (
              <li
                key={alert.id}
                className="flex flex-col gap-3 py-3 first:pt-0 last:pb-0 sm:flex-row sm:items-center"
              >
                <div className="flex min-w-0 flex-1 gap-3">
                  <Icon
                    name={alert.kind === 'threshold' ? 'bell' : 'trending-up'}
                    className="mt-0.5 text-warning"
                  />
                  <div className="min-w-0 space-y-1">
                    <p className="text-sm font-medium text-fg">
                      {budgetId ? (
                        message
                      ) : (
                        <Link
                          to={budgetPath(alert.budget_id)}
                          className="underline-offset-4 hover:underline"
                        >
                          {message}
                        </Link>
                      )}
                    </p>
                    <p className="text-xs text-fg-muted">
                      {alert.status === 'snoozed' && until
                        ? t('budgets.alerts.snoozedLabel', {
                            when: formatDateTime(until, formatLocale),
                          })
                        : raised
                          ? t('budgets.alerts.raised', {
                              when: formatRelativeTime(raised, formatLocale),
                            })
                          : null}
                    </p>
                  </div>
                </div>
                <BudgetAlertButtons alert={alert} message={message} actions={actions} />
              </li>
            );
          })}
        </ul>
      );
  }

  return (
    <Card title={t('budgets.alerts.title')} description={t('budgets.alerts.description')}>
      <RadioGroup<AlertStatus>
        legend={t('budgets.alerts.show')}
        hideLegend
        value={status}
        onChange={setStatus}
        options={(['active', 'snoozed', 'dismissed'] as const).map((value) => ({
          value,
          label: t(alertStatusLabel[value]),
        }))}
        className="mb-4"
      />
      {content}
      {alerts.isSuccess || alerts.isFetchNextPageError ? (
        <LoadMoreButton
          hasMore={alerts.hasNextPage}
          loading={alerts.isFetchingNextPage}
          failed={alerts.isFetchNextPageError}
          onLoadMore={() => {
            void alerts.fetchNextPage();
          }}
        />
      ) : null}
    </Card>
  );
}
