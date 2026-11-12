import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import type { IdempotencyKey } from '@/shared/api/idempotency';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { Select } from '@/shared/components/Select';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths } from '@/shared/config/paths';
import { categoryFitsType } from '@/shared/finance/categories';
import { invalidateFinance } from '@/shared/finance/keys';
import { accountGroups, categoryOptions } from '@/shared/finance/options';
import { useAccounts, useCategories, writableAccounts } from '@/shared/finance/reference';
import type { Account, Category } from '@/shared/finance/types';
import { FormAlert } from '@/shared/forms/FormAlert';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { receiptsApi } from '../api';
import { receiptErrorMessage } from '../errors';
import type { ReceiptCreateTransactionInput, ReceiptExtraction } from '../types';

interface RecordExpenseDialogProps {
  receiptId: string;
  /** The reviewed values: the expense uses exactly this total and date. */
  values: ReceiptExtraction;
  /**
   * Kept by the page so a retry after a lost response (even after closing
   * the dialog) replays the first result instead of recording twice.
   */
  idempotency: IdempotencyKey;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

/** Records the purchase as an expense from the reviewed values (Idempotency-Key protected). */
export function RecordExpenseDialog({
  receiptId,
  values,
  idempotency,
  open,
  onOpenChange,
}: RecordExpenseDialogProps) {
  const { t } = useI18n();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('receipts.record.title')}
      description={t('receipts.record.description')}
      busy={pending}
    >
      {open ? (
        <RecordGate
          receiptId={receiptId}
          values={values}
          idempotency={idempotency}
          onPendingChange={setPending}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

interface FormProps {
  receiptId: string;
  values: ReceiptExtraction;
  idempotency: IdempotencyKey;
  onPendingChange: (pending: boolean) => void;
  onDone: () => void;
}

/** Accounts and categories are needed before the form can show its choices. */
function RecordGate(props: FormProps) {
  const { t } = useI18n();
  const accounts = useAccounts();
  const categories = useCategories();
  if (accounts.isPending || categories.isPending) {
    return <LoadingState label={t('transactions.form.loading')} />;
  }
  if (accounts.isError || categories.isError) {
    return (
      <ErrorState
        titleAs="p"
        title={t('transactions.form.loadFailed')}
        error={accounts.error ?? categories.error}
        retrying={accounts.isFetching || categories.isFetching}
        onRetry={() => {
          if (accounts.isError) void accounts.refetch();
          if (categories.isError) void categories.refetch();
        }}
      />
    );
  }
  return <RecordForm {...props} accounts={accounts.data} categories={categories.data} />;
}

interface Values {
  accountId: string;
  categoryId: string;
  description: string;
}

function RecordForm({
  receiptId,
  values,
  idempotency,
  accounts,
  categories,
  onPendingChange,
  onDone,
}: FormProps & { accounts: Account[]; categories: Category[] }) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [formError, setFormError] = useState<string | null>(null);
  const currency = values.total?.currency ?? values.currency ?? '';
  // The API records the expense in the receipt currency, so only accounts in it can be used.
  const choices = writableAccounts(accounts).filter((account) => account.currency === currency);

  const schema = useMemo(
    () =>
      z.object({
        accountId: z.string().min(1, { error: t('validation.chooseAccount') }),
        categoryId: z.string(),
        description: z
          .string()
          .trim()
          .max(500, { error: t('validation.maxLength', { max: 500 }) }),
      }),
    [t],
  );
  const form = useForm<Values, unknown, Values>({
    resolver: zodResolver(schema),
    defaultValues: {
      accountId: choices.length === 1 ? (choices[0]?.id ?? '') : '',
      categoryId: '',
      description: '',
    },
  });
  const mutation = useMutation({
    mutationFn: (body: ReceiptCreateTransactionInput) =>
      receiptsApi.createTransaction(receiptId, body, idempotency.key),
    onSuccess: () => {
      // A new key only after a success: a retry of the same draft replays the first result.
      idempotency.renew();
    },
    onSettled: () => invalidateFinance(queryClient),
  });

  const onSubmit = form.handleSubmit(async (input) => {
    if (mutation.isPending) return;
    setFormError(null);
    const body: ReceiptCreateTransactionInput = {
      account_id: input.accountId,
      ...(input.categoryId ? { category_id: input.categoryId } : {}),
      ...(input.description ? { description: input.description } : {}),
    };
    onPendingChange(true);
    try {
      await mutation.mutateAsync(body);
      onPendingChange(false);
      toast.show({ tone: 'success', title: t('receipts.record.done') });
      onDone();
    } catch (error) {
      onPendingChange(false);
      if (
        hasErrorCode(error, 'VALIDATION_ERROR') &&
        error.details.some((detail) => detail.field === 'body.account_id')
      ) {
        form.setError(
          'accountId',
          { type: 'server', message: t('receipts.record.accountCurrency', { currency }) },
          { shouldFocus: true },
        );
      } else {
        setFormError(receiptErrorMessage(error, 'record', t, formatLocale));
      }
    }
  });

  const summary = (
    <Facts className="rounded-lg border border-line p-4">
      {values.total ? (
        <Fact label={t('receipts.fields.total')}>
          <MoneyText money={values.total} className="font-semibold" />
        </Fact>
      ) : null}
      {values.receipt_date ? (
        <Fact label={t('receipts.fields.date')}>
          {formatLocalDate(values.receipt_date, formatLocale, 'long')}
        </Fact>
      ) : null}
      {values.merchant_name ? (
        <Fact label={t('receipts.fields.merchant')}>{values.merchant_name}</Fact>
      ) : null}
    </Facts>
  );

  if (choices.length === 0) {
    return (
      <div className="space-y-4">
        {summary}
        <EmptyState
          icon="wallet"
          title={t('receipts.record.noAccount', { currency })}
          description={t('receipts.record.noAccountBody', { currency })}
          action={
            <ButtonLink to={paths.accountNew}>
              <Icon name="plus" className="size-4" />
              {t('accounts.add')}
            </ButtonLink>
          }
        />
      </div>
    );
  }

  const { errors } = form.formState;
  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      {summary}
      <Select
        label={t('transactions.form.account')}
        placeholder={t('transactions.form.accountPlaceholder')}
        groups={accountGroups(choices, t)}
        help={t('receipts.record.accountHelp', { currency })}
        error={errors.accountId?.message}
        {...form.register('accountId')}
      />
      <Select
        label={t('transactions.form.category')}
        optional
        placeholder={t('transactions.form.categoryNone')}
        options={categoryOptions(categories, t, formatLocale, (category) =>
          categoryFitsType(category, 'expense'),
        )}
        help={t('transactions.form.categoryHelp')}
        error={errors.categoryId?.message}
        {...form.register('categoryId')}
      />
      <TextField
        label={t('transactions.form.description')}
        optional
        maxLength={500}
        autoComplete="off"
        help={t('receipts.record.descriptionHelp')}
        error={errors.description?.message}
        {...form.register('description')}
      />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={mutation.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={mutation.isPending}>
          {t('receipts.record.submit')}
        </Button>
      </div>
    </form>
  );
}
