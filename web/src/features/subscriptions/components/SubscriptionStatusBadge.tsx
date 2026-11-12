import { StatusBadge } from '@/shared/components/StatusBadge';
import type { SubscriptionStatus } from '@/shared/finance/types';
import { useT } from '@/shared/i18n/I18nContext';
import { statusIcon, statusLabel, statusTone } from '../labels';

/** Status as icon + text (never color alone). */
export function SubscriptionStatusBadge({ status }: { status: SubscriptionStatus }) {
  const t = useT();
  return (
    <StatusBadge tone={statusTone[status]} icon={statusIcon[status]}>
      {t(statusLabel[status])}
    </StatusBadge>
  );
}
