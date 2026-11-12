import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { invalidateFinance } from '@/shared/finance/keys';
import { isAccountType } from '@/shared/finance/labels';
import type { AccountInput } from '@/shared/finance/types';
import { accountsApi } from './api';
import type { AccountFormResult } from './formValues';

/** Builds the create body from validated form values (only filled fields are sent). */
export function toAccountInput({
  values,
  openingBalance,
  creditLimit,
}: AccountFormResult): AccountInput {
  if (!isAccountType(values.accountType)) throw new Error('account type is validated by the form');
  const body: AccountInput = {
    name: values.name.trim(),
    account_type: values.accountType,
    currency: values.currency,
    include_in_overview: values.includeInOverview,
  };
  if (openingBalance) body.opening_balance = openingBalance;
  if (values.openingDate) body.opening_date = values.openingDate;
  if (values.institutionLabel.trim()) body.institution_label = values.institutionLabel.trim();
  if (values.maskedNumber.trim()) body.masked_number = values.maskedNumber.trim();
  if (creditLimit) body.credit_limit = creditLimit;
  if (values.statementDay) body.statement_day = Number(values.statementDay);
  if (values.paymentDueDay) body.payment_due_day = Number(values.paymentDueDay);
  if (values.notes.trim()) body.notes = values.notes.trim();
  return body;
}

/**
 * Account creation with one Idempotency-Key per draft: retrying after a lost
 * response returns the same account instead of creating a second one.
 */
export function useCreateAccount() {
  const queryClient = useQueryClient();
  const idempotency = useIdempotencyKey();
  const mutation = useMutation({
    mutationFn: (body: AccountInput) => accountsApi.create(body, idempotency.key),
    onSuccess: () => {
      idempotency.renew();
      void invalidateFinance(queryClient);
    },
  });
  return mutation;
}
