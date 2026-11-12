import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import type { Budget, BudgetProgress } from '@/shared/finance/types';
import {
  addDaysToLocalDate,
  formatBasisPoints,
  formatLocalDateRange,
} from '@/shared/formatting/dates';
import { isZeroDecimal } from '@/shared/formatting/decimal';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useBudgetProgress } from '../api';

interface BudgetHistoryCardProps {
  budget: Budget;
  /** A date inside the period being looked at ('' = the current period). */
  date: string;
  onDateChange: (date: string) => void;
}

/** Earlier periods side by side (the API returns a period and the one before it). */
export function BudgetHistoryCard({ budget, date, onDateChange }: BudgetHistoryCardProps) {
  const { t, formatLocale } = useI18n();
  const history = useBudgetProgress(budget.id, date);
  const currentStart = budget.progress?.period_start ?? '';

  let content;
  if (history.isPending) {
    content = <LoadingState label={t('budgets.history.loading')} />;
  } else if (history.isError) {
    content = hasErrorCode(history.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="p" />
    ) : (
      <ErrorState
        titleAs="p"
        title={t('budgets.history.error')}
        error={history.error}
        retrying={history.isFetching}
        onRetry={() => {
          void history.refetch();
        }}
      />
    );
  } else {
    const rows: BudgetProgress[] = history.data;
    content = (
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <caption className="sr-only">{t('budgets.history.caption')}</caption>
          <thead>
            <tr className="border-b border-line text-start text-fg-muted">
              <th scope="col" className="py-2 pe-4 text-start font-medium">
                {t('budgets.history.period')}
              </th>
              <th scope="col" className="py-2 pe-4 text-end font-medium">
                {t('budgets.detail.spent')}
              </th>
              <th scope="col" className="py-2 pe-4 text-end font-medium">
                {t('budgets.detail.limit')}
              </th>
              <th scope="col" className="py-2 text-start font-medium">
                {t('budgets.history.result')}
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-line">
            {rows.map((row) => {
              const over = !isZeroDecimal(row.overspent.amount);
              return (
                <tr key={row.period_start}>
                  <th scope="row" className="py-3 pe-4 text-start font-medium text-fg">
                    {formatLocalDateRange(row.period_start, row.period_end, formatLocale)}
                    {row.period_start === currentStart ? (
                      <span className="ms-2 font-normal text-fg-muted">
                        {t('budgets.history.current')}
                      </span>
                    ) : null}
                  </th>
                  <td className="py-3 pe-4 text-end">
                    <MoneyText money={row.spent} />
                  </td>
                  <td className="py-3 pe-4 text-end">
                    <MoneyText money={row.limit} />
                  </td>
                  <td className="py-3">
                    <StatusBadge
                      tone={over ? 'warning' : 'neutral'}
                      icon={over ? 'alert-triangle' : 'check-circle'}
                    >
                      {over
                        ? t('budgets.history.over', {
                            percent: formatBasisPoints(row.percent_bp, formatLocale),
                          })
                        : t('budgets.history.used', {
                            percent: formatBasisPoints(row.percent_bp, formatLocale),
                          })}
                    </StatusBadge>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    );
  }

  const shown = history.data ?? [];
  const earliest = shown[shown.length - 1];
  const latest = shown[0];
  return (
    <Card
      title={t('budgets.history.title')}
      description={t('budgets.history.description')}
      actions={
        <>
          <Button
            variant="secondary"
            size="sm"
            disabled={!earliest || history.isFetching}
            onClick={() => {
              if (earliest) onDateChange(addDaysToLocalDate(earliest.period_start, -1));
            }}
          >
            <Icon name="chevron-left" className="size-4" />
            {t('budgets.history.earlier')}
          </Button>
          <Button
            variant="secondary"
            size="sm"
            disabled={date === '' || !latest || history.isFetching}
            onClick={() => {
              if (!latest) return;
              const next = addDaysToLocalDate(latest.period_end, 1);
              onDateChange(currentStart && next >= currentStart ? '' : next);
            }}
          >
            {t('budgets.history.later')}
            <Icon name="chevron-right" className="size-4" />
          </Button>
        </>
      }
    >
      {content}
    </Card>
  );
}
