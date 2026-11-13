import { MoneyText } from '@/shared/components/MoneyText';
import type { RecurringCommitment, RecurringReport } from '@/shared/finance/types';
import { useI18n } from '@/shared/i18n/I18nContext';
import { commitmentKindLabel, recurringNoteLabel } from '../labels';

const KIND_ORDER = ['income', 'expense', 'bill', 'subscription', 'transfer', 'group_expense'];

type NoteCode = RecurringReport['note_code'];

interface CommitmentListProps {
  /** Monthly equivalents per kind and currency, as the API computed them. */
  commitments: readonly RecurringCommitment[];
  /** What the monthly figures count (`note_code` / `recurring_note_code`). */
  noteCode: string;
}

/**
 * Fixed recurring amounts as a monthly equivalent and the next 30 days, per
 * kind and currency (currencies are never added together), with what the
 * figures count in the interface language.
 */
export function CommitmentList({ commitments, noteCode }: CommitmentListProps) {
  const { t } = useI18n();
  const sorted = [...commitments].sort(
    (a, b) =>
      KIND_ORDER.indexOf(a.kind) - KIND_ORDER.indexOf(b.kind) ||
      a.currency.localeCompare(b.currency),
  );
  if (sorted.length === 0) {
    return <p className="text-sm text-fg-muted">{t('calendar.commitments.empty')}</p>;
  }
  // A code newer than this client has no message yet: the figures still stand on their own.
  const note = Object.hasOwn(recurringNoteLabel, noteCode)
    ? t(recurringNoteLabel[noteCode as NoteCode])
    : null;
  return (
    <>
      <ul className="divide-y divide-line">
        {sorted.map((commitment) => (
          <li
            key={`${commitment.kind}-${commitment.currency}`}
            className="space-y-2 py-3 first:pt-0 last:pb-0"
          >
            <p className="font-medium text-fg">
              {t(commitmentKindLabel[commitment.kind])}{' '}
              <span className="font-normal text-fg-muted">
                ({t('calendar.commitments.count', { count: commitment.rule_count })})
              </span>
            </p>
            <dl className="grid grid-cols-2 gap-2 text-sm">
              <div>
                <dt className="text-fg-muted">{t('calendar.commitments.monthly')}</dt>
                <dd>
                  <MoneyText
                    money={commitment.monthly_equivalent}
                    className="font-medium text-fg"
                  />
                </dd>
              </div>
              <div>
                <dt className="text-fg-muted">{t('calendar.commitments.next30')}</dt>
                <dd>
                  <MoneyText money={commitment.next_30_days} className="font-medium text-fg" />
                </dd>
              </div>
            </dl>
            {commitment.variable_count > 0 ? (
              <p className="text-sm text-fg-muted">
                {t('calendar.commitments.variable', { count: commitment.variable_count })}
              </p>
            ) : null}
          </li>
        ))}
      </ul>
      {note ? <p className="mt-4 text-sm text-fg-muted">{note}</p> : null}
    </>
  );
}
