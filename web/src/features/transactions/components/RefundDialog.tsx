import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { Dialog } from '@/shared/components/Dialog';
import { Fact, Facts } from '@/shared/components/Facts';
import { MoneyField } from '@/shared/components/MoneyField';
import { MoneyText } from '@/shared/components/MoneyText';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import { invalidateFinance } from '@/shared/finance/keys';
import { accountGroups } from '@/shared/finance/options';
import { useAccounts, writableAccounts } from '@/shared/finance/reference';
import type { RefundInput, Transaction } from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { normalizeDecimalInput } from '@/shared/formatting/decimal';
import { isLocalDate, todayInTimeZone } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { transactionsApi } from '../api';
import { domainRuleMessage } from '@/shared/finance/domainErrors';

type RefundType = 'refund' | 'reimbursement';

interface RefundValues {
  type: RefundType;
  amount: string;
  accountId: string;
  localDate: string;
  description: string;
  notes: string;
  isCorrection: boolean;
}

interface RefundDialogProps {
  original: Transaction;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

/**
 * A partial or full refund or reimbursement linked to an expense. The API
 * caps the total at the original amount unless it is marked as a correction.
 */
export function RefundDialog({ original, open, onOpenChange }: RefundDialogProps) {
  const { t } = useI18n();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('transactions.refund.title')}
      description={t('transactions.refund.description')}
      busy={pending}
      size="lg"
    >
      {open ? (
        <RefundForm
          original={original}
          onPendingChange={setPending}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

function RefundForm({
  original,
  onDone,
  onPendingChange,
}: {
  original: Transaction;
  onDone: () => void;
  onPendingChange: (pending: boolean) => void;
}) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const currencies = useCurrencies();
  const accounts = useAccounts();
  const idempotency = useIdempotencyKey();
  const [formError, setFormError] = useState<string | null>(null);
  const currency = original.amount.currency;
  const exponent = exponentFor(currencies.data, currency);
  const sameCurrency = writableAccounts(accounts.data).filter(
    (account) => account.currency === currency,
  );

  const schema = useMemo(
    () =>
      z
        .object({
          type: z.enum(['refund', 'reimbursement']),
          amount: z.string(),
          accountId: z.string(),
          localDate: z.string(),
          description: z.string().max(500, { error: t('validation.maxLength', { max: 500 }) }),
          notes: z.string().max(4000, { error: t('validation.maxLength', { max: 4000 }) }),
          isCorrection: z.boolean(),
        })
        .superRefine((values, ctx) => {
          checkAmount(ctx, {
            value: values.amount,
            path: 'amount',
            locale: formatLocale,
            currency,
            exponent,
            t,
          });
          if (values.localDate && !isLocalDate(values.localDate)) {
            ctx.addIssue({
              code: 'custom',
              path: ['localDate'],
              message: t('validation.dateInvalid'),
            });
          }
        }),
    [t, formatLocale, currency, exponent],
  );

  const form = useForm<RefundValues, unknown, RefundValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      type: 'refund',
      amount: '',
      accountId: '',
      localDate: todayInTimeZone(user.timezone),
      description: '',
      notes: '',
      isCorrection: false,
    },
  });

  const mutation = useMutation({
    mutationFn: (body: RefundInput) => transactionsApi.refund(original.id, body, idempotency.key),
    onSuccess: () => {
      idempotency.renew();
      void invalidateFinance(queryClient);
    },
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending) return;
    setFormError(null);
    const amount = normalizeDecimalInput(values.amount, formatLocale, { exponent });
    if (!amount.ok) return;
    const body: RefundInput = {
      type: values.type,
      amount: amount.value,
      ...(values.accountId ? { account_id: values.accountId } : {}),
      ...(values.localDate ? { local_date: values.localDate } : {}),
      ...(values.description.trim() ? { description: values.description.trim() } : {}),
      ...(values.notes.trim() ? { notes: values.notes.trim() } : {}),
      ...(values.isCorrection ? { is_correction: true } : {}),
    };
    onPendingChange(true);
    try {
      await mutation.mutateAsync(body);
      onPendingChange(false);
      toast.show({
        tone: 'success',
        title:
          values.type === 'refund'
            ? t('transactions.refund.doneRefund')
            : t('transactions.refund.doneReimbursement'),
      });
      onDone();
    } catch (error) {
      onPendingChange(false);
      if (hasErrorCode(error, 'DOMAIN_RULE_VIOLATION')) {
        setFormError(
          domainRuleMessage(error, t, formatLocale) ?? t('transactions.refund.capError'),
        );
      } else if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, {
          amount: 'amount',
          account_id: 'accountId',
          local_date: 'localDate',
          description: 'description',
          notes: 'notes',
        });
        if (rest.length > 0) setFormError(rest.join(' '));
      } else if (hasErrorCode(error, 'IDEMPOTENCY_CONFLICT')) {
        setFormError(t('finance.errors.maybeSaved'));
      } else {
        setFormError(describeError(error, t));
      }
    }
  });

  const { errors } = form.formState;

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <Facts className="rounded-lg border border-line p-4">
        <Fact label={t('transactions.refund.original')}>
          <MoneyText money={original.amount} />
        </Fact>
        <Fact label={t('transactions.refund.already')}>
          <MoneyText money={original.refunded_total} />
        </Fact>
      </Facts>
      <Controller
        control={form.control}
        name="type"
        render={({ field }) => (
          <RadioGroup<RefundType>
            legend={t('transactions.refund.kind')}
            value={field.value}
            onChange={field.onChange}
            variant="cards"
            options={[
              {
                value: 'refund',
                label: t('finance.txType.refund'),
                description: t('transactions.refund.refundHelp'),
              },
              {
                value: 'reimbursement',
                label: t('finance.txType.reimbursement'),
                description: t('transactions.refund.reimbursementHelp'),
              },
            ]}
          />
        )}
      />
      <div className="grid gap-5 sm:grid-cols-2">
        <MoneyField
          label={t('transactions.refund.amount')}
          currency={currency}
          help={t('transactions.refund.amountHelp')}
          error={errors.amount?.message}
          {...form.register('amount')}
        />
        <TextField
          label={t('transactions.form.date')}
          type="date"
          optional
          error={errors.localDate?.message}
          {...form.register('localDate')}
        />
      </div>
      {sameCurrency.length > 1 ? (
        <Select
          label={t('transactions.refund.account')}
          optional
          placeholder={t('transactions.refund.sameAccount', { account: original.account_name })}
          groups={accountGroups(sameCurrency, t)}
          error={errors.accountId?.message}
          {...form.register('accountId')}
        />
      ) : null}
      <TextField
        label={t('transactions.form.description')}
        optional
        maxLength={500}
        error={errors.description?.message}
        {...form.register('description')}
      />
      <TextArea
        label={t('transactions.form.notes')}
        optional
        rows={2}
        maxLength={4000}
        help={t('finance.sensitiveHint')}
        error={errors.notes?.message}
        {...form.register('notes')}
      />
      <Checkbox
        label={t('transactions.refund.correction')}
        description={t('transactions.refund.correctionHelp')}
        {...form.register('isCorrection')}
      />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={mutation.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={mutation.isPending}>
          {t('transactions.refund.submit')}
        </Button>
      </div>
    </form>
  );
}
