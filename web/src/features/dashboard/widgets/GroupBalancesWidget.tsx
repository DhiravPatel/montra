import { Link } from 'react-router';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { EmptyState } from '@/shared/components/states';
import { groupBalancesPath, paths } from '@/shared/config/paths';
import type { PlanningGroupBalance } from '@/shared/finance/types';
import { amountSign } from '@/shared/formatting/money';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useT } from '@/shared/i18n/I18nContext';
import { groupTypeIcon, isGroupType } from '@/features/groups/labels';
import { PlanningWidgetCard, type PlanningWidgetProps } from '../components/PlanningWidgetCard';

/** "You are owed ₹1,250.00" / "You owe ₹300.50": the API's balance in words, never a bare sign. */
function MyNet({ balance }: { balance: PlanningGroupBalance }) {
  const t = useT();
  const formatMoney = useFormatMoney();
  const sign = amountSign(balance.my_net.amount);
  if (sign === null) return <MoneyText money={balance.my_net} className="text-sm text-fg" />;
  const amount = formatMoney(balance.my_net, { signDisplay: 'never' });
  return (
    <p className="flex items-center gap-1.5 text-sm text-fg">
      <Icon
        name={sign === 1 ? 'arrow-down' : sign === -1 ? 'arrow-up' : 'check-circle'}
        className="size-4 shrink-0 text-fg-muted"
      />
      {sign === 1
        ? t('groups.list.owed', { amount })
        : sign === -1
          ? t('groups.list.owe', { amount })
          : t('groups.list.settled')}
    </p>
  );
}

/**
 * Groups where you are owed or owe, largest first within each currency
 * (amounts in different currencies are never added together).
 */
export function GroupBalancesWidget({ title, planning }: PlanningWidgetProps) {
  const t = useT();
  return (
    <PlanningWidgetCard
      title={title}
      planning={planning}
      scopeLabel={() => t('dashboard.groupBalances.scope')}
      loadingLabel={t('dashboard.groupBalances.loading')}
      errorTitle={t('dashboard.groupBalances.error')}
      total={(data) => data.group_count}
      countText={(data) =>
        t('dashboard.groupBalances.count', {
          count: data.group_count,
          shown: data.group_balances.length,
        })
      }
      viewAll={{
        to: paths.groups,
        label: (count) => t('dashboard.groupBalances.viewAll', { count }),
      }}
      empty={
        <EmptyState
          titleAs="p"
          icon="handshake"
          title={t('dashboard.groupBalances.empty')}
          description={t('dashboard.groupBalances.emptyBody')}
        />
      }
    >
      {(data) => (
        <ul className="divide-y divide-line">
          {data.group_balances.map((balance) => (
            <li key={balance.group_id} className="flex items-start gap-3 py-3 first:pt-0">
              <span className="inline-flex size-9 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
                <Icon
                  name={
                    isGroupType(balance.group_type) ? groupTypeIcon[balance.group_type] : 'users'
                  }
                  className="size-4"
                />
              </span>
              <div className="min-w-0 flex-1 space-y-1">
                <Link
                  to={groupBalancesPath(balance.group_id)}
                  className="font-medium break-words text-fg underline-offset-4 hover:underline"
                >
                  {balance.name}
                </Link>
                <MyNet balance={balance} />
              </div>
            </li>
          ))}
        </ul>
      )}
    </PlanningWidgetCard>
  );
}
