import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useToast } from '@/shared/components/toast/ToastContext';
import { financeKeys } from '@/shared/finance/keys';
import type { BudgetAlert, BudgetAlertUpdate } from '@/shared/finance/types';
import { formatBasisPoints, formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { budgetsApi } from './api';

const DAY_MS = 24 * 60 * 60 * 1000;

/** An RFC 3339 instant `days` from now (for snoozing). */
function snoozeUntil(days: number): string {
  return new Date(Date.now() + days * DAY_MS).toISOString();
}

/** The alert in words: the budget's name, what happened and the threshold reached. */
export function alertMessage(alert: BudgetAlert, t: Translate, locale: string): string {
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

export interface BudgetAlertActions {
  dismiss: (alert: BudgetAlert) => void;
  /** Snoozes for `days` days from now. */
  snooze: (alert: BudgetAlert, days: number) => void;
  reactivate: (alert: BudgetAlert) => void;
  /** True while this alert is being changed. */
  busy: (alert: BudgetAlert) => boolean;
}

/**
 * Dismiss, snooze and reactivate budget alerts (PATCH /budget-alerts/{id})
 * with a toast for the outcome. Every alert list and the dashboard's
 * planning cards are fetched again afterwards, so all of them agree.
 */
export function useBudgetAlertActions(): BudgetAlertActions {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const update = useMutation({
    mutationFn: ({ alert, body }: AlertChange) => budgetsApi.updateAlert(alert.id, body),
    onSettled: () =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: ['finance', 'budget-alerts'] }),
        queryClient.invalidateQueries({ queryKey: financeKeys.dashboardPlanning() }),
      ]),
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

  return {
    dismiss: (alert) => {
      change(alert, { status: 'dismissed' });
    },
    snooze: (alert, days) => {
      change(alert, { status: 'snoozed', snoozed_until: snoozeUntil(days) });
    },
    reactivate: (alert) => {
      change(alert, { status: 'active' });
    },
    busy: (alert) => update.isPending && update.variables.alert.id === alert.id,
  };
}
