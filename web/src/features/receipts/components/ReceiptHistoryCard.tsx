import { Alert } from '@/shared/components/Alert';
import { Card } from '@/shared/components/Card';
import { Disclosure } from '@/shared/components/Disclosure';
import { Icon } from '@/shared/components/Icon';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { earlierValues, extractionMethodLabel, extractionStatusLabel } from '../labels';
import type { ReceiptDetail } from '../types';
import { ReceiptValuesList } from './ReceiptValuesList';

/**
 * Every stored version of the receipt's values (newest first). Values read
 * automatically in the past are shown read-only; Montra never starts reading.
 */
export function ReceiptHistoryCard({ receipt }: { receipt: ReceiptDetail }) {
  const { t, formatLocale } = useI18n();
  const earlier = earlierValues(receipt);
  return (
    <Card title={t('receipts.history.title')} description={t('receipts.history.description')}>
      {receipt.history.length === 0 ? (
        <p className="text-sm text-fg-muted">{t('receipts.history.empty')}</p>
      ) : (
        <ol className="divide-y divide-line">
          {receipt.history.map((entry) => {
            const created = parseTimestamp(entry.created_at);
            const details = [
              t('receipts.history.version', { version: entry.version }),
              entry.status === 'succeeded' ? null : t(extractionStatusLabel(entry.status)),
              created ? formatDateTime(created, formatLocale) : null,
            ].filter(Boolean);
            return (
              <li key={entry.id} className="flex items-start gap-3 py-3 first:pt-0 last:pb-0">
                <Icon
                  name={entry.method === 'manual' ? 'pencil' : 'history'}
                  className="mt-0.5 size-4 shrink-0 text-fg-muted"
                />
                <div className="min-w-0 space-y-0.5">
                  <p className="font-medium text-fg">{t(extractionMethodLabel(entry.method))}</p>
                  <p className="text-sm text-fg-muted">{details.join(' · ')}</p>
                </div>
              </li>
            );
          })}
        </ol>
      )}
      {earlier ? (
        <Disclosure summary={t('receipts.history.showEarlier')} className="mt-4">
          <Alert tone="info" className="mb-4">
            {t('receipts.history.earlierNote')}
          </Alert>
          <ReceiptValuesList values={earlier} />
        </Disclosure>
      ) : null}
    </Card>
  );
}
