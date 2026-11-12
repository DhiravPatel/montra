import { SubNav } from '@/shared/components/SubNav';
import {
  groupBalancesPath,
  groupExpensesPath,
  groupPath,
  groupRecurringPath,
  groupReportsPath,
  groupSettingsPath,
} from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';

/**
 * Tabs between a group's pages (shared by the groups and group-money
 * features; keep its props stable).
 */
export function GroupSubNav({ groupId }: { groupId: string }) {
  const t = useT();
  return (
    <SubNav
      label={t('groupNav.label')}
      items={[
        { to: groupPath(groupId), label: t('groupNav.overview'), icon: 'users', end: true },
        { to: groupExpensesPath(groupId), label: t('groupNav.expenses'), icon: 'receipt' },
        { to: groupBalancesPath(groupId), label: t('groupNav.balances'), icon: 'handshake' },
        { to: groupRecurringPath(groupId), label: t('groupNav.recurring'), icon: 'repeat' },
        { to: groupReportsPath(groupId), label: t('groupNav.reports'), icon: 'bar-chart' },
        { to: groupSettingsPath(groupId), label: t('groupNav.settings'), icon: 'sliders' },
      ]}
    />
  );
}
