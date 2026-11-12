import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { ProgressMeter } from '@/shared/components/ProgressMeter';
import { categoriesById, categoryName } from '@/shared/finance/categories';
import { useAccounts, useCategories, useMerchant } from '@/shared/finance/reference';
import { useGroupDetail } from '@/shared/finance/sharing';
import type { Budget, BudgetAllocation } from '@/shared/finance/types';
import { formatBasisPoints } from '@/shared/formatting/dates';
import { isZeroDecimal } from '@/shared/formatting/decimal';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';

function MerchantLabel({ id }: { id: string }) {
  const { t } = useI18n();
  const merchant = useMerchant(id);
  return <>{merchant.data?.name ?? t('budgets.form.merchantUnknown')}</>;
}

/** Sub-limits with the API's spent / remaining for this period. */
export function BudgetAllocationsCard({ budget }: { budget: Budget }) {
  const { t, formatLocale } = useI18n();
  const formatMoney = useFormatMoney();
  const categories = useCategories(true);
  const accounts = useAccounts(true);
  const group = useGroupDetail(budget.group_id);
  const byCategory = categoriesById(categories.data);
  const accountNames = new Map((accounts.data ?? []).map((account) => [account.id, account.name]));
  const memberNames = new Map<string, string>([
    ...(group.data?.members ?? []).map((member) => [member.user_id, member.display_name] as const),
    ...budget.members.map((member) => [member.user_id, member.display_name] as const),
  ]);

  const target = (allocation: BudgetAllocation) => {
    if (allocation.category_id) {
      const category = byCategory.get(allocation.category_id);
      return category ? categoryName(category, t) : t('budgets.allocations.otherCategory');
    }
    if (allocation.merchant_id) return <MerchantLabel id={allocation.merchant_id} />;
    if (allocation.account_id) {
      return accountNames.get(allocation.account_id) ?? t('budgets.allocations.otherAccount');
    }
    if (allocation.member_user_id) {
      return memberNames.get(allocation.member_user_id) ?? t('budgets.allocations.member');
    }
    return allocation.label ?? t('budgets.allocations.unnamed');
  };

  return (
    <Card title={t('budgets.allocations.title')} description={t('budgets.allocations.description')}>
      <ul className="divide-y divide-line">
        {budget.allocations.map((allocation) => {
          // The API's own figure for spending beyond this allocation (never computed here).
          const over = !isZeroDecimal(allocation.overspent.amount);
          const hasTarget = Boolean(
            allocation.category_id ??
            allocation.merchant_id ??
            allocation.account_id ??
            allocation.member_user_id,
          );
          const name = target(allocation);
          const spent = formatMoney(allocation.spent);
          const limit = formatMoney(allocation.limit);
          return (
            <li key={allocation.id} className="space-y-2 py-4 first:pt-0 last:pb-0">
              <div className="flex flex-wrap items-baseline justify-between gap-2">
                <p className="font-medium text-fg">
                  {name}
                  {hasTarget && allocation.label ? (
                    <span className="font-normal text-fg-muted"> · {allocation.label}</span>
                  ) : null}
                </p>
                <p className="text-sm text-fg-muted">
                  {formatBasisPoints(allocation.percent_bp, formatLocale)}
                </p>
              </div>
              <ProgressMeter
                size="sm"
                percentBp={allocation.percent_bp}
                label={t('budgets.allocations.meterLabel', {
                  name: typeof name === 'string' ? name : t('budgets.allocations.merchant'),
                })}
                valueText={t('budgets.progress.spentOf', { spent, limit })}
                tone={over ? 'danger' : 'accent'}
              />
              <div className="flex flex-wrap justify-between gap-2 text-sm">
                <span className="text-fg">{t('budgets.progress.spentOf', { spent, limit })}</span>
                {over ? (
                  <span className="inline-flex items-center gap-1.5 font-medium text-fg">
                    <Icon name="alert-circle" className="size-4 text-danger" />
                    {t('budgets.allocations.overBy', {
                      amount: formatMoney(allocation.overspent),
                    })}
                  </span>
                ) : (
                  <span className="text-fg-muted">
                    {t('budgets.progress.left', { amount: formatMoney(allocation.remaining) })}
                  </span>
                )}
              </div>
            </li>
          );
        })}
      </ul>
    </Card>
  );
}
