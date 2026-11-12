import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type ReactNode, useState } from 'react';
import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { transactionPath } from '@/shared/config/paths';
import { TransactionAmount } from '@/shared/finance/components/TransactionAmount';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { importsApi, useImportRows } from '../api';
import { importErrorMessage } from '../errors';
import { importKeys } from '../keys';
import { fieldHint, rowReason } from '../reasons';
import { filterLabels } from '../rowFilters';
import type { ImportBatch, ImportRow, RowFilter } from '../types';
import { RowStatusBadge } from './ImportBadges';
import { RowFixDialog } from './RowFixDialog';

type Decision = 'import' | 'skip';

interface RowsReviewProps {
  batch: ImportBatch;
  filters: readonly RowFilter[];
  /** Whether rows can be changed here (the wizard's review step, or fixing failed rows). */
  editable: boolean;
  initialFilter?: RowFilter;
}

/**
 * The statement rows with their normalized values, status and the server's
 * reason, filtered by status and loaded a page at a time. While reviewing,
 * rows can be skipped, included, imported despite a possible duplicate, or
 * corrected.
 */
export function RowsReview({ batch, filters, editable, initialFilter = '' }: RowsReviewProps) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [filter, setFilter] = useState<RowFilter>(initialFilter);
  const [fixing, setFixing] = useState<ImportRow | null>(null);
  // Rows with a decision on its way (each row can be changed independently).
  const [pendingRows, setPendingRows] = useState<ReadonlySet<string>>(() => new Set());
  const rows = useImportRows(batch, filter);

  const decide = useMutation({
    mutationFn: ({ row, decision }: { row: ImportRow; decision: Decision }) =>
      importsApi.updateRow(batch.id, row.id, { decision }),
    // Resolves once the rows and counts are reloaded, so the row shows its new state.
    onSettled: () => queryClient.invalidateQueries({ queryKey: importKeys.batch(batch.id) }),
  });

  const setDecision = async (row: ImportRow, decision: Decision) => {
    if (pendingRows.has(row.id)) return;
    setPendingRows((current) => new Set(current).add(row.id));
    try {
      await decide.mutateAsync({ row, decision });
      toast.show({
        tone: 'success',
        title:
          decision === 'skip'
            ? t('imports.rows.skipped', { number: row.row_number })
            : t('imports.rows.included', { number: row.row_number }),
      });
    } catch (error) {
      toast.show({ tone: 'danger', title: importErrorMessage(error, t, formatLocale) });
    } finally {
      setPendingRows((current) => {
        const next = new Set(current);
        next.delete(row.id);
        return next;
      });
    }
  };

  const reviewing = editable && batch.status === 'preview_ready';
  const fixingFailed = editable && batch.status === 'completed_with_errors';

  const actionsFor = (row: ImportRow) => {
    const busy = pendingRows.has(row.id);
    const button = (label: MessageKey, aria: MessageKey, onClick: () => void, icon?: 'pencil') => (
      <Button
        key={label}
        variant="secondary"
        size="sm"
        loading={busy}
        aria-label={t(aria, { number: row.row_number })}
        onClick={onClick}
      >
        {icon ? <Icon name={icon} className="size-4" /> : null}
        {t(label)}
      </Button>
    );
    if (fixingFailed && row.status === 'failed') {
      return [
        button(
          'imports.rows.fix',
          'imports.rows.fixRow',
          () => {
            setFixing(row);
          },
          'pencil',
        ),
      ];
    }
    if (!reviewing) return [];
    switch (row.status) {
      case 'ready':
        return [
          row.user_decision === 'skip'
            ? button('imports.rows.include', 'imports.rows.includeRow', () => {
                void setDecision(row, 'import');
              })
            : button('imports.rows.skip', 'imports.rows.skipRow', () => {
                void setDecision(row, 'skip');
              }),
          button(
            'imports.rows.edit',
            'imports.rows.editRow',
            () => {
              setFixing(row);
            },
            'pencil',
          ),
        ];
      case 'duplicate':
        if (row.error_code === 'already_imported') return [];
        return [
          row.user_decision === 'import'
            ? button('imports.rows.skip', 'imports.rows.skipRow', () => {
                void setDecision(row, 'skip');
              })
            : button('imports.rows.importAnyway', 'imports.rows.importAnywayRow', () => {
                void setDecision(row, 'import');
              }),
        ];
      case 'invalid':
        return [
          button(
            'imports.rows.fix',
            'imports.rows.fixRow',
            () => {
              setFixing(row);
            },
            'pencil',
          ),
        ];
      default:
        return [];
    }
  };

  let content;
  if (rows.isPending) {
    content = <LoadingState label={t('imports.rows.loading')} />;
  } else if (rows.isError) {
    content = (
      <ErrorState
        title={t('imports.rows.error')}
        error={rows.error}
        retrying={rows.isFetching}
        onRetry={() => {
          void rows.refetch();
        }}
      />
    );
  } else {
    const items = rows.data.pages.flatMap((page) => page.rows);
    content =
      items.length === 0 ? (
        <EmptyState icon="list" title={t('imports.rows.empty')} />
      ) : (
        <>
          <ul className="divide-y divide-line" aria-busy={rows.isFetching || undefined}>
            {items.map((row) => (
              <RowItem key={row.id} batch={batch} row={row} actions={actionsFor(row)} />
            ))}
          </ul>
          {rows.hasNextPage ? (
            <div className="mt-4 flex justify-center">
              <Button
                variant="secondary"
                loading={rows.isFetchingNextPage}
                onClick={() => {
                  void rows.fetchNextPage();
                }}
              >
                {t('imports.rows.loadMore')}
              </Button>
            </div>
          ) : null}
        </>
      );
  }

  return (
    <div className="space-y-4">
      {filters.length > 1 ? (
        <RadioGroup
          legend={t('imports.rows.show')}
          value={filter}
          onChange={setFilter}
          options={filters.map((value) => ({ value, label: t(filterLabels[value]) }))}
        />
      ) : null}
      {reviewing ? <p className="text-sm text-fg-muted">{t('imports.rows.reviewHelp')}</p> : null}
      {content}
      <RowFixDialog
        batch={batch}
        row={fixing}
        onClose={() => {
          setFixing(null);
        }}
      />
    </div>
  );
}

function RowItem({
  batch,
  row,
  actions,
}: {
  batch: ImportBatch;
  row: ImportRow;
  actions: readonly ReactNode[];
}) {
  const { t, formatLocale } = useI18n();
  const reason = rowReason(row, batch, t, formatLocale);
  const hint = fieldHint(row.error_field, t);
  const normalized = Boolean(row.posted_date ?? row.amount);
  const cells = row.raw.filter((cell) => cell.trim() !== '');
  const details = [
    row.posted_date ? formatLocalDate(row.posted_date, formatLocale) : null,
    row.description,
    row.reference ? t('imports.rows.reference', { reference: row.reference }) : null,
  ].filter(Boolean);
  return (
    <li className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-start">
      <div className="min-w-0 flex-1 space-y-1">
        <p className="flex flex-wrap items-center gap-2">
          <span className="font-medium text-fg">
            {t('imports.rows.rowNumber', { number: row.row_number })}
          </span>
          <RowStatusBadge row={row} />
          {row.user_decision === 'skip' && row.status === 'ready' ? (
            <StatusBadge tone="neutral" icon="skip-forward">
              {t('imports.rows.decisionSkip')}
            </StatusBadge>
          ) : null}
          {row.user_decision === 'import' && row.status === 'duplicate' ? (
            <StatusBadge tone="info" icon="check">
              {t('imports.rows.decisionImport')}
            </StatusBadge>
          ) : null}
        </p>
        {normalized ? (
          <p className="break-words text-sm text-fg">{details.join(' · ')}</p>
        ) : cells.length > 0 ? (
          <p className="break-words text-sm text-fg-muted">
            <span className="sr-only">{t('imports.fix.asRead')} </span>
            {cells.join(' · ')}
          </p>
        ) : null}
        {reason ? (
          <p className="flex items-start gap-1.5 text-sm text-fg-muted">
            <Icon name="info" className="mt-0.5 size-4 shrink-0" />
            <span>
              {reason}
              {hint ? ` ${hint}` : ''}
            </span>
          </p>
        ) : null}
        {row.duplicate_of_transaction_id ? (
          <p className="text-sm">
            <TextLink to={transactionPath(row.duplicate_of_transaction_id)}>
              {t('imports.rows.viewExisting')}
            </TextLink>
          </p>
        ) : null}
        {row.transaction_id ? (
          <p className="text-sm">
            <TextLink to={transactionPath(row.transaction_id)}>
              {t('imports.rows.viewTransaction')}
            </TextLink>
          </p>
        ) : null}
      </div>
      <div className="flex flex-wrap items-center gap-2 sm:flex-col sm:items-end">
        {row.amount && row.direction ? (
          <TransactionAmount
            transaction={{ amount: row.amount, direction: row.direction, status: 'posted' }}
          />
        ) : null}
        {actions.length > 0 ? <div className="flex flex-wrap gap-2">{actions}</div> : null}
      </div>
    </li>
  );
}
