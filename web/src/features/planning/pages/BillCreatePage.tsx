import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { useToast } from '@/shared/components/toast/ToastContext';
import { billPath, paths } from '@/shared/config/paths';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type { BillInput } from '@/shared/finance/types';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { planningApi } from '../api';
import { BackLink } from '../components/BackLink';
import { BillForm } from '../components/BillForm';
import { emptyBillValues } from '../formValues';

export function BillCreatePage() {
  const t = useT();
  useDocumentTitle(t('bills.create.title'));
  const user = useCurrentUser();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [initialValues] = useState(() =>
    emptyBillValues(user.base_currency, todayInTimeZone(user.timezone)),
  );
  // One key per draft: a retry after a lost response replays the first result
  // instead of adding the bill twice. A new key only after a success.
  const idempotency = useIdempotencyKey();
  const create = useMutation({
    mutationFn: (input: BillInput) => planningApi.createBill(input, idempotency.key),
    onSuccess: (bill) => {
      idempotency.renew();
      queryClient.setQueryData(financeKeys.bill(bill.id), bill);
      void invalidateFinance(queryClient);
    },
  });

  return (
    <>
      <BackLink to={paths.bills} label={t('bills.backToList')} />
      <PageHeader title={t('bills.create.title')} description={t('bills.create.description')} />
      <Card>
        <BillForm
          mode="create"
          initialValues={initialValues}
          submitLabel={t('bills.create.submit')}
          secondaryAction={
            <ButtonLink to={paths.bills} variant="ghost">
              {t('common.cancel')}
            </ButtonLink>
          }
          onSubmit={async (input) => {
            if (create.isPending) return;
            const bill = await create.mutateAsync(input);
            toast.show({ tone: 'success', title: t('bills.create.done') });
            void navigate(billPath(bill.id));
          }}
        />
      </Card>
    </>
  );
}
