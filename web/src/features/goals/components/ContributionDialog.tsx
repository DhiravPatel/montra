import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { Controller, useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { MoneyField } from '@/shared/components/MoneyField';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import { invalidateFinance } from '@/shared/finance/keys';
import type { Goal, GoalContributionInput, Transaction } from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { absDecimal, decimalToInput, normalizeDecimalInput } from '@/shared/formatting/decimal';
import { isLocalDate, todayInTimeZone } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { goalsApi } from '../api';
import { contributionErrorMessage } from '../errors';
import { LinkTransactionField } from './LinkTransactionField';

type Kind = 'contribution' | 'withdrawal';
type Status = 'recorded' | 'planned';

interface Values {
  kind: Kind;
  status: Status;
  amount: string;
  date: string;
  note: string;
}

interface ContributionDialogProps {
  goal: Goal;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

/** Records a contribution or withdrawal; linking its transaction makes it verified. */
export function ContributionDialog({ goal, open, onOpenChange }: ContributionDialogProps) {
  const { t } = useI18n();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('goals.contribute.title')}
      description={t('goals.contribute.description')}
      busy={pending}
    >
      {open ? (
        <ContributionForm
          goal={goal}
          onPendingChange={setPending}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

function ContributionForm({
  goal,
  onPendingChange,
  onDone,
}: {
  goal: Goal;
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
  const [formError, setFormError] = useState<string | null>(null);
  const [linked, setLinked] = useState<Transaction | null>(null);

  const schema = useMemo(
    () =>
      z
        .object({
          kind: z.enum(['contribution', 'withdrawal']),
          status: z.enum(['recorded', 'planned']),
          amount: z.string(),
          date: z.string(),
          note: z
            .string()
            .trim()
            .max(500, { error: t('validation.maxLength', { max: 500 }) }),
        })
        .superRefine((values, ctx) => {
          checkAmount(ctx, {
            value: values.amount,
            path: 'amount',
            locale: formatLocale,
            currency,
            exponent: exponentFor(currencies.data, currency),
            t,
          });
          if (!linked) {
            if (!values.date) {
              ctx.addIssue({
                code: 'custom',
                path: ['date'],
                message: t('validation.dateRequired'),
              });
            } else if (!isLocalDate(values.date)) {
              ctx.addIssue({
                code: 'custom',
                path: ['date'],
                message: t('validation.dateInvalid'),
              });
            }
          }
        }),
    [t, formatLocale, currency, currencies.data, linked],
  );
  const form = useForm<Values, unknown, Values>({
    resolver: zodResolver(schema),
    defaultValues: {
      kind: 'contribution',
      status: 'recorded',
      amount: '',
      date: todayInTimeZone(user.timezone),
      note: '',
    },
  });
  const kind = useWatch({ control: form.control, name: 'kind' });

  const mutation = useMutation({
    mutationFn: (body: GoalContributionInput) =>
      goalsApi.contribute(goal.id, body, idempotency.key),
    onSuccess: () => {
      idempotency.renew();
      void invalidateFinance(queryClient);
    },
  });

  const linkTransaction = (transaction: Transaction | null) => {
    setLinked(transaction);
    if (transaction && !form.getValues('amount').trim()) {
      form.setValue('amount', decimalToInput(absDecimal(transaction.amount.amount), formatLocale));
    }
  };

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending) return;
    setFormError(null);
    const exact = normalizeDecimalInput(values.amount, formatLocale, {
      exponent: exponentFor(currencies.data, currency),
    });
    if (!exact.ok) return;
    const note = values.note.trim();
    const body: GoalContributionInput = {
      amount: exact.value,
      kind: values.kind,
      ...(note ? { note } : {}),
      // A linked transaction is an actual movement: it is verified and dated by the ledger.
      ...(linked
        ? { transaction_id: linked.id }
        : { status: values.status, contributed_on: values.date }),
    };
    onPendingChange(true);
    try {
      await mutation.mutateAsync(body);
      onPendingChange(false);
      toast.show({
        tone: 'success',
        title:
          values.kind === 'withdrawal'
            ? t('goals.contribute.doneWithdrawal')
            : t('goals.contribute.done'),
      });
      onDone();
    } catch (error) {
      onPendingChange(false);
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        if (linked && error.details.some((detail) => detail.field === 'body.amount')) {
          form.setError(
            'amount',
            { type: 'server', message: t('goals.contribute.errors.exceedsTransaction') },
            { shouldFocus: true },
          );
          return;
        }
        const rest = applyServerErrors(error, form.setError, {
          amount: 'amount',
          contributed_on: 'date',
          note: 'note',
        });
        if (rest.length > 0) setFormError(rest.join(' '));
      } else {
        setFormError(contributionErrorMessage(error, t, formatLocale));
      }
    }
  });

  const { errors } = form.formState;

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <Controller
        control={form.control}
        name="kind"
        render={({ field }) => (
          <RadioGroup
            legend={t('goals.contribute.kind')}
            value={field.value}
            onChange={field.onChange}
            options={[
              { value: 'contribution', label: t('goals.contribute.kindContribution') },
              { value: 'withdrawal', label: t('goals.contribute.kindWithdrawal') },
            ]}
          />
        )}
      />
      <MoneyField
        label={t('goals.contribute.amount')}
        currency={currency}
        error={errors.amount?.message}
        {...form.register('amount')}
      />
      <LinkTransactionField kind={kind} linked={linked} onLinkedChange={linkTransaction} />
      {linked ? null : (
        <>
          <TextField
            label={t('goals.contribute.date')}
            type="date"
            error={errors.date?.message}
            {...form.register('date')}
          />
          <Controller
            control={form.control}
            name="status"
            render={({ field }) => (
              <RadioGroup
                legend={t('goals.contribute.status')}
                variant="cards"
                value={field.value}
                onChange={field.onChange}
                options={[
                  {
                    value: 'recorded',
                    label: t('goals.contribute.statusRecorded'),
                    description: t('goals.contribute.statusRecordedHelp'),
                  },
                  {
                    value: 'planned',
                    label: t('goals.contribute.statusPlanned'),
                    description: t('goals.contribute.statusPlannedHelp'),
                  },
                ]}
              />
            )}
          />
        </>
      )}
      <TextField
        label={t('goals.contribute.note')}
        optional
        maxLength={500}
        autoComplete="off"
        error={errors.note?.message}
        {...form.register('note')}
      />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={mutation.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={mutation.isPending}>
          {t('goals.contribute.submit')}
        </Button>
      </div>
    </form>
  );
}
