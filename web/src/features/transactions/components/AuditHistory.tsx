import { Card } from '@/shared/components/Card';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import type { AuditEvent } from '@/shared/finance/types';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import { useTransactionAudit } from '../api';

const actionLabel: Readonly<Record<string, MessageKey>> = {
  created: 'transactions.audit.action.created',
  updated: 'transactions.audit.action.updated',
  voided: 'transactions.audit.action.voided',
  restored: 'transactions.audit.action.restored',
  duplicated: 'transactions.audit.action.duplicated',
  bulk_updated: 'transactions.audit.action.bulk_updated',
  attachment_added: 'transactions.audit.action.attachment_added',
  attachment_removed: 'transactions.audit.action.attachment_removed',
  rule_categorized: 'transactions.audit.action.rule_categorized',
};

const actorLabel: Readonly<Record<string, MessageKey>> = {
  user: 'transactions.audit.actor.user',
  system: 'transactions.audit.actor.system',
  integration: 'transactions.audit.actor.integration',
};

const fieldLabel: Readonly<Record<string, MessageKey>> = {
  account_id: 'transactions.audit.field.account',
  amount_minor: 'transactions.audit.field.amount',
  local_date: 'transactions.audit.field.date',
  status: 'transactions.audit.field.status',
  category_id: 'transactions.audit.field.category',
  merchant_id: 'transactions.audit.field.merchant',
  payment_method_id: 'transactions.audit.field.paymentMethod',
  description: 'transactions.audit.field.description',
  notes_changed: 'transactions.audit.field.notes',
  original_amount_minor: 'transactions.audit.field.originalAmount',
  tags: 'transactions.audit.field.tags',
};

/** Field names an update changed (values are not repeated here; the record shows them). */
function changedFields(event: AuditEvent, t: Translate): string[] {
  const changes: unknown = event.changes;
  if (event.action !== 'updated' || typeof changes !== 'object' || changes === null) return [];
  return Object.keys(changes)
    .map((key) => {
      const label = fieldLabel[key];
      return label ? t(label) : null;
    })
    .filter((label): label is string => label !== null);
}

/** Who changed what and when (spec §20B.5 audit history). */
export function AuditHistory({ transactionId }: { transactionId: string }) {
  const { t, formatLocale } = useI18n();
  const audit = useTransactionAudit(transactionId);
  let content;
  if (audit.isPending) {
    content = <LoadingState label={t('transactions.audit.loading')} />;
  } else if (audit.isError) {
    content = (
      <ErrorState
        title={t('transactions.audit.error')}
        error={audit.error}
        retrying={audit.isFetching}
        onRetry={() => {
          void audit.refetch();
        }}
      />
    );
  } else if (audit.data.length === 0) {
    content = <EmptyState icon="history" title={t('transactions.audit.empty')} />;
  } else {
    const events = [...audit.data].sort((a, b) => b.id - a.id);
    content = (
      <ol className="space-y-4 border-s-2 border-line ps-4">
        {events.map((event) => {
          const when = parseTimestamp(event.created_at);
          const label = actionLabel[event.action];
          const actor = actorLabel[event.actor_kind];
          const fields = changedFields(event, t);
          return (
            <li key={event.id} className="space-y-0.5">
              <p className="font-medium text-fg">{label ? t(label) : event.action}</p>
              <p className="text-sm text-fg-muted">
                {[
                  actor ? t(actor) : event.actor_kind,
                  when ? formatDateTime(when, formatLocale) : null,
                  t('transactions.audit.version', { version: event.version }),
                ]
                  .filter(Boolean)
                  .join(' · ')}
              </p>
              {fields.length > 0 ? (
                <p className="text-sm text-fg">
                  {t('transactions.audit.changed', { fields: fields.join(', ') })}
                </p>
              ) : null}
            </li>
          );
        })}
      </ol>
    );
  }
  return (
    <Card title={t('transactions.audit.title')} description={t('transactions.audit.description')}>
      {content}
    </Card>
  );
}
