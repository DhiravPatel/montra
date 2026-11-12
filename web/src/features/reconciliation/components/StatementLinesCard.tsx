import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { importPath, transactionPath } from '@/shared/config/paths';
import { LoadMoreButton } from '@/shared/finance/components/LoadMoreButton';
import { TransactionAmount } from '@/shared/finance/components/TransactionAmount';
import { TransactionPickerDialog } from '@/shared/finance/components/TransactionPickerDialog';
import { invalidateFinance } from '@/shared/finance/keys';
import { addDaysToLocalDate, formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { rowReason } from '@/features/imports/reasons';
import { loadedItems, reconciliationApi, useStatementLines } from '../api';
import { reconciliationErrorMessage } from '../errors';
import { rowStatusLabel } from '../labels';
import type { MatchInput, StatementLine, StatementLineStatus } from '../types';

/** How far around the line's date the ledger search looks. */
const SEARCH_WINDOW_DAYS = 14;

const STATUSES = ['unmatched', 'matched'] as const satisfies readonly StatementLineStatus[];

interface StatementLinesCardProps {
  accountId: string;
  /** Only lines of this statement import ('' for every import of the account). */
  batchId: string;
}

/**
 * Lines of the account's statement imports that were neither imported nor
 * matched, including the ones the matcher found nothing for. Each one can be
 * matched by hand with a transaction of the account (the amounts must add
 * up; the server checks). Matched lines can be listed too.
 */
export function StatementLinesCard({ accountId, batchId }: StatementLinesCardProps) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [status, setStatus] = useState<StatementLineStatus>('unmatched');
  const [picking, setPicking] = useState<StatementLine | null>(null);
  const [matchError, setMatchError] = useState<string | null>(null);
  const lines = useStatementLines(accountId, status, batchId, true);
  const loaded = loadedItems(lines.data);

  const match = useMutation({
    mutationFn: (body: MatchInput) => reconciliationApi.match(body),
    // The line, the suggestions, the matches and the transaction's state all change.
    onSettled: () => invalidateFinance(queryClient),
  });

  const confirm = (line: StatementLine, transactionId: string) => {
    if (match.isPending) return;
    setMatchError(null);
    match.mutate(
      {
        kind: 'statement_to_ledger',
        account_id: accountId,
        statement_row_ids: [line.import_row_id],
        transaction_ids: [transactionId],
      },
      {
        onSuccess: () => {
          toast.show({ tone: 'success', title: t('reconciliation.lines.matched') });
          setPicking(null);
        },
        onError: (error) => {
          setMatchError(reconciliationErrorMessage(error, t, formatLocale));
        },
      },
    );
  };

  let content;
  if (lines.isPending) {
    content = <LoadingState label={t('reconciliation.lines.loading')} />;
  } else if (lines.isError && !lines.isFetchNextPageError) {
    content = (
      <ErrorState
        title={t('reconciliation.lines.error')}
        error={lines.error}
        retrying={lines.isFetching}
        onRetry={() => {
          void lines.refetch();
        }}
      />
    );
  } else if (loaded.length === 0) {
    content = (
      <EmptyState
        icon="list"
        title={
          status === 'unmatched'
            ? t('reconciliation.lines.emptyUnmatched')
            : t('reconciliation.lines.emptyMatched')
        }
        description={
          status === 'unmatched' ? t('reconciliation.lines.emptyUnmatchedBody') : undefined
        }
      />
    );
  } else {
    content = (
      <>
        <ul className="divide-y divide-line">
          {loaded.map((line) => (
            <LineItem
              key={line.import_row_id}
              line={line}
              showImport={batchId === ''}
              onMatch={
                status === 'unmatched'
                  ? () => {
                      setMatchError(null);
                      setPicking(line);
                    }
                  : null
              }
            />
          ))}
        </ul>
        <LoadMoreButton
          hasMore={lines.hasNextPage}
          loading={lines.isFetchingNextPage}
          failed={lines.isFetchNextPageError}
          onLoadMore={() => {
            void lines.fetchNextPage();
          }}
        />
      </>
    );
  }

  return (
    <Card
      title={t('reconciliation.lines.title')}
      description={t('reconciliation.lines.description')}
    >
      <div className="space-y-4">
        <RadioGroup<StatementLineStatus>
          legend={t('reconciliation.lines.show')}
          hideLegend
          value={status}
          onChange={setStatus}
          options={STATUSES.map((value) => ({
            value,
            label:
              value === 'unmatched'
                ? t('reconciliation.lines.unmatched')
                : t('reconciliation.lines.matchedLines'),
          }))}
        />
        {content}
      </div>
      {picking ? (
        <TransactionPickerDialog
          open
          onOpenChange={(open) => {
            if (match.isPending) return;
            if (!open) {
              setPicking(null);
              setMatchError(null);
            }
          }}
          title={t('reconciliation.lines.pickTitle')}
          description={
            <>
              <p>
                {t('reconciliation.lines.pickBody', {
                  date: formatLocalDate(picking.date, formatLocale, 'long'),
                })}
              </p>
              <p className="mt-1">{t('reconciliation.lines.pickHelp')}</p>
            </>
          }
          search={{
            types: [],
            accountId,
            direction: picking.direction,
            reconciliationState: 'unreconciled',
            from: addDaysToLocalDate(picking.date, -SEARCH_WINDOW_DAYS),
            to: addDaysToLocalDate(picking.date, SEARCH_WINDOW_DAYS),
          }}
          confirmLabel={t('reconciliation.lines.pickConfirm')}
          pending={match.isPending}
          error={matchError}
          onConfirm={(transactionId) => {
            confirm(picking, transactionId);
          }}
        />
      ) : null}
    </Card>
  );
}

function LineItem({
  line,
  showImport,
  onMatch,
}: {
  line: StatementLine;
  showImport: boolean;
  onMatch: (() => void) | null;
}) {
  const { t, formatLocale } = useI18n();
  // The row's import reason (a possible duplicate, a fix it still needs…), as on the import page.
  const reason = rowReason(
    { status: line.record_status, error_code: line.error_code },
    { currency: line.amount.currency },
    t,
    formatLocale,
  );
  const title = line.description ?? t('reconciliation.candidates.noDescription');
  return (
    <li className="flex flex-col gap-3 py-3 first:pt-0 last:pb-0 sm:flex-row sm:items-start">
      <div className="min-w-0 flex-1 space-y-1">
        <p className="flex flex-wrap items-center gap-2">
          <span className="break-words font-medium text-fg">{title}</span>
          {line.match_id ? (
            <StatusBadge tone="success" icon="link">
              {t('reconciliation.lines.matchedBadge')}
            </StatusBadge>
          ) : (
            <StatusBadge tone="neutral" icon="list">
              {rowStatusLabel(line.record_status, t)}
            </StatusBadge>
          )}
        </p>
        <p className="text-sm text-fg-muted">
          {[
            formatLocalDate(line.date, formatLocale),
            t('reconciliation.lines.row', { number: line.row_number }),
            line.reference ? t('imports.rows.reference', { reference: line.reference }) : null,
          ]
            .filter(Boolean)
            .join(' · ')}
        </p>
        {reason ? <p className="text-sm text-fg-muted">{reason}</p> : null}
        <p className="flex flex-wrap gap-x-3 text-sm empty:hidden">
          {line.duplicate_of_transaction_id ? (
            <TextLink to={transactionPath(line.duplicate_of_transaction_id)}>
              {t('imports.rows.viewExisting')}
            </TextLink>
          ) : null}
          {showImport ? (
            <TextLink to={importPath(line.batch_id)}>
              {t('reconciliation.lines.viewImport')}
            </TextLink>
          ) : null}
        </p>
      </div>
      <div className="flex flex-wrap items-center gap-3 sm:flex-col sm:items-end">
        <TransactionAmount
          transaction={{ amount: line.amount, direction: line.direction, status: 'posted' }}
        />
        {onMatch ? (
          <Button
            variant="secondary"
            size="sm"
            aria-label={t('reconciliation.lines.matchLabel', { title })}
            onClick={onMatch}
          >
            <Icon name="link" className="size-4" />
            {t('reconciliation.lines.match')}
          </Button>
        ) : null}
      </div>
    </li>
  );
}
