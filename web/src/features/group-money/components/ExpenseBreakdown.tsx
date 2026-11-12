import { MoneyText } from '@/shared/components/MoneyText';
import { formatMoney } from '@/shared/formatting/money';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import type { People } from '../people';
import { trimDecimal } from '../splitForm';
import type { ExpenseShare, GroupExpenseDetail } from '../types';

/** How a participant's value was entered ("33.33%", "2 shares", "₹20.00"); empty for equal splits. */
function enteredAs(
  method: string,
  share: ExpenseShare,
  currency: string,
  t: Translate,
  locale: string,
): string {
  const value = share.input_value;
  if (!value) return '';
  switch (method) {
    case 'exact':
      try {
        return formatMoney(value, currency, locale);
      } catch {
        return `${value} ${currency}`;
      }
    case 'percentage':
      return t('groupMoney.breakdown.percent', { percent: trimDecimal(value) });
    case 'shares':
      return /^\d+$/.test(value)
        ? t('groupMoney.breakdown.sharesValue', { count: Number(value) })
        : value;
    default:
      return '';
  }
}

/**
 * The server's result for an expense: who paid what and each person's
 * exact share (and the items of an itemized split). Nothing here is
 * computed on the client.
 */
export function ExpenseBreakdown({
  expense,
  people,
}: {
  expense: GroupExpenseDetail;
  people: People;
}) {
  const { t, formatLocale } = useI18n();
  const paid = new Map(expense.payers.map((payer) => [payer.user_id, payer.paid]));
  const shared = new Set(expense.shares.map((share) => share.user_id));
  const showEntered =
    expense.split_method === 'exact' ||
    expense.split_method === 'percentage' ||
    expense.split_method === 'shares';
  // Payers who share nothing still get a row (their share is zero).
  const payersOnly = expense.payers.filter((payer) => !shared.has(payer.user_id));

  return (
    <div className="space-y-6">
      <div className="overflow-x-auto">
        <table className="w-full min-w-max border-collapse text-sm">
          <caption className="sr-only">{t('groupMoney.breakdown.caption')}</caption>
          <thead>
            <tr className="border-b border-line">
              <th scope="col" className="py-2 pe-4 text-start font-medium text-fg-muted">
                {t('groupMoney.breakdown.person')}
              </th>
              {showEntered ? (
                <th scope="col" className="py-2 pe-4 text-end font-medium text-fg-muted">
                  {t('groupMoney.breakdown.entered')}
                </th>
              ) : null}
              <th scope="col" className="py-2 pe-4 text-end font-medium text-fg-muted">
                {t('groupMoney.breakdown.share')}
              </th>
              <th scope="col" className="py-2 pe-4 text-end font-medium text-fg-muted">
                {t('groupMoney.breakdown.paid')}
              </th>
            </tr>
          </thead>
          <tbody>
            {expense.shares.map((share) => {
              const paidAmount = paid.get(share.user_id);
              return (
                <tr key={share.user_id} className="border-b border-line last:border-b-0">
                  <th scope="row" className="py-2 pe-4 text-start font-normal text-fg">
                    {people.name(share.user_id)}
                  </th>
                  {showEntered ? (
                    <td className="py-2 pe-4 text-end tabular-nums text-fg-muted">
                      {enteredAs(
                        expense.split_method,
                        share,
                        expense.amount.currency,
                        t,
                        formatLocale,
                      )}
                    </td>
                  ) : null}
                  <td className="py-2 pe-4 text-end font-medium">
                    <MoneyText money={share.share} />
                  </td>
                  <td className="py-2 pe-4 text-end">
                    {paidAmount ? <MoneyText money={paidAmount} /> : '—'}
                  </td>
                </tr>
              );
            })}
            {payersOnly.map((payer) => (
              <tr key={payer.user_id} className="border-b border-line last:border-b-0">
                <th scope="row" className="py-2 pe-4 text-start font-normal text-fg">
                  {people.name(payer.user_id)}
                </th>
                {showEntered ? <td className="py-2 pe-4" /> : null}
                <td className="py-2 pe-4 text-end text-fg-muted">
                  {t('groupMoney.breakdown.noShare')}
                </td>
                <td className="py-2 pe-4 text-end">
                  <MoneyText money={payer.paid} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {expense.items.length > 0 ? (
        <section aria-labelledby={`items-${expense.id}`} className="space-y-3">
          <h3 id={`items-${expense.id}`} className="text-base font-semibold text-fg">
            {t('groupMoney.breakdown.items')}
          </h3>
          <ul className="divide-y divide-line rounded-lg border border-line">
            {expense.items.map((item, index) => (
              <li key={`${item.description}-${index}`} className="space-y-2 p-3">
                <div className="flex flex-wrap items-baseline justify-between gap-2">
                  <p className="font-medium text-fg">
                    {item.description}
                    {item.quantity ? (
                      <span className="font-normal text-fg-muted">
                        {' '}
                        {t('groupMoney.breakdown.quantity', {
                          quantity: trimDecimal(item.quantity),
                        })}
                      </span>
                    ) : null}
                  </p>
                  <MoneyText money={item.amount} className="font-medium" />
                </div>
                <ul className="flex flex-wrap gap-x-4 gap-y-1 text-sm text-fg-muted">
                  {item.shares.map((share) => (
                    <li key={share.user_id}>
                      {people.name(share.user_id)}: <MoneyText money={share.share} />
                    </li>
                  ))}
                </ul>
              </li>
            ))}
          </ul>
          <p className="text-sm text-fg-muted">{t('groupMoney.breakdown.itemsNote')}</p>
        </section>
      ) : null}
    </div>
  );
}
