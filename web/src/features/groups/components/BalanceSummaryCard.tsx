import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { groupBalancesPath } from '@/shared/config/paths';
import { amountSign } from '@/shared/formatting/money';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useT } from '@/shared/i18n/I18nContext';
import { useGroupBalances } from '../api';

/**
 * The user's position in the group as the API derives it (expenses and
 * confirmed settlements). A summary only: who owes whom is on the
 * balances page.
 */
export function BalanceSummaryCard({ groupId }: { groupId: string }) {
  const t = useT();
  const me = useCurrentUser();
  const formatMoney = useFormatMoney();
  const balances = useGroupBalances(groupId);

  let content;
  if (balances.isPending) {
    content = <LoadingState label={t('groups.balance.loading')} />;
  } else if (balances.isError) {
    content = hasErrorCode(balances.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="p" />
    ) : (
      <ErrorState
        titleAs="p"
        title={t('groups.balance.error')}
        error={balances.error}
        retrying={balances.isFetching}
        onRetry={() => {
          void balances.refetch();
        }}
      />
    );
  } else {
    const data = balances.data;
    const net = data.my_net;
    const sign = amountSign(net.amount);
    const mine = data.balances.find((row) => row.user_id === me.id);
    const pendingOut = mine && amountSign(mine.pending_out.amount) === 1 ? mine.pending_out : null;
    const pendingIn = mine && amountSign(mine.pending_in.amount) === 1 ? mine.pending_in : null;
    content = (
      <div className="space-y-4">
        <div className="flex items-start gap-3">
          <Icon
            name={sign === 1 ? 'arrow-down' : sign === -1 ? 'arrow-up' : 'check-circle'}
            className="mt-1 size-5 text-fg-muted"
          />
          <div className="space-y-1">
            <p className="text-sm font-medium text-fg-muted">
              {sign === 1
                ? t('groups.balance.owed')
                : sign === -1
                  ? t('groups.balance.owe')
                  : t('groups.balance.settled')}
            </p>
            {sign === 0 ? null : (
              <p className="text-2xl font-semibold text-fg">
                <MoneyText money={net} signDisplay="never" />
              </p>
            )}
          </div>
        </div>
        {pendingOut || pendingIn || data.disputed_expenses > 0 ? (
          <ul className="space-y-1 text-sm text-fg-muted">
            {pendingOut ? (
              <li>{t('groups.balance.pendingOut', { amount: formatMoney(pendingOut) })}</li>
            ) : null}
            {pendingIn ? (
              <li>{t('groups.balance.pendingIn', { amount: formatMoney(pendingIn) })}</li>
            ) : null}
            {data.disputed_expenses > 0 ? (
              <li>{t('groups.balance.disputed', { count: data.disputed_expenses })}</li>
            ) : null}
          </ul>
        ) : null}
        <p className="text-sm text-fg-muted">{t('groups.balance.note')}</p>
        <TextLink to={groupBalancesPath(groupId)}>{t('groups.balance.link')}</TextLink>
      </div>
    );
  }

  return <Card title={t('groups.balance.title')}>{content}</Card>;
}
