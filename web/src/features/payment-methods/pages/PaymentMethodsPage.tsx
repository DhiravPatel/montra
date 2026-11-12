import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { invalidateFinance } from '@/shared/finance/keys';
import {
  isPaymentNetwork,
  networkLabel,
  paymentKindIcon,
  paymentKindLabel,
} from '@/shared/finance/labels';
import { useAccounts, usePaymentMethods } from '@/shared/finance/reference';
import type { PaymentMethod } from '@/shared/finance/types';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { AccountsSubNav } from '@/features/accounts/components/AccountsSubNav';
import { paymentMethodsApi } from '../api';
import { PaymentMethodDialog } from '../components/PaymentMethodDialog';

/** Payment methods with masked metadata only (spec §4.3). */
export function PaymentMethodsPage() {
  const t = useT();
  useDocumentTitle(t('paymentMethods.title'));
  const toast = useToast();
  const queryClient = useQueryClient();
  const [showArchived, setShowArchived] = useState(false);
  const methods = usePaymentMethods(showArchived);
  const accounts = useAccounts(true);
  const [editing, setEditing] = useState<PaymentMethod | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [removing, setRemoving] = useState<PaymentMethod | null>(null);
  const [removeError, setRemoveError] = useState<string | null>(null);
  const accountNames = new Map((accounts.data ?? []).map((account) => [account.id, account.name]));

  const remove = useMutation({
    mutationFn: (method: PaymentMethod) => paymentMethodsApi.remove(method.id),
    onSettled: () => invalidateFinance(queryClient),
  });
  const restore = useMutation({
    mutationFn: (method: PaymentMethod) => paymentMethodsApi.restore(method.id),
    onSettled: () => invalidateFinance(queryClient),
  });

  const openCreate = () => {
    setEditing(null);
    setDialogOpen(true);
  };

  const confirmRemove = () => {
    if (!removing || remove.isPending) return;
    setRemoveError(null);
    remove.mutate(removing, {
      onSuccess: (result) => {
        toast.show({
          tone: 'success',
          title: result.archived
            ? t('paymentMethods.remove.archived')
            : t('paymentMethods.remove.done'),
        });
        setRemoving(null);
      },
      onError: (error) => {
        if (hasErrorCode(error, 'NOT_FOUND')) {
          toast.show({ tone: 'info', title: t('paymentMethods.notFound') });
          setRemoving(null);
        } else {
          setRemoveError(describeError(error, t));
        }
      },
    });
  };

  let content;
  if (methods.isPending) {
    content = <LoadingState label={t('paymentMethods.loading')} />;
  } else if (methods.isError) {
    content = hasErrorCode(methods.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('paymentMethods.error')}
        error={methods.error}
        retrying={methods.isFetching}
        onRetry={() => {
          void methods.refetch();
        }}
      />
    );
  } else if (methods.data.length === 0) {
    content = (
      <EmptyState
        icon="credit-card"
        title={t('paymentMethods.empty.title')}
        description={t('paymentMethods.empty.body')}
        action={
          <Button onClick={openCreate}>
            <Icon name="plus" className="size-4" />
            {t('paymentMethods.add')}
          </Button>
        }
      />
    );
  } else {
    content = (
      <ul className="divide-y divide-line">
        {methods.data.map((method) => {
          const network =
            method.network && isPaymentNetwork(method.network)
              ? t(networkLabel[method.network])
              : null;
          const details = [t(paymentKindLabel[method.kind]), network, method.masked_hint].filter(
            Boolean,
          );
          const account = method.account_id ? accountNames.get(method.account_id) : undefined;
          return (
            <li
              key={method.id}
              className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-center"
            >
              <div className="flex min-w-0 flex-1 gap-3">
                <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
                  <Icon name={paymentKindIcon[method.kind]} />
                </span>
                <div className="min-w-0 space-y-1">
                  <p className="font-medium text-fg">{method.label}</p>
                  <p className="text-sm text-fg-muted">{details.join(' · ')}</p>
                  {account ? (
                    <p className="text-sm text-fg-muted">
                      {t('paymentMethods.linkedTo', { account })}
                    </p>
                  ) : null}
                  <div className="flex flex-wrap gap-2">
                    {method.is_default ? (
                      <StatusBadge tone="success" icon="check-circle">
                        {t('paymentMethods.default')}
                      </StatusBadge>
                    ) : null}
                    {method.archived_at ? (
                      <StatusBadge tone="neutral" icon="archive">
                        {t('paymentMethods.archived')}
                      </StatusBadge>
                    ) : null}
                  </div>
                </div>
              </div>
              <div className="flex shrink-0 gap-2">
                <Button
                  variant="secondary"
                  size="sm"
                  aria-label={`${t('common.edit')}: ${method.label}`}
                  onClick={() => {
                    setEditing(method);
                    setDialogOpen(true);
                  }}
                >
                  <Icon name="pencil" className="size-4" />
                  {t('common.edit')}
                </Button>
                {method.archived_at ? (
                  <Button
                    variant="secondary"
                    size="sm"
                    loading={restore.isPending && restore.variables.id === method.id}
                    aria-label={`${t('paymentMethods.restore.action')}: ${method.label}`}
                    onClick={() => {
                      restore.mutate(method, {
                        onSuccess: () => {
                          toast.show({ tone: 'success', title: t('paymentMethods.restore.done') });
                        },
                        onError: (error) => {
                          toast.show({
                            tone: 'danger',
                            title: t('paymentMethods.restore.failed'),
                            description: describeError(error, t),
                          });
                        },
                      });
                    }}
                  >
                    <Icon name="archive-restore" className="size-4" />
                    {t('paymentMethods.restore.action')}
                  </Button>
                ) : (
                  <Button
                    variant="secondary"
                    size="sm"
                    aria-label={`${t('paymentMethods.remove.action')}: ${method.label}`}
                    onClick={() => {
                      setRemoveError(null);
                      setRemoving(method);
                    }}
                  >
                    <Icon name="trash" className="size-4" />
                    {t('paymentMethods.remove.action')}
                  </Button>
                )}
              </div>
            </li>
          );
        })}
      </ul>
    );
  }

  return (
    <>
      <PageHeader
        title={t('paymentMethods.title')}
        description={t('paymentMethods.description')}
        actions={
          <Button onClick={openCreate}>
            <Icon name="plus" className="size-4" />
            {t('paymentMethods.add')}
          </Button>
        }
      />
      <AccountsSubNav />
      <Card
        title={t('paymentMethods.list.title')}
        description={t('paymentMethods.form.safety')}
        actions={
          <label className="inline-flex min-h-9 cursor-pointer items-center gap-2 text-sm text-fg">
            <input
              type="checkbox"
              checked={showArchived}
              onChange={(event) => {
                setShowArchived(event.target.checked);
              }}
              className="size-4 accent-accent"
            />
            {t('paymentMethods.showArchived')}
          </label>
        }
      >
        {content}
      </Card>
      <PaymentMethodDialog
        open={dialogOpen}
        method={editing}
        onOpenChange={(open) => {
          setDialogOpen(open);
          if (!open) setEditing(null);
        }}
      />
      <ConfirmDialog
        open={removing !== null}
        onOpenChange={(open) => {
          if (!open) setRemoving(null);
        }}
        title={t('paymentMethods.remove.title')}
        description={t('paymentMethods.remove.body', { label: removing?.label ?? '' })}
        confirmLabel={t('paymentMethods.remove.confirm')}
        onConfirm={confirmRemove}
        pending={remove.isPending}
        error={removeError}
      />
    </>
  );
}
