import type { ReactNode } from 'react';
import { Link } from 'react-router';
import { MoneyText } from '@/shared/components/MoneyText';
import { settlementPath } from '@/shared/config/paths';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { settlementMethodLabel } from '../labels';
import { type People, byCurrency, settlementTitle, useTransferSentence } from '../people';
import type { GroupTransfer, Settlement } from '../types';
import { SettlementStatusBadge } from './StatusBadges';

/** Debts or suggested payments from the server, per currency, with an optional action per row. */
export function TransferList({
  transfers,
  people,
  label,
  action,
}: {
  transfers: readonly GroupTransfer[];
  people: People;
  /** Accessible name for each currency's list. */
  label: (currency: string) => string;
  action?: (transfer: GroupTransfer) => ReactNode;
}) {
  const sentence = useTransferSentence(people);
  const groups = byCurrency(transfers, (transfer) => transfer.amount.currency);
  return (
    <div className="space-y-4">
      {groups.map(([currency, items]) => (
        <section key={currency} aria-label={label(currency)}>
          {groups.length > 1 ? (
            <h3 className="mb-2 text-sm font-semibold text-fg-muted">{currency}</h3>
          ) : null}
          <ul className="divide-y divide-line">
            {items.map((transfer) => (
              <li
                key={`${transfer.from_user_id}-${transfer.to_user_id}`}
                className="flex flex-wrap items-center justify-between gap-3 py-3 first:pt-0 last:pb-0"
              >
                <span className={transfer.involves_me ? 'font-medium text-fg' : 'text-fg'}>
                  {sentence(transfer)}
                </span>
                <span className="flex flex-wrap items-center gap-3">
                  <MoneyText money={transfer.amount} className="font-semibold" />
                  {action ? action(transfer) : null}
                </span>
              </li>
            ))}
          </ul>
        </section>
      ))}
    </div>
  );
}

/** One settlement in a list: who paid whom, when, how, and its two-sided status. */
export function SettlementRow({
  settlement,
  people,
  groupId,
}: {
  settlement: Settlement;
  people: People;
  groupId: string;
}) {
  const { t, formatLocale } = useI18n();
  const title = settlementTitle(settlement, people, t);
  return (
    <li className="flex flex-col gap-2 py-3 first:pt-0 last:pb-0 sm:flex-row sm:items-center sm:justify-between">
      <div className="min-w-0 space-y-1">
        <Link
          to={settlementPath(groupId, settlement.id)}
          className="font-medium text-fg underline-offset-4 hover:underline"
        >
          {title}
        </Link>
        <p className="text-sm text-fg-muted">
          {formatLocalDate(settlement.settled_on, formatLocale)} ·{' '}
          {t(settlementMethodLabel[settlement.method])}
        </p>
        <SettlementStatusBadge status={settlement.status} />
      </div>
      <MoneyText money={settlement.amount} className="shrink-0 font-semibold" />
    </li>
  );
}
