import { Alert } from '@/shared/components/Alert';
import { TextLink } from '@/shared/components/TextLink';
import { transactionPath } from '@/shared/config/paths';
import type { DuplicateHint } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { duplicateReasons } from '../duplicates';

/** Explainable "possible duplicate" hints. Nothing is merged or deleted automatically. */
export function DuplicateHints({ hints }: { hints: readonly DuplicateHint[] }) {
  const { t, formatLocale } = useI18n();
  if (hints.length === 0) return null;
  return (
    <Alert tone="warning" live="polite" title={t('transactions.duplicates.title')}>
      <p>{t('transactions.duplicates.body')}</p>
      <ul className="list-disc space-y-1 ps-5">
        {hints.map((hint) => (
          <li key={hint.transaction_id}>
            <TextLink to={transactionPath(hint.transaction_id)}>
              {t('transactions.duplicates.item', {
                date: formatLocalDate(hint.local_date, formatLocale, 'long'),
              })}
            </TextLink>
            {duplicateReasons(hint, t).length > 0 ? (
              <span className="text-fg-muted"> ({duplicateReasons(hint, t).join(', ')})</span>
            ) : null}
          </li>
        ))}
      </ul>
    </Alert>
  );
}
