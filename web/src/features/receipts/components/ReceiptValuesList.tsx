import { Fact, Facts } from '@/shared/components/Facts';
import { MoneyText } from '@/shared/components/MoneyText';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { trimQuantity } from '../formValues';
import type { ReceiptExtraction, ReceiptLineItem } from '../types';

/** Receipt values exactly as the API returns them (read-only). */
export function ReceiptValuesList({ values }: { values: ReceiptExtraction }) {
  const { t, formatLocale } = useI18n();
  const breakdown = [
    { label: t('receipts.fields.subtotal'), money: values.subtotal },
    { label: t('receipts.fields.tax'), money: values.tax },
    { label: t('receipts.fields.tip'), money: values.tip },
    { label: t('receipts.fields.discount'), money: values.discount },
  ];
  return (
    <div className="space-y-6">
      <Facts>
        {values.merchant_name ? (
          <Fact label={t('receipts.fields.merchant')}>{values.merchant_name}</Fact>
        ) : null}
        {values.receipt_date ? (
          <Fact label={t('receipts.fields.date')}>
            {formatLocalDate(values.receipt_date, formatLocale, 'long')}
            {values.receipt_time ? ` · ${values.receipt_time}` : ''}
          </Fact>
        ) : null}
        {values.total ? (
          <Fact label={t('receipts.fields.total')}>
            <MoneyText money={values.total} className="font-semibold" />
          </Fact>
        ) : null}
        {breakdown.map((item) =>
          item.money ? (
            <Fact key={item.label} label={item.label}>
              <MoneyText money={item.money} />
            </Fact>
          ) : null,
        )}
        {values.payment_hint ? (
          <Fact label={t('receipts.fields.paymentHint')}>{values.payment_hint}</Fact>
        ) : null}
        {values.receipt_number ? (
          <Fact label={t('receipts.fields.receiptNumber')}>{values.receipt_number}</Fact>
        ) : null}
      </Facts>
      {values.line_items.length > 0 ? <LineItemsTable items={values.line_items} /> : null}
    </div>
  );
}

function LineItemsTable({ items }: { items: readonly ReceiptLineItem[] }) {
  const { t, formatLocale } = useI18n();
  const quantity = (value: string | undefined) => {
    if (!value) return '—';
    const number = Number(trimQuantity(value));
    return Number.isFinite(number)
      ? new Intl.NumberFormat(formatLocale, { maximumFractionDigits: 3 }).format(number)
      : value;
  };
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[32rem] text-sm">
        <caption className="mb-2 text-start font-medium text-fg">
          {t('receipts.fields.lineItems')}
        </caption>
        <thead>
          <tr className="border-b border-line text-start text-fg-muted">
            <th scope="col" className="py-2 pe-3 text-start font-medium">
              {t('receipts.fields.description')}
            </th>
            <th scope="col" className="py-2 pe-3 text-end font-medium">
              {t('receipts.fields.quantity')}
            </th>
            <th scope="col" className="py-2 pe-3 text-end font-medium">
              {t('receipts.fields.unitPrice')}
            </th>
            <th scope="col" className="py-2 pe-3 text-end font-medium">
              {t('receipts.fields.lineAmount')}
            </th>
            <th scope="col" className="py-2 text-end font-medium">
              {t('receipts.fields.lineTax')}
            </th>
          </tr>
        </thead>
        <tbody className="divide-y divide-line">
          {items.map((item) => (
            <tr key={item.position}>
              <td className="py-2 pe-3 text-fg">{item.description ?? '—'}</td>
              <td className="py-2 pe-3 text-end tabular-nums">{quantity(item.quantity)}</td>
              <td className="py-2 pe-3 text-end">
                {item.unit_price ? <MoneyText money={item.unit_price} /> : '—'}
              </td>
              <td className="py-2 pe-3 text-end">
                {item.amount ? <MoneyText money={item.amount} /> : '—'}
              </td>
              <td className="py-2 text-end">{item.tax ? <MoneyText money={item.tax} /> : '—'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
