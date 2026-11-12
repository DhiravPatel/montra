import { StatusBadge } from '@/shared/components/StatusBadge';
import { useT } from '@/shared/i18n/I18nContext';
import { receiptStatusIcon, receiptStatusLabel, receiptStatusTone } from '../labels';
import type { ReceiptStatus } from '../types';

/** A receipt's status in words with an icon (never color alone). */
export function ReceiptStatusBadge({ status }: { status: ReceiptStatus }) {
  const t = useT();
  return (
    <StatusBadge tone={receiptStatusTone[status]} icon={receiptStatusIcon[status]}>
      {t(receiptStatusLabel[status])}
    </StatusBadge>
  );
}
