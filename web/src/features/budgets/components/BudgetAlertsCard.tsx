import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { buttonClasses } from '@/shared/components/buttonStyles';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { Menu, MenuContent, MenuItem, MenuTrigger } from '@/shared/components/Menu';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { budgetPath } from '@/shared/config/paths';
import { LoadMoreButton } from '@/shared/finance/components/LoadMoreButton';
import type { BudgetAlert, BudgetAlertUpdate } from '@/shared/finance/types';
import {
  formatBasisPoints,
  formatDateTime,
  formatRelativeTime,
  parseTimestamp,
} from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { type AlertStatus, budgetsApi, useBudgetAlerts } from '../api';
import { alertStatusLabel } from '../labels';

const DAY_MS = 24 * 60 * 60 * 1000;

/** An RFC 3339 instant `days` from now (for snoozing). */
function snoozeUntil(days: number): string {
  return new Date(Date.now() + days * DAY_MS).toISOString();
}

function alertMessage(alert: BudgetAlert, t: Translate, locale: string): string {
  switch (alert.kind) {
    case 'threshold':
      return t('budgets.alerts.threshold', {
        name: alert.budget_name,
        percent: formatBasisPoints(alert.threshold * 100, locale),
      });
    case 'forecast_overspend':
      return t('budgets.alerts.forecast', { name: alert.budget_name });
    case 'unusual_spend':
      return t('budgets.alerts.unusual', { name: alert.budget_name });
  }
}

interface AlertChange {
  alert: BudgetAlert;
  body: BudgetAlertUpdate;
}

/**
 * Budget alerts (thresholds reached, possible overspend) with dismiss,
 * snooze and reactivate, in cursor pages ("Load more"). Pass `budgetId` to
 * show one budget's alerts (the server filters by `budget_id`).
 */
export function BudgetAlertsCard({ budgetId }: { budgetId?: string }) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [status, setStatus] = useState<AlertStatus>('active');
  const alerts = useBudgetAlerts(status, budgetId ?? '');
  const update = useMutation({
    mutationFn: ({ alert, body }: AlertChange) => budgetsApi.updateAlert(alert.id, body),
    onSettled: () => queryClient.invalidateQueries({ queryKey: ['finance', 'budget-alerts'] }),
  });

  const change = (alert: BudgetAlert, body: BudgetAlertUpdate) => {
    if (update.isPending) return;
    update.mutate(
      { alert, body },
      {
        onSuccess: () => {
          let title: string;
          if (body.status === 'dismissed') title = t('budgets.alerts.dismissed');
          else if (body.status === 'active') title = t('budgets.alerts.reactivated');
          else {
            const until = parseTimestamp(body.snoozed_until);
            title = t('budgets.alerts.snoozedUntil', {
              when: until ? formatDateTime(until, formatLocale) : '',
            });
          }
          toast.show({ tone: 'success', title });
        },
        onError: (error) => {
          toast.show({
            tone: 'danger',
            title: t('budgets.alerts.updateFailed'),
            description: describeError(error, t),
          });
        },
      },
    );
  };

  const snooze = (alert: BudgetAlert, days: number) => {
    change(alert, {
      status: 'snoozed',
      snoozed_until: snoozeUntil(days),
    });
  };

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
            const busy = update.isPending && update.variables.alert.id === alert.id;
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
                <div className="flex shrink-0 flex-wrap gap-2">
                  {alert.status === 'active' ? (
                    <Menu>
                      <MenuTrigger
                        className={buttonClasses('secondary', 'sm')}
                        aria-label={`${t('budgets.alerts.snooze')}: ${message}`}
                        disabled={busy}
                      >
                        <Icon name="bell-off" className="size-4" />
                        {t('budgets.alerts.snooze')}
                      </MenuTrigger>
                      <MenuContent label={t('budgets.alerts.snooze')}>
                        <MenuItem
                          icon="clock"
                          onSelect={() => {
                            snooze(alert, 1);
                          }}
                        >
                          {t('budgets.alerts.snoozeDay')}
                        </MenuItem>
                        <MenuItem
                          icon="calendar"
                          onSelect={() => {
                            snooze(alert, 7);
                          }}
                        >
                          {t('budgets.alerts.snoozeWeek')}
                        </MenuItem>
                      </MenuContent>
                    </Menu>
                  ) : (
                    <Button
                      variant="secondary"
                      size="sm"
                      loading={busy}
                      aria-label={`${t('budgets.alerts.reactivate')}: ${message}`}
                      onClick={() => {
                        change(alert, { status: 'active' });
                      }}
                    >
                      <Icon name="bell" className="size-4" />
                      {t('budgets.alerts.reactivate')}
                    </Button>
                  )}
                  {alert.status !== 'dismissed' ? (
                    <Button
                      variant="ghost"
                      size="sm"
                      loading={busy}
                      aria-label={`${t('budgets.alerts.dismiss')}: ${message}`}
                      onClick={() => {
                        change(alert, { status: 'dismissed' });
                      }}
                    >
                      <Icon name="x" className="size-4" />
                      {t('budgets.alerts.dismiss')}
                    </Button>
                  ) : null}
                </div>
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
