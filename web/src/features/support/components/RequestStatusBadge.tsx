import { StatusBadge } from '@/shared/components/StatusBadge';
import { useT } from '@/shared/i18n/I18nContext';
import { statusIcon, statusLabel, statusTone } from '../labels';
import type { RequestStatus } from '../types';

/** A request's status as icon + text (never color alone). */
export function RequestStatusBadge({ status }: { status: RequestStatus }) {
  const t = useT();
  return (
    <StatusBadge tone={statusTone[status]} icon={statusIcon[status]}>
      {t(statusLabel[status])}
    </StatusBadge>
  );
}
