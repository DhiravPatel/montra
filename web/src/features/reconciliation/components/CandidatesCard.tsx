import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { transactionPath } from '@/shared/config/paths';
import { TransactionAmount } from '@/shared/finance/components/TransactionAmount';
import { invalidateFinance } from '@/shared/finance/keys';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { reconciliationApi, useCandidates } from '../api';
import { reconciliationErrorMessage } from '../errors';
import { MATCH_KINDS, itemStatusLabel, kindEffect, kindTitle } from '../labels';
import { reasonsText } from '../reasons';
import type { Candidate, CandidateItem, MatchInput, MatchKind } from '../types';

const sideLabels: Readonly<Record<MatchKind, { left: MessageKey; right: MessageKey }>> = {
  statement_to_ledger: {
    left: 'reconciliation.side.statement',
    right: 'reconciliation.side.ledger',
  },
  pending_to_posted: { left: 'reconciliation.side.pending', right: 'reconciliation.side.posted' },
  manual_to_imported: {
    left: 'reconciliation.side.manual',
    right: 'reconciliation.side.imported',
  },
};

function candidateKey(candidate: Candidate): string {
  const id = (item: CandidateItem) => item.import_row_id ?? item.transaction_id ?? '';
  return [candidate.kind, id(candidate.left), ...candidate.right.map(id)].join(':');
}

/** "0.887" → "89%" (the server's confidence, shown as a percentage). */
function confidencePercent(confidence: string, locale: string): string | null {
  const value = Number(confidence);
  if (!Number.isFinite(value)) return null;
  return new Intl.NumberFormat(locale, { style: 'percent', maximumFractionDigits: 0 }).format(
    value,
  );
}

/** The match to send when the user confirms a suggestion. */
function matchInput(candidate: Candidate, accountId: string, keepId: string | null): MatchInput {
  const transactions = candidate.right.flatMap((item) =>
    item.transaction_id ? [item.transaction_id] : [],
  );
  if (candidate.kind === 'statement_to_ledger') {
    return {
      kind: candidate.kind,
      account_id: accountId,
      statement_row_ids: candidate.left.import_row_id ? [candidate.left.import_row_id] : [],
      transaction_ids: transactions,
    };
  }
  const both = [
    ...(candidate.left.transaction_id ? [candidate.left.transaction_id] : []),
    ...transactions,
  ];
  return {
    kind: candidate.kind,
    account_id: accountId,
    transaction_ids: both,
    ...(candidate.kind === 'manual_to_imported' && keepId ? { keep_transaction_id: keepId } : {}),
  };
}

interface CandidatesCardProps {
  accountId: string;
  /** Only suggestions for this statement import ('' for all of the account). */
  batchId: string;
}

/**
 * Suggested matches with the server's confidence and reasons. Each one is
 * applied only when the user confirms it; its effect is explained first.
 */
export function CandidatesCard({ accountId, batchId }: CandidatesCardProps) {
  const { t } = useI18n();
  const candidates = useCandidates(accountId, batchId, true);

  let content;
  if (candidates.isPending) {
    content = <LoadingState label={t('reconciliation.candidates.loading')} />;
  } else if (candidates.isError) {
    content = (
      <ErrorState
        title={t('reconciliation.candidates.error')}
        error={candidates.error}
        retrying={candidates.isFetching}
        onRetry={() => {
          void candidates.refetch();
        }}
      />
    );
  } else if (candidates.data.length === 0) {
    content = (
      <EmptyState
        icon="check-circle"
        title={t('reconciliation.candidates.empty')}
        description={t('reconciliation.candidates.emptyBody')}
      />
    );
  } else {
    content = (
      <div className="space-y-8">
        {MATCH_KINDS.map((kind) => {
          const group = candidates.data.filter((candidate) => candidate.kind === kind);
          if (group.length === 0) return null;
          return (
            <section key={kind} aria-labelledby={`candidates-${kind}`} className="space-y-3">
              <h3 id={`candidates-${kind}`} className="text-base font-semibold text-fg">
                {t(kindTitle[kind])}
              </h3>
              <p className="text-sm text-fg-muted">{t(kindEffect[kind])}</p>
              <ul className="space-y-4">
                {group.map((candidate) => (
                  <CandidateItemView
                    key={candidateKey(candidate)}
                    accountId={accountId}
                    candidate={candidate}
                  />
                ))}
              </ul>
            </section>
          );
        })}
      </div>
    );
  }

  return (
    <Card
      title={t('reconciliation.candidates.title')}
      description={t('reconciliation.candidates.description')}
    >
      {content}
    </Card>
  );
}

function ItemView({ label, item }: { label: string; item: CandidateItem }) {
  const { t, formatLocale } = useI18n();
  return (
    <div className="min-w-0 flex-1 space-y-1 rounded-md border border-line p-3">
      <p className="text-xs font-medium tracking-wide text-fg-muted uppercase">{label}</p>
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0 space-y-0.5">
          <p className="break-words text-sm font-medium text-fg">
            {item.description ?? t('reconciliation.candidates.noDescription')}
          </p>
          <p className="text-sm text-fg-muted">
            {[formatLocalDate(item.date, formatLocale), itemStatusLabel(item, t)].join(' · ')}
          </p>
          {item.transaction_id ? (
            <p className="text-sm">
              <TextLink to={transactionPath(item.transaction_id)}>
                {t('reconciliation.candidates.viewTransaction')}
              </TextLink>
            </p>
          ) : null}
        </div>
        <TransactionAmount
          transaction={{ amount: item.amount, direction: item.direction, status: 'posted' }}
        />
      </div>
    </div>
  );
}

function CandidateItemView({ accountId, candidate }: { accountId: string; candidate: Candidate }) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [keepId, setKeepId] = useState<string>(candidate.left.transaction_id ?? '');
  // Results are reported from the mutation itself: a confirmed suggestion
  // leaves the list (and this item unmounts) as soon as the data refreshes.
  const confirm = useMutation({
    mutationFn: (body: MatchInput) => reconciliationApi.match(body),
    onSuccess: () => {
      toast.show({ tone: 'success', title: t('reconciliation.candidates.done') });
    },
    onError: (error) => {
      toast.show({ tone: 'danger', title: reconciliationErrorMessage(error, t, formatLocale) });
    },
    // Balances, transaction states, suggestions and matches all change (or were stale).
    onSettled: () => invalidateFinance(queryClient),
  });
  const labels = sideLabels[candidate.kind];
  const percent = confidencePercent(candidate.confidence, formatLocale);
  const reasons = reasonsText(candidate, t, formatLocale, candidate.left.amount.currency);
  const imported = candidate.right[0];
  const title = candidate.left.description ?? formatLocalDate(candidate.left.date, formatLocale);

  const submit = () => {
    if (confirm.isPending) return;
    confirm.mutate(matchInput(candidate, accountId, keepId || null));
  };

  return (
    <li className="space-y-3 rounded-lg border border-line p-4">
      <div className="flex flex-col gap-3 md:flex-row">
        <ItemView label={t(labels.left)} item={candidate.left} />
        <div className="flex flex-1 flex-col gap-2">
          {candidate.right.map((item) => (
            <ItemView
              key={item.transaction_id ?? item.import_row_id ?? item.date}
              label={t(labels.right)}
              item={item}
            />
          ))}
        </div>
      </div>
      <div className="space-y-1 text-sm">
        {percent ? (
          <p className="text-fg">{t('reconciliation.candidates.confidence', { percent })}</p>
        ) : null}
        {reasons.length > 0 ? (
          <p className="text-fg-muted">
            {t('reconciliation.candidates.why', { reasons: reasons.join(', ') })}
          </p>
        ) : null}
      </div>
      {candidate.kind === 'manual_to_imported' &&
      candidate.left.transaction_id &&
      imported?.transaction_id ? (
        <RadioGroup
          legend={t('reconciliation.candidates.keep')}
          value={keepId}
          onChange={setKeepId}
          options={[
            {
              value: candidate.left.transaction_id,
              label: t('reconciliation.candidates.keepManual'),
            },
            { value: imported.transaction_id, label: t('reconciliation.candidates.keepImported') },
          ]}
        />
      ) : null}
      <div className="flex justify-end">
        <Button
          size="sm"
          loading={confirm.isPending}
          aria-label={t('reconciliation.candidates.confirmLabel', { title })}
          onClick={submit}
        >
          <Icon name="link" className="size-4" />
          {t('reconciliation.candidates.confirm')}
        </Button>
      </div>
    </li>
  );
}
