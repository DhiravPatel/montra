import { StatusBadge } from '@/shared/components/StatusBadge';
import { useT } from '@/shared/i18n/I18nContext';
import {
  type StatusLook,
  disputeStatusLook,
  expenseStatusLook,
  settlementStatusLook,
} from '../labels';
import type { DisputeStatus, ExpenseStatus, SettlementStatus } from '../types';

function LookBadge({ look }: { look: StatusLook }) {
  const t = useT();
  return (
    <StatusBadge tone={look.tone} icon={look.icon}>
      {t(look.label)}
    </StatusBadge>
  );
}

/** Expense status (icon + text, never color alone). Active expenses show no badge in lists. */
export function ExpenseStatusBadge({ status }: { status: ExpenseStatus }) {
  return <LookBadge look={expenseStatusLook[status]} />;
}

export function DisputeStatusBadge({ status }: { status: DisputeStatus }) {
  return <LookBadge look={disputeStatusLook[status]} />;
}

export function SettlementStatusBadge({ status }: { status: SettlementStatus }) {
  return <LookBadge look={settlementStatusLook[status]} />;
}

/** Whether a settlement counts toward balances yet (only confirmed ones do). */
export function CountedBadge({ counted }: { counted: boolean }) {
  const t = useT();
  return counted ? (
    <StatusBadge tone="success" icon="check">
      {t('groupMoney.settlement.counted')}
    </StatusBadge>
  ) : (
    <StatusBadge tone="neutral" icon="clock">
      {t('groupMoney.settlement.notCounted')}
    </StatusBadge>
  );
}
