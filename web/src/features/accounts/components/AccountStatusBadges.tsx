import { StatusBadge } from '@/shared/components/StatusBadge';
import type { Account } from '@/shared/finance/types';
import { useT } from '@/shared/i18n/I18nContext';

/** Status, visibility and sharing badges (icon + text, never color alone). */
export function AccountStatusBadges({ account }: { account: Account }) {
  const t = useT();
  const badges = [];
  if (account.status === 'archived') {
    badges.push(
      <StatusBadge key="status" tone="neutral" icon="archive">
        {t('accounts.status.archived')}
      </StatusBadge>,
    );
  } else if (account.status === 'closed') {
    badges.push(
      <StatusBadge key="status" tone="neutral" icon="lock">
        {t('accounts.status.closed')}
      </StatusBadge>,
    );
  }
  if (!account.include_in_overview) {
    badges.push(
      <StatusBadge key="overview" tone="neutral" icon="eye-off">
        {t('accounts.status.notInOverview')}
      </StatusBadge>,
    );
  }
  if (!account.owned) {
    badges.push(
      <StatusBadge key="shared" tone="info" icon="users">
        {t('accounts.status.sharedWithYou')}
      </StatusBadge>,
    );
  } else if (account.shared_with_group) {
    badges.push(
      <StatusBadge key="household" tone="info" icon="users">
        {t('accounts.status.sharedHousehold')}
      </StatusBadge>,
    );
  }
  if (badges.length === 0) return null;
  return <div className="flex flex-wrap gap-2">{badges}</div>;
}
