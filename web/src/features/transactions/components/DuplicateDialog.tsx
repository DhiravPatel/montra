import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { transactionPath } from '@/shared/config/paths';
import { invalidateFinance } from '@/shared/finance/keys';
import type { Transaction } from '@/shared/finance/types';
import { FormAlert } from '@/shared/forms/FormAlert';
import { isLocalDate, todayInTimeZone } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { transactionsApi } from '../api';
import type { CreatedState } from '../duplicates';
import { domainRuleMessage } from '@/shared/finance/domainErrors';

interface DuplicateDialogProps {
  transaction: Transaction;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

/** Copies an expense or income to a new date (the API records a new transaction). */
export function DuplicateDialog({ transaction, open, onOpenChange }: DuplicateDialogProps) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const idempotency = useIdempotencyKey();
  const [date, setDate] = useState(() => todayInTimeZone(user.timezone));
  const [error, setError] = useState<string | null>(null);
  const mutation = useMutation({
    mutationFn: (localDate: string) =>
      transactionsApi.duplicate(transaction.id, localDate, idempotency.key),
    onSuccess: () => {
      idempotency.renew();
      void invalidateFinance(queryClient);
    },
  });

  const submit = () => {
    if (mutation.isPending) return;
    if (!isLocalDate(date)) {
      setError(t('validation.dateInvalid'));
      return;
    }
    setError(null);
    mutation.mutate(date, {
      onSuccess: (result) => {
        toast.show({ tone: 'success', title: t('transactions.duplicate.done') });
        onOpenChange(false);
        const state: CreatedState = { duplicates: result.possible_duplicates };
        void navigate(transactionPath(result.transaction.id), { state });
      },
      onError: (failure) => {
        setError(
          hasErrorCode(failure, 'DOMAIN_RULE_VIOLATION')
            ? (domainRuleMessage(failure, t, formatLocale) ??
                t('transactions.duplicate.notAllowed'))
            : hasErrorCode(failure, 'IDEMPOTENCY_CONFLICT')
              ? t('finance.errors.maybeSaved')
              : describeError(failure, t),
        );
      },
    });
  };

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('transactions.duplicate.title')}
      description={t('transactions.duplicate.description')}
      busy={mutation.isPending}
      size="sm"
    >
      <form
        noValidate
        className="space-y-5"
        onSubmit={(event) => {
          event.preventDefault();
          submit();
        }}
      >
        <FormAlert message={error} />
        <TextField
          label={t('transactions.duplicate.date')}
          type="date"
          value={date}
          onChange={(event) => {
            setDate(event.target.value);
          }}
        />
        <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <Button
            variant="secondary"
            disabled={mutation.isPending}
            onClick={() => {
              onOpenChange(false);
            }}
          >
            {t('common.cancel')}
          </Button>
          <Button type="submit" loading={mutation.isPending}>
            {t('transactions.duplicate.submit')}
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
