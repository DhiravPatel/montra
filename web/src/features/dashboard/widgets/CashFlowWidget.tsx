import type { ReactNode } from 'react';
import { MoneyText } from '@/shared/components/MoneyText';
import { EmptyState } from '@/shared/components/states';
import type { CashFlowTotals } from '@/shared/finance/types';
import { formatBasisPoints } from '@/shared/formatting/dates';
import { amountSign } from '@/shared/formatting/money';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import { CurrencyHeading, WidgetCard } from '../components/WidgetCard';
import type { WidgetProps } from './types';

function Stat({
  label,
  children,
  note,
}: {
  label: string;
  children: ReactNode;
  note?: string | null;
}) {
  return (
    <div className="rounded-lg border border-line p-4">
      <dt className="text-sm text-fg-muted">{label}</dt>
      <dd className="mt-1 text-2xl font-semibold text-fg">{children}</dd>
      {note ? <dd className="mt-1 text-sm text-fg-muted">{note}</dd> : null}
    </div>
  );
}

/** Income, spending (net of refunds), net cash flow and savings rate per currency. */
export function CashFlowWidget({ summary, title, drill }: WidgetProps) {
  const { t, formatLocale } = useI18n();
  const format = useFormatMoney();
  const totals = summary.cash_flow.filter((total) => total.transaction_count > 0);
  const previous = new Map(summary.previous_cash_flow.map((total) => [total.currency, total]));
  const prev = (
    total: CashFlowTotals,
    pick: (item: CashFlowTotals) => { amount: string; currency: string },
  ) => {
    const before = previous.get(total.currency);
    return before ? t('dashboard.previous', { value: format(pick(before)) }) : null;
  };
  const netLabel = (total: CashFlowTotals) => {
    const sign = amountSign(total.net_cash_flow.amount);
    return sign === 1
      ? t('dashboard.cashFlow.positive')
      : sign === -1
        ? t('dashboard.cashFlow.negative')
        : t('dashboard.cashFlow.even');
  };
  return (
    <WidgetCard
      title={title}
      window={summary.window}
      generatedAt={summary.generated_at}
      drillDown={{ to: drill(), label: t('dashboard.viewTransactions') }}
    >
      {totals.length === 0 ? (
        <EmptyState
          icon="list"
          title={t('dashboard.noActivity')}
          description={t('dashboard.noActivityBody')}
        />
      ) : (
        <div className="space-y-6">
          {totals.map((total) => (
            <section
              key={total.currency}
              aria-label={t('dashboard.inCurrency', { currency: total.currency })}
            >
              {totals.length > 1 ? <CurrencyHeading currency={total.currency} /> : null}
              <dl className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                <Stat
                  label={t('dashboard.cashFlow.income')}
                  note={prev(total, (item) => item.income)}
                >
                  <MoneyText money={total.income} />
                </Stat>
                <Stat
                  label={t('dashboard.cashFlow.spending')}
                  note={prev(total, (item) => item.net_expense)}
                >
                  <MoneyText money={total.net_expense} />
                </Stat>
                <Stat label={t('dashboard.cashFlow.net')} note={netLabel(total)}>
                  <MoneyText money={total.net_cash_flow} signDisplay="exceptZero" />
                </Stat>
                <Stat
                  label={t('dashboard.cashFlow.savingsRate')}
                  note={
                    total.savings_rate_bp === undefined ? t('dashboard.cashFlow.noIncome') : null
                  }
                >
                  {total.savings_rate_bp === undefined
                    ? '—'
                    : formatBasisPoints(total.savings_rate_bp, formatLocale)}
                </Stat>
              </dl>
              <p className="mt-3 text-sm text-fg-muted">
                {t('dashboard.cashFlow.detail', {
                  gross: format(total.gross_expense),
                  refunds: format(total.refunds),
                  count: total.transaction_count,
                })}
              </p>
            </section>
          ))}
        </div>
      )}
    </WidgetCard>
  );
}
