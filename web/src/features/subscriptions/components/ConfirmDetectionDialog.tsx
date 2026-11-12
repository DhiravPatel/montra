import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { MoneyField } from '@/shared/components/MoneyField';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import { categoryFitsType } from '@/shared/finance/categories';
import { errorDetailCode } from '@/shared/finance/domainErrors';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import { accountGroups, categoryOptions } from '@/shared/finance/options';
import { useAccounts, useCategories, writableAccounts } from '@/shared/finance/reference';
import type {
  DetectionCandidate,
  DetectionConfirmInput,
  SubscriptionDetail,
} from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { isLocalDate } from '@/shared/formatting/dates';
import { decimalToInput, normalizeDecimalInput } from '@/shared/formatting/decimal';
import { useI18n } from '@/shared/i18n/I18nContext';
import { subscriptionsApi } from '../api';
import { subscriptionErrorMessage } from '../errors';

interface Values {
  name: string;
  amount: string;
  categoryId: string;
  accountId: string;
  nextRenewalDate: string;
}

interface ConfirmDetectionDialogProps {
  candidate: DetectionCandidate | null;
  onOpenChange: (open: boolean) => void;
  onConfirmed: (subscription: SubscriptionDetail) => void;
  /** The detection was handled elsewhere (already confirmed or dismissed, or gone). */
  onStale: () => void;
}

/**
 * Turns a detected repeating charge into a subscription. Nothing is added
 * until the user confirms here; every field can be adjusted first.
 */
export function ConfirmDetectionDialog({
  candidate,
  onOpenChange,
  onConfirmed,
  onStale,
}: ConfirmDetectionDialogProps) {
  const { t } = useI18n();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={candidate !== null}
      onOpenChange={onOpenChange}
      title={t('subscriptions.review.confirmTitle')}
      description={t('subscriptions.review.confirmBody')}
      busy={pending}
    >
      {candidate ? (
        <ConfirmGate
          candidate={candidate}
          onPendingChange={setPending}
          onCancel={() => {
            onOpenChange(false);
          }}
          onConfirmed={onConfirmed}
          onStale={onStale}
        />
      ) : null}
    </Dialog>
  );
}

function ConfirmGate(props: {
  candidate: DetectionCandidate;
  onPendingChange: (pending: boolean) => void;
  onCancel: () => void;
  onConfirmed: (subscription: SubscriptionDetail) => void;
  onStale: () => void;
}) {
  const { t } = useI18n();
  const accounts = useAccounts();
  const categories = useCategories();
  const currencies = useCurrencies();
  const failed = [accounts, categories, currencies].find((query) => query.isError);
  if (failed) {
    return (
      <ErrorState
        title={t('subscriptions.form.loadError')}
        error={failed.error}
        onRetry={() => {
          void accounts.refetch();
          void categories.refetch();
          void currencies.refetch();
        }}
      />
    );
  }
  if (accounts.isPending || categories.isPending || currencies.isPending) {
    return <LoadingState label={t('subscriptions.form.loading')} />;
  }
  return <ConfirmForm {...props} />;
}

function ConfirmForm({
  candidate,
  onPendingChange,
  onCancel,
  onConfirmed,
  onStale,
}: {
  candidate: DetectionCandidate;
  onPendingChange: (pending: boolean) => void;
  onCancel: () => void;
  onConfirmed: (subscription: SubscriptionDetail) => void;
  onStale: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const queryClient = useQueryClient();
  const accounts = useAccounts();
  const categories = useCategories();
  const currencies = useCurrencies();
  const [formError, setFormError] = useState<string | null>(null);
  const currency = candidate.amount.currency;
  const exponent = exponentFor(currencies.data, currency);
  const schema = useMemo(
    () =>
      z
        .object({
          name: z
            .string()
            .trim()
            .min(1, { error: t('subscriptions.form.nameRequired') })
            .max(120, { error: t('validation.maxLength', { max: 120 }) }),
          amount: z.string(),
          categoryId: z.string(),
          accountId: z.string(),
          nextRenewalDate: z.string().refine((value) => value === '' || isLocalDate(value), {
            error: t('validation.dateInvalid'),
          }),
        })
        .superRefine((values, ctx) => {
          checkAmount(ctx, {
            value: values.amount,
            path: 'amount',
            locale: formatLocale,
            currency,
            t,
            exponent,
          });
        }),
    [t, formatLocale, currency, exponent],
  );
  const form = useForm<Values, unknown, Values>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: candidate.merchant_label,
      amount: decimalToInput(candidate.amount.amount, formatLocale),
      categoryId: '',
      accountId: '',
      nextRenewalDate: candidate.next_expected_date ?? '',
    },
  });
  const confirm = useMutation({
    mutationFn: (body: DetectionConfirmInput) =>
      subscriptionsApi.confirmDetection(candidate.id, body),
    onSuccess: (subscription) => {
      queryClient.setQueryData(financeKeys.subscription(subscription.id), subscription);
      void invalidateFinance(queryClient);
    },
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (confirm.isPending) return;
    setFormError(null);
    const exact = normalizeDecimalInput(values.amount, formatLocale, { exponent });
    if (!exact.ok) return;
    const body: DetectionConfirmInput = {
      name: values.name.trim(),
      amount: exact.value,
      ...(values.categoryId ? { category_id: values.categoryId } : {}),
      ...(values.accountId ? { payment_account_id: values.accountId } : {}),
      ...(values.nextRenewalDate ? { next_renewal_date: values.nextRenewalDate } : {}),
    };
    onPendingChange(true);
    try {
      const subscription = await confirm.mutateAsync(body);
      onPendingChange(false);
      onConfirmed(subscription);
    } catch (error) {
      onPendingChange(false);
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, {
          name: 'name',
          amount: 'amount',
          category_id: 'categoryId',
          payment_account_id: 'accountId',
          next_renewal_date: 'nextRenewalDate',
        });
        setFormError(rest.length > 0 ? rest.join(' ') : null);
      } else if (errorDetailCode(error) === 'detection_evidence_missing') {
        // Still pending, but its charges are gone: it can only be dismissed.
        setFormError(t('subscriptions.review.evidenceMissing'));
      } else if (hasErrorCode(error, 'CONFLICT') || hasErrorCode(error, 'NOT_FOUND')) {
        // detection_already_decided, or removed: the list is refreshed.
        setFormError(t('subscriptions.review.alreadyHandled'));
        onStale();
      } else {
        setFormError(subscriptionErrorMessage(error, t, formatLocale));
      }
    }
  });

  const { errors } = form.formState;
  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <TextField
        label={t('subscriptions.form.name')}
        maxLength={120}
        autoComplete="off"
        error={errors.name?.message}
        {...form.register('name')}
      />
      <MoneyField
        label={t('subscriptions.form.amount')}
        help={t('subscriptions.review.amountHelp')}
        currency={currency}
        error={errors.amount?.message}
        {...form.register('amount')}
      />
      <TextField
        type="date"
        label={t('subscriptions.form.nextRenewal')}
        help={t('subscriptions.review.nextHelp')}
        optional
        error={errors.nextRenewalDate?.message}
        {...form.register('nextRenewalDate')}
      />
      <Select
        label={t('subscriptions.form.account')}
        optional
        placeholder={t('subscriptions.review.accountDefault')}
        groups={accountGroups(writableAccounts(accounts.data), t)}
        error={errors.accountId?.message}
        {...form.register('accountId')}
      />
      <Select
        label={t('subscriptions.form.category')}
        optional
        placeholder={t('categories.uncategorized')}
        options={categoryOptions(categories.data ?? [], t, formatLocale, (category) =>
          categoryFitsType(category, 'expense'),
        )}
        error={errors.categoryId?.message}
        {...form.register('categoryId')}
      />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={confirm.isPending} onClick={onCancel}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={confirm.isPending}>
          {t('subscriptions.review.confirmSubmit')}
        </Button>
      </div>
    </form>
  );
}
