import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { invalidateFinance } from '@/shared/finance/keys';
import type { TransactionInput } from '@/shared/finance/types';
import { transactionsApi } from './api';

/** One Idempotency-Key per draft: a retry after a lost response cannot record the money twice. */
export function useCreateTransaction() {
  const queryClient = useQueryClient();
  const idempotency = useIdempotencyKey();
  return useMutation({
    mutationFn: (body: TransactionInput) => transactionsApi.create(body, idempotency.key),
    onSuccess: () => {
      idempotency.renew();
      void invalidateFinance(queryClient);
    },
  });
}
