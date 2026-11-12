import { formatWait } from '@/shared/i18n/formatWait';
import { useT } from '@/shared/i18n/I18nContext';

/** Silent countdown (the triggering error was already announced). */
export function RetryAfterNotice({ seconds }: { seconds: number }) {
  const t = useT();
  if (seconds <= 0) return null;
  return (
    <p className="text-sm text-fg-muted" aria-live="off">
      {t('auth.retryIn', { wait: formatWait(t, seconds) })}
    </p>
  );
}
