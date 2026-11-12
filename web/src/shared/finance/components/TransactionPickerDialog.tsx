import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { type ReactNode, useId, useState } from 'react';
import { api } from '@/shared/api/client';
import { commaSeparatedArrays } from '@/shared/api/query';
import { apiData } from '@/shared/api/request';
import type { Money } from '@/shared/api/types';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { MoneyText } from '@/shared/components/MoneyText';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextField } from '@/shared/components/TextField';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useDebouncedValue } from '@/shared/hooks/useDebouncedValue';
import { useI18n } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { financeKeys } from '../keys';
import { transactionTitle } from '../transactionDisplay';
import type { TransactionListQuery, TransactionType } from '../types';

/** A server-ranked match shown above the search results (e.g. a bill's payment candidates). */
export interface PickerSuggestion {
  transactionId: string;
  localDate: string;
  amount: Pick<Money, 'amount' | 'currency'>;
  accountName: string;
  title: string;
  /** Localized reasons it was suggested. */
  reasons?: readonly string[];
  /** A localized timing note, e.g. "2 days after the due date". */
  note?: string;
}

interface PickerSearch {
  /** Transaction types to search (default: expenses); an empty list searches every type. */
  types?: readonly TransactionType[];
  accountId?: string;
  /** YYYY-MM-DD bounds of the search. */
  from?: string;
  to?: string;
  /** Money in or money out only. */
  direction?: 'inflow' | 'outflow';
  /** Only transactions in this reconciliation state (e.g. not yet matched or reconciled). */
  reconciliationState?: NonNullable<TransactionListQuery['reconciliation_state']>;
}

interface TransactionPickerDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description?: ReactNode;
  suggestions?: readonly PickerSuggestion[];
  suggestionsLoading?: boolean;
  /** Shown when suggestions finished loading and there are none (omit to show nothing). */
  suggestionsEmptyText?: string;
  /** Filters for searching the ledger (default: expenses). */
  search?: PickerSearch;
  confirmLabel: string;
  onConfirm: (transactionId: string) => void;
  pending?: boolean;
  /** Error from the last attempt, shown inside the dialog. */
  error?: string | null;
  /** Transactions that cannot be chosen (e.g. already linked). */
  excludeIds?: readonly string[];
}

const RESULT_LIMIT = 20;

/**
 * Links an existing ledger transaction (a bill payment, a subscription
 * charge, a goal contribution...) instead of recording the money twice.
 * Suggestions come first; the user can also search their transactions.
 */
export function TransactionPickerDialog(props: TransactionPickerDialogProps) {
  return (
    <Dialog
      open={props.open}
      onOpenChange={props.onOpenChange}
      title={props.title}
      description={props.description}
      busy={props.pending}
      size="lg"
    >
      {props.open ? <PickerBody {...props} /> : null}
    </Dialog>
  );
}

function PickerBody({
  suggestions = [],
  suggestionsLoading = false,
  suggestionsEmptyText,
  search,
  confirmLabel,
  onConfirm,
  onOpenChange,
  pending = false,
  error,
  excludeIds = [],
}: TransactionPickerDialogProps) {
  const { t, formatLocale } = useI18n();
  const [text, setText] = useState('');
  const [selected, setSelected] = useState<string | null>(null);
  const q = useDebouncedValue(text.trim().slice(0, 100), 300);
  const name = useId();
  const types = search?.types ?? ['expense'];
  const query: TransactionListQuery = {
    ...(types.length > 0 ? { type: [...types] } : {}),
    limit: RESULT_LIMIT,
    sort: 'date_desc',
    ...(search?.accountId ? { account_id: [search.accountId] } : {}),
    ...(search?.from ? { from: search.from } : {}),
    ...(search?.to ? { to: search.to } : {}),
    ...(search?.direction ? { direction: search.direction } : {}),
    ...(search?.reconciliationState ? { reconciliation_state: search.reconciliationState } : {}),
    ...(q ? { q } : {}),
  };
  const results = useQuery({
    queryKey: [...financeKeys.transactions(query), 'picker'],
    queryFn: ({ signal }) => {
      const options = {
        params: { query },
        querySerializer: commaSeparatedArrays,
        signal,
      };
      return apiData(
        query.q ? api.GET('/transactions/search', options) : api.GET('/transactions', options),
      );
    },
    placeholderData: keepPreviousData,
  });

  const excluded = new Set(excludeIds);
  const suggested = suggestions.filter((item) => !excluded.has(item.transactionId));
  const suggestedIds = new Set(suggested.map((item) => item.transactionId));
  const found = (results.data ?? []).filter(
    (item) => !excluded.has(item.id) && !suggestedIds.has(item.id) && item.status !== 'voided',
  );

  const option = (
    id: string,
    titleText: string,
    details: string,
    amount: Pick<Money, 'amount' | 'currency'>,
    extra?: ReactNode,
  ) => {
    const checked = selected === id;
    return (
      <li key={id}>
        <label
          className={cx(
            'flex min-h-11 cursor-pointer items-start gap-3 rounded-md border px-3 py-2.5 text-sm',
            'has-[:focus-visible]:outline-3 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-focus',
            checked
              ? 'border-accent bg-accent-soft'
              : 'border-line-strong bg-surface hover:bg-surface-muted',
          )}
        >
          <input
            type="radio"
            name={name}
            value={id}
            checked={checked}
            onChange={() => {
              setSelected(id);
            }}
            className="mt-0.5 size-4 shrink-0 cursor-pointer accent-accent focus-visible:outline-none"
          />
          <span className="min-w-0 flex-1 space-y-0.5">
            <span className={cx('block text-fg', checked && 'font-semibold')}>{titleText}</span>
            <span className="block text-fg-muted">{details}</span>
            {extra}
          </span>
          <MoneyText money={amount} className="shrink-0 font-medium" />
        </label>
      </li>
    );
  };

  let searchResults: ReactNode;
  if (results.isPending) {
    searchResults = <LoadingState label={t('picker.loading')} />;
  } else if (results.isError) {
    searchResults = (
      <ErrorState
        titleAs="p"
        title={t('picker.error')}
        error={results.error}
        retrying={results.isFetching}
        onRetry={() => {
          void results.refetch();
        }}
      />
    );
  } else if (found.length === 0) {
    searchResults = (
      <p className="rounded-md border border-dashed border-line px-4 py-6 text-center text-sm text-fg-muted">
        {q ? t('picker.noMatches') : t('picker.empty')}
      </p>
    );
  } else {
    searchResults = (
      <ul className="space-y-2">
        {found.map((transaction) =>
          option(
            transaction.id,
            transactionTitle(transaction, t),
            [formatLocalDate(transaction.local_date, formatLocale), transaction.account_name].join(
              ' · ',
            ),
            transaction.amount,
          ),
        )}
      </ul>
    );
  }

  return (
    <div className="space-y-5">
      {error ? (
        <Alert tone="danger" live="assertive">
          {error}
        </Alert>
      ) : null}
      <fieldset className="space-y-5">
        <legend className="sr-only">{t('picker.legend')}</legend>
        {suggestionsLoading ? <LoadingState label={t('picker.suggestionsLoading')} /> : null}
        {!suggestionsLoading && suggested.length === 0 && suggestionsEmptyText ? (
          <p className="text-sm text-fg-muted">{suggestionsEmptyText}</p>
        ) : null}
        {suggested.length > 0 ? (
          <section className="space-y-2">
            <h3 className="text-sm font-semibold text-fg">{t('picker.suggested')}</h3>
            <ul className="space-y-2">
              {suggested.map((item) =>
                option(
                  item.transactionId,
                  item.title,
                  [formatLocalDate(item.localDate, formatLocale), item.accountName].join(' · '),
                  item.amount,
                  <>
                    {item.note ? <span className="block text-fg-muted">{item.note}</span> : null}
                    {item.reasons && item.reasons.length > 0 ? (
                      <span className="flex flex-wrap gap-1.5 pt-1">
                        {item.reasons.map((reason) => (
                          <StatusBadge key={reason} tone="info" icon="check">
                            {reason}
                          </StatusBadge>
                        ))}
                      </span>
                    ) : null}
                  </>,
                ),
              )}
            </ul>
          </section>
        ) : null}
        <section className="space-y-3">
          <h3 className="text-sm font-semibold text-fg">{t('picker.searchHeading')}</h3>
          <TextField
            label={t('picker.search')}
            type="search"
            optional
            autoComplete="off"
            maxLength={100}
            value={text}
            onChange={(event) => {
              setText(event.target.value);
            }}
          />
          <p role="status" className="sr-only">
            {results.isSuccess ? t('picker.resultCount', { count: found.length }) : ''}
          </p>
          {searchResults}
        </section>
      </fieldset>
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button
          variant="secondary"
          disabled={pending}
          onClick={() => {
            onOpenChange(false);
          }}
        >
          {t('common.cancel')}
        </Button>
        <Button
          loading={pending}
          disabled={!selected}
          onClick={() => {
            if (selected && !pending) onConfirm(selected);
          }}
        >
          {confirmLabel}
        </Button>
      </div>
    </div>
  );
}
