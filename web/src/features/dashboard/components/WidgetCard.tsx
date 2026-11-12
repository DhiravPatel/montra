import type { ReactNode } from 'react';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import type { ReportWindow } from '@/shared/finance/types';
import {
  formatLocalDateRange,
  formatRelativeTime,
  parseTimestamp,
} from '@/shared/formatting/dates';
import { useNow } from '@/shared/hooks/useNow';
import { useI18n } from '@/shared/i18n/I18nContext';

interface WidgetCardProps {
  title: string;
  /** The calculation window; omitted for point-in-time widgets (balances). */
  window?: ReportWindow;
  /** What a widget without a window covers (e.g. "Current balances"). */
  scopeLabel?: string;
  generatedAt: string;
  /** Route to the underlying records. */
  drillDown?: { to: string; label: string };
  children: ReactNode;
}

/**
 * A dashboard widget. Every widget states its period, when it was computed
 * and where its underlying records are (spec §20B.3).
 */
export function WidgetCard({
  title,
  window,
  scopeLabel,
  generatedAt,
  drillDown,
  children,
}: WidgetCardProps) {
  const { t, formatLocale } = useI18n();
  const now = useNow();
  const generated = parseTimestamp(generatedAt);
  return (
    <Card
      title={title}
      description={
        <p className="flex flex-wrap gap-x-2">
          {window ? (
            <span>
              {t('dashboard.window', {
                period: formatLocalDateRange(window.from, window.to, formatLocale),
                zone: window.timezone,
              })}
            </span>
          ) : (
            <span>{scopeLabel ?? t('dashboard.asOfNow')}</span>
          )}
          {generated ? (
            <span>
              ·{' '}
              <time dateTime={generatedAt}>
                {t('common.updated', { when: formatRelativeTime(generated, formatLocale, now) })}
              </time>
            </span>
          ) : null}
        </p>
      }
      actions={
        drillDown ? (
          <ButtonLink to={drillDown.to} variant="ghost" size="sm">
            {drillDown.label}
            <Icon name="arrow-right" className="size-4" />
          </ButtonLink>
        ) : null
      }
    >
      {children}
    </Card>
  );
}

/** Per-currency heading inside a widget (currencies are never added together). */
export function CurrencyHeading({ currency }: { currency: string }) {
  const { t } = useI18n();
  return (
    <h3 className="mb-3 text-sm font-semibold uppercase tracking-wide text-fg-muted">
      {t('dashboard.inCurrency', { currency })}
    </h3>
  );
}
