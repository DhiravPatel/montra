import { useCurrentUser } from '@/shared/auth/AuthContext';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { formatDate, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { sourceDisplay } from '../labels';
import { formatRate } from '../rate';
import type { DisclosedRate } from '../types';

/**
 * The rate behind a conversion, disclosed in full: "1 USD = 83.1234 INR",
 * where it comes from and the date it applies from (spec §4.19).
 */
export function DisclosedRateText({ rate }: { rate: DisclosedRate }) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const asOf = parseTimestamp(rate.as_of);
  const source = sourceDisplay[rate.source];
  return (
    <div className="space-y-1.5">
      <p className="font-medium text-fg">
        {t('fx.rate.equation', {
          base: rate.base,
          rate: formatRate(rate.rate, formatLocale),
          quote: rate.quote,
        })}
      </p>
      <p className="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-fg-muted">
        <StatusBadge tone={source.tone} icon={source.icon}>
          {t(source.label)}
        </StatusBadge>
        {asOf ? (
          <span>
            {t('fx.rate.asOf', {
              date: formatDate(asOf, formatLocale, user.timezone),
            })}
          </span>
        ) : null}
        {rate.inverted ? (
          <span>{t('fx.rate.inverted', { base: rate.quote, quote: rate.base })}</span>
        ) : null}
      </p>
    </div>
  );
}
