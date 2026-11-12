import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useToast } from '@/shared/components/toast/ToastContext';
import {
  type PickerSuggestion,
  TransactionPickerDialog,
} from '@/shared/finance/components/TransactionPickerDialog';
import { invalidateFinance } from '@/shared/finance/keys';
import { addDaysToLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { receiptsApi, useMatchCandidates } from '../api';
import { receiptErrorMessage } from '../errors';
import { candidateReasons, reviewedValues } from '../labels';
import type { ReceiptDetail } from '../types';

interface MatchTransactionDialogProps {
  receipt: ReceiptDetail;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

/** How far around the receipt date the ledger search looks. */
const SEARCH_WINDOW_DAYS = 30;

/**
 * Links the receipt to a purchase that is already in the ledger (no new
 * money is recorded). Server suggestions come first; any expense can be
 * searched.
 */
export function MatchTransactionDialog({
  receipt,
  open,
  onOpenChange,
}: MatchTransactionDialogProps) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [error, setError] = useState<string | null>(null);
  const candidates = useMatchCandidates(receipt.id, open);
  const match = useMutation({
    mutationFn: (transactionId: string) => receiptsApi.match(receipt.id, transactionId),
    onSettled: () => invalidateFinance(queryClient),
  });
  const date = reviewedValues(receipt)?.receipt_date;

  const suggestions: PickerSuggestion[] = (candidates.data ?? []).map((candidate) => ({
    transactionId: candidate.transaction_id,
    localDate: candidate.local_date,
    amount: candidate.amount,
    accountName: candidate.account_name,
    title: candidate.merchant ?? candidate.description ?? t('receipts.match.untitled'),
    reasons: candidateReasons(candidate, t),
  }));

  return (
    <TransactionPickerDialog
      open={open}
      onOpenChange={(next) => {
        if (match.isPending) return;
        if (!next) setError(null);
        onOpenChange(next);
      }}
      title={t('receipts.match.title')}
      description={
        <>
          <p>{t('receipts.match.description')}</p>
          {candidates.isError ? (
            <p className="mt-1">{t('receipts.match.candidatesFailed')}</p>
          ) : null}
        </>
      }
      suggestions={suggestions}
      suggestionsLoading={open && candidates.isPending}
      search={{
        types: ['expense', 'group_expense'],
        ...(date
          ? {
              from: addDaysToLocalDate(date, -SEARCH_WINDOW_DAYS),
              to: addDaysToLocalDate(date, SEARCH_WINDOW_DAYS),
            }
          : {}),
      }}
      confirmLabel={t('receipts.match.confirm')}
      pending={match.isPending}
      error={error}
      onConfirm={(transactionId) => {
        if (match.isPending) return;
        setError(null);
        match.mutate(transactionId, {
          onSuccess: () => {
            toast.show({ tone: 'success', title: t('receipts.match.done') });
            onOpenChange(false);
          },
          onError: (failure) => {
            setError(receiptErrorMessage(failure, 'match', t, formatLocale));
          },
        });
      }}
    />
  );
}
