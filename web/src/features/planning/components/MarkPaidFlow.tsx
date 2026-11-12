import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useRef, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { MoneyField } from '@/shared/components/MoneyField';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import {
  type PickerSuggestion,
  TransactionPickerDialog,
} from '@/shared/finance/components/TransactionPickerDialog';
import { invalidateFinance } from '@/shared/finance/keys';
import { accountGroups } from '@/shared/finance/options';
import { useAccounts, writableAccounts } from '@/shared/finance/reference';
import type { Bill, BillMarkPaidInput, Occurrence } from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import {
  addDaysToLocalDate,
  formatLocalDate,
  isLocalDate,
  todayInTimeZone,
} from '@/shared/formatting/dates';
import { decimalToInput, normalizeDecimalInput } from '@/shared/formatting/decimal';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { planningApi, usePaymentCandidates } from '../api';
import { planningConflictCode, planningErrorMessage } from '../errors';
import { candidateReasons, candidateTiming } from '../labels';

type Step = 'choose' | 'link' | 'record';
type Choice = Exclude<Step, 'choose'>;

interface MarkPaidFlowProps {
  bill: Bill;
  /** The unpaid occurrence to settle. */
  occurrence: Occurrence;
  onClose: () => void;
}

/**
 * Marks a bill payment as paid: link the payment the user already recorded
 * (suggested matches first, nothing new is created), or record a new
 * payment. Mount it only while open: every opening is a new draft with its
 * own Idempotency-Key, kept across retries of that draft.
 */
export function MarkPaidFlow({ bill, occurrence, onClose }: MarkPaidFlowProps) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const formatMoney = useFormatMoney();
  const [step, setStep] = useState<Step>('choose');
  const [choice, setChoice] = useState<Choice>('link');
  const [linkError, setLinkError] = useState<string | null>(null);
  const idempotency = useIdempotencyKey();
  const markPaid = useMutation({
    mutationFn: (body: BillMarkPaidInput) => planningApi.markPaid(bill.id, body, idempotency.key),
    onSettled: () => invalidateFinance(queryClient),
  });
  const candidates = usePaymentCandidates(bill.id, occurrence.id, step === 'link');
  // 409 occurrence_not_open: this payment was paid or skipped elsewhere.
  // Refresh the bill once so the screen behind the dialog shows it.
  const notOpen =
    candidates.isError && planningConflictCode(candidates.error) === 'occurrence_not_open';
  const refreshed = useRef(false);
  useEffect(() => {
    if (!notOpen || refreshed.current) return;
    refreshed.current = true;
    void invalidateFinance(queryClient);
  }, [notOpen, queryClient]);

  const done = () => {
    idempotency.renew();
    toast.show({ tone: 'success', title: t('bills.markPaid.done', { name: bill.name }) });
    onClose();
  };
  const closeUnlessBusy = (open: boolean) => {
    if (!open && !markPaid.isPending) onClose();
  };

  const due = formatLocalDate(occurrence.effective_date, formatLocale, 'long');
  const amount = occurrence.amount ?? bill.expected_amount;
  const dueText = amount
    ? t('bills.markPaid.dueWithAmount', { date: due, amount: formatMoney(amount) })
    : t('bills.markPaid.due', { date: due });

  if (step === 'link') {
    const suggestions: PickerSuggestion[] = (candidates.data ?? []).map((candidate) => {
      const timing = candidateTiming(candidate, t);
      return {
        transactionId: candidate.transaction_id,
        localDate: candidate.local_date,
        amount: candidate.amount,
        accountName: candidate.account_name,
        title: candidate.merchant ?? candidate.description ?? t('bills.markPaid.untitled'),
        reasons: candidateReasons(candidate, t),
        ...(timing ? { note: timing } : {}),
      };
    });
    return (
      <TransactionPickerDialog
        open
        onOpenChange={closeUnlessBusy}
        title={t('bills.markPaid.linkTitle', { name: bill.name })}
        description={
          <>
            <p>{dueText}</p>
            <p className="mt-1">{t('bills.markPaid.linkHelp')}</p>
            {notOpen ? (
              <p className="mt-1">{t('planning.conflict.occurrence_not_open')}</p>
            ) : candidates.isError ? (
              <p className="mt-1">{t('bills.markPaid.candidatesFailed')}</p>
            ) : null}
          </>
        }
        suggestions={suggestions}
        suggestionsLoading={candidates.isPending}
        // An empty list: nothing recorded looks like this payment yet.
        {...(candidates.isSuccess
          ? { suggestionsEmptyText: t('bills.markPaid.noSuggestions') }
          : {})}
        search={{
          types: ['expense', 'group_expense'],
          from: addDaysToLocalDate(occurrence.effective_date, -45),
          to: addDaysToLocalDate(occurrence.effective_date, 45),
        }}
        confirmLabel={t('bills.markPaid.linkConfirm')}
        pending={markPaid.isPending}
        error={linkError}
        onConfirm={(transactionId) => {
          if (markPaid.isPending) return;
          setLinkError(null);
          markPaid.mutate(
            { occurrence_id: occurrence.id, transaction_id: transactionId },
            {
              onSuccess: done,
              onError: (error) => {
                setLinkError(planningErrorMessage(error, t, formatLocale));
              },
            },
          );
        }}
      />
    );
  }

  return (
    <Dialog
      open
      onOpenChange={closeUnlessBusy}
      title={
        step === 'record'
          ? t('bills.markPaid.recordTitle', { name: bill.name })
          : t('bills.markPaid.title', { name: bill.name })
      }
      description={dueText}
      busy={markPaid.isPending}
    >
      {step === 'record' ? (
        <RecordPaymentForm
          bill={bill}
          occurrence={occurrence}
          pending={markPaid.isPending}
          onCancel={onClose}
          onSubmit={(body) =>
            markPaid.mutateAsync({ ...body, occurrence_id: occurrence.id }).then(done)
          }
        />
      ) : (
        <div className="space-y-5">
          <RadioGroup<Choice>
            legend={t('bills.markPaid.how')}
            variant="cards"
            value={choice}
            onChange={setChoice}
            options={[
              {
                value: 'link',
                label: t('bills.markPaid.choiceLink'),
                description: t('bills.markPaid.choiceLinkHelp'),
              },
              {
                value: 'record',
                label: t('bills.markPaid.choiceRecord'),
                description: t('bills.markPaid.choiceRecordHelp'),
              },
            ]}
          />
          <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
            <Button variant="secondary" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button
              onClick={() => {
                setStep(choice);
              }}
            >
              {t('bills.markPaid.continue')}
            </Button>
          </div>
        </div>
      )}
    </Dialog>
  );
}

interface RecordValues {
  accountId: string;
  amount: string;
  paidOn: string;
}

function recordSchema(t: Translate, locale: string, currency: string, exponent: number) {
  return z
    .object({ accountId: z.string(), amount: z.string(), paidOn: z.string() })
    .superRefine((values, ctx) => {
      if (!values.accountId) {
        ctx.addIssue({
          code: 'custom',
          path: ['accountId'],
          message: t('bills.markPaid.accountRequired'),
        });
      }
      if (!isLocalDate(values.paidOn)) {
        ctx.addIssue({ code: 'custom', path: ['paidOn'], message: t('validation.dateInvalid') });
      }
      checkAmount(ctx, { value: values.amount, path: 'amount', locale, currency, exponent, t });
    });
}

/** Records a new expense for the bill and marks the occurrence paid. */
function RecordPaymentForm({
  bill,
  occurrence,
  pending,
  onSubmit,
  onCancel,
}: {
  bill: Bill;
  occurrence: Occurrence;
  pending: boolean;
  onSubmit: (body: BillMarkPaidInput) => Promise<void>;
  onCancel: () => void;
}) {
  const { t } = useI18n();
  const accounts = useAccounts();
  const currencies = useCurrencies();
  const failed = [accounts, currencies].find((query) => query.isError);
  if (failed) {
    return (
      <ErrorState
        titleAs="p"
        title={t('bills.form.loadFailed')}
        error={failed.error}
        onRetry={() => {
          void failed.refetch();
        }}
      />
    );
  }
  if (accounts.isPending || currencies.isPending) {
    return <LoadingState label={t('bills.form.loading')} />;
  }
  return (
    <RecordPaymentFields
      bill={bill}
      occurrence={occurrence}
      pending={pending}
      onSubmit={onSubmit}
      onCancel={onCancel}
    />
  );
}

function RecordPaymentFields({
  bill,
  occurrence,
  pending,
  onSubmit,
  onCancel,
}: {
  bill: Bill;
  occurrence: Occurrence;
  pending: boolean;
  onSubmit: (body: BillMarkPaidInput) => Promise<void>;
  onCancel: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const accounts = useAccounts();
  const currencies = useCurrencies();
  const [formError, setFormError] = useState<string | null>(null);
  const currency = occurrence.amount?.currency ?? bill.currency;
  const exponent = exponentFor(currencies.data, currency);
  const writable = writableAccounts(accounts.data);
  const sameCurrency = writable.filter((account) => account.currency === currency);
  const choices = sameCurrency.length > 0 ? sameCurrency : writable;
  const preferred = choices.find((account) => account.id === bill.payment_account_id);
  const expected = occurrence.amount ?? bill.expected_amount;

  const schema = useMemo(
    () => recordSchema(t, formatLocale, currency, exponent),
    [t, formatLocale, currency, exponent],
  );
  const form = useForm<RecordValues, unknown, RecordValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      accountId: preferred?.id ?? (choices.length === 1 ? (choices[0]?.id ?? '') : ''),
      amount: expected ? decimalToInput(expected.amount, formatLocale) : '',
      paidOn: todayInTimeZone(user.timezone),
    },
  });
  const { errors } = form.formState;

  const submit = form.handleSubmit(async (values) => {
    if (pending) return;
    setFormError(null);
    const amount = normalizeDecimalInput(values.amount, formatLocale, { exponent });
    if (!amount.ok) return;
    try {
      await onSubmit({
        create_transaction: true,
        account_id: values.accountId,
        amount: amount.value,
        paid_on: values.paidOn,
      });
    } catch (error) {
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, {
          account_id: 'accountId',
          amount: 'amount',
          paid_on: 'paidOn',
        });
        setFormError(rest.length > 0 ? rest.join(' ') : null);
      } else {
        setFormError(planningErrorMessage(error, t, formatLocale));
      }
    }
  });

  return (
    <form onSubmit={submit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <Select
        label={t('bills.markPaid.account')}
        placeholder={t('bills.markPaid.accountChoose')}
        groups={accountGroups(choices, t)}
        error={errors.accountId?.message}
        {...form.register('accountId')}
      />
      <div className="grid gap-5 sm:grid-cols-2">
        <MoneyField
          label={t('bills.markPaid.amount')}
          currency={currency}
          error={errors.amount?.message}
          {...form.register('amount')}
        />
        <TextField
          label={t('bills.markPaid.paidOn')}
          type="date"
          error={errors.paidOn?.message}
          {...form.register('paidOn')}
        />
      </div>
      <p className="text-sm text-fg-muted">{t('bills.markPaid.recordHelp')}</p>
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={pending} onClick={onCancel}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={pending}>
          {t('bills.markPaid.recordSubmit')}
        </Button>
      </div>
    </form>
  );
}
