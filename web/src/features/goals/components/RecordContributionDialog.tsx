import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { MoneyField } from '@/shared/components/MoneyField';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type {
  Goal,
  GoalContribution,
  GoalContributionRecordInput,
  Transaction,
} from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { compareDecimal, decimalToInput, normalizeDecimalInput } from '@/shared/formatting/decimal';
import { formatLocalDate, isLocalDate, todayInTimeZone } from '@/shared/formatting/dates';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import { goalsApi } from '../api';
import { contributionErrorMessage, isContributionStale } from '../errors';
import { LinkTransactionField } from './LinkTransactionField';

interface RecordContributionDialogProps {
  goal: Goal;
  /** The planned contribution to record; null closes the dialog. */
  contribution: GoalContribution | null;
  onClose: () => void;
}

/**
 * Records one of your planned contributions: the planned row itself becomes
 * recorded (or verified with a linked transaction), so it is counted once.
 * Each opening is a new draft with its own Idempotency-Key, kept for retries.
 */
export function RecordContributionDialog({
  goal,
  contribution,
  onClose,
}: RecordContributionDialogProps) {
  const { t, formatLocale } = useI18n();
  const formatMoney = useFormatMoney();
  const [pending, setPending] = useState(false);
  const planned = contribution?.amount;
  const date = contribution ? formatLocalDate(contribution.contributed_on, formatLocale) : '';
  return (
    <Dialog
      open={contribution !== null}
      onOpenChange={(open) => {
        if (!open && !pending) onClose();
      }}
      title={
        contribution?.kind === 'withdrawal'
          ? t('goals.record.titleWithdrawal')
          : t('goals.record.title')
      }
      description={
        planned
          ? t('goals.record.descriptionAmount', { amount: formatMoney(planned), date })
          : t('goals.record.description', { date })
      }
      busy={pending}
    >
      {contribution ? (
        <RecordForm
          key={contribution.id}
          goal={goal}
          contribution={contribution}
          onPendingChange={setPending}
          onDone={onClose}
        />
      ) : null}
    </Dialog>
  );
}

interface Values {
  amount: string;
  date: string;
}

function RecordForm({
  goal,
  contribution,
  onPendingChange,
  onDone,
}: {
  goal: Goal;
  contribution: GoalContribution;
  onPendingChange: (pending: boolean) => void;
  onDone: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const currencies = useCurrencies();
  const idempotency = useIdempotencyKey();
  const currency = goal.target.currency;
  const today = todayInTimeZone(user.timezone);
  const [formError, setFormError] = useState<string | null>(null);
  const [linked, setLinked] = useState<Transaction | null>(null);

  const schema = useMemo(
    () =>
      z.object({ amount: z.string(), date: z.string() }).superRefine((values, ctx) => {
        checkAmount(ctx, {
          value: values.amount,
          path: 'amount',
          locale: formatLocale,
          currency,
          exponent: exponentFor(currencies.data, currency),
          t,
        });
        if (linked) return; // dated by the linked transaction
        if (!values.date) {
          ctx.addIssue({ code: 'custom', path: ['date'], message: t('validation.dateRequired') });
        } else if (!isLocalDate(values.date)) {
          ctx.addIssue({ code: 'custom', path: ['date'], message: t('validation.dateInvalid') });
        } else if (values.date > today) {
          ctx.addIssue({ code: 'custom', path: ['date'], message: t('goals.record.notFuture') });
        }
      }),
    [t, formatLocale, currency, currencies.data, linked, today],
  );
  const form = useForm<Values, unknown, Values>({
    resolver: zodResolver(schema),
    defaultValues: {
      amount: contribution.amount ? decimalToInput(contribution.amount.amount, formatLocale) : '',
      date: today,
    },
  });

  const mutation = useMutation({
    mutationFn: (body: GoalContributionRecordInput) =>
      goalsApi.recordPlanned(goal.id, contribution.id, body, idempotency.key),
    onSuccess: () => {
      idempotency.renew();
      void invalidateFinance(queryClient);
    },
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending) return;
    setFormError(null);
    const exact = normalizeDecimalInput(values.amount, formatLocale, {
      exponent: exponentFor(currencies.data, currency),
    });
    if (!exact.ok) return;
    const plan = contribution.amount?.amount;
    const body: GoalContributionRecordInput = {
      // The planned amount is the default: send one only when it differs.
      ...(plan && compareDecimal(plan, exact.value) === 0 ? {} : { amount: exact.value }),
      // A linked transaction verifies it and dates it; otherwise the chosen day.
      ...(linked ? { transaction_id: linked.id } : { contributed_on: values.date }),
    };
    onPendingChange(true);
    try {
      await mutation.mutateAsync(body);
      onPendingChange(false);
      toast.show({
        tone: 'success',
        title: linked ? t('goals.record.doneVerified') : t('goals.record.done'),
      });
      onDone();
    } catch (error) {
      onPendingChange(false);
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, {
          amount: 'amount',
          contributed_on: 'date',
        });
        if (rest.length > 0) setFormError(rest.join(' '));
        return;
      }
      setFormError(contributionErrorMessage(error, t, formatLocale));
      if (isContributionStale(error)) {
        // Recorded or voided elsewhere: show the history as it is now.
        void queryClient.invalidateQueries({ queryKey: financeKeys.goalContributions(goal.id) });
      }
    }
  });

  const { errors } = form.formState;

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <MoneyField
        label={t('goals.record.amount')}
        currency={currency}
        help={t('goals.record.amountHelp')}
        error={errors.amount?.message}
        {...form.register('amount')}
      />
      <LinkTransactionField kind={contribution.kind} linked={linked} onLinkedChange={setLinked} />
      {linked ? null : (
        <TextField
          label={t('goals.record.date')}
          type="date"
          max={today}
          error={errors.date?.message}
          {...form.register('date')}
        />
      )}
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={mutation.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={mutation.isPending}>
          {t('goals.record.submit')}
        </Button>
      </div>
    </form>
  );
}
