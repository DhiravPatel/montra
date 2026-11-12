import { Card } from '@/shared/components/Card';
import { Fact, Facts } from '@/shared/components/Facts';
import { MoneyText } from '@/shared/components/MoneyText';
import type { Budget } from '@/shared/finance/types';
import {
  formatDateTime,
  formatLocalDate,
  formatLocalDateRange,
  parseTimestamp,
} from '@/shared/formatting/dates';
import { isZeroDecimal } from '@/shared/formatting/decimal';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import { progressExplanation } from '../explanation';
import { BudgetMeter } from './BudgetMeter';
import { PaceBadge } from './PaceBadge';

/** This period's progress with every figure from the API and how it was counted. */
export function BudgetProgressCard({ budget }: { budget: Budget }) {
  const { t, formatLocale } = useI18n();
  const formatMoney = useFormatMoney();
  const progress = budget.progress;
  if (!progress) {
    return (
      <Card title={t('budgets.detail.thisPeriod')}>
        <p className="text-sm text-fg-muted">{t('budgets.noProgress')}</p>
      </Card>
    );
  }
  const over = !isZeroDecimal(progress.overspent.amount);
  const inProgress = progress.elapsed_days > 0 && progress.elapsed_days < progress.total_days;
  const carried = !isZeroDecimal(progress.rollover_in.amount);
  const asOf = parseTimestamp(progress.as_of);
  const count = new Intl.NumberFormat(formatLocale).format(progress.transaction_count);
  return (
    <Card
      title={t('budgets.detail.thisPeriod')}
      description={formatLocalDateRange(progress.period_start, progress.period_end, formatLocale)}
      actions={<PaceBadge pace={progress.pace} />}
    >
      <BudgetMeter name={budget.name} progress={progress} showExpected={inProgress} />
      <Facts className="mt-6">
        <Fact label={t('budgets.detail.spent')}>
          <MoneyText money={progress.spent} />
        </Fact>
        <Fact label={t('budgets.detail.limit')}>
          <MoneyText money={progress.limit} />
          {carried ? (
            <span className="ms-2 text-sm text-fg-muted">
              {t('budgets.detail.limitBreakdown', {
                base: formatMoney(progress.base_limit),
                carried: formatMoney(progress.rollover_in),
              })}
            </span>
          ) : null}
        </Fact>
        {over ? (
          <Fact label={t('budgets.detail.overspent')}>
            <MoneyText money={progress.overspent} />
          </Fact>
        ) : (
          <Fact label={t('budgets.detail.remaining')}>
            <MoneyText money={progress.remaining} />
          </Fact>
        )}
        {inProgress ? (
          <>
            <Fact label={t('budgets.detail.expected')}>
              <MoneyText money={progress.expected_by_now} />
            </Fact>
            {over ? null : (
              <Fact label={t('budgets.detail.dailyAllowance')}>
                {t('budgets.detail.perDay', { amount: formatMoney(progress.daily_allowance) })}
              </Fact>
            )}
            <Fact label={t('budgets.detail.projected')}>
              <span className="block">
                {t('budgets.detail.projectedValue', {
                  amount: formatMoney(progress.projected),
                  date: formatLocalDate(progress.period_end, formatLocale),
                })}
              </span>
              {isZeroDecimal(progress.projected_over.amount) ? null : (
                <span className="block text-sm text-fg-muted">
                  {t('budgets.detail.projectedOver', {
                    amount: formatMoney(progress.projected_over),
                  })}
                </span>
              )}
            </Fact>
          </>
        ) : null}
        <Fact label={t('budgets.detail.days')}>
          {t('budgets.detail.dayOf', {
            elapsed: progress.elapsed_days,
            total: progress.total_days,
          })}
        </Fact>
        <Fact label={t('budgets.detail.transactionCount')}>{count}</Fact>
      </Facts>
      {asOf ? (
        <p className="mt-4 text-sm text-fg-muted">
          {t('budgets.detail.asOf', { when: formatDateTime(asOf, formatLocale) })}
        </p>
      ) : null}
      <div className="mt-6 space-y-2">
        <h3 className="text-sm font-semibold text-fg">{t('budgets.detail.howCounted')}</h3>
        <ul className="list-disc space-y-1 ps-5 text-sm text-fg-muted">
          {progressExplanation(progress, t, formatMoney, formatLocale).map((line, index) => (
            <li key={`${String(index)}:${line}`}>{line}</li>
          ))}
        </ul>
      </div>
    </Card>
  );
}
