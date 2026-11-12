import type { ReactNode } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { ErrorState, PermissionDenied } from '@/shared/components/states';
import { formatLocalDateRange } from '@/shared/formatting/dates';
import { useI18n, useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import type { AnalyticsWindow } from '../types';

/** A headline figure with its label and an optional note (previous period, meaning). */
export function StatTile({
  label,
  children,
  note,
}: {
  label: string;
  children: ReactNode;
  note?: ReactNode;
}) {
  return (
    <div className="rounded-lg border border-line p-4">
      <dt className="text-sm text-fg-muted">{label}</dt>
      <dd className="mt-1 text-2xl font-semibold text-fg">{children}</dd>
      {note ? <dd className="mt-1 text-sm text-fg-muted">{note}</dd> : null}
    </div>
  );
}

/**
 * One currency's figures. Currencies are never added together, so every
 * block is labelled with its currency (a visible heading when there are several).
 */
export function CurrencySection({
  currency,
  showHeading,
  children,
}: {
  currency: string;
  showHeading: boolean;
  children: ReactNode;
}) {
  const t = useT();
  const label = t('analytics.inCurrency', { currency });
  return (
    <section aria-label={label} className="space-y-4">
      {showHeading ? (
        <h3 className="text-sm font-semibold tracking-wide text-fg-muted uppercase">{label}</h3>
      ) : null}
      {children}
    </section>
  );
}

/** "Nov 1 – 30, 2026 (Asia/Kolkata)": the calculation window the API used. */
export function WindowText({ window }: { window: AnalyticsWindow }) {
  const { t, formatLocale } = useI18n();
  return (
    <>
      {t('analytics.window', {
        period: formatLocalDateRange(window.from, window.to, formatLocale),
        zone: window.timezone,
      })}
    </>
  );
}

/** Keeps the previous figures on screen, dimmed, while new ones load (no layout jump). */
export function Refreshing({
  fetching,
  stale,
  children,
  className,
}: {
  fetching: boolean;
  stale: boolean;
  children: ReactNode;
  className?: string;
}) {
  return (
    <div
      aria-busy={fetching || undefined}
      className={cx(
        'transition-opacity motion-reduce:transition-none',
        stale && 'opacity-60',
        className,
      )}
    >
      {children}
    </div>
  );
}

/** A failed analytics request: permission, bad filters, or a retryable error. */
export function QueryError({
  error,
  title,
  retrying,
  onRetry,
}: {
  error: unknown;
  title: string;
  retrying: boolean;
  onRetry: () => void;
}) {
  const t = useT();
  if (hasErrorCode(error, 'FORBIDDEN')) return <PermissionDenied titleAs="h3" />;
  return (
    <ErrorState
      title={title}
      error={error}
      description={hasErrorCode(error, 'VALIDATION_ERROR') ? t('analytics.badFilters') : undefined}
      retrying={retrying}
      onRetry={onRetry}
    />
  );
}

/**
 * A background refresh failed while earlier results are on screen: they
 * stay visible, with a note that they may be out of date and a retry.
 */
export function RefreshFailed({
  message,
  retrying,
  onRetry,
}: {
  message: string;
  retrying: boolean;
  onRetry: () => void;
}) {
  const t = useT();
  return (
    <Alert tone="warning" live="polite" className="mb-4">
      <p>{message}</p>
      <Button variant="secondary" size="sm" loading={retrying} onClick={onRetry}>
        <Icon name="refresh" className="size-4" />
        {t('common.retry')}
      </Button>
    </Alert>
  );
}
