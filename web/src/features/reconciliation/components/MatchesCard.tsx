import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Checkbox } from '@/shared/components/Checkbox';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { transactionPath } from '@/shared/config/paths';
import { LoadMoreButton } from '@/shared/finance/components/LoadMoreButton';
import { TransactionAmount } from '@/shared/finance/components/TransactionAmount';
import { invalidateFinance } from '@/shared/finance/keys';
import { formatDateTime, formatLocalDate, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { loadedItems, reconciliationApi, useMatches } from '../api';
import { reconciliationErrorMessage } from '../errors';
import { effectLabel, itemStatusLabel, matchKindLabel } from '../labels';
import { reasonsText } from '../reasons';
import type { Match } from '../types';

/** Confirmed matches (and, on request, undone ones), each with what it changed and an undo. */
export function MatchesCard({ accountId }: { accountId: string }) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const matches = useMatches(accountId, true);
  const loaded = loadedItems(matches.data);
  const [showUndone, setShowUndone] = useState(false);
  const [undoing, setUndoing] = useState<Match | null>(null);
  const [undoError, setUndoError] = useState<string | null>(null);

  const unmatch = useMutation({
    mutationFn: (match: Match) => reconciliationApi.unmatch(match.id),
    onSettled: () => invalidateFinance(queryClient),
  });

  const confirmUndo = () => {
    if (!undoing || unmatch.isPending) return;
    setUndoError(null);
    unmatch.mutate(undoing, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('reconciliation.matches.undone') });
        setUndoing(null);
      },
      onError: (error) => {
        setUndoError(reconciliationErrorMessage(error, t, formatLocale));
      },
    });
  };

  let content;
  if (matches.isPending) {
    content = <LoadingState label={t('reconciliation.matches.loading')} />;
  } else if (matches.isError && !matches.isFetchNextPageError) {
    content = (
      <ErrorState
        title={t('reconciliation.matches.error')}
        error={matches.error}
        retrying={matches.isFetching}
        onRetry={() => {
          void matches.refetch();
        }}
      />
    );
  } else {
    const shown = loaded.filter((match) => showUndone || match.status === 'confirmed');
    content = (
      <>
        {shown.length === 0 ? (
          <EmptyState
            icon="link"
            title={
              matches.hasNextPage
                ? t('reconciliation.matches.noneLoadedYet')
                : t('reconciliation.matches.empty')
            }
            description={t('reconciliation.matches.emptyBody')}
          />
        ) : (
          <ul className="divide-y divide-line">
            {shown.map((match) => (
              <MatchItemView
                key={match.id}
                match={match}
                onUndo={() => {
                  setUndoError(null);
                  setUndoing(match);
                }}
              />
            ))}
          </ul>
        )}
        <LoadMoreButton
          hasMore={matches.hasNextPage}
          loading={matches.isFetchingNextPage}
          failed={matches.isFetchNextPageError}
          onLoadMore={() => {
            void matches.fetchNextPage();
          }}
        />
      </>
    );
  }

  return (
    <Card
      title={t('reconciliation.matches.title')}
      description={t('reconciliation.matches.description')}
    >
      <div className="space-y-4">
        <Checkbox
          label={t('reconciliation.matches.showUndone')}
          checked={showUndone}
          onChange={(event) => {
            setShowUndone(event.target.checked);
          }}
        />
        {content}
      </div>
      <ConfirmDialog
        open={undoing !== null}
        onOpenChange={(open) => {
          if (!open) setUndoing(null);
        }}
        tone="danger"
        title={t('reconciliation.matches.undoTitle')}
        description={t('reconciliation.matches.undoBody')}
        confirmLabel={t('reconciliation.matches.undoConfirm')}
        cancelLabel={t('reconciliation.matches.keep')}
        onConfirm={confirmUndo}
        pending={unmatch.isPending}
        error={undoError}
      />
    </Card>
  );
}

function MatchItemView({ match, onUndo }: { match: Match; onUndo: () => void }) {
  const { t, formatLocale } = useI18n();
  const confirmed = match.status === 'confirmed';
  const when = parseTimestamp(match.confirmed_at ?? match.created_at);
  const undone = parseTimestamp(match.unmatched_at);
  const currency = match.items[0]?.amount.currency;
  const reasons = reasonsText(match, t, formatLocale, currency);
  const kind = matchKindLabel(match.kind, t);
  return (
    <li className="space-y-3 py-4 first:pt-0 last:pb-0">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0 space-y-1">
          <p className="flex flex-wrap items-center gap-2">
            <span className="font-medium text-fg">{kind}</span>
            {confirmed ? (
              <StatusBadge tone="success" icon="check-circle">
                {t('reconciliation.matches.confirmed')}
              </StatusBadge>
            ) : (
              <StatusBadge tone="neutral" icon="undo">
                {t('reconciliation.matches.statusUndone')}
              </StatusBadge>
            )}
          </p>
          {when ? (
            <p className="text-sm text-fg-muted">
              {t('reconciliation.matches.when', { date: formatDateTime(when, formatLocale) })}
              {undone
                ? ` · ${t('reconciliation.matches.undoneWhen', { date: formatDateTime(undone, formatLocale) })}`
                : ''}
            </p>
          ) : null}
          {reasons.length > 0 ? (
            <p className="text-sm text-fg-muted">
              {t('reconciliation.candidates.why', { reasons: reasons.join(', ') })}
            </p>
          ) : null}
          {match.total ? (
            <p className="text-sm text-fg">
              {t('reconciliation.matches.total')} <MoneyText money={match.total} />
            </p>
          ) : null}
        </div>
        {confirmed ? (
          <Button
            variant="secondary"
            size="sm"
            aria-label={t('reconciliation.matches.undoLabel', { kind })}
            onClick={onUndo}
          >
            <Icon name="undo" className="size-4" />
            {t('reconciliation.matches.undo')}
          </Button>
        ) : null}
      </div>
      <ul className="space-y-2">
        {match.items.map((item, index) => (
          <li
            key={item.import_row_id ?? item.transaction_id ?? index}
            className="flex flex-wrap items-start justify-between gap-2 rounded-md border border-line px-3 py-2 text-sm"
          >
            <span className="min-w-0 space-y-0.5">
              <span className="flex flex-wrap items-center gap-x-2">
                <span className="font-medium text-fg">
                  {item.side === 'statement'
                    ? t('reconciliation.matches.statementLine')
                    : t('reconciliation.matches.transaction')}
                </span>
                <span className="text-fg-muted">{effectLabel(item.effect, t)}</span>
              </span>
              <span className="block break-words text-fg">
                {item.description ?? t('reconciliation.candidates.noDescription')}
              </span>
              <span className="block text-fg-muted">
                {[formatLocalDate(item.date, formatLocale), itemStatusLabel(item, t)].join(' · ')}
              </span>
              {item.transaction_id ? (
                <TextLink to={transactionPath(item.transaction_id)}>
                  {t('reconciliation.candidates.viewTransaction')}
                </TextLink>
              ) : null}
            </span>
            <TransactionAmount
              transaction={{
                amount: item.amount,
                direction: item.direction,
                status: item.record_status === 'voided' ? 'voided' : 'posted',
              }}
            />
          </li>
        ))}
      </ul>
    </li>
  );
}
