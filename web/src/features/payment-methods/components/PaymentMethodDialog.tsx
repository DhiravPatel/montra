import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { Dialog } from '@/shared/components/Dialog';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { Select } from '@/shared/components/Select';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { invalidateFinance } from '@/shared/finance/keys';
import {
  PAYMENT_METHOD_KINDS,
  PAYMENT_NETWORKS,
  isPaymentKind,
  isPaymentNetwork,
  networkLabel,
  paymentKindLabel,
} from '@/shared/finance/labels';
import { accountGroups } from '@/shared/finance/options';
import { useAccounts, writableAccounts } from '@/shared/finance/reference';
import type { PaymentMethod, PaymentMethodInput } from '@/shared/finance/types';
import type { PaymentMethodPatch } from '../api';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { maskedHintIsSafe, paymentMethodsApi } from '../api';

interface Values {
  kind: string;
  label: string;
  network: string;
  maskedHint: string;
  accountId: string;
  isDefault: boolean;
}

interface PaymentMethodDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Edit this method; create a new one when omitted. */
  method?: PaymentMethod | null;
}

export function PaymentMethodDialog({ open, onOpenChange, method }: PaymentMethodDialogProps) {
  const t = useT();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={method ? t('paymentMethods.edit.title') : t('paymentMethods.create.title')}
      description={t('paymentMethods.form.safety')}
      busy={pending}
    >
      {open ? (
        <PaymentMethodFormGate
          method={method ?? null}
          onPendingChange={setPending}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

/**
 * The linked-account select needs the accounts first, so it can show the
 * saved choice. After a version conflict the latest record is loaded and the
 * form starts again from it.
 */
function PaymentMethodFormGate(props: {
  method: PaymentMethod | null;
  onDone: () => void;
  onPendingChange: (pending: boolean) => void;
}) {
  const t = useT();
  const accounts = useAccounts();
  const [latest, setLatest] = useState<PaymentMethod | null>(props.method);
  const [reloadError, setReloadError] = useState<string | null>(null);
  const [conflict, setConflict] = useState(false);
  if (accounts.isError) {
    return (
      <ErrorState
        title={t('accounts.list.error')}
        error={accounts.error}
        onRetry={() => {
          void accounts.refetch();
        }}
      />
    );
  }
  if (accounts.isPending) return <LoadingState label={t('accounts.list.loading')} />;
  return (
    <>
      <FormAlert message={reloadError} />
      {conflict ? (
        <Alert tone="warning" live="assertive" className="mb-5" title={t('finance.conflict.title')}>
          {t('paymentMethods.conflict')}
        </Alert>
      ) : null}
      <PaymentMethodForm
        key={latest?.version ?? 'new'}
        {...props}
        method={latest}
        onConflict={() => {
          setConflict(true);
          if (!latest) return;
          paymentMethodsApi
            .get(latest.id)
            .then((fresh) => {
              setLatest(fresh);
            })
            .catch((error: unknown) => {
              setReloadError(describeError(error, t));
            });
        }}
      />
    </>
  );
}

function PaymentMethodForm({
  method,
  onDone,
  onPendingChange,
  onConflict,
}: {
  method: PaymentMethod | null;
  onDone: () => void;
  onPendingChange: (pending: boolean) => void;
  onConflict?: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const accounts = useAccounts();
  const [formError, setFormError] = useState<string | null>(null);
  const schema = useMemo(
    () =>
      z.object({
        kind: z.string().refine(isPaymentKind, { error: t('paymentMethods.form.kindRequired') }),
        label: z
          .string()
          .trim()
          .min(1, { error: t('paymentMethods.form.labelRequired') })
          .max(60, { error: t('validation.maxLength', { max: 60 }) }),
        network: z.string(),
        maskedHint: z
          .string()
          .trim()
          .max(24, { error: t('validation.maxLength', { max: 24 }) })
          .refine(maskedHintIsSafe, { error: t('paymentMethods.form.hintUnsafe') }),
        accountId: z.string(),
        isDefault: z.boolean(),
      }),
    [t],
  );
  const form = useForm<Values, unknown, Values>({
    resolver: zodResolver(schema),
    defaultValues: {
      kind: method?.kind ?? '',
      label: method?.label ?? '',
      network: method?.network ?? '',
      maskedHint: method?.masked_hint ?? '',
      accountId: method?.account_id ?? '',
      isDefault: method?.is_default ?? false,
    },
  });
  const mutation = useMutation({
    mutationFn: (body: PaymentMethodInput | PaymentMethodPatch) =>
      method
        ? paymentMethodsApi.update(method.id, body as PaymentMethodPatch)
        : paymentMethodsApi.create(body as PaymentMethodInput),
    onSuccess: () => invalidateFinance(queryClient),
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending || !isPaymentKind(values.kind)) return;
    setFormError(null);
    let body: PaymentMethodInput | PaymentMethodPatch;
    if (method) {
      // Only what changed, with the version that was edited ('' clears a hint or network).
      const patch: PaymentMethodPatch = { version: method.version };
      if (values.kind !== method.kind) patch.kind = values.kind;
      if (values.label.trim() !== method.label) patch.label = values.label.trim();
      if (values.isDefault !== method.is_default) patch.is_default = values.isDefault;
      if (values.network !== (method.network ?? '')) {
        patch.network = values.network && isPaymentNetwork(values.network) ? values.network : '';
      }
      if (values.maskedHint.trim() !== (method.masked_hint ?? ''))
        patch.masked_hint = values.maskedHint.trim();
      if (values.accountId !== (method.account_id ?? '')) {
        if (values.accountId) patch.account_id = values.accountId;
        else patch.clear_account = true;
      }
      body = patch;
    } else {
      body = {
        kind: values.kind,
        label: values.label.trim(),
        is_default: values.isDefault,
        ...(values.network && isPaymentNetwork(values.network) ? { network: values.network } : {}),
        ...(values.maskedHint.trim() ? { masked_hint: values.maskedHint.trim() } : {}),
        ...(values.accountId ? { account_id: values.accountId } : {}),
      };
    }
    onPendingChange(true);
    try {
      await mutation.mutateAsync(body);
      onPendingChange(false);
      toast.show({
        tone: 'success',
        title: method ? t('paymentMethods.edit.done') : t('paymentMethods.create.done'),
      });
      onDone();
    } catch (error) {
      onPendingChange(false);
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, {
          kind: 'kind',
          label: 'label',
          network: 'network',
          masked_hint: 'maskedHint',
          account_id: 'accountId',
        });
        if (rest.length > 0) setFormError(rest.join(' '));
      } else if (hasErrorCode(error, 'VERSION_CONFLICT')) {
        onConflict?.();
      } else if (hasErrorCode(error, 'NOT_FOUND')) {
        setFormError(t('paymentMethods.notFound'));
      } else {
        setFormError(describeError(error, t));
      }
    }
  });

  const { errors } = form.formState;
  const keep = method?.account_id;
  const accountChoices = writableAccounts(accounts.data).concat(
    (accounts.data ?? []).filter((account) => account.id === keep && account.status !== 'active'),
  );

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <Select
        label={t('paymentMethods.form.kind')}
        placeholder={t('paymentMethods.form.kindPlaceholder')}
        options={PAYMENT_METHOD_KINDS.map((kind) => ({
          value: kind,
          label: t(paymentKindLabel[kind]),
        }))}
        error={errors.kind?.message}
        {...form.register('kind')}
      />
      <TextField
        label={t('paymentMethods.form.label')}
        help={t('paymentMethods.form.labelHelp')}
        maxLength={60}
        autoComplete="off"
        error={errors.label?.message}
        {...form.register('label')}
      />
      <div className="grid gap-5 sm:grid-cols-2">
        <Select
          label={t('paymentMethods.form.network')}
          optional
          placeholder={t('common.none')}
          options={PAYMENT_NETWORKS.map((network) => ({
            value: network,
            label: t(networkLabel[network]),
          }))}
          error={errors.network?.message}
          {...form.register('network')}
        />
        <TextField
          label={t('paymentMethods.form.hint')}
          help={t('paymentMethods.form.hintHelp')}
          optional
          maxLength={24}
          autoComplete="off"
          error={errors.maskedHint?.message}
          {...form.register('maskedHint')}
        />
      </div>
      <Select
        label={t('paymentMethods.form.account')}
        optional
        placeholder={t('common.none')}
        groups={accountGroups(accountChoices, t)}
        help={t('paymentMethods.form.accountHelp')}
        error={errors.accountId?.message}
        {...form.register('accountId')}
      />
      <Checkbox
        label={t('paymentMethods.form.default')}
        description={t('paymentMethods.form.defaultHelp')}
        {...form.register('isDefault')}
      />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={mutation.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={mutation.isPending}>
          {method ? t('common.save') : t('paymentMethods.create.submit')}
        </Button>
      </div>
    </form>
  );
}
