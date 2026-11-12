import { StatusBadge } from '@/shared/components/StatusBadge';
import type {
  BillState,
  Occurrence,
  OccurrenceStatus,
  RecurringStatus,
} from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n, useT } from '@/shared/i18n/I18nContext';
import {
  type StatusLook,
  billStateLook,
  occurrenceStatusLook,
  recurringStatusLook,
} from '../labels';

function LookBadge({ look }: { look: StatusLook }) {
  const t = useT();
  return (
    <StatusBadge tone={look.tone} icon={look.icon}>
      {t(look.label)}
    </StatusBadge>
  );
}

/** Payment state of a bill's current cycle (icon + text, never color alone). */
export function BillStateBadge({ state }: { state: BillState }) {
  return <LookBadge look={billStateLook[state]} />;
}

export function OccurrenceStatusBadge({ status }: { status: OccurrenceStatus }) {
  return <LookBadge look={occurrenceStatusLook[status]} />;
}

export function RuleStatusBadge({ status }: { status: RecurringStatus }) {
  return <LookBadge look={recurringStatusLook[status]} />;
}

/**
 * A moved occurrence keeps its status (upcoming or overdue) and names the
 * date it was moved to (`postponed_to`).
 */
export function MovedBadge({ occurrence }: { occurrence: Pick<Occurrence, 'postponed_to'> }) {
  const { t, formatLocale } = useI18n();
  if (!occurrence.postponed_to) return null;
  return (
    <StatusBadge tone="info" icon="clock">
      {t('recurring.occurrence.movedTo', {
        date: formatLocalDate(occurrence.postponed_to, formatLocale),
      })}
    </StatusBadge>
  );
}
