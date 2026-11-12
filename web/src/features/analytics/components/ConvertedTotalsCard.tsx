import { Alert } from '@/shared/components/Alert';
import { Card } from '@/shared/components/Card';
import { MoneyText } from '@/shared/components/MoneyText';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import { DisclosedRateText } from '@/features/fx/components/DisclosedRate';
import type { AnalyticsWindow, CashFlowTotals, ConvertedTotals } from '../types';
import { StatTile } from './Blocks';

function listFormat(items: readonly string[], locale: string): string {
  try {
    return new Intl.ListFormat(locale, { type: 'conjunction' }).format(items);
  } catch {
    return items.join(', ');
  }
}

/**
 * Which rates the API used, by `rate_policy_code` (the English `rate_policy`
 * is the fallback for a policy newer than this client).
 */
function ratePolicyText(
  converted: ConvertedTotals,
  window: AnalyticsWindow,
  t: ReturnType<typeof useI18n>['t'],
  locale: string,
): string {
  if ((converted.rate_policy_code as string) === 'latest_on_or_before') {
    const date = converted.rate_policy_params.date ?? window.to;
    return t('analytics.converted.policy', { date: formatLocalDate(date, locale, 'medium') });
  }
  return converted.rate_policy;
}

/**
 * Totals converted into one display currency by the API, shown only with the
 * rates it used (pair, source, date), the currencies it could not convert
 * and the rate policy, so a combined figure is never presented without its
 * basis (spec §4.11, §20B.20).
 */
export function ConvertedTotalsCard({
  converted,
  totals,
  window,
}: {
  converted: ConvertedTotals;
  /** The per-currency totals with counted activity that the conversion is based on. */
  totals: readonly CashFlowTotals[];
  window: AnalyticsWindow;
}) {
  const { t, formatLocale } = useI18n();
  const format = useFormatMoney();
  const active = totals.map((total) => total.currency);
  // Currencies with only transfers have nothing to convert; they are not "missing".
  const missing = converted.unconverted.filter((code) => active.includes(code));
  const included = active.filter((code) => !missing.includes(code));

  return (
    <Card
      title={t('analytics.converted.title', { currency: converted.currency })}
      description={t('analytics.converted.description')}
    >
      <div className="space-y-5">
        {included.length > 0 ? (
          <>
            <dl className="grid gap-3 sm:grid-cols-3">
              <StatTile label={t('analytics.measure.income')}>
                <MoneyText money={converted.income} />
              </StatTile>
              <StatTile label={t('analytics.measure.spending')}>
                <MoneyText money={converted.net_expense} />
              </StatTile>
              <StatTile label={t('analytics.measure.net')}>
                <MoneyText money={converted.net_cash_flow} signDisplay="exceptZero" />
              </StatTile>
            </dl>
            <p className="text-sm text-fg-muted">
              {t('analytics.converted.includes', {
                currencies: listFormat(included, formatLocale),
              })}{' '}
              {t('analytics.converted.detail', {
                gross: format(converted.gross_expense),
                refunds: format(converted.refunds),
              })}
            </p>
          </>
        ) : null}
        {missing.length > 0 ? (
          <Alert tone="warning" title={t('analytics.converted.missingTitle')}>
            <p>
              {t('analytics.converted.missing', {
                currencies: listFormat(missing, formatLocale),
              })}
            </p>
            <p>
              <TextLink to={paths.exchangeRates}>{t('analytics.converted.addRate')}</TextLink>
            </p>
          </Alert>
        ) : null}
        {converted.rates.length > 0 ? (
          <div>
            <h3 className="mb-3 text-sm font-semibold text-fg">{t('analytics.converted.rates')}</h3>
            <ul className="divide-y divide-line">
              {converted.rates.map((rate) => (
                <li key={`${rate.base}-${rate.quote}`} className="py-3 first:pt-0 last:pb-0">
                  <DisclosedRateText rate={rate} />
                </li>
              ))}
            </ul>
          </div>
        ) : null}
        <p className="text-sm text-fg-muted">
          {ratePolicyText(converted, window, t, formatLocale)}{' '}
          {t('analytics.converted.recordsUnchanged')}
        </p>
      </div>
    </Card>
  );
}
