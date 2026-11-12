import { Fact, Facts } from '@/shared/components/Facts';
import { MoneyText } from '@/shared/components/MoneyText';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { formatLocalDate, formatLocalDateRange } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { ImportBatch } from '../types';

/**
 * What the statement says, as the server read and summed it: period,
 * opening and closing balances, totals of the valid rows and whether the
 * running balance in the file adds up. Every amount is the API's own Money
 * value; nothing here is computed in the browser.
 */
export function StatementFacts({ batch }: { batch: ImportBatch }) {
  const { t, formatLocale } = useI18n();
  const totals = batch.totals;
  const start = batch.statement_start ?? totals?.first_date;
  const end = batch.statement_end ?? totals?.last_date;
  const opening = batch.statement_opening_balance ?? totals?.opening_balance;
  const closing = batch.statement_closing_balance ?? totals?.closing_balance;

  return (
    <Facts>
      {start && end ? (
        <Fact label={t('imports.statement.period')}>
          {formatLocalDateRange(start, end, formatLocale)}
        </Fact>
      ) : start ? (
        <Fact label={t('imports.statement.period')}>{formatLocalDate(start, formatLocale)}</Fact>
      ) : null}
      {opening ? (
        <Fact label={t('imports.statement.opening')}>
          <MoneyText money={opening} />
        </Fact>
      ) : null}
      {closing ? (
        <Fact label={t('imports.statement.closing')}>
          <MoneyText money={closing} />
        </Fact>
      ) : null}
      {totals ? (
        <Fact label={t('imports.statement.inflow')}>
          <MoneyText money={totals.inflow} />
        </Fact>
      ) : null}
      {totals ? (
        <Fact label={t('imports.statement.outflow')}>
          <MoneyText money={totals.outflow} />
        </Fact>
      ) : null}
      {totals ? (
        <Fact label={t('imports.statement.net')}>
          <MoneyText money={totals.net} signDisplay="exceptZero" />
        </Fact>
      ) : null}
      {totals ? (
        <Fact label={t('imports.statement.balanceCheck')}>
          {totals.balance_check === 'ok' ? (
            <StatusBadge tone="success" icon="check-circle">
              {t('imports.statement.balanceOk')}
            </StatusBadge>
          ) : totals.balance_check === 'mismatch' ? (
            <div className="space-y-1">
              <StatusBadge tone="warning" icon="alert-triangle">
                {t('imports.statement.balanceMismatch')}
              </StatusBadge>
              {totals.mismatched_rows && totals.mismatched_rows.length > 0 ? (
                <p className="text-sm text-fg-muted">
                  {t('imports.statement.mismatchedRows', {
                    rows: totals.mismatched_rows.join(', '),
                  })}
                </p>
              ) : null}
            </div>
          ) : (
            <span className="text-fg-muted">{t('imports.statement.balanceUnavailable')}</span>
          )}
        </Fact>
      ) : null}
    </Facts>
  );
}
