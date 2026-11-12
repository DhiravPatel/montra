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
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import { invalidateFinance } from '@/shared/finance/keys';
import type { Account, AdjustmentInput } from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { compareDecimal, negateDecimal, normalizeDecimalInput } from '@/shared/formatting/decimal';
import { isLocalDate, todayInTimeZone } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { accountsApi } from '../api';
import { AccountBalance } from './AccountBalance';
import { domainRuleMessage } from '@/shared/finance/domainErrors';

type Mode = 'target' | 'delta';

interface AdjustValues {
  mode: Mode;
  amount: string;
  reason: string;
  effectiveDate: string;
}

interface AdjustBalanceDialogProps {
  account: Account;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

/**
 * Manual balance correction (spec §20B.4): recorded by the API as an
 * auditable adjustment transaction with a reason, never an overwrite.
 */
export function AdjustBalanceDialog({ account, open, onOpenChange }: AdjustBalanceDialogProps) {
  const { t } = useI18n();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('accounts.adjust.title')}
      description={t('accounts.adjust.description')}
      busy={pending}
      size="lg"
    >
      {open ? (
        <AdjustForm
          account={account}
          onPendingChange={setPending}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

function AdjustForm({
  account,
  onDone,
  onPendingChange,
}: {
  account: Account;
  onDone: () => void;
  onPendingChange: (pending: boolean) => void;
}) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const currencies = useCurrencies();
  const idempotency = useIdempotencyKey();
  const [formError, setFormError] = useState<string | null>(null);
  const exponent = exponentFor(currencies.data, account.currency);
  const owes = account.is_liability;

  const schema = useMemo(
    () =>
      z
        .object({
          mode: z.enum(['target', 'delta']),
          amount: z.string(),
          reason: z
            .string()
            .trim()
            .min(3, { error: t('accounts.adjust.reasonRequired') })
            .max(500, { error: t('validation.maxLength', { max: 500 }) }),
          effectiveDate: z.string(),
        })
        .superRefine((values, ctx) => {
          checkAmount(ctx, {
            value: values.amount,
            path: 'amount',
            locale: formatLocale,
            currency: account.currency,
            exponent,
            allowZero: values.mode === 'target',
            // A liability's target is "what you owe now" (entered as a positive number).
            allowNegative: values.mode === 'delta' || !owes,
            t,
          });
          if (values.effectiveDate && !isLocalDate(values.effectiveDate)) {
            ctx.addIssue({
              code: 'custom',
              path: ['effectiveDate'],
              message: t('validation.dateInvalid'),
            });
          }
        }),
    [t, formatLocale, account.currency, exponent, owes],
  );

  const form = useForm<AdjustValues, unknown, AdjustValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      mode: 'target',
      amount: '',
      reason: '',
      effectiveDate: todayInTimeZone(user.timezone),
    },
  });
  const mode = useWatch({ control: form.control, name: 'mode' });

  const mutation = useMutation({
    mutationFn: (body: AdjustmentInput) => accountsApi.adjust(account.id, body, idempotency.key),
    onSuccess: () => {
      idempotency.renew();
      void invalidateFinance(queryClient);
    },
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending) return;
    setFormError(null);
    const parsed = normalizeDecimalInput(values.amount, formatLocale, {
      exponent,
      allowZero: values.mode === 'target',
      allowNegative: true,
    });
    if (!parsed.ok) return;
    let amount = parsed.value;
    if (values.mode === 'target' && owes) amount = negateDecimal(amount);
    if (values.mode === 'target' && compareDecimal(amount, account.balance.amount) === 0) {
      form.setError(
        'amount',
        { type: 'validate', message: t('accounts.adjust.alreadyMatches') },
        { shouldFocus: true },
      );
      return;
    }
    const body: AdjustmentInput = {
      reason: values.reason.trim(),
      ...(values.mode === 'target' ? { target_balance: amount } : { delta: amount }),
      ...(values.effectiveDate ? { effective_date: values.effectiveDate } : {}),
    };
    onPendingChange(true);
    try {
      await mutation.mutateAsync(body);
      onPendingChange(false);
      toast.show({ tone: 'success', title: t('accounts.adjust.done') });
      onDone();
    } catch (error) {
      onPendingChange(false);
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, {
          target_balance: 'amount',
          delta: 'amount',
          reason: 'reason',
          effective_date: 'effectiveDate',
        });
        if (rest.length > 0) setFormError(rest.join(' '));
      } else if (hasErrorCode(error, 'DOMAIN_RULE_VIOLATION')) {
        setFormError(domainRuleMessage(error, t, formatLocale) ?? t('accounts.adjust.notAllowed'));
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
      <div className="rounded-lg border border-line bg-surface-muted p-4">
        <p className="text-sm text-fg-muted">{t('accounts.adjust.current')}</p>
        <AccountBalance account={account} align="start" />
      </div>
      <Controller
        control={form.control}
        name="mode"
        render={({ field }) => (
          <RadioGroup<Mode>
            legend={t('accounts.adjust.mode')}
            value={field.value}
            onChange={field.onChange}
            variant="cards"
            options={[
              {
                value: 'target',
                label: t('accounts.adjust.modeTarget'),
                description: t('accounts.adjust.modeTargetHelp'),
              },
              {
                value: 'delta',
                label: t('accounts.adjust.modeDelta'),
                description: t('accounts.adjust.modeDeltaHelp'),
              },
            ]}
          />
        )}
      />
      <MoneyField
        label={
          mode === 'target'
            ? owes
              ? t('accounts.adjust.targetOwed')
              : t('accounts.adjust.target')
            : t('accounts.adjust.delta')
        }
        currency={account.currency}
        help={
          mode === 'delta'
            ? owes
              ? t('accounts.adjust.deltaOwedHelp')
              : t('accounts.adjust.deltaHelp')
            : undefined
        }
        error={errors.amount?.message}
        {...form.register('amount')}
      />
      <TextArea
        label={t('accounts.adjust.reason')}
        help={t('accounts.adjust.reasonHelp')}
        maxLength={500}
        rows={2}
        error={errors.reason?.message}
        {...form.register('reason')}
      />
      <TextField
        label={t('accounts.adjust.date')}
        type="date"
        optional
        error={errors.effectiveDate?.message}
        {...form.register('effectiveDate')}
      />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={mutation.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={mutation.isPending}>
          {t('accounts.adjust.submit')}
        </Button>
      </div>
    </form>
  );
}
